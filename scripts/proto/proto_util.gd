class_name ProtoUtil
extends RefCounted
## Small helpers shared by the prototype scripts.


## Scales `model` so it is `height` tall, stands on y = 0 and is centered on x/z.
## `max_width` (optional) keeps wide models inside a footprint.
static func fit_model(model: Node3D, height: float, max_width: float = 0.0) -> void:
	var box := local_aabb(model)
	if box.size.y <= 0.0001:
		return
	var s := height / box.size.y
	if max_width > 0.0:
		var footprint := maxf(box.size.x, box.size.z)
		if footprint > 0.0001:
			s = minf(s, max_width / footprint)
	var c := box.get_center()
	model.scale = Vector3.ONE * s
	model.position = Vector3(-c.x * s, -box.position.y * s, -c.z * s)


## Bounding box of every mesh under `root`, in `root`'s own space.
## Works before the node is added to the scene tree.
static func local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for n in root.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		var box: AABB = _transform_to(vi, root) * vi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


static func _transform_to(node: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func lit_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m


## A flat colored ring lying on the ground.
static func make_ring(radius: float, color: Color, thickness: float = 0.12) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius - thickness, 0.01)
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.material_override = flat_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1.0, 0.15, 1.0)
	mi.position.y = 0.05
	return mi


## Text that floats up and fades out, e.g. "+20g".
static func float_text(parent: Node, world_pos: Vector3, text: String, color: Color, font_size: int = 40) -> void:
	if not AbilityUtil.SHOW_FLOATING_TEXT:
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
	label.global_position = world_pos
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position", world_pos + Vector3(0.0, 1.6, 0.0), 1.1)
	tw.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)


static func find_anim_player(root: Node) -> AnimationPlayer:
	var found := root.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return null
	return found[0] as AnimationPlayer


## Distance on the ground plane (ignores height).
static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
