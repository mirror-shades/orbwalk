class_name KnifeDefinition
extends AbilityDefinition
## Numbers for Cat's Paw's Q. Throw range is `cast_range`. See docs/champions/cats_paw.md.

## Hit width of the knife's path, in meters.
@export var width: float = 0.8
@export var throw_speed: float = 25.0
@export var recall_speed: float = 30.0
## Damage per hit (throw and recall each): base_damage (+ damage_per_rank) + ad_ratio * attack damage.
@export var base_damage: float = 50.0
@export var damage_per_rank: float = 25.0
@export var ad_ratio: float = 0.7
## Slow per hit (0.3 = 30%) and how long it lasts.
@export var slow: float = 0.3
@export var slow_duration: float = 1.5
## Seconds the knife stays in the ground before it disappears.
@export var lifetime: float = 5.0


func create_ability() -> Node:
	return load("res://scripts/abilities/cats_paw/knife_ability.gd").new()
