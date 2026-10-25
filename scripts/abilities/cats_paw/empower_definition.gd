class_name EmpowerDefinition
extends AbilityDefinition
## Numbers for Cat's Paw's W. See docs/champions/cats_paw.md.

## Flat bonus damage on the empowered auto-attack.
@export var bonus_damage: float = 40.0
@export var bonus_damage_per_rank: float = 20.0
## Extra bonus damage as a fraction of attack damage (0.5 = 50% AD).
@export var ad_ratio: float = 0.5
## Seconds the empowered attack waits before it fades unused.
@export var window: float = 4.0
## The bonus damage also hits every other enemy within this distance of the target (wave clear).
@export var splash_radius: float = 2.5


func create_ability() -> Node:
	return load("res://scripts/abilities/cats_paw/empower_ability.gd").new()
