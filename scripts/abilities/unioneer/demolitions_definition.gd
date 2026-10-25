class_name DemolitionsDefinition
extends AbilityDefinition

@export var tower_damage_bonus: float = 0.5


func create_ability() -> Node:
	return load("res://scripts/abilities/unioneer/demolitions_ability.gd").new()
