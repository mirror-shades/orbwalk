class_name ReelInDefinition
extends AbilityDefinition
## Numbers for the Artificer's E. See docs/champions/artificer.md.

## Every robot fires a ray at him. Each ray damages each enemy it crosses once:
## base_damage (+ damage_per_rank) + ap_ratio * AP magic damage. The robots stay put.
@export var base_damage: float = 20.0
@export var damage_per_rank: float = 10.0
@export var ap_ratio: float = 0.12
## How far either side of the ray an enemy still counts as crossed.
@export var ray_width: float = 1.2
## Shield: shield_base (+ shield_per_rank), plus shield_per_robot
## (+ shield_per_robot_per_rank) for each robot beyond the first, capped at
## shield_cap_contributions extra robots.
@export var shield_base: float = 40.0
@export var shield_per_rank: float = 15.0
@export var shield_per_robot: float = 20.0
@export var shield_per_robot_per_rank: float = 10.0
@export var shield_cap_contributions: int = 3
@export var shield_duration: float = 3.0
## Enemies within push_radius of him are shoved push_distance away from him and
## slowed by push_slow (+ push_slow_per_rank) for push_slow_duration.
@export var push_radius: float = 3.5
@export var push_distance: float = 3.0
@export var push_speed: float = 16.0
@export var push_slow: float = 0.3
@export var push_slow_per_rank: float = 0.05
@export var push_slow_duration: float = 1.5


func create_ability() -> Node:
	return load("res://scripts/abilities/artificer/reel_in_ability.gd").new()
