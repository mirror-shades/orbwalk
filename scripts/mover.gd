extends Entity

@export var stop_distance: float = 0.5
## Once an auto-attack has started, its damage lands even if the target keeps
## running: the swing follows through up to this many meters past attack range.
## Only a real escape (a dash/blink further than this) cancels the swing, and that
## cancels without using up the attack cooldown. Ordered moves still cancel swings.
@export var attack_follow_through: float = 3.0

@onready var models: Node3D = $Models
@onready var idle_model: Node3D = $Models/idle_model
@onready var run_model: Node3D = $Models/run_model
@onready var attack_model: Node3D = $Models/attack_model

var _target: Vector3
var _moving: bool = false

var _attacking: bool = false
var _in_attack_range: bool = false
var _attack_winding_down: bool = false

func _on_entity_ready() -> void:
	run_model.hide()
	attack_model.hide()

# ---- Orders ----
# Called by ProtoGame.execute_command() (from the local PlayerController or a bot).
# Input is never read here: see player_controller.gd.

## True while the unit is walking to a point or chasing a target.
func is_moving() -> bool:
	return _moving


## Walk to `pos`, dropping any attack target.
func order_move(pos: Vector3) -> void:
	_stop_attacking()
	_target = Vector3(pos.x, 0.0, pos.z)
	_moving = true


## Chase and auto-attack `target`. Returns "" or why it can't.
func order_attack(target: Node) -> String:
	if not can_target(target):
		return "You can't attack that."
	_begin_attack_target(target as CharacterBody3D)
	return ""


## Stand still.
func order_stop() -> void:
	_stop_attacking()
	_stop_moving()


## True if `node` is something this champion may auto-attack: a living, visible enemy.
func can_target(node: Node) -> bool:
	if node == null or node == self or not node is CharacterBody3D or not is_instance_valid(node):
		return false
	var ts := EntityData.get_stats_of(node)
	return ts != null and not ts.is_dead and EntityData.is_enemy(stats.get_team(), ts.get_team()) 			and FogOfWar.can_see(stats.get_team(), node)


func _begin_attack_target(target: CharacterBody3D) -> void:
	set_attack_target(target)
	_attacking = true
	_moving = true
	_target = target.global_position
	_target.y = 0.0

func _stop_attacking() -> void:
	_attacking = false
	_in_attack_range = false
	_attack_winding_down = false
	clear_attack_target()
	if attack_model.visible:
		attack_model.hide()

func _validate_attack_target() -> void:
	if _attack_winding_down:
		return
	if not _attack_target:
		return
	if not is_attack_target_valid():
		if attack_model.visible and is_attack_anim_active():
			_attack_winding_down = true
			return
		_stop_attacking()
		_stop_moving()

func _on_feared(dir: Vector3, delta: float) -> void:
	if _attacking:
		_stop_attacking()
	_moving = false
	_show_running(dir, delta)

func _on_stunned(_delta: float) -> void:
	_moving = false
	if not idle_model.visible:
		attack_model.hide()
		run_model.hide()
		idle_model.show()
		_start_anim(idle_model)

## Turns the model toward `dir`, unless a volley is locking its facing.
func _turn_model(dir: Vector3, delta: float) -> void:
	if firing_lock:
		return
	models.rotation.y = lerp_angle(models.rotation.y, atan2(-dir.x, -dir.z), minf(rotation_speed * delta, 1.0))

func _on_forced_move(dir: Vector3, delta: float) -> void:
	_show_running(dir, delta)

func _on_forced_move_started() -> void:
	# A dash cancels a plain move order but keeps chasing an attack target.
	if not _attacking:
		_moving = false

func _show_running(dir: Vector3, delta: float) -> void:
	if not run_model.visible:
		idle_model.hide()
		attack_model.hide()
		run_model.show()
		_start_anim(run_model)
	_turn_model(dir, delta)

func _scan_for_nearby_enemy() -> void:
	var scan_range := stats.get_attack_range() + 0.75
	var best_target: CharacterBody3D = null
	var best_dist: float = INF

	for node in EntityData.get_enemies_of(stats.get_team()):
		if not is_instance_valid(node) or not node is CharacterBody3D or not FogOfWar.can_see(stats.get_team(), node):
			continue
		var dist := global_position.distance_to(node.global_position)
		if dist <= scan_range and dist < best_dist:
			best_target = node
			best_dist = dist

	if best_target:
		_begin_attack_target(best_target)

func _physics_process(delta: float) -> void:
	if stats.is_dead:
		velocity = Vector3.ZERO
		return

	# Fear and dashes take over movement; attack cooldowns keep ticking.
	if process_crowd_control(delta):
		_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
		return

	var speed := stats.get_movement_speed()

	_validate_attack_target()
	var damage_now := process_attack(delta)

	if not _attacking and not _moving:
		_scan_for_nearby_enemy()

	if _attacking and _attack_target:
		_chase_and_attack(delta, speed, damage_now)
		return

	if not _moving:
		velocity = Vector3.ZERO
		attack_model.hide()
		run_model.hide()
		if not idle_model.visible:
			idle_model.show()
			_start_anim(idle_model)
		return

	# Rooted: hold position instead of walking.
	if status_effects() != null and status_effects().is_rooted():
		velocity = Vector3.ZERO
		move_and_slide()
		attack_model.hide()
		run_model.hide()
		if not idle_model.visible:
			idle_model.show()
			_start_anim(idle_model)
		return

	var move_vel := navigate_toward(_target, speed, stop_distance)
	if move_vel == Vector3.ZERO:
		_stop_moving()
		return

	if not run_model.visible:
		idle_model.hide()
		run_model.show()
		_start_anim(run_model)

	velocity = move_vel
	move_and_slide()

	_turn_model(move_vel, delta)

