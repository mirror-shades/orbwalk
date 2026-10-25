class_name LineZone
extends Node3D
## A rectangle on the ground (`length` along `axis`, `width` across) that lasts
## `duration` seconds and calls _on_tick() every `tick_interval` with the living
## allies and enemies of `team` standing in it. Towers and the orb are never
## included. Subclasses decide what the zone does (the Broom Rider's Gate).
##
## Set the fields, add it to the scene, then set global_position (y = 0) and
## call face(axis). The strip is drawn as a flat translucent box.

signal expired

var team: int = 0
var length: float = 8.0
var width: float = 2.0
var duration: float = 6.0
var tick_interval: float = 0.25
var color: Color = Color(1.0, 1.0, 1.0, 0.25)

var _axis := Vector3.RIGHT
var _time_left: float = 0.0
var _tick_left: float = 0.0
var _strip: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	_time_left = duration
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.02, length)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_strip = MeshInstance3D.new()
	_strip.mesh = box
	_strip.material_override = _mat
	_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_strip.position.y = 0.04
	add_child(_strip)


## Points the strip's long side along `axis` (flattened).
func face(axis: Vector3) -> void:
	axis.y = 0.0
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	_axis = axis.normalized()
	look_at(global_position + _axis, Vector3.UP)


## True if a unit at `pos` with size `unit_radius` overlaps the strip.
func contains(pos: Vector3, unit_radius: float = 0.0) -> bool:
	var rel := Vector2(pos.x - global_position.x, pos.z - global_position.z)
	var along := Vector2(_axis.x, _axis.z)
	var across := Vector2(-along.y, along.x)
	return absf(rel.dot(along)) <= length * 0.5 + unit_radius and absf(rel.dot(across)) <= width * 0.5 + unit_radius


## Living units of `team` (allies) or its enemies standing in the strip.
func units_inside(enemies: bool) -> Array[Node3D]:
	var reach := Vector2(length * 0.5, width * 0.5).length()
	var center := Vector3(global_position.x, 0.0, global_position.z)
	var near := AbilityUtil.enemies_in_radius(get_tree(), team, center, reach) if enemies \
			else AbilityUtil.allies_in_radius(get_tree(), team, center, reach)
	var out: Array[Node3D] = []
	for body in near:
		if contains(body.global_position, AbilityUtil.unit_radius(body)):
			out.append(body)
	return out


## Ends the zone early (replaced by a new one, for example).
func end() -> void:
	if is_queued_for_deletion():
		return
	expired.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		end()
		return
	# Fade out over the last half second.
	_strip.transparency = clampf(1.0 - _time_left * 2.0, 0.0, 1.0)
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = tick_interval
	_on_tick(units_inside(false), units_inside(true))


func _on_tick(_allies: Array[Node3D], _enemies: Array[Node3D]) -> void:
	pass
