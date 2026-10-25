class_name ReelDefinition
extends AbilityDefinition
## Numbers for Cat's Paw's R. See docs/champions/cats_paw.md.

## Furthest the knife can be for R to pull you to it. Further than this, R goes off in place.
@export var pull_range: float = 14.0
@export var pull_speed: float = 30.0
## Blast radius around you when you arrive (or where you stand).
@export var radius: float = 4.0
## Blast damage: base_damage (+ damage_per_rank) + ad_ratio * attack damage.
@export var base_damage: float = 150.0
@export var damage_per_rank: float = 100.0
@export var ad_ratio: float = 0.8
## Fear on every enemy champion and mercenary hit.
@export var fear_duration: float = 1.0


func create_ability() -> Node:
	return load("res://scripts/abilities/cats_paw/reel_ability.gd").new()
