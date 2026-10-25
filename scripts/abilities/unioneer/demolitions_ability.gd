class_name DemolitionsAbility
extends Ability

func scale_auto_damage(dmg: float, victim_stats: StatsComponent) -> float:
	if victim_stats == null or victim_stats.is_dead:
		return dmg
	if victim_stats.get_entity_type() != EntityDefinition.EntityType.TOWER:
		return dmg
	return dmg * (1.0 + (definition as DemolitionsDefinition).tower_damage_bonus)
