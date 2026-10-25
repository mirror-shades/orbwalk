class_name PotionMixDefinition
extends AbilityDefinition
## Numbers for one of the Potion Seller's ingredients (W = glue, E = poison).
## Casting it loads the ingredient into his next Q. See docs/champions/potion_seller.md.

enum Kind { GLUE, POISON }

@export var kind: Kind = Kind.GLUE
## Seconds the ingredient stays loaded before it fades unused.
@export var window: float = 5.0
@export var color: Color = Color(0.95, 0.8, 0.25)

@export_group("Potion changes")
## Bonus magic damage on impact: bonus_damage (+ per rank) + bonus_ap_ratio * ability power.
@export var bonus_damage: float = 30.0
@export var bonus_damage_per_rank: float = 15.0
@export var bonus_ap_ratio: float = 0.2
## Replaces the Q's radius and flight time (0 = leave the Q's own value).
@export var radius: float = 0.0
@export var flight_time: float = 0.0

@export_group("Glue")
## Slow on enemies hit (0.35 = 35%) and how long it lasts. 0 = no slow.
@export var slow: float = 0.0
@export var slow_duration: float = 2.0

@export_group("Poison")
## Total poison damage: poison_damage (+ per rank) + poison_ap_ratio * ability power, over poison_duration. 0 = no poison.
@export var poison_damage: float = 0.0
@export var poison_damage_per_rank: float = 0.0
@export var poison_ap_ratio: float = 0.0
@export var poison_duration: float = 3.0


func create_ability() -> Node:
	return load("res://scripts/abilities/potion_seller/potion_mix_ability.gd").new()
