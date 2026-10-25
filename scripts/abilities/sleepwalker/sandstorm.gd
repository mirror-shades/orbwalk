class_name Sandstorm
extends Node3D
## The Sleepwalker's R storm. Rolls straight to `dest`. Enemies inside are blinded
## and take magic damage + a Grit stack once a second. Never touches structures.

const COLOR := Color(0.86, 0.74, 0.5)

var team: int = 0
var source: Node3D
var dest := Vector3.ZERO
var speed: float = 4.0
var radius: float = 5.0
var damage_per_tick: float = 20.0
var tick_interval: float = 1.0
var blind_refresh: float = 0.25

var _tick_left: float = 0.0
var _spinner: Node3D


func _ready() -> void:
	_tick_left = tick_interval
	_build_visual()


func _physics_process(delta: float) -> void:
	var to := dest - global_position
	to.y = 0.0
	var step := speed * delta
	if to.length() <= step:
		global_position = Vector3(dest.x, 0.0, dest.z)
		_apply_aura()
		queue_free()
		return
	global_position += to.normalized() * step
	_apply_aura()
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left += tick_interval
		_tick()
	if _spinner:
		_spinner.rotate_y(delta * 0.8)


## Blind is refreshed every frame while an enemy is inside, so it ends when they leave.
func _apply_aura() -> void:
	for body in AbilityUtil.enemies_in_radius(get_tree(), team, global_position, radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead:
			continue
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			fx.apply_blind(blind_refresh, "sandstorm")


func _tick() -> void:
	var src: Node = source if is_instance_valid(source) else null
	var grit := GritAbility.of(source)
	for body in AbilityUtil.enemies_in_radius(get_tree(), team, global_position, radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead:
			continue
		st.take_magic_damage(damage_per_tick, src)
		if grit:
			grit.add(body)


func _build_visual() -> void:
	_spinner = Node3D.new()
	add_child(_spinner)

	var column_mat := StandardMaterial3D.new()
	column_mat.albedo_color = Color(COLOR, 0.16)
	column_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	column_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var column := CylinderMesh.new()
	column.top_radius = radius
	column.bottom_radius = radius
	column.height = 3.0
	column.radial_segments = 32
	var column_mesh := MeshInstance3D.new()
	column_mesh.mesh = column
	column_mesh.material_override = column_mat
	column_mesh.position.y = 1.5
	column_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spinner.add_child(column_mesh)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.95, 0.85, 0.62, 0.55)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for height in [0.8, 1.8, 2.8]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius * 0.9
		ring.outer_radius = radius
		ring.rings = 40
		ring.ring_segments = 6
		var ring_mesh := MeshInstance3D.new()
		ring_mesh.mesh = ring
		ring_mesh.material_override = ring_mat
		ring_mesh.scale = Vector3(1.0, 0.15, 1.0)
		ring_mesh.position.y = float(height)
		ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spinner.add_child(ring_mesh)

	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(COLOR, 0.22)
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.03
	disc.radial_segments = 40
	var disc_mesh := MeshInstance3D.new()
	disc_mesh.mesh = disc
	disc_mesh.material_override = disc_mat
	disc_mesh.position.y = 0.04
	disc_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc_mesh)
