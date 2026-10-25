class_name WranglerPet
extends CharacterBody3D
## The Wrangler's pug. It is part of her kit, not a targetable unit: it has no
## Stats, never joins the "entity" group, and can't be targeted or killed. It
## moves on its own, chasing after her along the navmesh, and only acts when one
## of her abilities tells it to.
##
## States are one job at a time. A new command replaces the old one (E and R are
## allowed to override anything; Q is refused while the pug is charging). The
## pounce and latch logic live in the abilities; this node only handles where the
## pug is, what it looks like, and how it gets there.

enum State { FOLLOW, LEAP, LATCHED, WAIT, CHARGE }

const MODEL_PATH := "res://assets/models/minions/pug/Pug.gltf"
const MODEL_HEIGHT := 1.15
## Where he appears after a respawn or a long teleport (relative to her facing).
const FOLLOW_OFFSET := Vector3(1.1, 0.0, 0.25)
## He settles this far from her, on whichever side he's already on.
const FOLLOW_DIST := 1.6
## He starts chasing once she gets this far away...
const CHASE_START := 2.6
## ...and steps aside if she ends up standing on him.
const TOO_CLOSE := 0.8
## He hesitates briefly when she runs off, then chases.
const FOLLOW_DELAY := 0.18
## Chasing: a bit faster than her, plus extra per unit he's behind, capped.
const CHASE_SPEED_MULT := 1.15
const CHASE_CATCHUP := 1.5
const FOLLOW_MAX_SPEED := 18.0
## Trotting the last few units in once she has stopped.
const WALK_SPEED := 2.6
const WALK_RANGE := 4.0
const LEASH_RANGE := 12.0
## Further than this (a recall or respawn) he just appears beside her.
const TELEPORT_RANGE := 30.0
## Ask for a new path when the goal moves this much, or this often.
const REPATH_MOVE := 0.4
const REPATH_TIME := 0.25
const GIANT_SCALE := 2.5

var owner_entity: Entity
var state: State = State.FOLLOW
## Bumped by every new command. Abilities can tell whether their command is still
## the one the pug is following.
var command_id: int = 0
## Set by E during its wait, so the pug counts as charging even while it's
## still finishing a Q latch.
var heel_pending := false

var _model: Node3D
var _anim: AnimationPlayer
var _current_anim: String = ""
var _base_scale := Vector3.ONE
var _giant := false

var _target: Node3D
var _leap_speed := 20.0
var _leap_arrived: Callable
var _wait_left := 0.0
var _wait_done: Callable
var _charge_to := Vector3.ZERO
var _charge_speed := 20.0
var _charge_done: Callable

var _follow_wait := 0.0
var _chasing := false
var _still_time := 0.0
var _last_owner_pos := Vector3.ZERO

var _path := PackedVector3Array()
var _path_idx := 0
var _path_goal := Vector3.INF
var _repath_left := 0.0


func _ready() -> void:
	# Part of the Wrangler's kit, not a physics unit: it never collides.
	collision_layer = 0
	collision_mask = 0
	# He's her child (so abilities can find him and he's freed with her), but he
	# moves through the world on his own instead of being carried with her.
	top_level = true
	if owner_entity:
		global_position = _follow_point()
		_last_owner_pos = owner_entity.global_position
	_build_model()


func _build_model() -> void:
	var ps := load(MODEL_PATH) as PackedScene
	if ps == null:
		return
	_model = ps.instantiate() as Node3D
	ProtoUtil.fit_model(_model, MODEL_HEIGHT)
	_base_scale = _model.scale
	add_child(_model)
	_anim = ProtoUtil.find_anim_player(_model)
	_play("Idle", true)


# ---- Commands ----

## Follow her again. Drops any pending leap, wait or charge.
func follow() -> void:
	_clear_callbacks()
	command_id += 1
	state = State.FOLLOW
	_follow_wait = 0.0
	_chasing = false
	_clear_path()
	if owner_entity and is_instance_valid(owner_entity):
		_last_owner_pos = owner_entity.global_position


## Leap onto `target`, then call `on_arrive` (if it's still the current command).
func leap_to_target(target: Node3D, speed: float, on_arrive: Callable) -> void:
	_clear_callbacks()
	command_id += 1
	_target = target
	_leap_speed = speed
	_leap_arrived = on_arrive
	state = State.LEAP
	_play("Jump", false)


## Sit on `target` until the command is replaced.
func latch_to(target: Node3D) -> void:
	_clear_callbacks()
	command_id += 1
	_target = target
	state = State.LATCHED
	_play("Idle", true)


