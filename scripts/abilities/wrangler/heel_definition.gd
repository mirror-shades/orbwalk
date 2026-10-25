class_name HeelDefinition
extends AbilityDefinition
## Numbers for the Wrangler's E. See docs/champions/wrangler.md.

@export var dash_distance: float = 5.0
@export var dash_speed: float = 22.0
## The pug waits this long after her dash before charging after her.
@export var pug_delay: float = 2.0
@export var charge_speed: float = 25.0
## How wide the pug's charge hits.
@export var width: float = 1.2
## Physical damage: base_damage + damage_per_rank * (rank - 1) + ad_ratio * AD.
@export var base_damage: float = 40.0
@export var damage_per_rank: float = 25.0
@export var ad_ratio: float = 0.4
@export var stun_duration: float = 0.75


func create_ability() -> Node:
	return load("res://scripts/abilities/wrangler/heel_ability.gd").new()
