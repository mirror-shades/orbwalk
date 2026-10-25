class_name CleaveDefinition
extends AbilityDefinition
## Numbers for the Drill Sergeant's Q. See docs/champions/drill_sergeant.md.

## Arc in front of him: how far it reaches and how wide it is (degrees, total).
@export var reach: float = 3.0
@export var angle: float = 120.0
## Damage: base_damage (+ damage_per_rank) + ad_ratio * attack damage, physical.
@export var base_damage: float = 60.0
@export var damage_per_rank: float = 25.0
@export var ad_ratio: float = 0.8
## He heals for this fraction of the damage he deals (after armor).
@export var champion_heal: float = 0.2
@export var mercenary_heal: float = 0.05


func create_ability() -> Node:
	return load("res://scripts/abilities/drill_sergeant/cleave_ability.gd").new()