## Hold still for `duration`, then call `on_done` (E's delay before the charge).
func wait_for(duration: float, on_done: Callable = Callable()) -> int:
	_clear_callbacks()
	command_id += 1
	_wait_left = maxf(duration, 0.0)
	_wait_done = on_done
	state = State.WAIT
	_play("Idle", true)
	return command_id


## Charge in a straight line to `to`, then call `on_done` (E and R).
func start_charge(to: Vector3, speed: float, on_done: Callable = Callable()) -> int:
	_clear_callbacks()
	command_id += 1
	_charge_to = Vector3(to.x, global_position.y, to.z)
	_charge_speed = speed
	_charge_done = on_done
	state = State.CHARGE
	_play("Roll", true)
	return command_id


func set_giant(on: bool) -> void:
	_giant = on
	if _model:
		_model.scale = _base_scale * (GIANT_SCALE if on else 1.0)


func bite() -> void:
	_play("Punch", false)


func _clear_callbacks() -> void:
	_leap_arrived = Callable()
	_wait_done = Callable()
	_charge_done = Callable()


# ---- Queries ----

func is_following() -> bool:
	return state == State.FOLLOW


## True while E or R has the pug (or E is about to send it, even if it's still
## latched on a Q target until then). Q can't be cast meanwhile.
func is_charging() -> bool:
	return heel_pending or state == State.WAIT or state == State.CHARGE


func is_latched_to(target: Node) -> bool:
	return state == State.LATCHED and _target == target and is_instance_valid(_target)


func position() -> Vector3:
	return global_position


# ---- Tick ----

func _physics_process(delta: float) -> void:
	if owner_entity == null or not is_instance_valid(owner_entity):
		queue_free()
		return
	var st := owner_entity.stats
	if st == null:
		return
	if st.is_dead:
		visible = false
		if state != State.FOLLOW:
			follow()
		global_position = _follow_point()
		_play("Idle", true)
		return
	visible = true
	match state:
		State.FOLLOW:
			_tick_follow(delta)
		State.LEAP:
			_tick_leap(delta)
		State.LATCHED:
			_tick_latched()
		State.WAIT:
			_tick_wait(delta)
		State.CHARGE:
			_tick_charge(delta)


## He chases her like a dog: sits while she's close, runs after her when she
## leaves, and settles on his own side of her rather than a fixed spot. Paths
## around walls and towers, so he finds his way back after being sent off.
func _tick_follow(delta: float) -> void:
	var owner_pos := owner_entity.global_position
	var owner_moving := ProtoUtil.flat_distance(owner_pos, _last_owner_pos) > 0.01
	_last_owner_pos = owner_pos
	var dist := ProtoUtil.flat_distance(global_position, owner_pos)

	if dist > TELEPORT_RANGE:
		global_position = _follow_point()
		_chasing = false
		_clear_path()
		_play("Idle", true)
		return

	if not _chasing and (dist > CHASE_START or dist < TOO_CLOSE):
		_chasing = true
		# A beat before he reacts, unless he's been left far behind.
		_follow_wait = FOLLOW_DELAY if dist <= LEASH_RANGE else 0.0

	var moved := false
	var walking := false
	if _chasing:
		if _follow_wait > 0.0:
			_follow_wait -= delta
		else:
			var goal := _settle_point(owner_pos)
			walking = not owner_moving and dist <= WALK_RANGE
			var speed := WALK_SPEED
			if not walking:
				var her_speed := owner_entity.stats.get_movement_speed()
				speed = clampf(her_speed * CHASE_SPEED_MULT + maxf(dist - CHASE_START, 0.0) * CHASE_CATCHUP,
					her_speed, FOLLOW_MAX_SPEED)
			moved = _move_along_path(goal, speed, delta)
			# Caught up while she's still walking: keep trotting along with her.
			if not moved and not owner_moving:
				_chasing = false
				_clear_path()

	if _giant and dist <= 2.5:
		set_giant(false)
	# Don't flick to Idle for a single frame where he happened not to move.
	_still_time = 0.0 if moved else _still_time + delta
	if moved:
		_play("Walk" if walking else "Run", true)
	elif _still_time > 0.12:
		_play("Idle", true)


