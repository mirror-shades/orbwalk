class_name RopesEndAbility
extends Ability
## E: after a short wind-up, lash the end of the rope in a half circle in front of
## him (toward the cursor). Every enemy champion and mercenary hit takes damage
## (scales with his max HP) and is slowed.
## Passive: on an enemy champion that's already Marked, the lash uses up the mark;
## otherwise it adds a Tide stack.

const COLOR := Color(0.85, 0.7, 0.45)
const SLOW_ID := "argonaut_e_slow"

var _windup_left: float = 0.0
var _dir := Vector3.RIGHT


func is_active() -> bool:
	return _windup_left > 0.0


func _cast(target_pos: Vector3) -> void:
	var def := definition as RopesEndDefinition
	var models := caster.get_node_or_null("Models") as Node3D
	var d := target_pos - caster.global_position
	d.y = 0.0
	if d.length() < 0.1:
		d = -models.global_basis.z if models else Vector3.RIGHT
		d.y = 0.0
	_dir = d.normalized()
	if models:
		models.rotation.y = atan2(-_dir.x, -_dir.z)
	_windup_left = maxf(def.cast_time, 0.001)


func _tick(delta: float) -> void:
	if _windup_left <= 0.0:
		return
	if caster.stats.is_dead:
		_windup_left = 0.0
		return
	_windup_left -= delta
	if _windup_left <= 0.0:
		_lash()


func _lash() -> void:
	var def := definition as RopesEndDefinition
	var center := caster.global_position
	var dmg := ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad() + def.hp_ratio * caster.stats.get_max_health()
	var tide := TideMarkAbility.of(caster)
	for body in AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), center, def.radius):
		var to := body.global_position - center
		to.y = 0.0
		# Half circle: anything not behind him. A unit right on top of him counts.
		if to.length() > 0.1 and to.normalized().dot(_dir) < 0.0:
			continue
		var st := body.get_node_or_null("Stats") as StatsComponent
		if tide and st.get_entity_type() == EntityDefinition.EntityType.CHAMPION:
			tide.on_ropes_end_hit(body)
		if st.is_dead:
			continue
		st.take_physical_damage(dmg, caster)
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx and not st.is_dead:
			fx.apply_slow(def.slow, def.slow_duration, SLOW_ID)
	_flash(center, def.radius)


## A half disc in front of him that fades out.
func _flash(center: Vector3, radius: float) -> void:
	var verts := PackedVector3Array()
	var steps := 24
	var base := atan2(_dir.x, _dir.z)
	for i in steps:
		var a0 := base - PI * 0.5 + PI * float(i) / float(steps)
		var a1 := base - PI * 0.5 + PI * float(i + 1) / float(steps)
		verts.append(Vector3.ZERO)
		verts.append(Vector3(sin(a0), 0.0, cos(a0)) * radius)
		verts.append(Vector3(sin(a1), 0.0, cos(a1)) * radius)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(COLOR, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(mi)
	mi.global_position = Vector3(center.x, 0.08, center.z)
	var tw := mi.create_tween()
	tw.tween_property(mi, "transparency", 1.0, 0.35).set_delay(0.1)
	tw.tween_callback(mi.queue_free)
