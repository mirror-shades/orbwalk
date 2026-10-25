class_name ShieldRushAbility
extends Ability
## E: dash toward the cursor behind his shield. Every enemy he passes takes damage
## once; the first enemy champion he hits is stunned. Stops early at towers, the
## orb and the lane edge (like the other dashes).

var _rushing: bool = false
var _hit: Dictionary = {}
var _stunned_one: bool = false
var _damage: float = 0.0


func is_active() -> bool:
	return _rushing


func _cast_problem() -> String:
	var fx := caster.status_effects()
	if fx == null or fx.is_movement_locked():
		return "Already dashing."
	if fx.is_rooted():
		return "Rooted."
	return ""


func _cast(target_pos: Vector3) -> void:
	var def := definition as ShieldRushDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	if dir.length() < 0.1:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	dir = dir.normalized()
	var dest := DashAbility.clip_to_navmesh(caster, from, from + dir * def.distance)
	_damage = ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	_hit.clear()
	_stunned_one = false
	_rushing = true
	caster.status_effects().start_forced_move(dest, def.dash_speed)
	_hit_around()


func _tick(_delta: float) -> void:
	if not _rushing:
		return
	if caster.stats.is_dead:
		_rushing = false
		return
	_hit_around()
	if not caster.status_effects().is_movement_locked():
		_rushing = false


func _hit_around() -> void:
	var def := definition as ShieldRushDefinition
	for body in AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), caster.global_position, def.hit_radius):
		var id := body.get_instance_id()
		if _hit.has(id):
			continue
		_hit[id] = true
		var st := body.get_node_or_null("Stats") as StatsComponent
		st.take_physical_damage(_damage, caster)
		if not _stunned_one and not st.is_dead and st.get_entity_type() == EntityDefinition.EntityType.CHAMPION:
			_stunned_one = true
			var fx := body.get_node_or_null("StatusEffects") as StatusEffects
			if fx:
				fx.apply_stun(def.stun_duration)
				AbilityUtil.pop_text(get_tree().current_scene, body.global_position + Vector3(0.0, 3.0, 0.0), "Bash!", Color(1.0, 0.9, 0.3), 36)
