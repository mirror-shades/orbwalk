class_name HomingShot
extends Node3D
## A homing projectile for ranged auto-attacks. Deals physical damage on arrival.
## Entity.deal_attack_damage() fires one when the definition has attack_projectile_speed > 0.
## Abilities can fire one too: set `magic` for a spell hit (magic damage, not an auto-attack).

## Emitted when the shot reaches its target, after the damage.
signal landed(target: Node3D)

var target: Node3D
var damage: float = 0.0
var source_id: int = 0
var speed: float = 18.0
var color: Color = Color.WHITE
## Deal magic damage as a spell instead of an auto-attack's physical damage.
var magic: bool = false
## What the match log calls this shot's damage (e.g. "hex_swarm:missile").
## Empty = the log works it out from the call stack.
var cause: String = ""


## Creates a shot from `shooter` (chest height) toward `target`.
static func fire(shooter: Node3D, p_target: Node3D, p_damage: float, p_speed: float, p_color: Color) -> HomingShot:
	var shot := HomingShot.new()
	shot.target = p_target
	shot.damage = p_damage
	shot.source_id = shooter.get_instance_id()
	shot.speed = p_speed
	shot.color = p_color
	shooter.get_parent().add_child(shot)
	shot.global_position = shooter.global_position + Vector3(0.0, 1.5, 0.0)
	return shot


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh.radial_segments = 10
	mesh.rings = 5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var ts := target.get_node_or_null("Stats") as StatsComponent
	if ts == null or ts.is_dead:
		queue_free()
		return
	var aim := target.global_position + Vector3(0.0, 1.0, 0.0)
	var to := aim - global_position
	var step := speed * delta
	if to.length() <= step:
		var source := instance_from_id(source_id) as Node if source_id != 0 else null
		MatchLog.cause_override = cause
		if magic:
			ts.take_magic_damage(damage, source)
		else:
			ts.take_physical_damage(damage, source, true)
		MatchLog.cause_override = ""
		landed.emit(target)
		queue_free()
		return
	global_position += to.normalized() * step
