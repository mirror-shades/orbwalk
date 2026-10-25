class_name TumbleDefinition
extends AbilityDefinition

@export var distance: float = 3.0
@export var dash_speed: float = 20.0
@export var charge_duration: float = 4.0
@export var ad_bonus: float = 0.3
@export var ad_bonus_per_rank: float = 0.1


func create_ability() -> Node:
	return load("res://scripts/abilities/wakeman/tumble_ability.gd").new()