func _tick_leap(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		follow()
		return
	var st := _target.get_node_or_null("Stats") as StatsComponent
	if st == null or st.is_dead:
		follow()
		return
	var to := _target.global_position
	var reach := AbilityUtil.unit_radius(_target) + 0.45
	if ProtoUtil.flat_distance(global_position, to) <= reach:
		var cb := _leap_arrived
		_leap_arrived = Callable()
		if cb.is_valid():
			cb.call()
		if state == State.LEAP:
			follow()
		return
	_move_toward(to, _leap_speed, delta)


func _tick_latched() -> void:
	if _target == null or not is_instance_valid(_target):
		follow()
		return
	var st := _target.get_node_or_null("Stats") as StatsComponent
	if st == null or st.is_dead:
		follow()
		return
	var to := _target.global_position + Vector3(0.55, 0.0, 0.55)
	global_position = Vector3(to.x, 0.0, to.z)
	if _anim and not _anim.is_playing():
		_play("Idle", true)


func _tick_wait(delta: float) -> void:
	_wait_left -= delta
	if _wait_left > 0.0:
		return
	var cb := _wait_done
	_wait_done = Callable()
	if cb.is_valid():
		cb.call()


func _tick_charge(delta: float) -> void:
	var to := _charge_to - global_position
	to.y = 0.0
	var step := _charge_speed * delta
	if to.length() <= step:
		global_position = Vector3(_charge_to.x, 0.0, _charge_to.z)
		var cb := _charge_done
		_charge_done = Callable()
		if cb.is_valid():
			cb.call()
		if state == State.CHARGE:
			follow()
		return
	global_position += to.normalized() * step
	_face(to)


# ---- Helpers ----

func _move_toward(to: Vector3, speed: float, delta: float) -> bool:
	var dir := to - global_position
	dir.y = 0.0
	var dist := dir.length()
	if dist < 0.08:
		return false
	var step := minf(speed * delta, dist)
	global_position += dir / dist * step
	_face(dir)
	return true


## The spot he wants beside her: FOLLOW_DIST from her, on the side he's on now,
## so he trails behind when she walks away and doesn't swing round as she turns.
func _settle_point(owner_pos: Vector3) -> Vector3:
	var side := global_position - owner_pos
	side.y = 0.0
	var p: Vector3
	if side.length_squared() < 0.01:
		p = _follow_point()
	else:
		p = owner_pos + side.normalized() * FOLLOW_DIST
	return _snap_to_nav(p)


## Walks the navmesh path toward `goal`. Returns false once he's there.
func _move_along_path(goal: Vector3, speed: float, delta: float) -> bool:
	if ProtoUtil.flat_distance(global_position, goal) < 0.15:
		return false
	_repath_left -= delta
	if _path.is_empty() or _repath_left <= 0.0 or ProtoUtil.flat_distance(goal, _path_goal) > REPATH_MOVE:
		_repath(goal)
	var step := speed * delta
	var moved := false
	while step > 0.0 and _path_idx < _path.size():
		var wp := _path[_path_idx]
		var dir := wp - global_position
		dir.y = 0.0
		var d := dir.length()
		if d <= step:
			global_position = Vector3(wp.x, global_position.y, wp.z)
			step -= d
			_path_idx += 1
			moved = moved or d > 0.001
			continue
		global_position += dir / d * step
		_face(dir)
		return true
	return moved


func _repath(goal: Vector3) -> void:
	_path_goal = goal
	_repath_left = REPATH_TIME
	_path_idx = 0
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		_path = PackedVector3Array([goal])
		return
	_path = NavigationServer3D.map_get_path(map, global_position, goal, true)
	if _path.is_empty():
		_path = PackedVector3Array([goal])
	# The first point is where he already stands.
	elif _path.size() > 1 and ProtoUtil.flat_distance(_path[0], global_position) < 0.3:
		_path_idx = 1


func _clear_path() -> void:
	_path = PackedVector3Array()
	_path_idx = 0
	_path_goal = Vector3.INF


func _snap_to_nav(p: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return p
	var c := NavigationServer3D.map_get_closest_point(map, p)
	return Vector3(c.x, p.y, c.z)


func _follow_point() -> Vector3:
	var models := owner_entity.get_node_or_null("Models") as Node3D
	if models == null:
		return owner_entity.global_position + FOLLOW_OFFSET
	var basis := models.global_basis
	var offset := basis * FOLLOW_OFFSET
	offset.y = 0.0
	return owner_entity.global_position + offset


## The pug model faces +Z, like the minions.
func _face(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	rotation.y = atan2(dir.x, dir.z)


func _play(anim_name: String, loop: bool) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if loop and _current_anim == anim_name and _anim.is_playing():
		return
	_current_anim = anim_name
	var a := _anim.get_animation(anim_name)
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_anim.stop()
	_anim.play(anim_name)
