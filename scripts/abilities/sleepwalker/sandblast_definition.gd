class_name SandblastDefinition
extends AbilityDefinition
## Numbers for the Sleepwalker's E. See docs/champions/sleepwalker.md.

## Radius around him that gets blasted.
@export var radius: float = 8.0
@export var base_damage: float = 30.0
@export var damage_per_rank: float = 15.0
@export var ap_ratio: float = 0.2
## Extra damage per Grit stack (and its AP ratio).
@export var per_stack_damage: float = 20.0
@export var per_stack_per_rank: float = 10.0
@export var stack_ap_ratio: float = 0.12
## Stun per stack (0.4 = 0.4s per stack, 2s at 5 stacks).
@export var stun_per_stack: float = 0.4


func create_ability() -> Node:
	return load("res://scripts/abilities/sleepwalker/sandblast_ability.gd").new()
