class_name DashDefinition
extends AbilityDefinition
## Numbers for Cat's Paw's E. See docs/champions/cats_paw.md.

## How far the dash goes (always the full distance, toward the cursor).
@export var distance: float = 4.0
## Dash travel speed in meters per second.
@export var dash_speed: float = 25.0
## Attack speed bonus after dashing (0.4 = +40%).
@export var attack_speed_bonus: float = 0.4
@export var attack_speed_bonus_per_rank: float = 0.05
## How long the attack speed bonus lasts, in seconds.
@export var buff_duration: float = 3.0


func create_ability() -> Node:
	return load("res://scripts/abilities/cats_paw/dash_ability.gd").new()
