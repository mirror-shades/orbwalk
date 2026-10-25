class_name FetchDefinition
extends AbilityDefinition
## Numbers for the Wrangler's R. See docs/champions/wrangler.md.

## Seconds between the throw and the pug's charge.
@export var cast_time: float = 0.25
@export var charge_speed: float = 16.0
## The pug's hit width while giant.
@export var width: float = 3.0
## Physical damage: base_damage + damage_per_rank * (rank - 1) + ad_ratio * AD.
@export var base_damage: float = 150.0
@export var damage_per_rank: float = 100.0
@export var ad_ratio: float = 0.8
## How far enemies are knocked to the side, and how fast.
@export var knock_distance: float = 3.0
@export var knock_speed: float = 14.0
@export var stun_duration: float = 0.5


func create_ability() -> Node:
	return load("res://scripts/abilities/wrangler/fetch_ability.gd").new()
