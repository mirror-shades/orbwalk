class_name FanBullet
extends Node3D
## One bullet from Fan the Hammer. Flies straight, ignores towers and the orb,
## and stops at the first living enemy it touches. It can crit and counts as an
## attack landing (on-hit item effects), but doesn't proc Hair Trigger.

var team: int = 0
var damage: float = 0.0
var speed: float = 26.0
var width: float = 1.0
var color: Color = Color(1.0, 0.88, 0.5)
var source_id: int = 0

var _dir := Vector3.RIGHT
var _max_distance: float = 10.0
var _travelled: float = 0.0


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.55)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


## Call after adding to the scene: starts the bullet from `from`, in `direction`,
## and frees it after `distance`.
func launch(from: Vector3, direction: Vector3, distance: float) -> void:
	global_position = from
	_dir = Vector3(direction.x, 0.0, direction.z)
	if _dir.length_squared() < 0.0001:
		_dir = Vector3.RIGHT
	_dir = _dir.normalized()
	_max_distance = distance
	look_at(global_position + _dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	var prev := global_position
	var next := prev + _dir * speed * delta
	var hit := _first_hit(prev, next)
	if hit:
		_damage(hit)
		queue_free()
		return
	global_position = next
	_travelled += speed * delta
	if _travelled >= _max_distance:
		queue_free()


## The closest enemy whose body the segment a-b touches, or null.
func _first_hit(a: Vector3, b: Vector3) -> Node3D:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var len2 := ab.length_squared()
	if len2 < 0.000001:
		return null
	var center := (a + b) * 0.5
	var reach := Vector2(ab).length() * 0.5 + width + 2.0
	var best: Node3D = null
	var best_t := INF
	for body in AbilityUtil.enemies_in_radius(get_tree(), team, center, reach):
		var ap := Vector2(body.global_position.x - a.x, body.global_position.z - a.z)
		var t := ap.dot(ab) / len2
		if t < 0.0 or t > 1.0:
			continue
		if (ap - ab * t).length() > width * 0.5 + AbilityUtil.unit_radius(body):
			continue
		if t < best_t:
			best_t = t
			best = body
	return best


func _damage(body: Node3D) -> void:
	var st := EntityData.get_stats_of(body)
	if st == null:
		return
	var source := instance_from_id(source_id) as Entity if source_id != 0 else null
	var crit := 1.0
	if source and source.stats:
		crit = source.stats.roll_crit()
	var dealt := damage * crit
	st.take_physical_damage(dealt, source)
	if crit > 1.0:
		AbilityUtil.pop_text(body.get_parent(), body.global_position + Vector3(0.0, 2.4, 0.0), "%d!" % roundi(dealt), Color(1.0, 0.35, 0.2), 48)
	if source and is_instance_valid(source):
		source.emit_ability_hit(body)
