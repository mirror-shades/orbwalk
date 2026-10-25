class_name BigIronAbility
extends Ability
## R: aim for a moment, then fire a huge slug down a straight line. The windup
## locks movement and shows a faint line. The recoil shoves him backwards even if
## the shot hits nothing, and is his only real escape.

const CHANNEL_ID := "gunslinger_big_iron_channel"
const COLOR := Color(1.0, 0.82, 0.35)

var _casting: bool = false
var _cast_left: float = 0.0
var _start := Vector3.ZERO
var _dir := Vector3.RIGHT
var _length: float = 0.0
var _telegraph: MeshInstance3D


func display_name() -> String:
	return definition.ability_name


func is_active() -> bool:
	return _casting


func _cast(target_pos: Vector3) -> void:
	var def := definition as BigIronDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = _facing()
	dir = dir.normalized()

	_dir = dir
	_start = from + dir * def.start_distance
	var end := AbilityUtil.clip_spell_to_lane(caster, _start, _start + dir * def.line_length)
	_length = AbilityUtil.flat_distance(_start, end)

	_casting = true
	_cast_left = def.cast_time
	_make_telegraph()
	_refresh_channel()


func _tick(delta: float) -> void:
	if not _casting:
		return
	var fx := caster.status_effects()
	if caster.stats.is_dead or (fx and (fx.is_stunned() or fx.is_feared())):
		_cancel()
		return
	_cast_left -= delta
	_refresh_channel()
	if _cast_left <= 0.0:
		_release()


func _refresh_channel() -> void:
	var fx := caster.status_effects()
	if fx:
		fx.apply_channel(0.2, CHANNEL_ID)


func _release() -> void:
	var def := definition as BigIronDefinition
	_casting = false
	_clear_telegraph()
	var fx := caster.status_effects()
	if fx:
		fx.remove_effect(CHANNEL_ID)

	if _length < 0.5:
		_recoil(def)
		return

	var damage := ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	_damage_line(def, damage)
	_flash()
	_recoil(def)


## Every living enemy in the line, each once. Towers and the orb are skipped.
func _damage_line(def: BigIronDefinition, damage: float) -> void:
	var center := _start + _dir * (_length * 0.5)
	var reach := Vector2(_length * 0.5, def.width * 0.5).length() + 2.0
	var along_axis := Vector2(_dir.x, _dir.z)
	var across_axis := Vector2(-_dir.z, _dir.x)
	for body in AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), center, reach):
		var rel := Vector2(body.global_position.x - _start.x, body.global_position.z - _start.z)
		var along := rel.dot(along_axis)
		var across := absf(rel.dot(across_axis))
		var radius := AbilityUtil.unit_radius(body)
		if along < -radius or along > _length + radius:
			continue
		if across > def.width * 0.5 + radius:
			continue
		var st := EntityData.get_stats_of(body)
		if st:
			st.take_physical_damage(damage, caster)


## Shoved backwards, stopping at towers, the orb and the lane edge like a dash.
func _recoil(def: BigIronDefinition) -> void:
	var fx := caster.status_effects()
	if fx == null:
		return
	var from := caster.global_position
	var to := from - _dir * def.recoil_distance
	to.y = from.y
	to = DashAbility.clip_to_navmesh(caster, from, to)
	fx.start_forced_move(to, def.recoil_speed)


func _cancel() -> void:
	_casting = false
	_cast_left = 0.0
	_clear_telegraph()
	if is_instance_valid(caster) and caster.status_effects():
		caster.status_effects().remove_effect(CHANNEL_ID)


func _facing() -> Vector3:
	var models := caster.get_node_or_null("Models") as Node3D
	if models:
		var f := -models.global_basis.z
		f.y = 0.0
		if f.length_squared() > 0.0001:
			return f
	return Vector3.RIGHT


# ---- Visuals ----

func _make_telegraph() -> void:
	_clear_telegraph()
	var def := definition as BigIronDefinition
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(COLOR, 0.18)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.02, 1.0)
	_telegraph = MeshInstance3D.new()
	_telegraph.mesh = mesh
	_telegraph.material_override = mat
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(_telegraph)

	var end := _start + _dir * _length
	_telegraph.global_position = Vector3((_start.x + end.x) * 0.5, 0.06, (_start.z + end.z) * 0.5)
	_telegraph.scale = Vector3(def.width, 1.0, _length)
	_telegraph.look_at(Vector3(end.x, 0.06, end.z), Vector3.UP)


func _flash() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var a := _start + Vector3(0.0, 1.2, 0.0)
	var b := _start + _dir * _length + Vector3(0.0, 1.2, 0.0)
	var length := a.distance_to(b)
	if length < 0.2:
		return
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.45, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(COLOR, 0.85)
	mat.emission_enabled = true
	mat.emission = COLOR * 0.9
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var beam := MeshInstance3D.new()
	beam.mesh = box
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(beam)
	beam.global_position = (a + b) * 0.5
	beam.look_at(b, Vector3.UP)
	beam.scale = Vector3(1.0, 1.0, length)
	var tw := beam.create_tween()
	tw.tween_property(beam, "transparency", 1.0, 0.3)
	tw.tween_callback(beam.queue_free)
	AbilityUtil.ring_flash(scene, b, 1.6, Color(COLOR, 0.85))


func _clear_telegraph() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _exit_tree() -> void:
	if _casting:
		_cancel()
