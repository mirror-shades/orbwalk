class_name EntityDefinition
extends Resource
## A unit's starting numbers: base stats at level 1, how much each stat grows per
## level, and its abilities. StatsComponent turns these into live values.
## See docs/stats.md for every stat and formula.

enum EntityType {
	CHAMPION,
	MINION,
	TOWER,
	ORB,
	JUNGLE,
	SPAWNER,
}

enum Team {
	TEAM_1,
	TEAM_2,
	NEUTRAL,
}

@export var entity_id: String = ""
@export var entity_name: String = ""

@export var entity_type: EntityType = EntityType.CHAMPION
@export var team: Team = Team.TEAM_1

@export_group("Base Stats", "stats_")
@export var stats_max_health: float = 500.0
## Health per second.
@export var stats_health_regen: float = 5.0
@export var stats_max_mana: float = 300.0
## Mana per second.
@export var stats_mana_regen: float = 7.0
@export var stats_attack_damage: float = 60.0
@export var stats_ability_power: float = 0.0
@export var stats_armor: float = 25.0
@export var stats_magic_resist: float = 30.0
## Attacks per second at level 1 with no bonuses.
@export var stats_attack_speed: float = 0.625
@export var stats_attack_range: float = 1.5
@export var stats_movement_speed: float = 5.0
## How far this unit reveals the fog of war for its team.
@export var stats_sight_range: float = 13.0
## Chance (0 to 1) for an auto-attack to crit.
@export var stats_crit_chance: float = 0.0
## Crit damage multiplier (2.0 = a crit deals 200%).
@export var stats_crit_damage: float = 2.0

@export_group("Ranged Attack", "attack_")
## 0 = melee (damage lands instantly). Above 0, auto-attacks fire a projectile at this speed.
@export var attack_projectile_speed: float = 0.0
@export var attack_projectile_color: Color = Color(1.0, 1.0, 1.0)

@export_group("Per-Level Growth", "growth_")
## Each growth value is roughly what the stat gains per level (see growth_at_level).
@export var growth_health: float = 85.0
@export var growth_health_regen: float = 0.5
@export var growth_mana: float = 40.0
@export var growth_mana_regen: float = 0.5
@export var growth_attack_damage: float = 3.5
@export var growth_armor: float = 3.0
@export var growth_magic_resist: float = 1.0
## Bonus attack speed per level, as a fraction of base attack speed (0.03 = +3% per level).
@export var growth_attack_speed: float = 0.025

@export_group("Abilities")
@export var ability_1: AbilityDefinition
@export var ability_2: AbilityDefinition
@export var ability_3: AbilityDefinition
@export var ability_4: AbilityDefinition
## Always-on effect with no key. Created by AbilityCaster like the others.
@export var passive: AbilityDefinition
## Order bots max their basic abilities in (0 = Q, 1 = W, 2 = E). R is always taken when possible.
@export var skill_priority: PackedInt32Array = PackedInt32Array([0, 1, 2])


## How many "levels of growth" a unit has at `level`. League's curve: it's 0 at
## level 1 and exactly 17 at level 18, like linear growth, but early levels give a
## little less and late levels a little more.
static func growth_at_level(level: int) -> float:
	var n := float(maxi(level, 1) - 1)
	return n * (0.7025 + 0.0175 * n)
