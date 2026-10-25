class_name RopeLine
extends MeshInstance3D
## A rope drawn as a thin box stretched between two points. Visual only.
## Call set_ends() every frame while it should show. Used by Argonaut's Q and W.

const COLOR := Color(0.78, 0.64, 0.42)


## Creates a rope under `parent`. It stays hidden until set_ends() is called.
static func make(parent: Node) -> RopeLine:
	var r := RopeLine.new()
	parent.add_child(r)
	return r


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.06, 1.0)
	mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	visible = false


func set_ends(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.2:
		visible = false
		return
	visible = true
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var xf := Transform3D(Basis.IDENTITY, (a + b) * 0.5).looking_at(b, up)
	global_transform = xf.scaled_local(Vector3(1.0, 1.0, length))
