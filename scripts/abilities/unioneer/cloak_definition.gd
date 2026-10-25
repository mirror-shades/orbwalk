class_name CloakDefinition
extends AbilityDefinition

@export var base_duration: float = 3.0
@export var duration_per_rank: float = 0.25
@export var move_speed_bonus: float = 0.4


func create_ability() -> Node:
	return load("res://scripts/abilities/unioneer/cloak_ability.gd").new()
