class_name QuickDrawDefinition
extends AbilityDefinition

@export var attack_speed_per_rank: float = 0.08
@export var crit_chance_per_rank: float = 0.04


func create_ability() -> Node:
	return load("res://scripts/abilities/gunslinger/quick_draw_ability.gd").new()
