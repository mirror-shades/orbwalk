class_name UndertowDefinition
extends AbilityDefinition
## Numbers for the Argonaut's W. See docs/champions/argonaut.md.

## Seconds the charged auto waits before it fades unused.
@export var window: float = 4.0
## Bonus physical damage on the charged auto: bonus_damage (+ per rank) + ad_ratio * AD.
@export var bonus_damage: float = 30.0
@export var bonus_damage_per_rank: float = 20.0
@export var ad_ratio: float = 0.3
## The slow starts at slow_start and grows to slow_max (+ per rank) over slow_duration.
@export var slow_start: float = 0.25
@export var slow_max: float = 0.6
@export var slow_max_per_rank: float = 0.05
@export var slow_duration: float = 2.5


func create_ability() -> Node:
	return load("res://scripts/abilities/argonaut/undertow_ability.gd").new()
