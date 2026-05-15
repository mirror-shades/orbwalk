extends CharacterBody3D

@export var move_speed: float = 6.0
@export var rotation_speed: float = 10.0
@export var stop_distance: float = 0.5

@onready var idle_model: Node3D = $Models/idle_model
@onready var run_model: Node3D = $Models/run_model
@onready var models: Node3D = $Models

var _target: Vector3
var _moving: bool = false

func _ready() -> void:
	run_model.hide()
	$Models/attack_model.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var camera := get_viewport().get_camera_3d()
		if not camera:
			return
		var from := camera.project_ray_origin(event.position)
		var to := from + camera.project_ray_normal(event.position) * 1000.0
		var query := PhysicsRayQueryParameters3D.create(from, to)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.has("position"):
			_target = hit["position"]
			_moving = true

func _physics_process(delta: float) -> void:
	if not _moving:
		velocity = Vector3.ZERO
		if run_model.visible:
			run_model.hide()
			idle_model.show()
			_start_anim(idle_model)
		return

	var dir: Vector3 = _target - global_position
	dir.y = 0.0

	if dir.length() <= stop_distance:
		_moving = false
		velocity = Vector3.ZERO
		if run_model.visible:
			run_model.hide()
			idle_model.show()
			_start_anim(idle_model)
		return

	dir = dir.normalized()

	if not run_model.visible:
		idle_model.hide()
		run_model.show()
		_start_anim(run_model)

	velocity = dir * move_speed
	move_and_slide()

	models.rotation.y = lerp_angle(models.rotation.y, atan2(-dir.x, -dir.z), rotation_speed * delta)

func _start_anim(model: Node3D) -> void:
	var anim := model.get_node("AnimationPlayer") as AnimationPlayer
	if anim and anim.has_animation("Take 001"):
		anim.stop()
		anim.get_animation("Take 001").loop_mode = Animation.LOOP_LINEAR
		anim.play("Take 001")
