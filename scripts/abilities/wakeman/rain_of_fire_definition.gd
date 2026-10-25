class_name RainOfFireDefinition
extends AbilityDefinition

@export var cast_time: float = 0.75
@export var start_distance: float = 1.0
@export var line_length: float = 20.0
@export var width: float = 3.0
@export var landing_time: float = 0.5
@export var base_damage: float = 150.0
@export var damage_per_rank: float = 100.0
@export var ad_ratio: float = 1.0
@export var fire_duration: float = 4.0
@export var burn_damage: float = 40.0
@export var burn_damage_per_rank: float = 20.0
@export var burn_ad_ratio: float = 0.3
@export var burn_tick_interval: float = 0.5


func create_ability() -> Node:
	return load("res://scripts/abilities/wakeman/rain_of_fire_ability.gd").new()
