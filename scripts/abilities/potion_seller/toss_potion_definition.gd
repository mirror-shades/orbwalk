class_name TossPotionDefinition
extends AbilityDefinition
## Numbers for the Potion Seller's Q. Throw range is `cast_range`. See docs/champions/potion_seller.md.

@export var radius: float = 1.5
## Seconds in the air (the same at any distance, so it's easy to read).
@export var flight_time: float = 0.5
## Magic damage: base_damage (+ damage_per_rank) + ap_ratio * ability power.
@export var base_damage: float = 45.0
@export var damage_per_rank: float = 20.0
@export var ap_ratio: float = 0.35
@export var color: Color = Color(0.45, 0.85, 1.0)


func create_ability() -> Node:
	return load("res://scripts/abilities/potion_seller/toss_potion_ability.gd").new()
