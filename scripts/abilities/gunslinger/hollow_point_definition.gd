class_name HollowPointDefinition
extends AbilityDefinition

@export var window: float = 4.0
@export var bleed_stacks: float = 2.0
@export var bleed_stacks_per_rank: float = 1.0


func create_ability() -> Node:
	return load("res://scripts/abilities/gunslinger/hollow_point_ability.gd").new()
