class_name OverloadDefinition
extends AbilityDefinition

@export var radius: float = 7.0
@export var leash_range: float = 10.0
@export var shock_count: int = 3
@export var shock_interval: float = 0.5
@export var base_damage: float = 60.0
@export var damage_per_rank: float = 30.0
@export var ap_ratio: float = 0.25
@export var stun_duration: float = 1.5


func create_ability() -> Node:
	return load("res://scripts/abilities/unioneer/overload_ability.gd").new()
