class_name RollingJug
extends Node3D
## The Potion Seller's R jug. Rolls along the ground to `dest` (over units,
## towers and the orb), then sits there. Explodes when the fuse runs out or on
## explode(): magic damage + poison to every enemy within `radius`, and a patch
## of goo that slows enemies standing in it. A circle on the ground shows the blast.

signal exploded
## An enemy champion was hit by the blast (for his passive).
signal champion_hit(target: Node3D)

const COLOR := Color(0.6, 0.85, 0.2)

var team: int = 0
var source: Node3D
var dest := Vector3.ZERO
var speed: float = 8.0
var fuse_time: float = 3.0
var radius: float = 3.5
var damage: float = 200.0
var poison_damage: float = 100.0
var poison_duration: float = 3.0
var goo_slow: float = 0.8
var goo_duration: float = 3.0

## Seconds since it was cast.
var age: float = 0.0
var _done: bool = false
var _jug: Node3D
var _circle: MeshInstance3D
var _circle_mat: StandardMaterial3D


func _ready() -> void:
	_jug = Node3D.new()
	_jug.position.y = 0.6
	add_child(_jug)
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.62, 0.42, 0.26)
	var body := SphereMesh.new()
	body.radius = 0.6
	body.height = 1.2
	_add_mesh(body, Vector3.ZERO, clay)
	var band := StandardMaterial3D.new()
	band.albedo_color = COLOR
	band.emission_enabled = true
	band.emission = COLOR * 0.4
	var stripe := CylinderMesh.new()
	stripe.top_radius = 0.62
	stripe.bottom_radius = 0.62
	stripe.height = 0.18
	_add_mesh(stripe, Vector3.ZERO, band)

	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 48
	_circle_mat = StandardMaterial3D.new()
	_circle_mat.albedo_color = Color(COLOR, 0.2)
	_circle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_circle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_circle = MeshInstance3D.new()
	_circle.mesh = disc
	_circle.material_override = _circle_mat
	_circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_circle.position.y = 0.04
	add_child(_circle)


func _add_mesh(mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_jug.add_child(mi)


func _physics_process(delta: float) -> void:
	if _done:
		return
	age += delta
	var to := dest - global_position
	to.y = 0.0
	var step := speed * delta
	if to.length() > 0.01:
		var move := to.normalized() * minf(step, to.length())
		global_position += move
		# Roll: spin around the axis sideways to the direction of travel.
		var axis := Vector3.UP.cross(to.normalized())
		if axis.length_squared() > 0.0001:
			_jug.rotate(axis.normalized(), move.length() / 0.6)
	# The circle pulses faster as the fuse runs down.
	var k := clampf(age / maxf(fuse_time, 0.01), 0.0, 1.0)
	_circle_mat.albedo_color = Color(COLOR, lerpf(0.15, 0.4, k) + 0.08 * sin(age * lerpf(6.0, 22.0, k)))
	if age >= fuse_time:
		explode()


func explode() -> void:
	if _done:
		return
	_done = true
	var src: Node = source if is_instance_valid(source) else null
	var center := Vector3(global_position.x, 0.0, global_position.z)
	for body in AbilityUtil.enemies_in_radius(get_tree(), team, center, radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		st.take_magic_damage(damage, src)
		if st.get_entity_type() == EntityDefinition.EntityType.CHAMPION:
			champion_hit.emit(body)
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx and not st.is_dead:
			fx.apply_poison(poison_damage, poison_duration, src, "ps_poison")

	var goo := GooPatch.new()
	goo.team = team
	goo.radius = radius
	goo.duration = goo_duration
	goo.slow = goo_slow
	goo.slow_id = "ps_r_goo"
	var scene := get_parent()
	scene.add_child(goo)
	goo.global_position = center

	AbilityUtil.ring_flash(scene, center, radius, Color(COLOR, 0.95))
	AbilityUtil.pop_text(scene, center + Vector3(0.0, 2.5, 0.0), "Splash!", COLOR, 48)
	exploded.emit()
	queue_free()
