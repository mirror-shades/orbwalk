class_name FanTheHammerDefinition
extends AbilityDefinition

@export var bullet_count: float = 6.0
@export var bullet_count_per_rank: float = 0.0
@export var base_damage: float = 30.0
@export var damage_per_rank: float = 10.0
@export var ad_ratio: float = 0.25
@export var width: float = 1.0
@export var bullet_speed: float = 26.0
@export var spacing: float = 0.15


func create_ability() -> Node:
	return load("res://scripts/abilities/gunslinger/fan_the_hammer_ability.gd").new()
