class_name GritDefinition
extends AbilityDefinition
## Numbers for the Sleepwalker's passive. See docs/champions/sleepwalker.md.

## Slow per Grit stack (0.05 = 5%).
@export var slow_per_stack: float = 0.05
## Most stacks one target can have.
@export var max_stacks: int = 5
## Stacks all fall off this long after the last one is added (refreshed on each add).
@export var stack_duration: float = 4.0
## How long the slow effect is refreshed for; it lapses this soon after stacks end.
@export var slow_refresh: float = 0.35


func create_ability() -> Node:
	return load("res://scripts/abilities/sleepwalker/grit_ability.gd").new()
