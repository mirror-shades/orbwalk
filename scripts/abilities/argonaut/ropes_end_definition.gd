class_name RopesEndDefinition
extends AbilityDefinition
## Numbers for Argonaut's E. See docs/champions/argonaut.md.

## Reach of the half circle in front of him.
@export var radius: float = 3.5
## Seconds between pressing E and the lash landing.
@export var cast_time: float = 0.25
## Physical damage: base_damage + ad_ratio * attack damage + hp_ratio * his max HP.
@export var base_damage: float = 50.0
@export var damage_per_rank: float = 25.0
@export var ad_ratio: float = 0.4
@export var hp_ratio: float = 0.04
## Slow on everything hit (0.4 = 40%) and how long it lasts.
@export var slow: float = 0.4
@export var slow_duration: float = 1.5


func create_ability() -> Node:
	return load("res://scripts/abilities/argonaut/ropes_end_ability.gd").new()
