class_name GooPatch
extends Node3D
## A patch of goo on the ground. Enemies standing in it are slowed; the slow
## ends as soon as they step out. Left behind by the Potion Seller's R.

const TICK := 0.2

var team: int = 0
var radius: float = 3.5
var duration: float = 3.0
var slow: float = 0.8
var slow_id: String = "ps_goo"
var color: Color = Color(0.6, 0.85, 0.2, 0.55)

var _time_left: float = 0.0
var _tick_left: float = 0.0


func _ready() -> void:
	_time_left = duration
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.radial_segments = 48
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var disc := MeshInstance3D.new()
	disc.mesh = mesh
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = 0.04
	add_child(disc)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = TICK
	for body in AbilityUtil.enemies_in_radius(get_tree(), team, global_position, radius):
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			# Lasts just past the next tick, so it drops right after they leave.
			fx.apply_slow(slow, TICK + 0.05, slow_id)
