class_name WarBanner
extends Node3D
## The Drill Sergeant's W banner in the world. Allies within its radius (champions,
## mercenaries and himself) get a short stat buff that's refreshed every tick, so
## it lingers briefly after they leave.
##
## If `carrier` is set (an allied mercenary), the banner follows it. When the carrier
## dies, the banner stays where it fell. It isn't an Entity, so nothing can target
## or damage it. It disappears when its duration runs out.

signal expired

const BUFF_ID := "war_banner"
const TICK := 0.25
## How long the buff lasts after a tick (so it lingers ~0.5s after leaving).
const LINGER := 0.5

var team: int = 0
var radius: float = 6.0
var duration: float = 10.0
## {StatsComponent.Stat: amount} given to allies in range.
var bonuses: Dictionary = {}
var carrier: Node3D

var _time_left: float = 0.0
var _tick_left: float = 0.0
var _ring: MeshInstance3D
var _pole: Node3D


func _ready() -> void:
	_time_left = duration
	_build_visuals()
	_follow_carrier()


func is_carried() -> bool:
	return carrier != null


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		expired.emit()
		queue_free()
		return
	_follow_carrier()
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = TICK
	for body in AbilityUtil.allies_in_radius(get_tree(), team, global_position, radius):
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			fx.apply_stat_buff(BUFF_ID, bonuses, LINGER, "Banner")
	# The ring fades out over the last second.
	if _ring:
		_ring.transparency = clampf(1.0 - _time_left, 0.0, 1.0)


## Moves with the carrier while it lives; drops in place when it dies.
func _follow_carrier() -> void:
	if carrier == null:
		return
	var st: StatsComponent = null
	if is_instance_valid(carrier):
		st = carrier.get_node_or_null("Stats") as StatsComponent
	if st == null or st.is_dead:
		carrier = null
		_pole.position.y = 0.0
		return
	global_position = Vector3(carrier.global_position.x, 0.0, carrier.global_position.z)
	_pole.position.y = 0.4


func _build_visuals() -> void:
	var color := Color(0.3, 0.55, 1.0) if team == EntityDefinition.Team.TEAM_1 else Color(1.0, 0.35, 0.3)
	_pole = Node3D.new()
	add_child(_pole)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.15)
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.08
	pole_mesh.height = 3.4
	var pole := MeshInstance3D.new()
	pole.mesh = pole_mesh
	pole.material_override = wood
	pole.position.y = 1.7
	_pole.add_child(pole)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = color
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(1.0, 0.65, 0.04)
	var flag := MeshInstance3D.new()
	flag.mesh = flag_mesh
	flag.material_override = cloth
	flag.position = Vector3(0.52, 2.95, 0.0)
	_pole.add_child(flag)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.8, 0.3)
	gold.metallic = 0.6
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.12
	tip_mesh.height = 0.24
	var tip := MeshInstance3D.new()
	tip.mesh = tip_mesh
	tip.material_override = gold
	tip.position.y = 3.45
	_pole.add_child(tip)

	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	torus.rings = 64
	torus.ring_segments = 6
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.6)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.scale = Vector3(1.0, 0.15, 1.0)
	_ring.position.y = 0.06
	add_child(_ring)
