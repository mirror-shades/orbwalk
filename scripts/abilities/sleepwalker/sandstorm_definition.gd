class_name SandstormDefinition
extends AbilityDefinition
## Numbers for the Sleepwalker's R. See docs/champions/sleepwalker.md.

## Charge time. Releasing early gives the smallest storm.
@export var min_charge: float = 0.5
@export var max_charge: float = 2.0
## Size and reach grow with the charge.
@export var min_radius: float = 3.0
@export var max_radius: float = 5.0
@export var min_distance: float = 20.0
@export var max_distance: float = 35.0
@export var travel_speed: float = 4.0
## Seconds between damage + Grit ticks inside the storm.
@export var tick_interval: float = 1.0
@export var base_damage: float = 20.0
@export var damage_per_rank: float = 15.0
@export var ap_ratio: float = 0.1
## Blind is refreshed this often while an enemy stands inside.
@export var blind_refresh: float = 0.25


func create_ability() -> Node:
	return load("res://scripts/abilities/sleepwalker/sandstorm_ability.gd").new()
