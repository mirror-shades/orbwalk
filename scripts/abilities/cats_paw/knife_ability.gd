class_name KnifeAbility
extends Ability
## Q: throw the knife in a straight line (damage + slow on everything it passes).
## It lands at the clicked point (or max range) and stays for a few seconds. Press
## Q again to recall it, hitting everything on the way back. Pressing Q while the
## knife is still flying queues the recall for when it lands instead of cancelling
## the throw. The cooldown starts on the throw and can never be shorter than the
## knife's time out, so only one knife exists at a time.
##
## R uses has_knife_in_ground(), knife_position() and pick_up_knife().

var _knife: ThrownKnife


func display_name() -> String:
	return "Recall" if _has_knife() else definition.ability_name


func is_active() -> bool:
	return _has_knife()


## Cooldown reduction can never take Q below the knife's time out, so only one knife exists at a time.
func effective_cooldown() -> float:
	var def := definition as KnifeDefinition
	return maxf(super(), def.lifetime + def.cast_range / maxf(def.throw_speed, 0.01))


func wants_recast() -> bool:
	return _has_knife() and _knife.state != ThrownKnife.State.RECALL


func recast(_target_pos: Vector3) -> void:
	if _has_knife():
		_knife.request_recall()


func has_knife_in_ground() -> bool:
	return _has_knife() and _knife.is_in_ground()


func knife_position() -> Vector3:
	return _knife.ground_position() if _has_knife() else Vector3.ZERO


func pick_up_knife() -> void:
	if _has_knife():
		_knife.remove()


func _cast(target_pos: Vector3) -> void:
	var def := definition as KnifeDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	var distance := def.cast_range
	if dir.length() >= 0.1:
		# Land where the player clicked, not always at max range.
		distance = clampf(dir.length(), 0.0, def.cast_range)
	else:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	dir = dir.normalized()

	var knife := ThrownKnife.new()
	knife.thrower = caster
	knife.team = caster.stats.get_team()
	knife.damage = ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	knife.slow = def.slow
	knife.slow_duration = def.slow_duration
	knife.width = def.width
	knife.lifetime = def.lifetime
	knife.throw_speed = def.throw_speed
	knife.recall_speed = def.recall_speed
	caster.get_parent().add_child(knife)
	knife.launch(from + Vector3(0.0, 1.0, 0.0), from + dir * distance + Vector3(0.0, 0.3, 0.0))
	knife.finished.connect(_on_knife_finished)
	_knife = knife


func _has_knife() -> bool:
	return _knife != null and is_instance_valid(_knife) and not _knife.is_queued_for_deletion()


func _on_knife_finished() -> void:
	_knife = null
