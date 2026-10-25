class_name SatisfiedCustomerAbility
extends Ability
## Passive: when his Q (plain or empowered) or the R blast hits an enemy champion,
## he heals a little over a few seconds. Internal cooldown (definition.cooldown).
## Poison ticks don't trigger it; Q and R call on_spell_hit() on the hit itself.

const COLOR := Color(0.4, 1.0, 0.55)

var _per_second: float = 0.0
var _heal_left: float = 0.0


## The Satisfied Customer passive on `entity`, or null if it doesn't have one.
static func of(entity: Node) -> SatisfiedCustomerAbility:
	if entity == null or not is_instance_valid(entity):
		return null
	var c := entity.get_node_or_null("Abilities") as AbilityCaster
	return c.passive as SatisfiedCustomerAbility if c else null


func is_active() -> bool:
	return _heal_left > 0.0


## One of his spells hit `target`. Starts the heal if it's an enemy champion and off cooldown.
func on_spell_hit(target: Node3D) -> void:
	if cooldown_left > 0.0 or caster.stats.is_dead:
		return
	var st := target.get_node_or_null("Stats") as StatsComponent if is_instance_valid(target) else null
	if st == null or st.get_entity_type() != EntityDefinition.EntityType.CHAMPION:
		return
	if not EntityData.is_enemy(caster.stats.get_team(), st.get_team()):
		return
	var def := definition as SatisfiedCustomerDefinition
	var total := def.heal + def.heal_ap_ratio * ap()
	_heal_left = maxf(def.heal_duration, 0.01)
	_per_second = total / _heal_left
	start_cooldown()
	AbilityUtil.pop_text(get_tree().current_scene, caster.global_position + Vector3(0.0, 3.0, 0.0), "+%d" % roundi(total), COLOR, 34)


func _tick(delta: float) -> void:
	if _heal_left <= 0.0:
		return
	if caster.stats.is_dead:
		_heal_left = 0.0
		return
	var step := minf(delta, _heal_left)
	caster.stats.heal(_per_second * step)
	_heal_left -= step
