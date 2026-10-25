class_name SmokeBombDefinition
extends AbilityDefinition
## Numbers for the Hired Blade's R. See docs/champions/hired_blade.md.

## How long the smoke (auto-attack dodge) lasts and the stun waits.
@export var duration: float = 3.0
## Radius of the smoke and the end-of-smoke stun, in meters.
@export var radius: float = 4.0
## Stun duration on every enemy in the radius at the end.
@export var stun_duration: float = 1.0
@export var stun_duration_per_rank: float = 0.25


func create_ability() -> Node:
	return load("res://scripts/abilities/hired_blade/smoke_bomb_ability.gd").new()
