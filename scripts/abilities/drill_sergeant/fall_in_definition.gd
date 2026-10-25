class_name FallInDefinition
extends AbilityDefinition
## Numbers for the Drill Sergeant's passive. See docs/champions/drill_sergeant.md.

## Damage reduction per allied mercenary nearby (0.03 = 3%).
@export var reduction_per_mercenary: float = 0.03
## Only this many mercenaries count (5 x 3% = 15% max).
@export var max_mercenaries: int = 5
## How close a mercenary must be to count, in meters.
@export var radius: float = 6.0


func create_ability() -> Node:
	return load("res://scripts/abilities/drill_sergeant/fall_in_ability.gd").new()
