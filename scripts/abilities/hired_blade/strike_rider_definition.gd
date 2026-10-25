class_name StrikeRiderDefinition
extends AbilityDefinition
## Numbers for the Hired Blade's Q and W: riders on his next auto-attacks.
## See docs/champions/hired_blade.md.

## How many of his next auto-attacks get the bonus.
@export var strikes: int = 2
## The window in which those attacks must land.
@export var window: float = 4.0
## Physical damage per strike: bonus_damage + ad_ratio * attack damage.
@export var bonus_damage: float = 35.0
@export var bonus_damage_per_rank: float = 15.0
@export var ad_ratio: float = 0.35
## Bleed stacks per strike (Q). 0 = no bleed.
@export var bleed_stacks: int = 0
## Slow per strike (W). 0 = no slow.
@export var slow: float = 0.0
@export var slow_per_rank: float = 0.0
@export var slow_duration: float = 1.25
## Ring color under him while the strikes are waiting.
@export var glow_color: Color = Color(0.85, 0.2, 0.18)


func create_ability() -> Node:
	return load("res://scripts/abilities/hired_blade/strike_rider_ability.gd").new()
