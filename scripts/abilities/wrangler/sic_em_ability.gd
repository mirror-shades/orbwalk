class_name SicEmAbility
extends Ability
## Q: the pug jumps onto an enemy champion, mercenary or jungle monster and stays
## there, biting three times. It lets go if the target gets too far from her, if the
## target dies, or if E/R gives it a new command.

const CLICK_TOLERANCE := 1.3

var _target: Node3D
var _latched := false
var _bites_left := 0
var _bite_timer := 0.0


func is_active() -> bool:
	return _latched


func _cast_problem() -> String:
	var pet := WranglerPounceAbility.pet_of(caster)
	if pet == null:
		return "The pug isn't here."
	if pet.is_charging():
		return "The pug is charging."
	return ""


func _target_problem(target_pos: Vector3) -> String:
	if _find_target(target_pos) == null:
		return "No enemy unit there."
	return ""


func _cast(target_pos: Vector3) -> void:
	var target := _find_target(target_pos)
	if target == null:
		return
	var pet := WranglerPounceAbility.pet_of(caster)
	if pet == null:
		return
	var def := definition as SicEmDefinition
	_target = target
	_latched = false
	_bites_left = 0
	_bite_timer = 0.0
	pet.leap_to_target(target, def.leap_speed, _on_arrived.bind(target))


func _on_arrived(target: Node3D) -> void:
	if target == null or not is_instance_valid(target) or target != _target:
		return
	var pet := WranglerPounceAbility.pet_of(caster)
	if pet == null:
		return
	pet.latch_to(target)
	_latched = true
	_bites_left = (definition as SicEmDefinition).bites
	_bite_timer = 0.0


func _tick(delta: float) -> void:
	if not _latched:
		return
	var pet := WranglerPounceAbility.pet_of(caster)
	if pet == null or caster.stats.is_dead:
		_end()
		return
	if not pet.is_latched_to(_target):
		# E, R or a new Q took the pug away.
		_latched = false
		return
	var st := _target.get_node_or_null("Stats") as StatsComponent
	if st == null or st.is_dead:
		_end()
		return
	var def := definition as SicEmDefinition
	if ProtoUtil.flat_distance(caster.global_position, _target.global_position) > def.leash_range:
		_end()
		return
	_bite_timer -= delta
	if _bite_timer > 0.0:
		return
	_bite_timer = def.bite_interval
	_bite()
	_bites_left -= 1
	if _bites_left <= 0:
		_end()


func _bite() -> void:
	var st := _target.get_node_or_null("Stats") as StatsComponent
	if st == null or st.is_dead:
		return
	var def := definition as SicEmDefinition
	var dmg := ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	st.take_physical_damage(dmg, caster)
	var pet := WranglerPounceAbility.pet_of(caster)
	if pet:
		pet.bite()
	AbilityUtil.ring_flash(get_tree().current_scene, _target.global_position, 0.9, Color(0.95, 0.75, 0.35, 0.8))


func _end() -> void:
	_latched = false
	_bites_left = 0
	_bite_timer = 0.0
	_target = null
	var pet := WranglerPounceAbility.pet_of(caster)
	if pet:
		pet.follow()


## The living enemy unit closest to the clicked point: champions, mercenaries and
## jungle monsters. Structures can't be targeted.
func _find_target(clicked: Vector3) -> Node3D:
	var team := caster.stats.get_team()
	var best: Node3D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("entity"):
		if not (node is Node3D) or node == caster:
			continue
		var body := node as Node3D
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead or st.invulnerable:
			continue
		var kind := st.get_entity_type()
		if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB \
				or kind == EntityDefinition.EntityType.SPAWNER:
			continue
		if not EntityData.is_enemy(team, st.get_team()):
			continue
		if not FogOfWar.can_see(team, body):
			continue
		var click_dist := ProtoUtil.flat_distance(body.global_position, clicked)
		if click_dist > CLICK_TOLERANCE + AbilityUtil.unit_radius(body):
			continue
		if ProtoUtil.flat_distance(caster.global_position, body.global_position) > definition.cast_range + AbilityUtil.unit_radius(body):
			continue
		if click_dist < best_dist:
			best_dist = click_dist
			best = body
	return best
