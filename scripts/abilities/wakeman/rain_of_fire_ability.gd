class_name RainOfFireAbility
extends Ability

const CHANNEL_ID := "wakeman_rain_channel"
const COLOR := Color(1.0, 0.45, 0.15)

var _casting: bool = false
var _cast_left: float = 0.0
var _aim := Vector3.ZERO
var _telegraph: MeshInstance3D
var _telegraph_mat: StandardMaterial3D


func display_name() -> String:
	return definition.ability_name


func is_active() -> bool:
	return _casting


func is_charging() -> bool:
	return _casting


func set_aim(target_pos: Vector3) -> void:
	if _casting:
		_aim = target_pos


func _cast_problem() -> String:
	if caster.status_effects() and caster.status_effects().is_rooted():
		return "Rooted."
	return ""


func _cast(target_pos: Vector3) -> void:
	var def := definition as RainOfFireDefinition
	_casting = true
	_cast_left = def.cast_time
	_aim = target_pos
	_make_telegraph()
	_refresh_channel()
	_update_telegraph()


func _tick(delta: float) -> void:
	if not _casting:
		return
	var fx := caster.status_effects()
	if caster.stats.is_dead or (fx and (fx.is_stunned() or fx.is_feared())):
		_cancel()
		return
	_cast_left -= delta
	_refresh_channel()
	_update_telegraph()
	if _cast_left <= 0.0:
		_release()


func _refresh_channel() -> void:
	var fx := caster.status_effects()
	if fx:
		fx.apply_channel(0.25, CHANNEL_ID)


func _release() -> void:
	var def := definition as RainOfFireDefinition
	var from := caster.global_position
	var dir := _aim - from
	dir.y = 0.0
	if dir.length() < 0.1:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	dir = dir.normalized()
	_casting = false
	_clear_telegraph()
	var fx := caster.status_effects()
	if fx:
		fx.remove_effect(CHANNEL_ID)

	var start := from + dir * def.start_distance
	var end := AbilityUtil.clip_spell_to_lane(caster, start, start + dir * def.line_length)
	var length := AbilityUtil.flat_distance(start, end)
	if length < 0.5:
		return
	var zone := RainOfFireZone.new()
	zone.team = caster.stats.get_team()
	zone.source = caster
	zone.impact_damage = ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	zone.burn_per_tick = (ranked(def.burn_damage, def.burn_damage_per_rank) + def.burn_ad_ratio * ad()) * def.burn_tick_interval
	zone.line_length = length
	zone.width = def.width
	zone.landing_time = def.landing_time
	zone.fire_duration = def.fire_duration
	zone.tick_interval = def.burn_tick_interval
	zone.color = Color(COLOR, 0.3)
	get_tree().current_scene.add_child(zone)
	zone.launch(start, dir)


func _cancel() -> void:
	_casting = false
	_cast_left = 0.0
	_clear_telegraph()
	if is_instance_valid(caster) and caster.status_effects():
		caster.status_effects().remove_effect(CHANNEL_ID)


func _make_telegraph() -> void:
	_clear_telegraph()
	_telegraph_mat = StandardMaterial3D.new()
	_telegraph_mat.albedo_color = Color(COLOR, 0.18)
	_telegraph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.02, 1.0)
	_telegraph = MeshInstance3D.new()
	_telegraph.mesh = mesh
	_telegraph.material_override = _telegraph_mat
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_telegraph.visible = false
	get_tree().current_scene.add_child(_telegraph)


func _update_telegraph() -> void:
	if not is_instance_valid(_telegraph):
		return
	var def := definition as RainOfFireDefinition
	var from := caster.global_position
	var dir := _aim - from
	dir.y = 0.0
	if dir.length() < 0.1:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	if dir.length() < 0.1:
		_telegraph.visible = false
		return
	dir = dir.normalized()
	var start := from + dir * def.start_distance
	var end := AbilityUtil.clip_spell_to_lane(caster, start, start + dir * def.line_length)
	var length := AbilityUtil.flat_distance(start, end)
	if length < 0.5:
		_telegraph.visible = false
		return
	_telegraph.visible = true
	_telegraph.global_position = Vector3((start.x + end.x) * 0.5, 0.06, (start.z + end.z) * 0.5)
	_telegraph.scale = Vector3(def.width, 1.0, length)
	_telegraph.look_at(Vector3(end.x, 0.06, end.z), Vector3.UP)


func _clear_telegraph() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _exit_tree() -> void:
	if _casting:
		_cancel()
