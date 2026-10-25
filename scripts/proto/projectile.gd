class_name ProtoProjectile
extends Node3D
## A simple homing shot. Deals its damage when it reaches the target.

var target: Node3D
var damage: float = 0.0
var true_damage: bool = false
## Instance id of whoever fired it (0 = nobody). Stored as an id so the shot
## still lands safely if the shooter dies mid-flight.
var source_id: int = 0
var speed: float = 20.0
var aim_height: float = 1.0
var color: Color = Color.WHITE
var size: float = 0.2


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = ProtoUtil.flat_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var ts := EntityData.get_stats_of(target)
	if ts == null or ts.is_dead:
		queue_free()
		return
	var aim := target.global_position + Vector3(0.0, aim_height, 0.0)
	var to_aim := aim - global_position
	var step := speed * delta
	if to_aim.length() <= step:
		var source: Node = null
		if source_id != 0:
			source = instance_from_id(source_id) as Node
		if true_damage:
			ts.take_true_damage(damage, source, true)
		else:
			ts.take_physical_damage(damage, source, true)
		queue_free()
		return
	global_position += to_aim.normalized() * step
