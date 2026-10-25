class_name DustDevil
extends Node3D
## The Sleepwalker's W whirlwind. Ticks damage and Grit once a second for 3s.

const COLOR := Color(0.86, 0.74, 0.5)

var team: int = 0
var source: Node3D
var radius: float = 2.5
var duration: float = 3.0
var tick_interval: float = 1.0
var damage: float = 30.0

var _time_left: float = 0.0
var _tick_left: float = 0.0
var _spinner: Node3D


func _ready() -> void:
	_time_left = duration
	_tick_left = tick_interval
	_build_visual()


func _physics_process(delta: float) -> void:
	_time_left -= delta
	_tick_left -= delta
	if _tick_left <= 0.0 and _time_left > -tick_interval:
		_tick_left += tick_interval
		_tick()
	if _spinner:
		_spinner.rotate_y(delta * 9.0)
	if _time_left <= 0.0:
		queue_free()


func _tick() -> void:
	var src: Node = source if is_instance_valid(source) else null
	var grit := GritAbility.of(source)
	for body in AbilityUtil.enemies_in_radius(get_tree(), team, global_position, radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead:
			continue
		st.take_magic_damage(damage, src)
		if grit:
			grit.add(body)


func _build_visual() -> void:
	_spinner = Node3D.new()
	add_child(_spinner)

	var funnel_mat := StandardMaterial3D.new()
	funnel_mat.albedo_color = Color(COLOR, 0.32)
	funnel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	funnel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var funnel := CylinderMesh.new()
	funnel.top_radius = radius * 0.45
	funnel.bottom_radius = radius
	funnel.height = 2.2
	funnel.radial_segments = 24
	var funnel_mesh := MeshInstance3D.new()
	funnel_mesh.mesh = funnel
	funnel_mesh.material_override = funnel_mat
	funnel_mesh.position.y = 1.1
	funnel_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spinner.add_child(funnel_mesh)

	var streak_mat := StandardMaterial3D.new()
	streak_mat.albedo_color = Color(0.95, 0.85, 0.62, 0.7)
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 3:
		var streak := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 1.6, 0.08)
		streak.mesh = box
		streak.material_override = streak_mat
		var angle := TAU * float(i) / 3.0
		streak.position = Vector3(cos(angle) * radius * 0.6, 0.9, sin(angle) * radius * 0.6)
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spinner.add_child(streak)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(COLOR, 0.7)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.08
	ring.outer_radius = radius
	ring.rings = 40
	ring.ring_segments = 6
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = ring
	ring_mesh.material_override = ring_mat
	ring_mesh.scale = Vector3(1.0, 0.15, 1.0)
	ring_mesh.position.y = 0.05
	ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring_mesh)
