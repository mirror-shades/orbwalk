class_name WarBannerDefinition
extends AbilityDefinition
## Numbers for the Drill Sergeant's W. Placement range is `cast_range`.

## The closest allied mercenary within this distance of the spot picks the banner up.
@export var pickup_radius: float = 4.0
@export var duration: float = 10.0
## Aura radius around the banner (or its carrier).
@export var radius: float = 6.0
## Buff to allies in the aura: bonus attack speed (0.25 = +25%) and armor.
@export var attack_speed: float = 0.25
@export var attack_speed_per_rank: float = 0.05
@export var armor: float = 20.0
@export var armor_per_rank: float = 5.0


func create_ability() -> Node:
	return load("res://scripts/abilities/drill_sergeant/war_banner_ability.gd").new()
