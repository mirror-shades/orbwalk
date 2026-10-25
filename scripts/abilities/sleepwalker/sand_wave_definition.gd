class_name SandWaveDefinition
extends AbilityDefinition
## Numbers for the Sleepwalker's Q. See docs/champions/sleepwalker.md.

## The wave always travels this far (clipped only by the lane edge).
@export var travel_distance: float = 10.0
@export var travel_speed: float = 14.0
@export var width: float = 1.2
@export var base_damage: float = 70.0
@export var damage_per_rank: float = 40.0
@export var ap_ratio: float = 0.6
@export var root_duration: float = 0.75
@export var root_per_rank: float = 0.125


func create_ability() -> Node:
	return load("res://scripts/abilities/sleepwalker/sand_wave_ability.gd").new()
