class_name HexSwarmDefinition
extends AbilityDefinition
## Numbers for the Broom Rider's W. See docs/champions/broom_rider.md.

## Shield on herself: shield (+ per rank) + shield_ap_ratio * AP, for shield_duration seconds.
@export var shield: float = 60.0
@export var shield_per_rank: float = 30.0
@export var shield_ap_ratio: float = 0.3
@export var shield_duration: float = 3.0
## Homing missiles at the closest enemies within missile_range (spares go to the closest).
@export var missile_count: int = 5
@export var missile_range: float = 6.0
@export var missile_speed: float = 16.0
## Magic damage per missile: missile_damage (+ per rank) + missile_ap_ratio * AP.
@export var missile_damage: float = 40.0
@export var missile_damage_per_rank: float = 25.0
@export var missile_ap_ratio: float = 0.3
## Damage multiplier for missiles that hit mercenaries and monsters (wave clear).
@export var non_champion_mult: float = 1.5


func create_ability() -> Node:
	return load("res://scripts/abilities/broom_rider/hex_swarm_ability.gd").new()
