class_name StrikeRiderAbility
extends Ability
## Q / W: his next `strikes` auto-attacks each deal bonus physical damage and
## apply either Bleed stacks or a slow. Charges are spent one per landed auto.

const SLOW_ID := "hired_blade_hamstring"

var _charges: int = 0
var _time_left: float = 0.0
var _glow: MeshInstance3D


func _ready() -> void:
	caster.attack_landed.connect(_on_attack_landed)


func is_active() -> bool:
	return _charges > 0 and _time_left > 0.0


func _cast(_target_pos: Vector3) -> void:
	var def := definition as StrikeRiderDefinition
	var per_cast := maxi(def.strikes, 1)
	# A second pair stacks on top of the first (until its window runs out).
	_charges = mini(_charges + per_cast, per_cast * 2)
	_time_left = def.window
	_set_glow(true)


func _tick(delta: float) -> void:
	if _charges <= 0:
		return
	_time_left -= delta
	if _time_left <= 0.0 or caster.stats.is_dead:
		_clear()


func _on_attack_landed(target: Node) -> void:
	if not is_active() or not (target is Node3D):
		return
	var st := target.get_node_or_null("Stats") as StatsComponent
	if st == null:
		return
	var kind := st.get_entity_type()
	if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB:
		return
	var def := definition as StrikeRiderDefinition
	if not st.is_dead:
		var dmg := ranked(def.bonus_damage, def.bonus_damage_per_rank) + def.ad_ratio * ad()
		st.take_physical_damage(dmg, caster)
		var fx := target.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			if def.bleed_stacks > 0:
				fx.apply_bleed(def.bleed_stacks, caster)
			if def.slow > 0.0:
				fx.apply_slow(ranked(def.slow, def.slow_per_rank), def.slow_duration, SLOW_ID)
	_charges -= 1
	if _charges <= 0:
		_clear()


func _clear() -> void:
	_charges = 0
	_time_left = 0.0
	_set_glow(false)


## A ring under him while the strikes are waiting.
func _set_glow(on: bool) -> void:
	if _glow == null:
		var def := definition as StrikeRiderDefinition
		var torus := TorusMesh.new()
		torus.inner_radius = 0.95
		torus.outer_radius = 1.15
		torus.rings = 48
		torus.ring_segments = 6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = def.glow_color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow = MeshInstance3D.new()
		_glow.mesh = torus
		_glow.material_override = mat
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.scale = Vector3(1.0, 0.15, 1.0)
		_glow.position.y = 0.08
		caster.add_child(_glow)
	_glow.visible = on
