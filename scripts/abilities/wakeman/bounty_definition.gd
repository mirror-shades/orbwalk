class_name BountyDefinition
extends AbilityDefinition

@export var attack_damage_per_stack: float = 0.5
@export var kill_stacks: int = 10
@export var assist_stacks: int = 5
@export var tumble_kill_stacks: int = 1


func create_ability() -> Node:
	return load("res://scripts/abilities/wakeman/bounty_ability.gd").new()
