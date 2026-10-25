class_name GrappleDefinition
extends AbilityDefinition
## Numbers for the Hired Blade's E. See docs/champions/hired_blade.md.

## How fast he leaps to the target, in meters per second.
@export var leap_speed: float = 28.0
## Physical damage on arrival to an enemy: base_damage + ad_ratio * attack damage.
@export var base_damage: float = 60.0
@export var damage_per_rank: float = 30.0
@export var ad_ratio: float = 0.6


func create_ability() -> Node:
	return load("res://scripts/abilities/hired_blade/grapple_ability.gd").new()
