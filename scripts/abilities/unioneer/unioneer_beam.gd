class_name UnioneerBeam
extends MeshInstance3D

var color: Color = Color(0.35, 0.75, 1.0)


static func make(parent: Node, p_color: Color) -> UnioneerBeam:
	var beam := UnioneerBeam.new()
	beam.color = p_color
	parent.add_child(beam)
	return beam


static func flash(parent: Node, a: Vector3, b: Vector3, p_color: Color, duration: float = 0.3) -> void:
	var beam := make(parent, p_color)
	beam.set_ends(a, b)
	var tw := beam.create_tween()
	tw.tween_property(beam, "transparency", 1.0, duration)
	tw.tween_callback(beam.queue_free)


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.09, 0.09, 1.0)
	mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.95)
	mat.emission_enabled = true
	mat.emission = color * 0.9
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	visible = false


func set_ends(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		visible = false
		return
	visible = true
	global_transform = Transform3D(Basis.IDENTITY, (a + b) * 0.5).looking_at(b, Vector3.UP).scaled_local(Vector3(1.0, 1.0, length))
