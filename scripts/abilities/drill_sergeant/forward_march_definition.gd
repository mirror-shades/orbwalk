class_name ForwardMarchDefinition
extends AbilityDefinition
## Numbers for the Drill Sergeant's R.

## He and allied mercenaries within this radius when he casts get the buff.
@export var radius: float = 12.0
@export var duration: float = 6.0
## Buff: bonus move speed (0.4 = +40%), bonus damage as a fraction of each unit's
## base attack damage (0.25 = +25%), and slow immunity for the whole duration.
@export var move_speed: float = 0.4
@export var damage_bonus: float = 0.25
## His shield: shield_base (+ shield_per_rank) + shield_hp_ratio * his max health.
@export var shield_base: float = 150.0
@export var shield_per_rank: float = 100.0
@export var shield_hp_ratio: float = 0.15


func create_ability() -> Node:
	return load("res://scripts/abilities/drill_sergeant/forward_march_ability.gd").new()
