class_name FlashbangDefinition
extends AbilityDefinition

@export var radius: float = 2.5
@export var flight_time: float = 0.5
@export var base_damage: float = 40.0
@export var damage_per_rank: float = 25.0
@export var ad_ratio: float = 0.3
@export var slow: float = 0.4
@export var slow_duration: float = 1.5
@export var blind_duration: float = 1.5


func create_ability() -> Node:
	return load("res://scripts/abilities/wakeman/flashbang_ability.gd").new()
