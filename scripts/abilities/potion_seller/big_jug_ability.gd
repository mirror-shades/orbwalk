class_name BigJugAbility
extends Ability
## R: roll a big jug along the ground to the clicked point (or max range). Press R
## again to explode it early, or it explodes when the fuse runs out.
## The blast deals magic damage and poisons every enemy in it, then leaves goo that
## heavily slows enemies standing in it. W and E never change the jug.
## Hitting an enemy champion triggers his passive.

var _jug: RollingJug


func display_name() -> String:
	return "Explode" if _jug_alive() else definition.ability_name


func is_active() -> bool:
	return _jug_alive()


func wants_recast() -> bool:
	return _jug_alive() and _jug.age >= (definition as BigJugDefinition).min_recast_time


func recast(_target_pos: Vector3) -> void:
	if _jug_alive():
		_jug.explode()


## The jug on the ground, or null. Used by the bot.
func jug() -> RollingJug:
	return _jug if _jug_alive() else null


func _cast_problem() -> String:
	if _jug_alive():
		return "The jug is still rolling."
	return ""


func _cast(target_pos: Vector3) -> void:
	var def := definition as BigJugDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	var roll := def.roll_distance
	if dir.length() >= 0.1:
		# Roll to the clicked point, or max range if it was further away.
		roll = clampf(dir.length(), 0.0, def.roll_distance)
	else:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	dir = dir.normalized()
	# Towers and the orb don't block spells; only the lane edge stops the jug.
	var dest := AbilityUtil.clip_spell_to_lane(caster, from, from + dir * roll)

	var j := RollingJug.new()
	j.team = caster.stats.get_team()
	j.source = caster
	j.dest = Vector3(dest.x, 0.0, dest.z)
	j.speed = def.roll_speed
	j.fuse_time = def.fuse_time
	j.radius = def.radius
	j.damage = ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
	j.poison_damage = ranked(def.poison_damage, def.poison_damage_per_rank) + def.poison_ap_ratio * ap()
	j.poison_duration = def.poison_duration
	j.goo_slow = def.goo_slow
	j.goo_duration = def.goo_duration
	var passive := SatisfiedCustomerAbility.of(caster)
	if passive:
		j.champion_hit.connect(passive.on_spell_hit)
	get_tree().current_scene.add_child(j)
	var spawn_dist := minf(0.8, Vector2(dest.x - from.x, dest.z - from.z).length())
	j.global_position = Vector3(from.x, 0.0, from.z) + dir * spawn_dist
	j.exploded.connect(_on_exploded)
	_jug = j


func _on_exploded() -> void:
	_jug = null


func _jug_alive() -> bool:
	return _jug != null and is_instance_valid(_jug) and not _jug.is_queued_for_deletion()
