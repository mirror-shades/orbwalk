class_name HeavyOrbAbility
extends Ability
## R: a huge, slow orb rolls straight out. It damages every enemy it passes through
## once, then bursts at the end of the road (or when R is pressed again): heavy
## magic damage and a long stun to every enemy near it. The recast costs nothing.

var _orb: HeavyOrb


func display_name() -> String:
	return "Burst" if _orb_alive() else definition.ability_name


func is_active() -> bool:
	return _orb_alive()


func wants_recast() -> bool:
	return _orb_alive() and _orb.age >= (definition as HeavyOrbDefinition).min_recast_time


func recast(_target_pos: Vector3) -> void:
	if _orb_alive():
		_orb.burst()


## The orb in flight, or null. Used by the bot.
func orb() -> HeavyOrb:
	return _orb if _orb_alive() else null


func _cast_problem() -> String:
	if _orb_alive():
		return "The orb is still rolling."
	return ""


func _cast(target_pos: Vector3) -> void:
	var def := definition as HeavyOrbDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	if dir.length() < 0.1:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	dir = dir.normalized()
	# Always the full distance. Towers and the orb don't block spells; only the
	# lane edge does.
	var dest := AbilityUtil.clip_spell_to_lane(caster, from, from + dir * def.travel_distance)

	var o := HeavyOrb.new()
	o.team = caster.stats.get_team()
	o.source = caster
	o.dest = Vector3(dest.x, 0.0, dest.z)
	o.speed = def.travel_speed
	o.radius = def.orb_radius
	o.damage = ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
	o.burst_radius = def.burst_radius
	o.burst_damage = ranked(def.burst_damage, def.burst_damage_per_rank) + def.burst_ap_ratio * ap()
	o.stun_duration = ranked(def.stun_duration, def.stun_duration_per_rank)
	get_tree().current_scene.add_child(o)
	o.global_position = Vector3(from.x, 0.0, from.z) + dir * minf(0.6, Vector2(dest.x - from.x, dest.z - from.z).length())
	o.finished.connect(_on_finished)
	_orb = o


func _on_finished() -> void:
	_orb = null


func _orb_alive() -> bool:
	return _orb != null and is_instance_valid(_orb) and not _orb.is_queued_for_deletion()
