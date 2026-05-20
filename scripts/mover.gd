extends CharacterBody3D

const SWING_POINT_RATIO: float = 0.35

@export var definition: EntityDefinition
@export var rotation_speed: float = 10.0
@export var click_ray_length: float = 1000.0
@export var stop_distance: float = 0.5

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var models: Node3D = $Models
@onready var idle_model: Node3D = $Models/idle_model
@onready var run_model: Node3D = $Models/run_model
@onready var attack_model: Node3D = $Models/attack_model
@onready var health_bar: Node3D = $HealthBar

var stats: StatsComponent = null

var _target: Vector3
var _moving: bool = false
var _indicator: MeshInstance3D
var _path_mesh: ImmediateMesh
var _path_instance: MeshInstance3D

var _attack_target: CharacterBody3D = null
var _attacking: bool = false
var _in_attack_range: bool = false
var _attack_cooldown_timer: float = 0.0
var _attack_anim_time: float = 0.0
var _damage_proc_timer: float = 0.0
var _damage_dealt_this_swing: bool = false

func _ready() -> void:
	_setup_stats()
	run_model.hide()
	attack_model.hide()
	collision_layer = 3
	_setup_path_line()

func _setup_stats() -> void:
	stats = $Stats if has_node("Stats") else StatsComponent.new()
	if not stats.is_inside_tree():
		stats.name = "Stats"
		add_child(stats)
	stats.initialize(definition)
	stats.health_changed.connect(_on_health_changed)
	stats.died.connect(_on_died)
	if health_bar:
		health_bar.max_health = stats.get_max_health()
		health_bar.current_health = stats.current_health

func _unhandled_input(event: InputEvent) -> void:
	if stats.is_dead:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var camera := get_viewport().get_camera_3d()
		if not camera:
			return
		var origin := camera.project_ray_origin(event.position)
		var dir := camera.project_ray_normal(event.position)

		var t := -origin.y / dir.y
		if t > 0.0:
			_target = origin + dir * t
		else:
			_target = origin + dir * click_ray_length
		_target.y = 0.0

		var world := get_world_3d()
		if world:
			var space_state := world.direct_space_state
			if space_state:
				var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * click_ray_length)
				query.collision_mask = 2
				var result := space_state.intersect_ray(query)
				if not result.is_empty():
					var target := _find_attackable_target(result.collider)
					if target:
						_set_attack_target(target)
						return

		_clear_attack_target()
		if nav:
			_target = NavigationServer3D.map_get_closest_point(nav.get_navigation_map(), _target)
			nav.target_position = _target
		_moving = true
		_show_indicator(_target)

func _find_attackable_target(collider) -> CharacterBody3D:
	var node := collider as Node
	while node:
		if node is CharacterBody3D and node != self and node.is_in_group("enemy"):
			for child in node.get_children():
				if child is StatsComponent and not child.is_dead:
					return node
		node = node.get_parent()
	return null

func _set_attack_target(target: CharacterBody3D) -> void:
	_attack_target = target
	_attacking = true
	_moving = true
	_target = target.global_position
	_target.y = 0.0
	if nav:
		nav.target_position = _target
	_show_indicator(_target)

func _clear_attack_target() -> void:
	if _attacking and not _damage_dealt_this_swing:
		_attack_cooldown_timer = 0.0
	_attack_target = null
	_attacking = false
	_in_attack_range = false
	_attack_anim_time = 0.0
	_damage_proc_timer = 0.0
	_damage_dealt_this_swing = false
	if attack_model.visible:
		attack_model.hide()

func _physics_process(delta: float) -> void:
	if stats.is_dead:
		velocity = Vector3.ZERO
		return

	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)

	var speed := stats.get_movement_speed()

	_validate_attack_target()

	if _attacking and _attack_target:
		_chase_and_attack(delta, speed)
		return

	if not _moving:
		velocity = Vector3.ZERO
		attack_model.hide()
		run_model.hide()
		if not idle_model.visible:
			idle_model.show()
			_start_anim(idle_model)
		_update_path_line()
		return

	var next_pos: Vector3 = _target
	if nav:
		if nav.is_navigation_finished():
			_stop_moving()
			return
		next_pos = nav.get_next_path_position()

	var move_dir: Vector3 = next_pos - global_position
	move_dir.y = 0.0

	if move_dir.length() < 0.01:
		if not nav:
			move_dir = _target - global_position
			move_dir.y = 0.0
		else:
			velocity = Vector3.ZERO
			_update_path_line()
			return

	if not nav and move_dir.length() <= stop_distance:
		_stop_moving()
		return

	move_dir = move_dir.normalized()

	if not run_model.visible:
		idle_model.hide()
		run_model.show()
		_start_anim(run_model)

	velocity = move_dir * speed
	move_and_slide()

	models.rotation.y = lerp_angle(models.rotation.y, atan2(-move_dir.x, -move_dir.z), rotation_speed * delta)
	_update_path_line()

func _validate_attack_target() -> void:
	if not _attack_target:
		_clear_attack_target()
		return
	if not is_instance_valid(_attack_target):
		_clear_attack_target()
		_stop_moving()
		return
	var target_stats: StatsComponent = _attack_target.get_node_or_null("Stats")
	if not target_stats or target_stats.is_dead:
		_clear_attack_target()
		_stop_moving()

