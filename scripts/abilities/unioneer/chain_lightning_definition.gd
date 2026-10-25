class_name ChainLightningDefinition
extends AbilityDefinition

@export var bolt_range: float = 10.0
@export var width: float = 0.9
@export var chain_range: float = 5.0
@export var max_chains: int = 4
@export var base_damage: float = 100.0
@export var damage_per_rank: float = 50.0
@export var ap_ratio: float = 0.7


func create_ability() -> Node:
	return load("res://scripts/abilities/unioneer/chain_lightning_ability.gd").new()
