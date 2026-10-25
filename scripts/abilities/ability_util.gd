class_name AbilityUtil
extends RefCounted
## Small helpers for abilities: area queries, range clamping, and simple effects.

## Floating text in the world (damage / heal / gold numbers, ability shouts like
## "Bash!"). Off to keep the screen clean; set true to bring it all back.
const SHOW_FLOATING_TEXT := false


## Living enemies of `team` within `radius` of `center` (champions, mercenaries,
## monsters). Towers and the orb are never included. Unit size counts toward reach.
static func enemies_in_radius(tree: SceneTree, team: int, center: Vector3, radius: float) -> Array[Node3D]:
	return _units_in_radius(tree, team, center, radius, true)


## Living allies of `team` (including the caster) within `radius` of `center`. No structures.
static func allies_in_radius(tree: SceneTree, team: int, center: Vector3, radius: float) -> Array[Node3D]:
	return _units_in_radius(tree, team, center, radius, false)


static func _units_in_radius(tree: SceneTree, team: int, center: Vector3, radius: float, enemies: bool) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in tree.get_nodes_in_group("entity"):
		if not (node is Node3D):
			continue
		var st := node.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead:
			continue
		var kind := st.get_entity_type()
		if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB:
			continue
		var is_enemy := EntityData.is_enemy(team, st.get_team())
		if is_enemy != enemies:
			continue
		if enemies and st.invulnerable:
			continue
		var body := node as Node3D
		if flat_distance(body.global_position, center) <= radius + unit_radius(body):
			out.append(body)
	return out


## Living enemies of `team` inside an arc: within `reach` of `center` (plus unit size),
## and within `angle_deg` total width around `facing` (e.g. 120 = 60 each side).
static func enemies_in_arc(tree: SceneTree, team: int, center: Vector3, facing: Vector3, reach: float, angle_deg: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var f := Vector2(facing.x, facing.z)
	if f.length_squared() < 0.0001:
		f = Vector2(1.0, 0.0)
	f = f.normalized()
	var half := deg_to_rad(angle_deg) * 0.5
	for body in enemies_in_radius(tree, team, center, reach):
		var to := Vector2(body.global_position.x - center.x, body.global_position.z - center.z)
		# Units right on top of the center always count.
		if to.length() <= unit_radius(body) or absf(f.angle_to(to)) <= half:
			out.append(body)
	return out


static func unit_radius(body: Node3D) -> float:
	var cs := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs:
		var s := absf(cs.scale.x)
		if cs.shape is CapsuleShape3D:
			return (cs.shape as CapsuleShape3D).radius * s
		if cs.shape is CylinderShape3D:
			return (cs.shape as CylinderShape3D).radius * s
	return 0.5


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Flat distance from `p` to the ground-plane segment a-b.
static func segment_distance_xz(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var len2 := ab.length_squared()
	var t := 0.0 if len2 < 0.000001 else clampf(ap.dot(ab) / len2, 0.0, 1.0)
	return (ap - ab * t).length()


## `to`, pulled back toward `from` so it's at most `max_range` away. y is set to 0.
static func clamp_to_range(from: Vector3, to: Vector3, max_range: float) -> Vector3:
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if d.length() > max_range:
		d = d.normalized() * max_range
	return Vector3(from.x + d.x, 0.0, from.z + d.z)


## Clips a straight spell's travel to the lane when the caster belongs to the
## prototype game. Towers and the orb don't block spells, so this ignores the navmesh.
static func clip_spell_to_lane(caster: Node, from: Vector3, to: Vector3) -> Vector3:
	var game: Variant = caster.get_parent() if caster else null
	if game == null or not game.has_method("clip_spell_to_lane"):
		return to
	var clipped: Variant = game.clip_spell_to_lane(from, to)
	return clipped if clipped is Vector3 else to


## A colored ring that expands to `radius` on the ground and fades.
static func ring_flash(parent: Node, center: Vector3, radius: float, color: Color) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 64
	torus.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = Vector3(center.x, 0.1, center.z)
	ring.scale = Vector3(0.4, 0.15, 0.4)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius, 0.15, radius), 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "transparency", 1.0, 0.45).set_delay(0.15)
	tw.chain().tween_callback(ring.queue_free)


## A flat fan on the ground showing an arc attack: `reach` long, `angle_deg` wide, facing `facing`. Fades out.
static func arc_flash(parent: Node, center: Vector3, facing: Vector3, reach: float, angle_deg: float, color: Color) -> void:
	var f := Vector2(facing.x, facing.z)
	if f.length_squared() < 0.0001:
		f = Vector2(1.0, 0.0)
	var start := f.angle() - deg_to_rad(angle_deg) * 0.5
	var steps := 16
	var verts := PackedVector3Array()
	for i in steps:
		var a0 := start + deg_to_rad(angle_deg) * float(i) / float(steps)
		var a1 := start + deg_to_rad(angle_deg) * float(i + 1) / float(steps)
		verts.append(Vector3.ZERO)
		verts.append(Vector3(cos(a1) * reach, 0.0, sin(a1) * reach))
		verts.append(Vector3(cos(a0) * reach, 0.0, sin(a0) * reach))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fan := MeshInstance3D.new()
	fan.mesh = mesh
	fan.material_override = mat
	fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fan)
	fan.global_position = Vector3(center.x, 0.08, center.z)
	var tw := fan.create_tween()
	tw.tween_property(fan, "transparency", 1.0, 0.35).set_delay(0.08)
	tw.tween_callback(fan.queue_free)


## Text that floats up and fades out.
static func pop_text(parent: Node, pos: Vector3, text: String, color: Color, font_size: int = 40) -> void:
	if not SHOW_FLOATING_TEXT:
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.outline_size = 10
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	parent.add_child(label)
	label.global_position = pos
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position", pos + Vector3(0.0, 1.3, 0.0), 1.0)
	tw.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)
