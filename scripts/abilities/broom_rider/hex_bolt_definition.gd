class_name HexBoltDefinition
extends AbilityDefinition
## Numbers for the Broom Rider's E. See docs/champions/broom_rider.md.

## Bonus magic damage on the next auto: bonus_damage (+ per rank) + ap_ratio * AP.
@export var bonus_damage: float = 40.0
@export var bonus_damage_per_rank: float = 25.0
@export var ap_ratio: float = 0.5
## Slow on the target when the bolt lands: slow (+ per rank) for slow_duration seconds.
@export var slow: float = 0.3
@export var slow_per_rank: float = 0.05
@export var slow_duration: float = 1.5
## Seconds the charge waits for an auto before it fades unused.
@export var window: float = 4.0
@export var bolt_speed: float = 24.0


func create_ability() -> Node:
	return load("res://scripts/abilities/broom_rider/hex_bolt_ability.gd").new()
