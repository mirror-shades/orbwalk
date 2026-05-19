class_name EntityDefinition
extends Resource

@export var entity_id: String = ""
@export var entity_name: String = ""

@export_group("Base Stats", "stats_")
@export var stats_max_health: float = 500.0
@export var stats_health_regen: float = 5.0
@export var stats_max_mana: float = 300.0
@export var stats_mana_regen: float = 7.0
@export var stats_attack_damage: float = 60.0
@export var stats_ability_power: float = 0.0
@export var stats_armor: float = 25.0
@export var stats_magic_resist: float = 30.0
@export var stats_attack_speed: float = 0.625
@export var stats_attack_range: float = 1.5
@export var stats_movement_speed: float = 5.0

@export_group("Per-Level Growth")
@export var growth_health: float = 85.0
@export var growth_health_regen: float = 0.5
@export var growth_mana: float = 40.0
@export var growth_mana_regen: float = 0.5
@export var growth_attack_damage: float = 3.5
@export var growth_armor: float = 3.0
@export var growth_magic_resist: float = 1.0
@export var growth_attack_speed: float = 0.02

@export_group("Abilities")
@export var ability_1: AbilityDefinition
@export var ability_2: AbilityDefinition
@export var ability_3: AbilityDefinition
@export var ability_4: AbilityDefinition

func get_stat_at_level(base: float, growth: float, level: int) -> float:
	return base + growth * (level - 1)
