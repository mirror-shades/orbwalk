extends Node3D

enum State {INIT, IDLE, RUN, ATTACK}

var current_state: State = State.INIT
@onready var idle_model = $idle_model
@onready var run_model = $run_model
@onready var attack_model = $attack_model
@onready var movement_root: Node3D = get_parent() as Node3D
@onready var movement_body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var navigation_agent: NavigationAgent3D = movement_root.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
@export var move_speed: float = 6
@export var rotation_speed: float = 10.0
@export var click_ray_length: float = 1000.0
@export var stop_distance: float = 0.15

var target_position: Vector3
var has_target: bool = false

var _click_indicator: MeshInstance3D

func _ready():
	if navigation_agent:
		navigation_agent.path_desired_distance = stop_distance
		navigation_agent.target_desired_distance = stop_distance
		navigation_agent.max_speed = move_speed
		await get_tree().process_frame
		var map_rid := navigation_agent.get_navigation_map()
		print("NavAgent map RID: ", map_rid, " | regions on map: ", NavigationServer3D.map_get_regions(map_rid).size())

	run_model.hide()
	attack_model.hide()
	change_state(State.IDLE)

func _ensure_click_indicator() -> MeshInstance3D:
	if _click_indicator:
		return _click_indicator

	var disc := CylinderMesh.new()
	disc.top_radius = 0.35
	disc.bottom_radius = 0.35
	disc.height = 0.02

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.2, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_click_indicator = MeshInstance3D.new()
	_click_indicator.name = "ClickIndicator"
	_click_indicator.mesh = disc
	_click_indicator.material_override = mat
	_click_indicator.visible = false

	get_tree().current_scene.add_child(_click_indicator)
	return _click_indicator

func _show_click_at(pos: Vector3) -> void:
	var indicator := _ensure_click_indicator()
	indicator.global_position = Vector3(pos.x, 0.04, pos.z)
	indicator.scale = Vector3.ZERO
	indicator.visible = true

	var tw := create_tween()
	tw.tween_property(indicator, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(indicator, "scale", Vector3.ZERO, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): indicator.visible = false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			return

		var from := camera.project_ray_origin(event.position)
		var to := from + camera.project_ray_normal(event.position) * click_ray_length
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.has("position"):
			target_position = hit["position"]
			if navigation_agent:
				navigation_agent.target_position = target_position
			has_target = true
			_show_click_at(target_position)

func _physics_process(delta):
	if not has_target:
		stop_movement()
		if current_state == State.RUN:
			change_state(State.IDLE)
		return

	var to_target := target_position - movement_root.global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= stop_distance:
		has_target = false
		if current_state == State.RUN:
			change_state(State.IDLE)
		return

	if current_state == State.IDLE:
		change_state(State.RUN)

	var move_dir := get_move_direction()
	if move_dir == Vector3.ZERO:
		stop_movement()
		return

	handle_movement(move_dir)
	handle_rotation(delta, move_dir)

func change_state(new_state: State) -> void:
	if new_state == current_state:
		return
		
	# Hide current model
	match current_state:
		State.IDLE: idle_model.hide()
		State.RUN: run_model.hide()
	
	# Show and animate new model
	current_state = new_state
	var model = idle_model if new_state == State.IDLE else run_model
	model.show()
	var anim_player = model.get_node("AnimationPlayer")
	anim_player.stop()
	anim_player.get_animation("Take 001").loop_mode = Animation.LOOP_LINEAR
	anim_player.play("Take 001")

func get_move_direction() -> Vector3:
	var next_position := target_position
	if navigation_agent and not navigation_agent.is_navigation_finished():
		next_position = navigation_agent.get_next_path_position()
		if Engine.get_process_frames() % 120 == 0:
			print("Following nav path — next waypoint: ", next_position)

	var move_dir := next_position - movement_root.global_position
	move_dir.y = 0.0
	if move_dir.length() <= 0.001:
		move_dir = target_position - movement_root.global_position
		move_dir.y = 0.0

	if move_dir.length() <= 0.001:
		return Vector3.ZERO

	return move_dir.normalized()

func handle_movement(move_dir: Vector3) -> void:
	if movement_body:
		movement_body.velocity = move_dir * move_speed
		movement_body.move_and_slide()
	else:
		movement_root.global_position += move_dir * move_speed * get_physics_process_delta_time()

func stop_movement() -> void:
	if movement_body:
		movement_body.velocity = Vector3.ZERO

func handle_rotation(delta: float, move_dir: Vector3) -> void:
	# Rotate to face movement direction
	var local_move_dir := movement_root.global_transform.basis.inverse() * move_dir
	var target_rotation := atan2(local_move_dir.x, local_move_dir.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func is_moving() -> bool:
	return has_target
