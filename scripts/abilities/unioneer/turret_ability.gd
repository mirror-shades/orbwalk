class_name TurretAbility
extends Ability

var _turrets: Array[UnioneerTurret] = []


func is_active() -> bool:
	return not _living_turrets().is_empty()


func turret_count() -> int:
	return _living_turrets().size()


func _cast(target_pos: Vector3) -> void:
	var def := definition as TurretDefinition
	var game := caster.get_parent() as ProtoGame
	if game == null:
		return
	var turrets := _living_turrets()
	if turrets.size() >= def.max_turrets:
		var oldest: UnioneerTurret = turrets.pop_front()
		if is_instance_valid(oldest):
			oldest.remove_turret()
	_turrets = turrets

	var from := caster.global_position
	var dest := AbilityUtil.clamp_to_range(from, target_pos, def.cast_range)
	dest = AbilityUtil.clip_spell_to_lane(caster, from, dest)

	var turret := UnioneerTurret.new()
	turret.setup(game, caster, def, rank)
	game.add_child(turret)
	turret.global_position = Vector3(dest.x, 0.0, dest.z)
	game.track_entity(turret)
	turret.stats.died.connect(_on_turret_died.bind(turret))
	_turrets.append(turret)
	AbilityUtil.ring_flash(get_tree().current_scene, turret.global_position, def.turret_radius + 0.5, Color(0.35, 0.75, 1.0, 0.85))


func _living_turrets() -> Array[UnioneerTurret]:
	var out: Array[UnioneerTurret] = []
	for t in _turrets:
		if is_instance_valid(t) and not t.is_queued_for_deletion() and not t.stats.is_dead:
			out.append(t)
	_turrets = out
	return out


func _on_turret_died(turret: UnioneerTurret) -> void:
	_turrets.erase(turret)
