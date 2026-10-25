class_name WarBannerAbility
extends Ability
## W: plant a war banner near him. Allies around it (himself, allied champions and
## mercenaries) get attack speed and armor. If an allied mercenary is close to the
## spot, the closest one picks it up and carries it forward with the wave; when the
## carrier dies the banner stays where it fell. The banner can't be targeted or hurt.
## Casting again replaces the old banner.

var _banner: WarBanner


func is_active() -> bool:
	return banner() != null


## The banner that's out, or null.
func banner() -> WarBanner:
	if _banner != null and is_instance_valid(_banner) and not _banner.is_queued_for_deletion():
		return _banner
	return null


## The allied mercenary that would pick up a banner planted at `spot`, or null. Used by the bot too.
func carrier_for(spot: Vector3) -> Node3D:
	var def := definition as WarBannerDefinition
	var best: Node3D = null
	var best_d := INF
	for body in AbilityUtil.allies_in_radius(get_tree(), caster.stats.get_team(), spot, def.pickup_radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st.get_entity_type() != EntityDefinition.EntityType.MINION:
			continue
		var d := AbilityUtil.flat_distance(spot, body.global_position)
		if d < best_d:
			best_d = d
			best = body
	return best


func _cast(target_pos: Vector3) -> void:
	var def := definition as WarBannerDefinition
	var old := banner()
	if old:
		old.queue_free()
	var spot := AbilityUtil.clamp_to_range(caster.global_position, target_pos, def.cast_range)
	var b := WarBanner.new()
	b.team = caster.stats.get_team()
	b.radius = def.radius
	b.duration = def.duration
	b.bonuses = {
		StatsComponent.Stat.ATTACK_SPEED: ranked(def.attack_speed, def.attack_speed_per_rank),
		StatsComponent.Stat.ARMOR: ranked(def.armor, def.armor_per_rank),
	}
	b.carrier = carrier_for(spot)
	var scene := get_tree().current_scene
	scene.add_child(b)
	b.global_position = spot
	_banner = b
	AbilityUtil.ring_flash(scene, spot, def.radius, Color(1.0, 0.85, 0.4, 0.8))
	if b.carrier:
		AbilityUtil.pop_text(scene, b.carrier.global_position + Vector3(0.0, 3.0, 0.0), "Carry the colors!", Color(1.0, 0.85, 0.4), 30)
