extends "res://scripts/entity.gd"

const ANIM_FLY := "CharacterArmature|Fast_Flying"
const ANIM_IDLE := "CharacterArmature|Flying_Idle"
const ANIM_ATTACK := "CharacterArmature|Headbutt"
const ANIM_DEATH := "CharacterArmature|Death"

const SWING_RATIO: float = 0.35

var _current_anim: String = ""

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var visual_pivot: Node3D = $VisualPivot
@onready var anim_player: AnimationPlayer = $VisualPivot/Pigeon/AnimationPlayer

func _on_entity_ready() -> void:
	_play_anim(ANIM_FLY)

func _physics_process(delta: float) -> void:
	if stats.is_dead:
		return

	var damage_now := process_attack(delta)

	if not is_attack_target_valid():
		_acquire_target()

	if not _attack_target:
		velocity = Vector3.ZERO
		move_and_slide()
		_play_anim(ANIM_IDLE)
		return

	var speed := stats.get_movement_speed()
	var dist := global_position.distance_to(_attack_target.global_position)
	var atk_range := stats.get_attack_range()

	if dist <= atk_range:
		velocity = Vector3.ZERO
		move_and_slide()
		face_position(_attack_target.global_position, visual_pivot, delta)

		if not is_attack_anim_active() and _current_anim == ANIM_ATTACK:
			_play_anim(ANIM_IDLE)

		if can_attack():
			start_attack_cooldown()
			_do_attack()
		elif _current_anim != ANIM_ATTACK:
			_play_anim(ANIM_IDLE)

		if damage_now:
			deal_attack_damage()
		return

	nav.target_position = _attack_target.global_position

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

	face_position(next_pos, visual_pivot, delta)

func _acquire_target() -> void:
	var nearest := EntityData.get_nearest_enemy(global_position, stats.get_team())
	if nearest and nearest is CharacterBody3D:
		set_attack_target(nearest)

func _do_attack() -> void:
	if not _attack_target:
		return
	var dir := _horizontal_direction_to(_attack_target.global_position)
	if dir == Vector3.ZERO:
		return

	_play_anim(ANIM_ATTACK)

	var anim_length: float = 0.0
	if anim_player and anim_player.has_animation(ANIM_ATTACK):
		anim_length = anim_player.get_animation(ANIM_ATTACK).length
	begin_attack_anim(anim_length, SWING_RATIO)

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

func _on_entity_died() -> void:
	_play_anim(ANIM_DEATH)
	if anim_player and anim_player.has_animation(ANIM_DEATH):
		var death_length := anim_player.get_animation(ANIM_DEATH).length
		await get_tree().create_timer(death_length).timeout
	queue_free()
