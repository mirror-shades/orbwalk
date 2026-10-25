class_name WitchsTitheDefinition
extends AbilityDefinition
## Numbers for the Broom Rider's passive. See docs/champions/broom_rider.md.

## Healing for each enemy one of her spells hits (once per enemy per cast;
## each W missile counts as its own hit).
@export var heal_per_hit: float = 15.0


func create_ability() -> Node:
	return load("res://scripts/abilities/broom_rider/witchs_tithe_ability.gd").new()
