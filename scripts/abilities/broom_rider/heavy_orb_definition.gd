class_name HeavyOrbDefinition
extends AbilityDefinition
## Numbers for the Broom Rider's R (her ultimate). See docs/champions/broom_rider.md.

## How far the orb rolls (always straight out toward the cursor), and how fast.
@export var travel_distance: float = 16.0
@export var travel_speed: float = 4.0
## Enemies this close to the orb's center (plus their size) are hit as it passes.
@export var orb_radius: float = 1.4
## Magic damage to everything it passes through: base_damage (+ per rank) + ap_ratio * AP.
@export var base_damage: float = 80.0
@export var damage_per_rank: float = 35.0
@export var ap_ratio: float = 0.55
## The burst at the end of the road (or on recast): magic damage and a stun to
## everything within burst_radius. Damage: burst_damage (+ per rank) + burst_ap_ratio * AP.
@export var burst_radius: float = 4.5
@export var burst_damage: float = 300.0
@export var burst_damage_per_rank: float = 150.0
@export var burst_ap_ratio: float = 1.0
@export var stun_duration: float = 0.7
@export var stun_duration_per_rank: float = 0.15
## Pressing Q again bursts it, but only after this long (so a double tap doesn't waste it).
@export var min_recast_time: float = 0.25


func create_ability() -> Node:
	return load("res://scripts/abilities/broom_rider/heavy_orb_ability.gd").new()
