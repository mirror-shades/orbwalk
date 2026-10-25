class_name QuickDrawAbility
extends Ability
## W (passive): each rank permanently grants bonus attack speed and crit chance.
## The stat engine that makes his slow autos and crit payoff come online.

const MODIFIER_ID := "gunslinger_quick_draw"


func _ready() -> void:
	var caster_node := get_parent() as AbilityCaster
	if caster_node:
		caster_node.ability_ranked_up.connect(_on_ranked_up)
	_apply()


func cast_problem(_target_pos: Variant = null) -> String:
	return "%s is a passive." % display_name()


func _on_ranked_up(slot: int, _new_rank: int) -> void:
	if slot == 1:
		_apply()


func _apply() -> void:
	if caster == null or caster.stats == null:
		return
	var def := definition as QuickDrawDefinition
	var ranks := float(maxi(rank, 0))
	if ranks <= 0.0:
		caster.stats.remove_modifier(MODIFIER_ID)
		return
	caster.stats.set_modifier(MODIFIER_ID, {
		StatsComponent.Stat.ATTACK_SPEED: def.attack_speed_per_rank * ranks,
		StatsComponent.Stat.CRIT_CHANCE: def.crit_chance_per_rank * ranks,
	})