func _chase_and_attack(delta: float, speed: float) -> void:
	if nav:
		nav.target_position = _attack_target.global_position
	_target = _attack_target.global_position

	var dist := global_position.distance_to(_attack_target.global_position)
	var attack_range := stats.get_attack_range()

	if _in_attack_range and dist > attack_range + 1.0:
		_in_attack_range = false
	elif not _in_attack_range and dist <= attack_range:
		_in_attack_range = true

	if _in_attack_range:
		velocity = Vector3.ZERO
		move_and_slide()

		var face_dir := _horizontal_direction_to(_attack_target.global_position)
		if face_dir != Vector3.ZERO:
			models.rotation.y = lerp_angle(
				models.rotation.y,
				atan2(-face_dir.x, -face_dir.z),
				rotation_speed * delta
			)

		_attack_anim_time = maxf(_attack_anim_time - delta, 0.0)
		if _attack_anim_time <= 0.0 and (attack_model.visible or run_model.visible):
			attack_model.hide()
			run_model.hide()
			idle_model.show()
			_start_anim(idle_model)

		_damage_proc_timer = maxf(_damage_proc_timer - delta, 0.0)
		if _damage_proc_timer <= 0.0 and not _damage_dealt_this_swing:
			_damage_dealt_this_swing = true
			var target_stats: StatsComponent = _attack_target.get_node_or_null("Stats")
			if target_stats:
				target_stats.take_physical_damage(stats.get_attack_damage(), self)

		if _attack_cooldown_timer <= 0.0 and dist <= attack_range:
			_attack_cooldown_timer = 1.0 / stats.get_attack_speed()
			_do_attack()

		_update_path_line()
		return

	var next_pos: Vector3 = _target
	if nav:
		if nav.is_navigation_finished():
			return
		next_pos = nav.get_next_path_position()

	var move_dir := next_pos - global_position
	move_dir.y = 0.0

	if move_dir.length() < 0.01:
		velocity = Vector3.ZERO
		_update_path_line()
		return

	move_dir = move_dir.normalized()

	if not run_model.visible:
		idle_model.hide()
		attack_model.hide()
		run_model.show()
		_start_anim(run_model)

	velocity = move_dir * speed
	move_and_slide()

	models.rotation.y = lerp_angle(
		models.rotation.y,
		atan2(-move_dir.x, -move_dir.z),
		rotation_speed * delta
	)
	_update_path_line()

func _do_attack() -> void:
	if not _attack_target or not is_instance_valid(_attack_target):
		return

	idle_model.hide()
	run_model.hide()
	attack_model.show()

	var anim := attack_model.get_node("AnimationPlayer") as AnimationPlayer
	if anim and anim.has_animation("Take 001"):
		anim.stop()
		var a := anim.get_animation("Take 001")
		a.loop_mode = Animation.LOOP_NONE
		anim.play("Take 001")
		_attack_anim_time = a.length
		_damage_proc_timer = a.length * SWING_POINT_RATIO
	else:
		_attack_anim_time = 0.3
		_damage_proc_timer = 0.3 * SWING_POINT_RATIO

	_damage_dealt_this_swing = false

func _horizontal_direction_to(target_pos: Vector3) -> Vector3:
	var dir := target_pos - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return dir.normalized()

func _show_indicator(pos: Vector3) -> void:
	if not _indicator:
		var disc := CylinderMesh.new()
		disc.top_radius = 0.35
		disc.bottom_radius = 0.35
		disc.height = 0.02
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.9, 0.2, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_indicator = MeshInstance3D.new()
		_indicator.name = "ClickIndicator"
		_indicator.mesh = disc
		_indicator.material_override = mat
		_indicator.visible = false
		get_tree().current_scene.add_child(_indicator)

	_indicator.global_position = Vector3(pos.x, 0.05, pos.z)
	_indicator.scale = Vector3.ZERO
	_indicator.visible = true
	var tw := create_tween()
	tw.tween_property(_indicator, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(_indicator, "scale", Vector3.ZERO, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _indicator.visible = false)

func _setup_path_line() -> void:
	_path_instance = MeshInstance3D.new()
	_path_instance.name = "PathLine"
	_path_mesh = ImmediateMesh.new()
	_path_instance.mesh = _path_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.0, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_path_instance.material_override = mat
	get_tree().current_scene.add_child.call_deferred(_path_instance)

func _update_path_line() -> void:
	if not _path_mesh:
		return
	_path_mesh.clear_surfaces()

	if not _moving:
		_path_instance.visible = false
		return

	_path_instance.visible = true
	_path_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	var offset := Vector3(0, 0.5, 0)

	if nav:
		var nav_path := nav.get_current_navigation_path()
		if nav_path.size() > 1:
			for pt in nav_path:
				_path_mesh.surface_add_vertex(pt + offset)
			_path_mesh.surface_end()
			return

	_path_mesh.surface_add_vertex(global_position + offset)
	_path_mesh.surface_add_vertex(_target + offset)
	_path_mesh.surface_end()

func _start_anim(model: Node3D) -> void:
	var anim := model.get_node("AnimationPlayer") as AnimationPlayer
	if anim and anim.has_animation("Take 001"):
		anim.stop()
		anim.get_animation("Take 001").loop_mode = Animation.LOOP_LINEAR
		anim.play("Take 001")

func _stop_moving() -> void:
	_moving = false
	velocity = Vector3.ZERO
	attack_model.hide()
	run_model.hide()
	if not idle_model.visible:
		idle_model.show()
		_start_anim(idle_model)
	_update_path_line()

func _on_health_changed(current: float, _max_hp: float) -> void:
	if health_bar:
		health_bar.current_health = current

func _on_died() -> void:
	_clear_attack_target()
	_attack_cooldown_timer = 0.0
	_stop_moving()
	$CollisionShape3D.set_deferred("disabled", true)
	if nav:
		nav.set_deferred("avoidance_enabled", false)
