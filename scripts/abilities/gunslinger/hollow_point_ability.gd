class_name HollowPointAbility
extends Ability
## E: reset the auto-attack timer and make the next auto within the window a
## guaranteed crit that applies Bleed stacks. A miss (Blind / Dodge) doesn't use
## up the guarantee or the Bleed.

const GLOW_COLOR := Color(1.0, 0.45, 0.2)

var _time_left: float = 0.0
var _glow: MeshInstance3D


func _ready() -> void:
	caster.attack_landed.connect(_on_attack_landed)
	caster.stats.died.connect(_on_died)


func is_active() -> bool:
	return _time_left > 0.0


func _cast(_target_pos: Vector3) -> void:
	var def := definition as HollowPointDefinition
	caster.guarantee_next_crit()
	caster.reset_attack_timer()
	_time_left = def.window
	_set_glow(true)


func _tick(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	if _time_left <= 0.0 or caster.stats.is_dead:
		_expire()


func _on_attack_landed(target: Node) -> void:
	if _time_left <= 0.0 or caster.landing_from_ability:
		return
	var def := definition as HollowPointDefinition
	var stacks := int(round(ranked(def.bleed_stacks, def.bleed_stacks_per_rank)))
	_time_left = 0.0
	caster.clear_guaranteed_crit()
	_set_glow(false)

	var st := EntityData.get_stats_of(target)
	if st == null:
		return
	var kind := st.get_entity_type()
	if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB:
		return
	var fx := target.get_node_or_null("StatusEffects") as StatusEffects
	if fx:
		fx.apply_bleed(stacks, caster)


func _expire() -> void:
	_time_left = 0.0
	caster.clear_guaranteed_crit()
	_set_glow(false)


func _on_died() -> void:
	_time_left = 0.0
	_set_glow(false)


## A small ring under the champion while the shot is loaded.
func _set_glow(on: bool) -> void:
	if _glow == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.95
		torus.outer_radius = 1.15
		torus.rings = 48
		torus.ring_segments = 6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = GLOW_COLOR
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow = MeshInstance3D.new()
		_glow.mesh = torus
		_glow.material_override = mat
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.scale = Vector3(1.0, 0.15, 1.0)
		_glow.position.y = 0.08
		caster.add_child(_glow)
	_glow.visible = on
