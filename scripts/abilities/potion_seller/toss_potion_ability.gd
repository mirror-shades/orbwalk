class_name TossPotionAbility
extends Ability
## Q: toss a small potion at a spot (clamped to range). It lands after a short,
## fixed flight and shatters, dealing magic damage to every enemy in a small circle.
## The landing spot is shown while it flies.
## If W (glue) or E (poison) is loaded, this potion uses it: glue makes it bigger,
## slower and slowing; poison adds impact damage and a poison.
## Hitting an enemy champion triggers his passive.


func _cast(target_pos: Vector3) -> void:
	var def := definition as TossPotionDefinition
	var to := AbilityUtil.clamp_to_range(caster.global_position, target_pos, def.cast_range)
	var mix := PotionMixAbility.loaded_on(caster)
	var fx: Dictionary = mix.consume() if mix else {}
	var radius := float(fx.get("radius", 0.0))
	if radius <= 0.0:
		radius = def.radius
	var flight := float(fx.get("flight_time", 0.0))
	if flight <= 0.0:
		flight = def.flight_time
	var color: Color = fx.get("color", def.color)
	var dmg := ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap() + float(fx.get("bonus_damage", 0.0))
	var size := 0.25 if mix == null else 0.32
	var flask := LobbedFlask.throw(caster.get_parent(), caster.global_position + Vector3(0.0, 1.6, 0.0), to, flight, color, size, radius)
	flask.landed.connect(_on_landed.bind(caster.stats.get_team(), dmg, radius, color, fx))


func _on_landed(pos: Vector3, team: int, dmg: float, radius: float, color: Color, fx: Dictionary) -> void:
	var src: Node = caster if is_instance_valid(caster) else null
	var slow := float(fx.get("slow", 0.0))
	var poison := float(fx.get("poison_damage", 0.0))
	var passive := SatisfiedCustomerAbility.of(caster) if src else null
	for body in AbilityUtil.enemies_in_radius(get_tree(), team, pos, radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		st.take_magic_damage(dmg, src)
		if passive:
			passive.on_spell_hit(body)
		var se := body.get_node_or_null("StatusEffects") as StatusEffects
		if se == null or st.is_dead:
			continue
		if slow > 0.0:
			se.apply_slow(slow, float(fx.get("slow_duration", 2.0)), "ps_glue_slow")
		if poison > 0.0:
			se.apply_poison(poison, float(fx.get("poison_duration", 3.0)), src, "ps_poison")
	AbilityUtil.ring_flash(get_tree().current_scene, pos, radius, Color(color, 0.9))
