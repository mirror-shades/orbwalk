class_name BigIronDefinition
extends AbilityDefinition

@export var cast_time: float = 0.35
@export var start_distance: float = 0.6
@export var line_length: float = 12.0
@export var width: float = 2.4
@export var base_damage: float = 200.0
@export var damage_per_rank: float = 125.0
@export var ad_ratio: float = 1.1
@export var recoil_distance: float = 4.0
@export var recoil_speed: float = 20.0


func create_ability() -> Node:
	return load("res://scripts/abilities/gunslinger/big_iron_ability.gd").new()
