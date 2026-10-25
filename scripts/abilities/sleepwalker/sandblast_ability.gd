class_name SandblastAbility
extends Ability
## E: spends every Grit stack on enemies within 8 for damage per stack and a
## stun of 0.4s per stack. Refused if nobody nearby is stacked.

func _cast_problem() -> String:
	var grit := GritAbility.of(caster)
	var def := definition as SandblastDefinition
	if grit == null or grit.stacked_in_radius(caster.global_position, def.radius).is_empty():
		return "No enemy with Grit nearby."
	return ""


func _cast(_target_pos: Vector3) -> void:
	var def := definition as SandblastDefinition
	var grit := GritAbility.of(caster)
	if grit == null:
		return
	var damage_base := ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
	var damage_per_stack := ranked(def.per_stack_damage, def.per_stack_per_rank) + def.stack_ap_ratio * ap()
	for body in grit.stacked_in_radius(caster.global_position, def.radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead:
			continue
		var stacks := grit.stacks_of(body)
		st.take_magic_damage(damage_base + damage_per_stack * float(stacks), caster)
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx and not st.is_dead:
			fx.apply_stun(def.stun_per_stack * float(stacks))
		grit.consume(body)
	AbilityUtil.ring_flash(get_tree().current_scene, caster.global_position, def.radius, Color(0.92, 0.8, 0.55, 0.9))
