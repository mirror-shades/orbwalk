class_name DemolitionDefinition
extends AbilityDefinition
## Numbers for the Artificer's W. See docs/champions/artificer.md.

## Radius of each robot's detonation.
@export var radius: float = 2.5
## Magic damage per burst: base_damage (+ damage_per_rank) + ap_ratio * AP.
@export var base_damage: float = 70.0
@export var damage_per_rank: float = 35.0
@export var ap_ratio: float = 0.5
## Bleed stacks added to every enemy hit by each burst.
@export var bleed_stacks: int = 2
## How fast a woken robot runs at its target, and how far from the robot it looks.
@export var seek_speed: float = 14.0
@export var seek_range: float = 14.0


func create_ability() -> Node:
	return load("res://scripts/abilities/artificer/demolition_ability.gd").new()
