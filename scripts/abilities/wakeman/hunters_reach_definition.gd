class_name HuntersReachDefinition
extends AbilityDefinition

@export var range_per_rank: float = 0.35
@export var attack_speed_per_rank: float = 0.08


func create_ability() -> Node:
	return load("res://scripts/abilities/wakeman/hunters_reach_ability.gd").new()
