class_name ChainLightningAbility
extends Ability

const COLOR := Color(0.35, 0.75, 1.0)
const HEIGHT := 1.2


func _cast(target_pos: Vector3) -> void:
	var def := definition as ChainLightningDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	if dir.length() < 0.1:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	var first := _first_on_line(from, from + dir * def.bolt_range, def.width)
	if first == null:
		return

	var damage := ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
	var hit: Array[Node3D] = [first]
	var bounced: Dictionary = {}
	var links: Array[Vector3] = [from + Vector3(0.0, HEIGHT, 0.0), _aim_point(first)]
	_damage(first, damage)
	var last_pos := first.global_position
	var chains_left := def.max_chains
	while chains_left > 0:
		var next := _nearest_unhit(last_pos, def.chain_range, hit)
		if next:
			hit.append(next)
			_damage(next, damage)
			links.append(_aim_point(next))
			last_pos = next.global_position
			chains_left -= 1
			continue
		var relay := _nearest_relay(last_pos, def.chain_range, bounced)
		if relay == null:
			break
		bounced[relay.get_instance_id()] = true
		links.append(_aim_point(relay))
		last_pos = relay.global_position
	_draw(links)


func _first_on_line(from: Vector3, to: Vector3, width: float) -> Node3D:
	var best: Node3D = null
	var best_t := INF
	var ab := Vector2(to.x - from.x, to.z - from.z)
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return null
	var center := (from + to) * 0.5
	var reach := Vector2(ab).length() * 0.5 + width + 2.0
	for body in AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), center, reach):
		var ap := Vector2(body.global_position.x - from.x, body.global_position.z - from.z)
		var t := ap.dot(ab) / len2
		if t < 0.0 or t > 1.0:
			continue
		if (ap - ab * t).length() > width * 0.5 + AbilityUtil.unit_radius(body):
			continue
		if t < best_t:
			best_t = t
			best = body
	return best


func _nearest_unhit(center: Vector3, radius: float, hit: Array[Node3D]) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for body in AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), center, radius):
		if hit.has(body):
			continue
		var d := AbilityUtil.flat_distance(center, body.global_position)
		if d < best_d:
			best_d = d
			best = body
	return best


func _nearest_relay(center: Vector3, radius: float, bounced: Dictionary) -> UnioneerTurret:
	var best: UnioneerTurret = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("unioneer_turret"):
		var t := node as UnioneerTurret
		if t == null or t.stats.is_dead or t.team != caster.stats.get_team():
			continue
		if t.owner_champion != caster or bounced.has(t.get_instance_id()):
			continue
		var d := AbilityUtil.flat_distance(center, t.global_position)
		if d <= radius and d < best_d:
			best_d = d
			best = t
	return best


func _damage(body: Node3D, damage: float) -> void:
	var st := EntityData.get_stats_of(body)
	if st:
		st.take_magic_damage(damage, caster)


func _aim_point(body: Node3D) -> Vector3:
	return body.global_position + Vector3(0.0, HEIGHT, 0.0)


func _draw(links: Array[Vector3]) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for i in range(links.size() - 1):
		UnioneerBeam.flash(scene, links[i], links[i + 1], COLOR, 0.3)
