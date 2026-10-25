class_name LowCutDefinition
extends AbilityDefinition
## Numbers for Cat's Paw's passive. See docs/champions/cats_paw.md.

## Bonus auto-attack damage (0.15 = +15%) applied when the victim is below `cut_below` health.
@export var bonus_damage: float = 0.15
## The victim's current health has to be below this fraction of their max (0.35 = 35%).
@export var cut_below: float = 0.35


func create_ability() -> Node:
	return load("res://scripts/abilities/cats_paw/low_cut_ability.gd").new()
