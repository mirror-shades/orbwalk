class_name KataAbility
extends Ability
## Passive: every successful spell cast ticks every ability's cooldown down 1s
## and refreshes/extends his stacking move speed.

const SPEED_ID := "hired_blade_kata"

var _stacks: int = 0


func _ready() -> void:
	var caster_node := get_parent() as AbilityCaster
	if caster_node:
		caster_node.ability_cast.connect(_on_ability_cast)


func _on_ability_cast(_slot: int) -> void:
	var def := definition as KataDefinition
	var caster_node := get_parent() as AbilityCaster
	if caster_node == null or def == null:
		return
	for ability in caster_node.abilities:
		if ability:
			ability.cooldown_left = maxf(ability.cooldown_left - def.cooldown_discount, 0.0)
	var fx := caster.status_effects()
	if fx == null:
		return
	if not fx.has_effect(SPEED_ID):
		_stacks = 0
	_stacks = mini(_stacks + 1, def.max_stacks)
	fx.apply_move_speed(def.move_speed_per_stack * float(_stacks), def.stack_duration, SPEED_ID)
