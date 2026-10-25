class_name ForwardMarchAbility
extends Ability
## R: "Forward, march!" He and every allied mercenary near him get bonus move speed,
## bonus damage and slow immunity for a few seconds, and he gets a big shield.
## Allied champions aren't buffed (that's the banner's job). Doesn't remove fear or stuns.

const BUFF_ID := "forward_march"
const SHIELD_ID := "forward_march_shield"
const COLOR := Color(1.0, 0.8, 0.3)

var _active_left: float = 0.0


func is_active() -> bool:
	return _active_left > 0.0


## Allied mercenaries that would be buffed if he cast now. Used by the bot.
func mercenaries_in_range() -> int:
	var def := definition as ForwardMarchDefinition
	var n := 0
	for body in AbilityUtil.allies_in_radius(get_tree(), caster.stats.get_team(), caster.global_position, def.radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st.get_entity_type() == EntityDefinition.EntityType.MINION:
			n += 1
	return n


func _cast(_target_pos: Vector3) -> void:
	var def := definition as ForwardMarchDefinition
	var center := caster.global_position
	for body in AbilityUtil.allies_in_radius(get_tree(), caster.stats.get_team(), center, def.radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		if body != caster and st.get_entity_type() != EntityDefinition.EntityType.MINION:
			continue
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx == null:
			continue
		# Separate ids: effects that share an id replace each other.
		fx.apply_move_speed(def.move_speed, def.duration, BUFF_ID + "_speed")
		fx.apply_slow_immunity(def.duration, BUFF_ID + "_immune")
		fx.apply_stat_buff(BUFF_ID, {StatsComponent.Stat.ATTACK_DAMAGE: st.get_base_attack_damage() * def.damage_bonus}, def.duration, "March!")
	var shield := ranked(def.shield_base, def.shield_per_rank) + def.shield_hp_ratio * caster.stats.get_max_health()
	caster.stats.add_shield(shield, def.duration, SHIELD_ID)
	_active_left = def.duration
	var scene := get_tree().current_scene
	AbilityUtil.ring_flash(scene, center, def.radius, Color(COLOR, 0.9))
	AbilityUtil.pop_text(scene, center + Vector3(0.0, 3.3, 0.0), "Forward, march!", COLOR, 44)


func _tick(delta: float) -> void:
	if _active_left > 0.0:
		_active_left -= delta
