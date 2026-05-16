extends CharacterBody3D

@export var move_speed: float = 4.0
@export var rotation_speed: float = 8.0
@export var stop_distance: float = 1.5
@export var attack_range: float = 2.5
@export var attack_cooldown: float = 1.2
@export var attack_stop_distance: float = 0.7
@export var attack_lunge_height: float = 0.3

var player: CharacterBody3D
var attack_timer: float = 0.0
var attack_tween: Tween

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var visual_pivot: Node3D = $VisualPivot

func _ready() -> void:
	player = get_tree().current_scene.get_node_or_null("Gnome") as CharacterBody3D
	if not player:
		push_error("BirdEnemy: Could not find Gnome player node!")

func _physics_process(delta: float) -> void:
	if not player:
		return

	var dist := global_position.distance_to(player.global_position)

	if dist <= attack_range:
		velocity = Vector3.ZERO
		move_and_slide()

		var face_dir := _horizontal_direction_to(player.global_position)
		if face_dir != Vector3.ZERO:
			visual_pivot.rotation.y = lerp_angle(
				visual_pivot.rotation.y,
				atan2(-face_dir.x, -face_dir.z),
				minf(rotation_speed * delta, 1.0)
			)

		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = attack_cooldown
			_do_attack()
		return

	nav.target_position = player.global_position

	if nav.is_navigation_finished():
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var next_pos := nav.get_next_path_position()
	var dir := next_pos - global_position
	dir.y = 0.0

	if dir.length() < 0.01:
		return

	dir = dir.normalized()
	velocity = dir * move_speed
	move_and_slide()

	visual_pivot.rotation.y = lerp_angle(
		visual_pivot.rotation.y,
		atan2(-dir.x, -dir.z),
		minf(rotation_speed * delta, 1.0)
	)

func _do_attack() -> void:
	var dir := _horizontal_direction_to(player.global_position)
	if dir == Vector3.ZERO:
		return

	if attack_tween:
		attack_tween.kill()

	var dist := global_position.distance_to(player.global_position)
	var lunge_dist: float = clamp(dist - attack_stop_distance, 0.0, attack_range)
	var lunge_pos := dir * lunge_dist + Vector3.UP * attack_lunge_height

	attack_tween = create_tween()
	attack_tween.tween_property(visual_pivot, "position", lunge_pos, 0.1).set_ease(Tween.EASE_OUT)
	attack_tween.parallel().tween_property(visual_pivot, "scale", Vector3(1.4, 1.4, 1.4), 0.1).set_ease(Tween.EASE_OUT)
	attack_tween.tween_property(visual_pivot, "position", Vector3.ZERO, 0.15).set_ease(Tween.EASE_IN)
	attack_tween.parallel().tween_property(visual_pivot, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_IN)

func _horizontal_direction_to(target_position: Vector3) -> Vector3:
	var dir := target_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return dir.normalized()