func _chase_and_attack(delta: float, speed: float, damage_now: bool) -> void:
	if _attack_winding_down:
		velocity = Vector3.ZERO
		move_and_slide()
		if not is_attack_anim_active():
			attack_model.hide()
			idle_model.show()
			_start_anim(idle_model)
			_attack_target = null
			_attacking = false
			_in_attack_range = false
			_attack_winding_down = false
			_stop_moving()
		return

	_target = _attack_target.global_position

	var dist := global_position.distance_to(_attack_target.global_position)
	var attack_range := stats.get_attack_range()

	# A started swing commits: resolve it wherever the target is now.
	if damage_now:
		_resolve_attack_damage(dist, attack_range)

	# The windup roots the attacker: no chasing until the damage point, so a swing
	# can't be started in range and then landed on the run. After the damage point
	# the backswing can be walked out of as usual.
	if is_attack_anim_active() and not _damage_dealt_this_swing:
		velocity = Vector3.ZERO
		move_and_slide()
		face_position(_attack_target.global_position, models, delta)
		return

	if _in_attack_range and dist > attack_range + 1.0:
		_in_attack_range = false
	elif not _in_attack_range and dist <= attack_range:
		_in_attack_range = true

	if _in_attack_range:
		velocity = Vector3.ZERO
		move_and_slide()

		face_position(_attack_target.global_position, models, delta)

		if not is_attack_anim_active() and (attack_model.visible or run_model.visible):
			attack_model.hide()
			run_model.hide()
			idle_model.show()
			_start_anim(idle_model)

		if can_attack():
			start_attack_cooldown()
			_do_attack()

		return

	# Rooted: can't close the gap. Hold still and keep facing the target.
	if status_effects() != null and status_effects().is_rooted():
		velocity = Vector3.ZERO
		move_and_slide()
		face_position(_attack_target.global_position, models, delta)
		attack_model.hide()
		run_model.hide()
		if not idle_model.visible:
			idle_model.show()
			_start_anim(idle_model)
		return

	var move_vel := navigate_toward(_target, speed, 0.0)
	if move_vel == Vector3.ZERO:
		return

	if not run_model.visible:
		idle_model.hide()
		attack_model.hide()
		run_model.show()
		_start_anim(run_model)

	velocity = move_vel
	move_and_slide()

	_turn_model(move_vel, delta)

## The damage point of a started swing. It follows through as long as the target is
## within attack range plus the follow-through reach; only a bigger escape cancels
## it. A cancelled swing refunds its cooldown: chasing a runner never costs a full
## attack.
func _resolve_attack_damage(dist: float, attack_range: float) -> void:
	if _attack_target and is_instance_valid(_attack_target) and dist <= attack_range + attack_follow_through:
		deal_attack_damage()
	else:
		_cancel_attack_swing()


## Ends a swing that was escaped from, without the cooldown penalty.
func _cancel_attack_swing() -> void:
	_attack_anim_time = 0.0
	_damage_proc_timer = 0.0
	_damage_dealt_this_swing = false
	_attack_cooldown_timer = 0.0
	attack_model.hide()


func _do_attack() -> void:
	if not _attack_target or not is_instance_valid(_attack_target):
		return

	break_stealth()
	idle_model.hide()
	run_model.hide()
	attack_model.show()

	var anim := attack_model.get_node("AnimationPlayer") as AnimationPlayer
	var anim_name := _anim_name(attack_model)
	if anim and anim.has_animation(anim_name):
		anim.stop()
		var a := anim.get_animation(anim_name)
		a.loop_mode = Animation.LOOP_NONE
		# Speed the swing up if it's longer than the time between attacks.
		var interval := 1.0 / maxf(stats.get_attack_speed(), 0.01)
		var speed_scale := maxf(1.0, a.length / interval)
		anim.play(anim_name, -1.0, speed_scale)
		begin_attack_anim(a.length / speed_scale, 0.5)
	else:
		begin_attack_anim(0.3, 0.5)

func _start_anim(model: Node3D) -> void:
	var anim := model.get_node("AnimationPlayer") as AnimationPlayer
	var anim_name := _anim_name(model)
	if anim and anim.has_animation(anim_name):
		anim.stop()
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		anim.play(anim_name)

## Which animation a model plays. Models with one clip use "Take 001"; models with
## many clips (like the Cleric) name theirs with an "anim" metadata entry on the node.
func _anim_name(model: Node3D) -> String:
	return str(model.get_meta("anim", "Take 001"))

func _stop_moving() -> void:
	_moving = false
	velocity = Vector3.ZERO
	attack_model.hide()
	run_model.hide()
	if not idle_model.visible:
		idle_model.show()
		_start_anim(idle_model)

func _on_entity_died() -> void:
	_stop_attacking()
	_stop_moving()
