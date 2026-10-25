class_name HairTriggerDefinition
extends AbilityDefinition

@export var move_speed_bonus: float = 0.3
@export var duration: float = 1.5
@export var internal_cooldown: float = 0.5


func create_ability() -> Node:
	return load("res://scripts/abilities/gunslinger/hair_trigger_ability.gd").new()
