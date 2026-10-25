class_name ProductionLineDefinition
extends AbilityDefinition
## Numbers for the Artificer's R. See docs/champions/artificer.md.

## The wall: robot_count robots in a line across the aim, centered on the aimed spot
## (at least start_distance from him), spaced every `spacing` meters. They are
## ordinary robots (same fuse, burst, slow and lifetime as Q's), just stronger.
@export var robot_count: int = 5
@export var start_distance: float = 1.0
@export var spacing: float = 2.0
@export var deploy_speed: float = 12.0
@export var lifetime: float = 15.0
## Magic damage per burst: base_damage (+ damage_per_rank) + ap_ratio * AP.
@export var base_damage: float = 130.0
@export var damage_per_rank: float = 60.0
@export var ap_ratio: float = 0.6
@export var pulses: int = 1
@export var pulse_interval: float = 0.6
@export var pulse_radius: float = 3.0
@export var slow: float = 0.25
@export var slow_duration: float = 1.5


func create_ability() -> Node:
	return load("res://scripts/abilities/artificer/production_line_ability.gd").new()
