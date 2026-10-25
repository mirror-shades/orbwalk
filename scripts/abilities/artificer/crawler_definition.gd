class_name CrawlerDefinition
extends AbilityDefinition
## Numbers for the Artificer's Q. See docs/champions/artificer.md.

## Seconds a robot stays on the board.
@export var lifetime: float = 15.0
## Q charges: each cast spends one, and each spent charge comes back on its own
## cooldown (the cooldowns overlap, they don't queue).
@export var max_charges: int = 3
## How fast a robot crawls to its target spot.
@export var deploy_speed: float = 12.0
## The robot explodes `pulses` time(s), the first one `pulse_interval` seconds after
## it lands. Q robots explode once and then sit dormant until W or E uses them.
@export var pulses: int = 1
@export var pulse_interval: float = 0.6
@export var pulse_radius: float = 3.0
## Magic damage per pulse: base_damage (+ damage_per_rank) + ap_ratio * AP.
@export var base_damage: float = 85.0
@export var damage_per_rank: float = 30.0
@export var ap_ratio: float = 0.6
## Slow per pulse: slow (+ slow_per_rank) for slow_duration.
@export var slow: float = 0.25
@export var slow_per_rank: float = 0.05
@export var slow_duration: float = 1.5


func create_ability() -> Node:
	return load("res://scripts/abilities/artificer/crawler_ability.gd").new()
