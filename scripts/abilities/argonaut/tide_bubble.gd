class_name TideBubble
extends Node3D
## The healing bubble from Argonaut's passive. Starts at the marked enemy, flies to
## the nearest allied champion within range and heals them, then bounces to the
## nearest other allied champion within range of that one. Each ally is healed once.
## If nobody is in range for a hop, it pops and disappears.

const COLOR := Color(0.55, 0.9, 1.0)
const HEAL_COLOR := Color(0.4, 1.0, 0.7)

var team: int = 0
var heal: float = 60.0
var hops_left: int = 2
var bounce_range: float = 4.0
var speed: float = 12.0

var _target: Node3D
var _healed: Dictionary = {}


## Sends a bubble out from `from` (the marked enemy). Does nothing if no ally is in range.
static func launch(parent: Node, p_team: int, from: Vector3, p_heal: float, p_hops: int, p_range: float, p_speed: float) -> void:
	var b := TideBubble.new()
	b.team = p_team
	b.heal = p_heal
	b.hops_left = p_hops
	b.bounce_range = p_range
	b.speed = p_speed
	b._target = b._next_ally(parent.get_tree(), from)
	if b._target == null:
		b.free()
		return
	parent.add_child(b)
	b.global_position = from + Vector3(0.0, 1.3, 0.0)


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(COLOR, 0.65)
	mat.emission_enabled = true
	mat.emission = COLOR * 0.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _physics_process(delta: float) -> void:
	if not _alive(_target):
		queue_free()
		return
	var aim := _target.global_position + Vector3(0.0, 1.3, 0.0)
	var to := aim - global_position
	var step := speed * delta
	if to.length() > step:
		global_position += to.normalized() * step
		return
	global_position = aim
	_heal_target()
	hops_left -= 1
	_target = _next_ally(get_tree(), _target.global_position) if hops_left > 0 else null
	if _target == null:
		queue_free()


func _heal_target() -> void:
	var st := _target.get_node_or_null("Stats") as StatsComponent
	st.heal(heal)
	_healed[_target.get_instance_id()] = true
	AbilityUtil.pop_text(get_tree().current_scene, _target.global_position + Vector3(0.0, 2.8, 0.0), "+%d" % roundi(heal), HEAL_COLOR, 36)


## The nearest living allied champion within range of `from` that this bubble hasn't healed.
func _next_ally(tree: SceneTree, from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for body in AbilityUtil.allies_in_radius(tree, team, from, bounce_range):
		if _healed.has(body.get_instance_id()):
			continue
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st.get_entity_type() != EntityDefinition.EntityType.CHAMPION:
			continue
		var d := AbilityUtil.flat_distance(from, body.global_position)
		if d < best_d:
			best_d = d
			best = body
	return best


func _alive(n: Node3D) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var st := n.get_node_or_null("Stats") as StatsComponent
	return st != null and not st.is_dead
