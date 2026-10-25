class_name BarkDefinition
extends AbilityDefinition
## Numbers for the Wrangler's W. See docs/champions/wrangler.md.

@export var radius: float = 3.0
## Physical damage: base_damage + damage_per_rank * (rank - 1) + ad_ratio * AD.
@export var base_damage: float = 60.0
@export var damage_per_rank: float = 35.0
@export var ad_ratio: float = 0.5
@export var slow: float = 0.4
@export var slow_duration: float = 1.5


func create_ability() -> Node:
	return load("res://scripts/abilities/wrangler/bark_ability.gd").new()
