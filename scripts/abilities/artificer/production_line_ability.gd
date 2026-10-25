class_name ProductionLineAbility
extends Ability
## R: a wall of five robots across the aim, centered on the aimed spot. They are the
## same robots as Q's (crawl out, arm, burst once, sit dormant until their lifetime
## ends) and join W and E like any other, so R then W is the big nuke.


func _cast(target_pos: Vector3) -> void:
	var def := definition as ProductionLineDefinition
	var manager := ArtificerRobots.get_or_create(caster)
	if manager == null:
		return
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	var dist := dir.length()
	if dist < 0.0001:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
		if dir.length_squared() < 0.0001:
			dir = Vector3.RIGHT
		dist = 0.0
	dir = dir.normalized()
	var across := Vector3(-dir.z, 0.0, dir.x)
	var center := from + dir * clampf(dist, def.start_distance, definition.cast_range)
	var damage := ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
	var slow := def.slow
	for i in def.robot_count:
		var offset := (float(i) - float(def.robot_count - 1) * 0.5) * def.spacing
		var spot := AbilityUtil.clip_spell_to_lane(caster, from, center + across * offset)
		var robot := ArtificerRobot.new()
		robot.setup(caster, manager, spot, damage, def.pulse_radius, slow, def.slow_duration)
		robot.crawl_speed = def.deploy_speed
		robot.pulse_interval = def.pulse_interval
		robot.pulses_left = def.pulses
		robot.lifetime = def.lifetime
		manager.add_robot(robot)
		robot.global_position = Vector3(from.x, 0.0, from.z)
		robot.start_crawl(spot)
