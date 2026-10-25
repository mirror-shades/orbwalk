class_name ShieldRushDefinition
extends AbilityDefinition
## Numbers for the Drill Sergeant's E. Dash length is `distance`.

@export var distance: float = 5.0
@export var dash_speed: float = 22.0
## Enemies this close to him (plus their size) during the dash get hit.
@export var hit_radius: float = 1.2
## Damage to everything in his path: base_damage (+ damage_per_rank) + ad_ratio * attack damage.
@export var base_damage: float = 50.0
@export var damage_per_rank: float = 25.0
@export var ad_ratio: float = 0.5
## Stun on the first enemy champion he hits.
@export var stun_duration: float = 0.75


func create_ability() -> Node:
	return load("res://scripts/abilities/drill_sergeant/shield_rush_ability.gd").new()
