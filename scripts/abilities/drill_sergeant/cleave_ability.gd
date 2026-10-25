class_name CleaveAbility
extends Ability
## Q: a wide swing toward the cursor. Physical damage to every enemy in the arc,
## and he heals for part of the damage dealt (more from champions than mercenaries).

const COLOR := Color(0.95, 0.75, 0.35)


func _cast(target_pos: Vector3) -> void:
	var def := definition as CleaveDefinition
	var center := caster.global_position
	var facing := target_pos - center
	facing.y = 0.0
	if facing.length() < 0.2:
		facing = _model_forward()
	facing = facing.normalized()
	_turn_model(facing)

	var dmg := ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	var healed := 0.0
	for body in AbilityUtil.enemies_in_arc(get_tree(), caster.stats.get_team(), center, facing, def.reach, def.angle):
		var st := body.get_node_or_null("Stats") as StatsComponent
		var dealt := st.take_physical_damage(dmg, caster)
		var is_champion := st.get_entity_type() == EntityDefinition.EntityType.CHAMPION
		healed += dealt * (def.champion_heal if is_champion else def.mercenary_heal)
	var scene := get_tree().current_scene
	if healed > 0.0:
		caster.stats.heal(healed)
		AbilityUtil.pop_text(scene, center + Vector3(0.0, 3.0, 0.0), "+%d" % roundi(healed), Color(0.45, 1.0, 0.5), 34)
	AbilityUtil.arc_flash(scene, center, facing, def.reach, def.angle, Color(COLOR, 0.55))


## The direction his model faces (models face -Z after mover.gd turns them).
func _model_forward() -> Vector3:
	var models := caster.get_node_or_null("Models") as Node3D
	if models:
		var f := -models.global_basis.z
		f.y = 0.0
		if f.length_squared() > 0.0001:
			return f
	return Vector3.RIGHT


func _turn_model(dir: Vector3) -> void:
	var models := caster.get_node_or_null("Models") as Node3D
	if models:
		models.rotation.y = atan2(-dir.x, -dir.z)
