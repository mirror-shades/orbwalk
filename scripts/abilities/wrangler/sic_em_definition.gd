class_name SicEmDefinition
extends AbilityDefinition
## Numbers for the Wrangler's Q. See docs/champions/wrangler.md.

@export var leap_speed: float = 20.0
@export var bites: int = 3
@export var bite_interval: float = 0.5
## Physical damage per bite: base_damage + damage_per_rank * (rank - 1) + ad_ratio * AD.
@export var base_damage: float = 30.0
@export var damage_per_rank: float = 15.0
@export var ad_ratio: float = 0.3
## The pug lets go when the target gets this far from her.
@export var leash_range: float = 7.0


func create_ability() -> Node:
	return load("res://scripts/abilities/wrangler/sic_em_ability.gd").new()
