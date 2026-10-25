class_name Ability
extends Node
## Base class for one champion ability. AbilityCaster handles mana and starting
## the cooldown; subclasses only describe what the ability does.
##
## Override:
##   _cast(target_pos)      what happens when it's cast (required)
##   _cast_problem()        extra reasons it can't be cast right now ("" = fine)
##   _target_problem(pos)   reasons it can't be cast at that spot (e.g. no ally clicked)
##   wants_recast()/recast() for two-part abilities (like pulling a knife back);
##                          a recast costs no mana and ignores the cooldown
##   _tick(delta)           per-frame logic

var definition: AbilityDefinition
var caster: Entity
var cooldown_left: float = 0.0
## Skill points put into this ability (0 = not learned yet). AbilityCaster sets it.
## Passives are always rank 1.
var rank: int = 0


func setup(p_definition: AbilityDefinition, p_caster: Entity) -> void:
	definition = p_definition
	caster = p_caster


func display_name() -> String:
	return definition.ability_name


func is_learned() -> bool:
	return rank > 0


## A number that grows with rank: `base` at rank 1, + `per_rank` for each rank after.
func ranked(base: float, per_rank: float) -> float:
	return base + per_rank * float(maxi(rank - 1, 0))


func mana_cost() -> float:
	return maxf(ranked(definition.mana_cost, definition.mana_cost_per_rank), 0.0)


func cooldown() -> float:
	return maxf(ranked(definition.cooldown, definition.cooldown_per_rank), 0.0)


## The cooldown after the caster's cooldown reduction.
func effective_cooldown() -> float:
	var cdr := caster.stats.get_cooldown_reduction() if caster and caster.stats else 0.0
	return cooldown() * (1.0 - cdr)


## The caster's attack damage and ability power, for "+ 70% AD" style ratios.
func ad() -> float:
	return caster.stats.get_attack_damage()


func ap() -> float:
	return caster.stats.get_ability_power()


func start_cooldown() -> void:
	cooldown_left = effective_cooldown()


## Returns "" if the ability can be cast right now, otherwise the reason it can't.
## Pass `target_pos` to also check the aim (abilities that need a target there).
func cast_problem(target_pos: Variant = null) -> String:
	if not is_learned():
		return "%s isn't learned yet." % display_name()
	if cooldown_left > 0.0:
		return "%s isn't ready." % display_name()
	if caster.stats.current_mana < mana_cost():
		return "Not enough mana."
	var problem := _cast_problem()
	if problem == "" and target_pos is Vector3:
		problem = _target_problem(target_pos)
	return problem


func cast(target_pos: Vector3) -> void:
	_cast(target_pos)


func wants_recast() -> bool:
	return false


func recast(_target_pos: Vector3) -> void:
	pass


## True while the ability has an effect waiting (e.g. an empowered attack). Used by the HUD.
func is_active() -> bool:
	return false


func _cast_problem() -> String:
	return ""


func _target_problem(_target_pos: Vector3) -> String:
	return ""


func _cast(_target_pos: Vector3) -> void:
	pass


## Per-ability game logic. Runs on the fixed simulation tick (_physics_process).
func _tick(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_tick(delta)
