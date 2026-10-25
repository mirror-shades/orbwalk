class_name HaulInDefinition
extends AbilityDefinition
## Numbers for Argonaut's Q. Throw range is `cast_range`. See docs/champions/argonaut.md.

## Hit width of the rope, in meters.
@export var width: float = 0.7
## How fast the rope flies out, in meters per second.
@export var rope_speed: float = 22.0
## How fast a hooked target is dragged to him.
@export var pull_speed: float = 18.0
## Physical damage: base_damage + ad_ratio * attack damage.
@export var base_damage: float = 60.0
@export var damage_per_rank: float = 35.0
@export var ad_ratio: float = 0.5


func create_ability() -> Node:
	return load("res://scripts/abilities/argonaut/haul_in_ability.gd").new()
