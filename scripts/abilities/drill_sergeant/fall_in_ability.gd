class_name FallInAbility
extends Ability
## Passive: he takes less damage for each allied mercenary near him (up to a cap).
## Updated a few times a second through a StatsComponent modifier.

const MODIFIER_ID := "fall_in"
const TICK := 0.25

## How many mercenaries currently count.
var count: int = 0

var _tick_left: float = 0.0


func display_name() -> String:
	if count > 0:
		return "%s %d%%" % [definition.ability_name, roundi(current_reduction() * 100.0)]
	return definition.ability_name


func is_active() -> bool:
	return count > 0


func current_reduction() -> float:
	return float(count) * (definition as FallInDefinition).reduction_per_mercenary


func _tick(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = TICK
	if caster.stats.is_dead:
		_set_count(0)
		return
	var def := definition as FallInDefinition
	var n := 0
	for body in AbilityUtil.allies_in_radius(get_tree(), caster.stats.get_team(), caster.global_position, def.radius):
		if body == caster:
			continue
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st.get_entity_type() == EntityDefinition.EntityType.MINION:
			n += 1
	_set_count(mini(n, def.max_mercenaries))


func _set_count(n: int) -> void:
	if n == count:
		return
	count = n
	if n <= 0:
		caster.stats.remove_modifier(MODIFIER_ID)
	else:
		caster.stats.set_modifier(MODIFIER_ID, {StatsComponent.Stat.DAMAGE_REDUCTION: current_reduction()})


func _exit_tree() -> void:
	if caster and caster.stats:
		caster.stats.remove_modifier(MODIFIER_ID)
