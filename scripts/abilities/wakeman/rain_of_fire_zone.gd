class_name RainOfFireZone
extends Node3D

var team: int = 0
var source: Node3D
var impact_damage: float = 0.0
var burn_per_tick: float = 0.0
var line_length: float = 20.0
var width: float = 3.0
var landing_time: float = 0.5
var fire_duration: float = 4.0
var tick_interval: float = 0.5
var color: Color = Color(1.0, 0.45, 0.15)

var _start := Vector3.ZERO
var _dir := Vector3.RIGHT
var _land_left: float = 0.0
var _fire_left: float = 0.0
var _burn_left: float = 0.0
var _landed: bool = false
var _land_front: float = 0.0
var _hit: Dictionary = {}
var _strip: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	_land_left = landing_time
	_fire_left = fire_duration
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.03, line_length)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_strip = MeshInstance3D.new()
	_strip.mesh = box
	_strip.material_override = _mat
	_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_strip.position = Vector3(0.0, 0.04, -line_length * 0.5)
	add_child(_strip)


func launch(start: Vector3, direction: Vector3) -> void:
	_start = Vector3(start.x, 0.0, start.z)
	_dir = Vector3(direction.x, 0.0, direction.z)
	if _dir.length_squared() < 0.0001:
		_dir = Vector3.RIGHT
	_dir = _dir.normalized()
	global_position = _start
	look_at(_start + _dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	if not _landed:
		_land_left = maxf(_land_left - delta, 0.0)
		var ratio := 1.0 - _land_left / maxf(landing_time, 0.01)
		_land_front = line_length * clampf(ratio, 0.0, 1.0)
		_impact(_land_front)
		if _land_left <= 0.0:
			_landed = true
			_land_front = line_length
			_burn_left = 0.0
		return

	_fire_left -= delta
	if _fire_left <= 0.0:
		queue_free()
		return
	_strip.transparency = clampf(_fire_left * 2.0, 0.0, 1.0)
	_burn_left -= delta
	if _burn_left <= 0.0:
		_burn_left = tick_interval
		_burn()


func _impact(front: float) -> void:
	var src: Node = source if is_instance_valid(source) else null
	for body in _candidates():
		var id := body.get_instance_id()
		if _hit.has(id):
			continue
		if not _inside(body, front):
			continue
		_hit[id] = true
		var st := EntityData.get_stats_of(body)
		if st:
			st.take_physical_damage(impact_damage, src)


func _burn() -> void:
	var src: Node = source if is_instance_valid(source) else null
	for body in _candidates():
		if not _inside(body, line_length):
			continue
		var st := EntityData.get_stats_of(body)
		if st:
			st.take_magic_damage(burn_per_tick, src)


func _candidates() -> Array[Node3D]:
	var center := _start + _dir * (line_length * 0.5)
	var reach := Vector2(line_length * 0.5, width * 0.5).length() + 2.0
	return AbilityUtil.enemies_in_radius(get_tree(), team, center, reach)


func _inside(body: Node3D, front: float) -> bool:
	var rel := Vector2(body.global_position.x - _start.x, body.global_position.z - _start.z)
	var along := rel.dot(Vector2(_dir.x, _dir.z))
	var across := absf(rel.dot(Vector2(-_dir.z, _dir.x)))
	var radius := AbilityUtil.unit_radius(body)
	return along >= -radius and along <= front + radius and across <= width * 0.5 + radius
