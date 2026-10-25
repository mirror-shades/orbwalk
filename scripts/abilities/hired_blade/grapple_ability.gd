class_name GrappleAbility
extends Ability
## E: point-and-click leap to any unit within range. Enemies take physical damage
## on arrival; allies are just a reposition. Clips at towers, the orb and the lane
## edge like every dash.

const COLOR := Color(0.8, 0.22, 0.18)
## How close to the clicked point a unit must be to be picked.
const CLICK_TOLERANCE := 1.3

var _leaping: bool = false
var _target_id: int = 0


func _ready() -> void:
	caster.status_effects().forced_move_finished.connect(_on_forced_move_finished)
	caster.stats.died.connect(_cancel_leap)


func _cast_problem() -> String:
	var fx := caster.status_effects()
	if fx == null:
		return "Can't leap."
	if fx.is_movement_locked():
		return "Already dashing."
	if fx.is_rooted():
		return "Rooted."
	return ""


func _target_problem(target_pos: Vector3) -> String:
	var target := _find_target(target_pos)
	if target == null:
		return "No unit there."
	var def := definition as GrappleDefinition
	var reach := def.cast_range + AbilityUtil.unit_radius(target)
	if AbilityUtil.flat_distance(caster.global_position, target.global_position) > reach:
		return "Out of range."
	return ""


func _cast(target_pos: Vector3) -> void:
	var target := _find_target(target_pos)
	if target == null:
		return
	var def := definition as GrappleDefinition
	var from := caster.global_position
	var to := target.global_position
	var dir := to - from
	dir.y = 0.0
	if dir.length() > 0.1:
		# Land just outside the target instead of inside it.
		to -= dir.normalized() * 0.45
	var dest := DashAbility.clip_to_navmesh(caster, from, to)
	_leaping = true
	_target_id = target.get_instance_id()
	caster.status_effects().start_forced_move(dest, def.leap_speed)


func _on_forced_move_finished() -> void:
	if not _leaping:
		return
	_leaping = false
	var target: Node3D = null
	if _target_id != 0 and is_instance_id_valid(_target_id):
		target = instance_from_id(_target_id) as Node3D
	_target_id = 0
	if target == null or caster.stats.is_dead:
		return
	var st := target.get_node_or_null("Stats") as StatsComponent
	if st == null or st.is_dead:
		return
	if not EntityData.is_enemy(caster.stats.get_team(), st.get_team()):
		return
	if AbilityUtil.flat_distance(caster.global_position, target.global_position) > 1.2 + AbilityUtil.unit_radius(target):
		return
	var def := definition as GrappleDefinition
	var dmg := ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	st.take_physical_damage(dmg, caster)
	AbilityUtil.ring_flash(get_tree().current_scene, caster.global_position, 1.4, Color(COLOR, 0.9))


func _cancel_leap() -> void:
	_leaping = false
	_target_id = 0


## The living unit closest to the clicked point (champions, mercenaries,
## monsters), or null. Structures and spawners can't be grappled to.
func _find_target(clicked: Vector3) -> Node3D:
	var def := definition as GrappleDefinition
	var my_team := caster.stats.get_team()
	var best: Node3D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("entity"):
		if not (node is Node3D) or node == caster:
			continue
		var body := node as Node3D
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead:
			continue
		var kind := st.get_entity_type()
		if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB \
				or kind == EntityDefinition.EntityType.SPAWNER:
			continue
		if not FogOfWar.can_see(my_team, body):
			continue
		var click_dist := AbilityUtil.flat_distance(body.global_position, clicked)
		if click_dist > CLICK_TOLERANCE + AbilityUtil.unit_radius(body):
			continue
		if AbilityUtil.flat_distance(caster.global_position, body.global_position) > def.cast_range + AbilityUtil.unit_radius(body):
			continue
		if click_dist < best_dist:
			best_dist = click_dist
			best = body
	return best
