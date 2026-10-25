class_name WhaleSongDefinition
extends AbilityDefinition
## Numbers for Argonaut's R. See docs/champions/argonaut.md.

## Area around him, in meters.
@export var radius: float = 4.0
## Seconds he sings before the spout erupts.
@export var cast_time: float = 0.5
## Magic damage to enemies: base_damage + ad_ratio * attack damage.
@export var base_damage: float = 150.0
@export var damage_per_rank: float = 100.0
@export var ad_ratio: float = 0.6
@export var knockup_duration: float = 1.0
## Shield on allies (and himself): shield_base + shield_hp_ratio * his max HP.
@export var shield_base: float = 100.0
@export var shield_per_rank: float = 50.0
@export var shield_hp_ratio: float = 0.08
@export var shield_duration: float = 3.0


func create_ability() -> Node:
	return load("res://scripts/abilities/argonaut/whale_song_ability.gd").new()
