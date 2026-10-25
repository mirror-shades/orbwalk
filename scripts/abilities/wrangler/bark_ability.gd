class_name BarkAbility
extends Ability
## W: the pug barks wherever it is, damaging and slowing every enemy around it.
## Self-cast: the cursor doesn't matter. Structures are never hit.

const SLOW_ID := "wrangler_bark_slow"
const COLOR := Color(0.95, 0.75, 0.35)


func _cast(_target_pos: Vector3) -> void:
	var pet := WranglerPounceAbility.pet_of(caster)
	var center := pet.global_position if pet else caster.global_position
	var def := definition as BarkDefinition
	var dmg := ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	for body in AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), center, def.radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		st.take_physical_damage(dmg, caster)
		if st.is_dead:
			continue
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			fx.apply_slow(def.slow, def.slow_duration, SLOW_ID)
	if pet:
		pet.bite()
	AbilityUtil.ring_flash(get_tree().current_scene, center, def.radius, Color(COLOR, 0.9))
