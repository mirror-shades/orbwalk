class_name FlashbangAbility
extends Ability

const COLOR := Color(1.0, 0.92, 0.45)
const SLOW_ID := "wakeman_flashbang_slow"
const BLIND_ID := "wakeman_flashbang_blind"


func _cast(target_pos: Vector3) -> void:
	var def := definition as FlashbangDefinition
	var from := caster.global_position
	var dest := AbilityUtil.clamp_to_range(from, target_pos, def.cast_range)
	var flask := LobbedFlask.throw(get_tree().current_scene, from + Vector3(0.0, 1.2, 0.0), dest, def.flight_time, COLOR, 0.28, def.radius)
	flask.landed.connect(_on_landed)


func _on_landed(pos: Vector3) -> void:
	var def := definition as FlashbangDefinition
	var damage := ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	var source: Node = caster if is_instance_valid(caster) else null
	for body in AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), pos, def.radius):
		var st := EntityData.get_stats_of(body)
		if st == null or st.is_dead:
			continue
		st.take_physical_damage(damage, source)
		if st.is_dead:
			continue
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			fx.apply_slow(def.slow, def.slow_duration, SLOW_ID)
			fx.apply_blind(def.blind_duration, BLIND_ID)
	AbilityUtil.ring_flash(get_tree().current_scene, pos, def.radius, Color(COLOR, 0.9))
