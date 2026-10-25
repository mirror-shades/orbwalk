class_name PounceDefinition
extends AbilityDefinition
## Numbers for the Wrangler's passive. See docs/champions/wrangler.md.

## How far the pug can leap from where it is standing.
@export var leap_range: float = 8.0
@export var leap_speed: float = 20.0
## Physical bite: base_damage + damage_per_level * her level + ad_ratio * AD.
@export var base_damage: float = 15.0
@export var damage_per_level: float = 5.0
@export var ad_ratio: float = 0.3
@export var slow: float = 0.25
@export var slow_duration: float = 1.0
## Per champion, after a pounce.
@export var target_cooldown: float = 8.0


func create_ability() -> Node:
	return load("res://scripts/abilities/wrangler/pounce_ability.gd").new()
