extends Node3D

@export var move_speed: float = 6.0
@export var rotation_speed: float = 10.0
@export var click_ray_length: float = 1000.0
@export var stop_distance: float = 0.5

@onready var body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var nav: NavigationAgent3D = body.get_node("NavigationAgent3D") as NavigationAgent3D
@onready var idle_model: Node3D = $idle_model
@onready var run_model: Node3D = $run_model

var _target: Vector3
var _moving: bool = false
var _right_held: bool = false
var _indicator: MeshInstance3D

func _ready() -> void:
	if nav:
		nav.path_desired_distance = 0.3
		nav.target_desired_distance = stop_distance
		nav.max_speed = move_speed
		await get_tree().process_frame
		print("NavAgent map RID: ", nav.get_navigation_map())

	run_model.hide()
	$attack_model.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_right_held = true
			_set_target(event.position)
		else:
			_right_held = false

func _physics_process(delta: float) -> void:
	if _right_held:
		_set_target(get_viewport().get_mouse_position())

	if not _moving:
		body.velocity = Vector3.ZERO
		if run_model.visible:
			run_model.hide()
			idle_model.show()
			_play_anim(idle_model)
		return

	var to_target: Vector3 = _target - body.global_position
	to_target.y = 0.0
	if to_target.length() <= stop_distance:
		_moving = false
		body.velocity = Vector3.ZERO
		if run_model.visible:
			run_model.hide()
			idle_model.show()
			_play_anim(idle_model)
		return

	var next_pos: Vector3 = _target
	if nav and not nav.is_navigation_finished():
		next_pos = nav.get_next_path_position()

	var dir: Vector3 = next_pos - body.global_position
	dir.y = 0.0

	if dir.length() < 0.01:
		dir = _target - body.global_position
		dir.y = 0.0

	if dir.length() < 0.01:
		return

	dir = dir.normalized()

	if not run_model.visible:
		idle_model.hide()
		run_model.show()
		_play_anim(run_model)

	body.velocity = dir * move_speed
	body.move_and_slide()

	var local_dir := body.global_transform.basis.inverse() * dir
	rotation.y = lerp_angle(rotation.y, atan2(local_dir.x, local_dir.z), rotation_speed * delta)

func _set_target(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * click_ray_length
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if hit.has("position"):
		_target = hit["position"]
		if nav:
			nav.target_position = _target
		_moving = true
		_show_indicator(_target)

func _play_anim(model: Node3D) -> void:
	var anim := model.get_node("AnimationPlayer") as AnimationPlayer
	if anim and anim.has_animation("Take 001"):
		anim.stop()
		anim.get_animation("Take 001").loop_mode = Animation.LOOP_LINEAR
		anim.play("Take 001")

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
