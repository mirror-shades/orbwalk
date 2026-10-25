class_name KataDefinition
extends AbilityDefinition
## Numbers for the Hired Blade's passive. See docs/champions/hired_blade.md.

## Seconds taken off every ability cooldown on a successful cast.
@export var cooldown_discount: float = 1.0
## Move speed per stack (0.05 = +5%), stacking up to `max_stacks`.
@export var move_speed_per_stack: float = 0.05
@export var max_stacks: int = 4
@export var stack_duration: float = 4.0


func create_ability() -> Node:
	return load("res://scripts/abilities/hired_blade/kata_ability.gd").new()
