class_name BigJugDefinition
extends AbilityDefinition
## Numbers for the Potion Seller's R. See docs/champions/potion_seller.md.

## How far the jug rolls toward the cursor, and how fast.
@export var roll_distance: float = 10.0
@export var roll_speed: float = 8.0
## Seconds from the cast until it explodes on its own.
@export var fuse_time: float = 3.0
## Pressing R again explodes it early, but only after this long.
@export var min_recast_time: float = 0.3
@export var radius: float = 3.5
## Magic damage: base_damage (+ damage_per_rank) + ap_ratio * ability power.
@export var base_damage: float = 200.0
@export var damage_per_rank: float = 125.0
@export var ap_ratio: float = 0.7
## Poison on everyone hit: poison_damage (+ per rank) + poison_ap_ratio * ability power, over poison_duration.
@export var poison_damage: float = 100.0
@export var poison_damage_per_rank: float = 50.0
@export var poison_ap_ratio: float = 0.5
@export var poison_duration: float = 3.0
## Goo left behind: slow on enemies standing in it (0.8 = 80%) and how long it lasts.
@export var goo_slow: float = 0.8
@export var goo_duration: float = 3.0


func create_ability() -> Node:
	return load("res://scripts/abilities/potion_seller/big_jug_ability.gd").new()
