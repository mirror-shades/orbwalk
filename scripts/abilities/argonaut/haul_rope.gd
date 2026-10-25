class_name HaulRope
extends Node3D
## Argonaut's Q rope. Flies out in a straight line and stops at the first enemy
## champion or mercenary it touches. That enemy is damaged and dragged to just in
## front of the thrower. On a miss (max range) the rope reels back in and
## disappears. Towers and the orb don't block it.

signal hooked(target: Node3D)

enum State { OUT, PULLING, RETURN }

const RETURN_SPEED := 40.0

var thrower: Node3D
var team: int = 0
var damage: float = 60.0
var width: float = 0.7
var max_range: float = 9.0
var speed: float = 22.0
var pull_speed: float = 18.0
var dir := Vector3.RIGHT

var state: State = State.OUT
var _travelled: float = 0.0
var _target: Node3D
var _hook: MeshInstance3D
var _line: RopeLine


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.4)
	mat.metallic = 0.7
	_hook = MeshInstance3D.new()
	_hook.mesh = sphere
	_hook.material_override = mat
	_hook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hook)
	_line = RopeLine.make(self)


func _physics_process(delta: float) -> void:
	if not _thrower_alive():
		queue_free()
		return
	match state:
		State.OUT:
			_fly(delta)
		State.PULLING:
			_follow_target()
		State.RETURN:
			_reel_back(delta)
	if is_instance_valid(self) and not is_queued_for_deletion():
		_line.set_ends(_hand(), global_position)


func _fly(delta: float) -> void:
	var step := minf(speed * delta, max_range - _travelled)
	var prev := global_position
	global_position += dir * step
	_travelled += step
	var hit := _first_enemy_on(prev, global_position)
	if hit:
		_hook_target(hit)
		return
	if _travelled >= max_range - 0.001:
		state = State.RETURN


func _hook_target(body: Node3D) -> void:
	var st := body.get_node_or_null("Stats") as StatsComponent
	st.take_physical_damage(damage, thrower)
	hooked.emit(body)
	if st.is_dead:
		state = State.RETURN
		return
	_target = body
	state = State.PULLING
	var fx := body.get_node_or_null("StatusEffects") as StatusEffects
	if fx == null:
		state = State.RETURN
		return
	# Just in front of him, on the side the rope went out.
	var gap := AbilityUtil.unit_radius(thrower) + AbilityUtil.unit_radius(body) + 0.3
	var dest := thrower.global_position + dir * gap
	dest = DashAbility.clip_to_navmesh(body, body.global_position, dest)
	fx.start_forced_move(dest, pull_speed)


## While the target is dragged, the hook rides on it. Done when the drag ends.
func _follow_target() -> void:
	if not is_instance_valid(_target):
		queue_free()
		return
	global_position = _target.global_position + Vector3(0.0, 1.0, 0.0)
	var st := _target.get_node_or_null("Stats") as StatsComponent
	var fx := _target.get_node_or_null("StatusEffects") as StatusEffects
	if st == null or st.is_dead or fx == null or not fx.is_movement_locked():
		queue_free()


func _reel_back(delta: float) -> void:
	var to := _hand() - global_position
	var step := RETURN_SPEED * delta
	if to.length() <= step:
		queue_free()
		return
	global_position += to.normalized() * step


## The closest-to-the-thrower enemy champion or mercenary touching the segment a→b.
func _first_enemy_on(a: Vector3, b: Vector3) -> Node3D:
	var best: Node3D = null
	var best_t := INF
	for node in get_tree().get_nodes_in_group("entity"):
		if not (node is Node3D) or node == thrower:
			continue
		var st := node.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead or st.invulnerable:
			continue
		var kind := st.get_entity_type()
		if kind != EntityDefinition.EntityType.CHAMPION and kind != EntityDefinition.EntityType.MINION:
			continue
		if not EntityData.is_enemy(team, st.get_team()):
			continue
		var body := node as Node3D
		var p := body.global_position
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(p.x - a.x, p.z - a.z)
		var len2 := ab.length_squared()
		var t := 0.0 if len2 < 0.000001 else clampf(ap.dot(ab) / len2, 0.0, 1.0)
		if (ap - ab * t).length() > width * 0.5 + AbilityUtil.unit_radius(body):
			continue
		if t < best_t:
			best_t = t
			best = body
	return best


func _hand() -> Vector3:
	return thrower.global_position + Vector3(0.0, 1.0, 0.0)


func _thrower_alive() -> bool:
	if not is_instance_valid(thrower):
		return false
	var st := thrower.get_node_or_null("Stats") as StatsComponent
	return st != null and not st.is_dead
