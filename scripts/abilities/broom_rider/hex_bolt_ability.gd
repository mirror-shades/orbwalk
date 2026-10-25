class_name HexBoltAbility
extends Ability
## E: charges her next auto-attack (within the window) and resets the attack
## timer so it can go right away. When that auto fires, a hex bolt flies with it:
## bonus magic damage and a slow on the target when it lands.

const COLOR := Color(0.95, 0.5, 1.0)
const SLOW_ID := "br_hex_bolt_slow"

var _time_left: float = 0.0
var _glow: MeshInstance3D


func _ready() -> void:
	caster.attack_landed.connect(_on_attack)


func is_active() -> bool:
	return _time_left > 0.0


func _cast(_target_pos: Vector3) -> void:
	_time_left = (definition as HexBoltDefinition).window
	caster.reset_attack_timer()
	_set_glow(true)


func _tick(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	if _time_left <= 0.0 or caster.stats.is_dead:
		_time_left = 0.0
		_set_glow(false)


## Her auto just fired at `target`: send the hex bolt with it.
func _on_attack(target: Node) -> void:
	if _time_left <= 0.0 or not (target is Node3D):
		return
	_time_left = 0.0
	_set_glow(false)
	var def := definition as HexBoltDefinition
	var dmg := ranked(def.bonus_damage, def.bonus_damage_per_rank) + def.ap_ratio * ap()
	var shot := HomingShot.fire(caster, target as Node3D, dmg, def.bolt_speed, COLOR)
	shot.magic = true
	shot.cause = "hex_bolt:bolt"
	shot.scale = Vector3.ONE * 1.8
	shot.landed.connect(_on_bolt_landed)


func _on_bolt_landed(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var fx := target.get_node_or_null("StatusEffects") as StatusEffects
	if fx:
		var def := definition as HexBoltDefinition
		fx.apply_slow(ranked(def.slow, def.slow_per_rank), def.slow_duration, SLOW_ID)


## A pink ring under her while the charge is waiting.
func _set_glow(on: bool) -> void:
	if _glow == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.95
		torus.outer_radius = 1.15
		torus.rings = 48
		torus.ring_segments = 6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLOR
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow = MeshInstance3D.new()
		_glow.mesh = torus
		_glow.material_override = mat
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.scale = Vector3(1.0, 0.15, 1.0)
		_glow.position.y = 0.08
		caster.add_child(_glow)
	_glow.visible = on
