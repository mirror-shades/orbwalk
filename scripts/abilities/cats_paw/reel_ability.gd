class_name ReelAbility
extends Ability
## R: if the Q knife is in the ground within range, pull yourself to it and pick it
## up. Then (or right away, if there's no knife) blast every enemy champion and
## mercenary around you: damage + fear. Towers and the orb are ignored.

var _pulling: bool = false


func is_active() -> bool:
	return _pulling


func _cast_problem() -> String:
	var fx := caster.status_effects()
	if fx and fx.is_movement_locked():
		return "Can't use R mid-dash."
	if fx and fx.is_rooted():
		return "Rooted."
	return ""


## The knife this R would pull to, or null if R would go off in place.
func pull_target_knife() -> KnifeAbility:
	var q := _knife_ability()
	if q == null or not q.has_knife_in_ground():
		return null
	var def := definition as ReelDefinition
	var to := q.knife_position()
	if Vector2(to.x - caster.global_position.x, to.z - caster.global_position.z).length() > def.pull_range:
		return null
	return q


func _cast(_target_pos: Vector3) -> void:
	var def := definition as ReelDefinition
	var q := pull_target_knife()
	if q == null:
		_blast()
		return
	var dest := DashAbility.clip_to_navmesh(caster, caster.global_position, q.knife_position())
	caster.status_effects().start_forced_move(dest, def.pull_speed)
	_pulling = true


func _tick(_delta: float) -> void:
	if not _pulling:
		return
	if caster.stats.is_dead:
		_pulling = false
		return
	if caster.status_effects().is_movement_locked():
		return
	# Arrived.
	_pulling = false
	var q := _knife_ability()
	if q:
		q.pick_up_knife()
	_blast()


func _blast() -> void:
	var def := definition as ReelDefinition
	var center := caster.global_position
	var dmg := ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	var team := caster.stats.get_team()
	for node in caster.get_tree().get_nodes_in_group("entity"):
		if node == caster or not (node is Node3D):
			continue
		var st := node.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead or st.invulnerable:
			continue
		var kind := st.get_entity_type()
		if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB:
			continue
		if not EntityData.is_enemy(team, st.get_team()):
			continue
		var body := node as Node3D
		if Vector2(body.global_position.x - center.x, body.global_position.z - center.z).length() > def.radius:
			continue
		st.take_physical_damage(dmg, caster)
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx and not st.is_dead:
			fx.apply_fear(def.fear_duration, center)
	_flash(center, def.radius)


func _knife_ability() -> KnifeAbility:
	var abilities := caster.get_node_or_null("Abilities") as AbilityCaster
	if abilities == null:
		return null
	return abilities.get_ability(0) as KnifeAbility


## A purple ring that expands to the blast radius and fades.
func _flash(center: Vector3, radius: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 64
	torus.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.4, 1.0, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	caster.get_parent().add_child(ring)
	ring.global_position = Vector3(center.x, 0.1, center.z)
	ring.scale = Vector3(0.5, 0.15, 0.5)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius, 0.15, radius), 0.25).set_ease(Tween.EASE_OUT)
	# Fade via the node (not the material) so nothing outlives the ring.
	tw.tween_property(ring, "transparency", 1.0, 0.45).set_delay(0.15)
	tw.chain().tween_callback(ring.queue_free)
