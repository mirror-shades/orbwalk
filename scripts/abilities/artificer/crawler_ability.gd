class_name CrawlerAbility
extends Ability
## Q: send one robot crawling to a spot. It arms for a moment, explodes once
## (damage and slow in a wide radius), then goes dormant there for the rest of its
## lifetime. There is no cap on how many robots can be out.
##
## Q has charges: each cast spends one and that charge returns on its own cooldown,
## so a second cast while the first is still recharging works, and the timers overlap.
## `cooldown_left` is the wait for the next charge once all of them are spent.

var _recharge: Array[float] = []


func max_charges() -> int:
	return (definition as CrawlerDefinition).max_charges


func charges() -> int:
	return max_charges() - _recharge.size()


func start_cooldown() -> void:
	_recharge.append(effective_cooldown())
	_sync_cooldown()


func cast_problem(target_pos: Variant = null) -> String:
	var saved := cooldown_left
	if charges() > 0:
		cooldown_left = 0.0
	var problem := super.cast_problem(target_pos)
	cooldown_left = saved
	return problem


func _tick(delta: float) -> void:
	for i in range(_recharge.size() - 1, -1, -1):
		_recharge[i] -= delta
		if _recharge[i] <= 0.0:
			_recharge.remove_at(i)
	_sync_cooldown()


func _sync_cooldown() -> void:
	if charges() > 0 or _recharge.is_empty():
		cooldown_left = 0.0
		return
	var soonest := _recharge[0]
	for t in _recharge:
		soonest = minf(soonest, t)
	cooldown_left = soonest


func _cast(target_pos: Vector3) -> void:
	var def := definition as CrawlerDefinition
	var manager := ArtificerRobots.get_or_create(caster)
	if manager == null:
		return
	var spot := AbilityUtil.clamp_to_range(caster.global_position, target_pos, def.cast_range)
	var damage := ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
	var robot := ArtificerRobot.new()
	robot.setup(caster, manager, spot, damage, def.pulse_radius, ranked(def.slow, def.slow_per_rank), def.slow_duration)
	robot.crawl_speed = def.deploy_speed
	robot.pulse_interval = def.pulse_interval
	robot.pulses_left = def.pulses
	robot.lifetime = def.lifetime
	manager.add_robot(robot)
	robot.global_position = Vector3(caster.global_position.x, 0.0, caster.global_position.z)
	robot.start_crawl(spot)
