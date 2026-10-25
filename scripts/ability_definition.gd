class_name AbilityDefinition
extends Resource
## Numbers for one ability. Values that change with rank use the pattern
## `x` (rank 1) + `x_per_rank` (added for each rank after 1); see Ability.ranked().
## Basic abilities have 5 ranks, the ultimate (slot 4) has 3. See docs/stats.md.

@export var ability_name: String = ""
@export var description: String = ""
@export var cooldown: float = 5.0
## Added to the cooldown each rank after 1 (negative = shorter at higher ranks).
@export var cooldown_per_rank: float = 0.0
@export var mana_cost: float = 25.0
@export var mana_cost_per_rank: float = 0.0
@export var cast_range: float = 5.0
@export var icon: Texture2D

## Creates the runtime Ability node that performs this ability (see scripts/abilities/).
## Each ability's definition subclass overrides this. It returns Node and subclasses
## load() their ability script, because naming the Ability class here would create
## a script reference loop (Entity -> definitions -> Ability -> Entity) that leaks at exit.
func create_ability() -> Node:
	return null
