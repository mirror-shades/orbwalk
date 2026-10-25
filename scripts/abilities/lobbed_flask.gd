class_name LobbedFlask
extends Node3D
## A bottle thrown in an arc to a spot on the ground. Emits `landed` when it hits.
## Optionally shows a warning circle at the landing spot while it's in the air.

signal landed(pos: Vector3)

var from := Vector3.ZERO
var to := Vector3.ZERO
var flight_time: float = 0.6
var arc_height: float = 3.0
var color: Color = Color(1.0, 0.5, 0.2)
var size: float = 0.25
## Radius of the warning circle at the landing spot (0 = none).
var warning_radius: float = 0.0

var _t: float = 0.0
var _bottle: Node3D
var _warning: MeshInstance3D


## Creates and launches a flask under `parent`.
static func throw(parent: Node, p_from: Vector3, p_to: Vector3, p_flight_time: float, p_color: Color, p_size: float = 0.25, p_warning_radius: float = 0.0) -> LobbedFlask:
	var f := LobbedFlask.new()
	f.from = p_from
	f.to = p_to
	f.flight_time = maxf(p_flight_time, 0.05)
	f.color = p_color
	f.size = p_size
	f.warning_radius = p_warning_radius
	f.arc_height = clampf(AbilityUtil.flat_distance(p_from, p_to) * 0.35, 1.5, 6.0)
	parent.add_child(f)
	f.global_position = p_from
	return f


func _ready() -> void:
	_bottle = Node3D.new()
	add_child(_bottle)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = color
	glass.emission_enabled = true
	glass.emission = color * 0.5
	var body := SphereMesh.new()
	body.radius = size
	body.height = size * 2.0
	_add_mesh(body, Vector3.ZERO, glass)
	var neck := CylinderMesh.new()
	neck.top_radius = size * 0.3
	neck.bottom_radius = size * 0.35
	neck.height = size * 1.1
	var cork := StandardMaterial3D.new()
	cork.albedo_color = Color(0.55, 0.4, 0.25)
	_add_mesh(neck, Vector3(0.0, size * 1.2, 0.0), cork)

	if warning_radius > 0.0:
		var disc := CylinderMesh.new()
		disc.top_radius = warning_radius
		disc.bottom_radius = warning_radius
		disc.height = 0.02
		disc.radial_segments = 48
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color, 0.25)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_warning = MeshInstance3D.new()
		_warning.mesh = disc
		_warning.material_override = mat
		_warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_warning.top_level = true
		add_child(_warning)
		_warning.global_position = Vector3(to.x, 0.04, to.z)


func _add_mesh(mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bottle.add_child(mi)


func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / flight_time, 0.0, 1.0)
	var p := from.lerp(to, k)
	p.y = lerpf(from.y, to.y, k) + arc_height * 4.0 * k * (1.0 - k)
	global_position = p
	_bottle.rotation.z += delta * 10.0
	if k >= 1.0:
		landed.emit(Vector3(to.x, 0.0, to.z))
		queue_free()
