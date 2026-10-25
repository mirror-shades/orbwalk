class_name TideMarkDefinition
extends AbilityDefinition
## Numbers for Argonaut's passive. See docs/champions/argonaut.md.

## Tide stacks needed to mark an enemy champion.
@export var stacks_to_mark: int = 3
## Stacks fall off this long after the last one (refreshed on each stack).
@export var stack_duration: float = 4.0
## How long the mark waits to be used up.
@export var mark_duration: float = 4.0
## Per target, after the mark is used up or runs out, before they can be stacked again.
@export var target_cooldown: float = 8.0
## Magic damage when the mark is used up: payoff_base + payoff_hp_ratio * Argonaut's max HP.
@export var payoff_base: float = 40.0
@export var payoff_hp_ratio: float = 0.05
## Healing bubble: flat heal per ally champion, how many allies it reaches, bounce range, speed.
@export var bubble_heal: float = 60.0
@export var bubble_bounces: int = 2
@export var bubble_range: float = 4.0
@export var bubble_speed: float = 12.0


func create_ability() -> Node:
	return load("res://scripts/abilities/argonaut/tide_mark_ability.gd").new()
