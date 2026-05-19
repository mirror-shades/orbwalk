extends CharacterBody3D

@export var definition: EntityDefinition
@export var rotation_speed: float = 10.0
@export var click_ray_length: float = 1000.0
@export var stop_distance: float = 0.5

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var models: Node3D = $Models
@onready var idle_model: Node3D = $Models/idle_model
@onready var run_model: Node3D = $Models/run_model
@onready var health_bar: Node3D = $HealthBar

var stats: StatsComponent = null

var _target: Vector3
var _moving: bool = false
var _indicator: MeshInstance3D
var _path_mesh: ImmediateMesh
var _path_instance: MeshInstance3D

func _ready() -> void:
	_setup_stats()
	run_model.hide()
	$Models/attack_model.hide()
	_setup_path_line()

func _setup_stats() -> void:
	stats = $Stats if has_node("Stats") else StatsComponent.new()
	if not stats.is_inside_tree():
		stats.name = "Stats"
		add_child(stats)
	stats.initialize(definition)
	stats.health_changed.connect(_on_health_changed)
	if health_bar:
		health_bar.max_health = stats.get_max_health()
		health_bar.current_health = stats.current_health

func _unhandled_input(event: InputEvent) -> void:
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
		if nav:
			_target = NavigationServer3D.map_get_closest_point(nav.get_navigation_map(), _target)
			nav.target_position = _target
		_moving = true
		_show_indicator(_target)

func _physics_process(delta: float) -> void:
	var speed := stats.get_movement_speed()

	if not _moving:
		velocity = Vector3.ZERO
		if run_model.visible:
			run_model.hide()
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

	var dir: Vector3 = next_pos - global_position
	dir.y = 0.0

	if dir.length() < 0.01:
		if not nav:
			dir = _target - global_position
			dir.y = 0.0
		else:
			velocity = Vector3.ZERO
			_update_path_line()
			return

	if not nav and dir.length() <= stop_distance:
		_stop_moving()
		return

	dir = dir.normalized()

	if not run_model.visible:
		idle_model.hide()
		run_model.show()
		_start_anim(run_model)

	velocity = dir * speed
	move_and_slide()

	models.rotation.y = lerp_angle(models.rotation.y, atan2(-dir.x, -dir.z), rotation_speed * delta)
	_update_path_line()

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
	if run_model.visible:
		run_model.hide()
		idle_model.show()
		_start_anim(idle_model)
	_update_path_line()

func _on_health_changed(current: float, _max_hp: float) -> void:
	if health_bar:
		health_bar.current_health = current
