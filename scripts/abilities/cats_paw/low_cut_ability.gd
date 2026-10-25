class_name LowCutAbility
extends Ability
## Passive: his auto-attacks deal bonus damage to an enemy already cut below a
## health threshold. Auto-attacks only: spitting on a low-health target with a
## knife or a blast doesn't get the bonus. Stack it with W's attack reset.
## Applied by Entity.deal_attack_damage on every swing.


## The Low Cut passive on `entity`, or null if it doesn't have one.
static func of(entity: Node) -> LowCutAbility:
	var c := entity.get_node_or_null("Abilities") as AbilityCaster
	return c.passive as LowCutAbility if c else null


## Called by Entity for each auto-attack this champion lands.
func scale_auto_damage(dmg: float, victim_stats: StatsComponent) -> float:
	var def := definition as LowCutDefinition
	if victim_stats == null or victim_stats.is_dead:
		return dmg
	if victim_stats.current_health / victim_stats.get_max_health() > def.cut_below:
		return dmg
	return dmg * (1.0 + def.bonus_damage)
