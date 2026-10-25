class_name DustDevilDefinition
extends AbilityDefinition
## Numbers for the Sleepwalker's W. See docs/champions/sleepwalker.md.

@export var radius: float = 2.5
@export var duration: float = 3.0
## Seconds between ticks: the zone damages at 1s, 2s and 3s.
@export var tick_interval: float = 1.0
@export var base_damage: float = 25.0
@export var damage_per_rank: float = 10.0
@export var ap_ratio: float = 0.15


func create_ability() -> Node:
	return load("res://scripts/abilities/sleepwalker/dust_devil_ability.gd").new()
