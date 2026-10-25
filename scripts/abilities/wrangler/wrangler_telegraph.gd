class_name WranglerTelegraph
extends MeshInstance3D
## A flat strip on the ground between two points, used to show where the pug is
## about to charge. Visual only.

const HEIGHT := 0.035

var _box: BoxMesh
var _mat: StandardMaterial3D


static func make(parent: Node) -> WranglerTelegraph:
	var t := WranglerTelegraph.new()
	parent.add_child(t)
	return t


func _ready() -> void:
	_box = BoxMesh.new()
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh = _box
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	visible = false


func set_ends(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var length := ProtoUtil.flat_distance(a, b)
	if length < 0.2:
		visible = false
		return
	visible = true
	_box.size = Vector3(width, 0.02, length)
	_mat.albedo_color = color
	var mid := (a + b) * 0.5
	global_position = Vector3(mid.x, HEIGHT, mid.z)
	var dir := b - a
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	look_at(Vector3(b.x, HEIGHT, b.z), Vector3.UP)
