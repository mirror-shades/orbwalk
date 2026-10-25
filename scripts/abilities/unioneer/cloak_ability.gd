class_name CloakAbility
extends Ability

const CLOAK_ID := "unioneer_cloak"
const HASTE_ID := "unioneer_cloak_haste"


func is_active() -> bool:
	var fx := caster.status_effects() if caster else null
	return fx != null and fx.has_effect(CLOAK_ID)


func _cast(_target_pos: Vector3) -> void:
	var def := definition as CloakDefinition
	var duration := ranked(def.base_duration, def.duration_per_rank)
	var fx := caster.status_effects()
	if fx == null:
		return
	fx.apply_stealth(duration, CLOAK_ID)
	fx.apply_move_speed(def.move_speed_bonus, duration, HASTE_ID)


func _tick(_delta: float) -> void:
	var fx := caster.status_effects() if caster else null
	if fx == null:
		return
	if not fx.has_effect(CLOAK_ID):
		fx.remove_effect(HASTE_ID)
