class_name TurretDefinition
extends AbilityDefinition

@export var max_turrets: int = 2
@export var turret_radius: float = 0.55
@export var turret_range: float = 6.5
@export var attack_speed: float = 0.9
@export var health: float = 250.0
@export var health_per_rank: float = 75.0
@export var armor: float = 20.0
@export var magic_resist: float = 20.0
@export var base_damage: float = 18.0
@export var damage_per_rank: float = 8.0
@export var ap_ratio: float = 0.2


func create_ability() -> Node:
	return load("res://scripts/abilities/unioneer/turret_ability.gd").new()
