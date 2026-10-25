class_name HeavyOrb
extends Node3D
## The Broom Rider's R orb. Rolls slowly along the ground to `dest`, passing
## through units: every enemy it touches takes magic damage once. When it arrives
## (or burst() is called) it bursts: `burst_damage` magic damage and a stun to
## every enemy within `burst_radius`.
## Towers and the orb are never hit. Each enemy it touches or stuns heals her once
## (Witch's Tithe).

signal finished

const COLOR := Color(0.7, 0.45, 1.0)

var team: int = 0
var source: Node3D
var dest := Vector3.ZERO
var speed: float = 4.0
var radius: float = 0.9
var damage: float = 80.0
var burst_radius: float = 4.5
var burst_damage: float = 300.0
var stun_duration: float = 0.7

## Seconds since it was thrown.
var age: float = 0.0
var _done: bool = false
## Instance ids of enemies already damaged by the pass-through.
var _hit: Dictionary = {}
## Instance ids of enemies that already healed her this cast.
var _healed: Dictionary = {}
var _ball: MeshInstance3D
var _ring: MeshInstance3D


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(COLOR, 0.85)
	mat.emission_enabled = true
	mat.emission = COLOR * 0.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	_ball = MeshInstance3D.new()
	_ball.mesh = sphere
	_ball.material_override = mat
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ball.position.y = radius
	add_child(_ball)

	# Faint circle showing where the burst will land.
	var torus := TorusMesh.new()
	torus.inner_radius = burst_radius - 0.1
	torus.outer_radius = burst_radius
	torus.rings = 48
	torus.ring_segments = 6
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(COLOR, 0.5)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.scale = Vector3(1.0, 0.15, 1.0)
	_ring.position.y = 0.05
	add_child(_ring)


func _physics_process(delta: float) -> void:
	if _done:
		return
	age += delta
	var to := dest - global_position
	to.y = 0.0
	var step := speed * delta
	if to.length() <= step:
		global_position = Vector3(dest.x, 0.0, dest.z)
		_hit_touching()
		burst()
		return
	global_position += to.normalized() * step
	_ball.rotate(Vector3.UP.cross(to.normalized()).normalized(), step / maxf(radius, 0.1))
	_hit_touching()


## Damages every enemy the orb is touching that it hasn't hit yet.
func _hit_touching() -> void:
	var src: Node = source if is_instance_valid(source) else null
	for body in AbilityUtil.enemies_in_radius(get_tree(), team, global_position, radius):
		var id := body.get_instance_id()
		if _hit.has(id):
			continue
		_hit[id] = true
		var st := body.get_node_or_null("Stats") as StatsComponent
		st.take_magic_damage(damage, src)
		_heal_once(body)


func burst() -> void:
	if _done:
		return
	_done = true
	var center := Vector3(global_position.x, 0.0, global_position.z)
	var src: Node = source if is_instance_valid(source) else null
	for body in AbilityUtil.enemies_in_radius(get_tree(), team, center, burst_radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		st.take_magic_damage(burst_damage, src)
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx and not st.is_dead:
			fx.apply_stun(stun_duration)
		_heal_once(body)
	var scene := get_parent()
	AbilityUtil.ring_flash(scene, center, burst_radius, Color(COLOR, 0.95))
	AbilityUtil.ring_flash(scene, center, burst_radius * 0.6, Color(1.0, 0.85, 1.0, 0.9))
	AbilityUtil.pop_text(scene, center + Vector3(0.0, 2.5, 0.0), "Burst!", COLOR, 44)
	finished.emit()
	queue_free()


func _heal_once(body: Node3D) -> void:
	var id := body.get_instance_id()
	if _healed.has(id) or not is_instance_valid(source):
		return
	_healed[id] = true
	WitchsTitheAbility.spell_hit(source, body)
