extends CharacterBody3D

const ANIM_FLY := "CharacterArmature|Fast_Flying"
const ANIM_IDLE := "CharacterArmature|Flying_Idle"
const ANIM_ATTACK := "CharacterArmature|Headbutt"
const ANIM_DEATH := "CharacterArmature|Death"

@export var definition: EntityDefinition
@export var rotation_speed: float = 8.0
@export var stop_distance: float = 1.5
@export var attack_range: float = 2.5
@export var attack_cooldown: float = 1.2

var player: CharacterBody3D
var attack_timer: float = 0.0
var stats: StatsComponent = null
var _current_anim: String = ""

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var visual_pivot: Node3D = $VisualPivot
@onready var health_bar: Node3D = $HealthBar
@onready var anim_player: AnimationPlayer = $VisualPivot/Pigeon/AnimationPlayer

func _ready() -> void:
	_setup_stats()
	player = get_tree().current_scene.get_node_or_null("Gnome") as CharacterBody3D
	if not player:
		push_error("BirdEnemy: Could not find Gnome player node!")
	_play_anim(ANIM_FLY)

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

func _physics_process(delta: float) -> void:
	if not player or stats.is_dead:
		return

	var speed := stats.get_movement_speed()
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
		elif _current_anim != ANIM_ATTACK:
			_play_anim(ANIM_IDLE)
		return

	nav.target_position = player.global_position

	if nav.is_navigation_finished():
		velocity = Vector3.ZERO
		move_and_slide()
		_play_anim(ANIM_IDLE)
		return

	var next_pos := nav.get_next_path_position()
	var dir := next_pos - global_position
	dir.y = 0.0

	if dir.length() < 0.01:
		_play_anim(ANIM_IDLE)
		return

	dir = dir.normalized()
	velocity = dir * speed
	move_and_slide()
	_play_anim(ANIM_FLY)

	visual_pivot.rotation.y = lerp_angle(
		visual_pivot.rotation.y,
		atan2(-dir.x, -dir.z),
		minf(rotation_speed * delta, 1.0)
	)

func _do_attack() -> void:
	var dir := _horizontal_direction_to(player.global_position)
	if dir == Vector3.ZERO:
		return

	_play_anim(ANIM_ATTACK)

	var player_stats: StatsComponent = null
	if player and player.has_node("Stats"):
		player_stats = player.get_node("Stats") as StatsComponent
	if player_stats:
		player_stats.take_physical_damage(stats.get_attack_damage(), self)

func _horizontal_direction_to(target_position: Vector3) -> Vector3:
	var dir := target_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return dir.normalized()

func _play_anim(anim_name: String) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	if _current_anim == anim_name and anim_player.is_playing():
		return
	_current_anim = anim_name
	anim_player.stop()
	if anim_name == ANIM_DEATH or anim_name == ANIM_ATTACK:
		anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_NONE
	else:
		anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	anim_player.play(anim_name)

func _on_died() -> void:
	$CollisionShape3D.set_deferred("disabled", true)
	if nav:
		nav.set_deferred("avoidance_enabled", false)
	_play_anim(ANIM_DEATH)
	if anim_player and anim_player.has_animation(ANIM_DEATH):
		var death_length := anim_player.get_animation(ANIM_DEATH).length
		await get_tree().create_timer(death_length).timeout
	queue_free()

func _on_health_changed(current: float, _max_hp: float) -> void:
	if health_bar:
		health_bar.current_health = current
