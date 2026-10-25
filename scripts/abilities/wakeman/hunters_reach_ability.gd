class_name HuntersReachAbility
extends Ability

const MODIFIER_ID := "wakeman_reach"


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
	var def := definition as HuntersReachDefinition
	var ranks := float(maxi(rank, 0))
	if ranks <= 0.0:
		caster.stats.remove_modifier(MODIFIER_ID)
		return
	caster.stats.set_modifier(MODIFIER_ID, {
		StatsComponent.Stat.ATTACK_RANGE: def.range_per_rank * ranks,
		StatsComponent.Stat.ATTACK_SPEED: def.attack_speed_per_rank * ranks,
	})
