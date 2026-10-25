class_name RideDefinition
extends AbilityDefinition
## Numbers for the Broom Rider's Q. See docs/champions/broom_rider.md.

## The dash: always `distance` toward the cursor (stops at towers, the orb and the lane edge).
@export var distance: float = 7.0
@export var dash_speed: float = 16.0
## Enemies this close to her (plus their size) during the dash are hit.
@export var hit_radius: float = 1.3
## Magic damage to everything she flies through: base_damage (+ per rank) + ap_ratio * AP.
@export var base_damage: float = 60.0
@export var damage_per_rank: float = 30.0
@export var ap_ratio: float = 0.4
## Press Q again within this many seconds of the dash to blink back to the start.
@export var return_window: float = 3.0


func create_ability() -> Node:
	return load("res://scripts/abilities/broom_rider/ride_ability.gd").new()
