class_name SandstormAbility
extends Ability
## R: gather a storm (anchored, aimable, up to 2s), then send it rolling. Enemies
## inside are blinded, gain Grit each second and take magic damage. Losing control
## while charging loses the storm and keeps the cooldown.

const CHANNEL_ID := "sleepwalker_channel"

var _charging: bool = false
var _charge_time: float = 0.0
var _aim := Vector3.ZERO
var _gather: Node3D
var _aim_line: MeshInstance3D


func display_name() -> String:
	return "Release" if _charging else definition.ability_name


func is_active() -> bool:
	return _charging


func wants_recast() -> bool:
	return _charging


func is_charging() -> bool:
	return _charging


## 0 at the smallest storm, 1 at full charge.
func charge_ratio() -> float:
	var def := definition as SandstormDefinition
	var span := maxf(def.max_charge - def.min_charge, 0.01)
	return clampf((_charge_time - def.min_charge) / span, 0.0, 1.0)


## Live aim while the cast is held (from PlayerController).
func set_aim(target_pos: Vector3) -> void:
	if _charging:
		_aim = target_pos


func _cast(target_pos: Vector3) -> void:
	_charging = true
	_charge_time = 0.0
	_aim = target_pos
	_gather = _make_gathering()
	get_tree().current_scene.add_child(_gather)
	_aim_line = _make_aim_line()
	get_tree().current_scene.add_child(_aim_line)
	_refresh_channel()
	_update_charge_visual()


func recast(target_pos: Vector3) -> void:
	if not _charging:
		return
	_aim = target_pos
	_release()


func _tick(delta: float) -> void:
	if not _charging:
		return
	var def := definition as SandstormDefinition
	_charge_time += delta
	var fx := caster.status_effects()
	if caster.stats.is_dead or (fx != null and (fx.is_stunned() or fx.is_feared())):
		_cancel()
		return
	_refresh_channel()
	_update_charge_visual()
	if _charge_time >= def.max_charge:
		_release()


func _refresh_channel() -> void:
	var fx := caster.status_effects()
	if fx:
		fx.apply_channel(0.3, CHANNEL_ID)


func _release() -> void:
	var def := definition as SandstormDefinition
	var ratio := charge_ratio()
	_charging = false
	var fx := caster.status_effects()
	if fx:
		fx.remove_effect(CHANNEL_ID)
	_clear_visuals()

	var from := caster.global_position
	var dir := _aim - from
	dir.y = 0.0
	if dir.length() < 0.1:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	dir = dir.normalized()
	var distance := lerpf(def.min_distance, def.max_distance, ratio)
	var dest := AbilityUtil.clip_spell_to_lane(caster, from, from + dir * distance)

	var storm := Sandstorm.new()
	storm.team = caster.stats.get_team()
	storm.source = caster
	storm.dest = Vector3(dest.x, 0.0, dest.z)
	storm.speed = def.travel_speed
	storm.radius = lerpf(def.min_radius, def.max_radius, ratio)
	storm.damage_per_tick = ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
	storm.tick_interval = def.tick_interval
	storm.blind_refresh = def.blind_refresh
	get_tree().current_scene.add_child(storm)
	storm.global_position = Vector3(from.x, 0.0, from.z)


## CC or death while charging: the storm is lost and R goes on full cooldown.
func _cancel() -> void:
	_charging = false
	if is_instance_valid(caster) and caster.status_effects():
		caster.status_effects().remove_effect(CHANNEL_ID)
	_clear_visuals()
	if is_instance_valid(caster) and caster.stats:
		start_cooldown()


func _clear_visuals() -> void:
	if is_instance_valid(_gather):
		_gather.queue_free()
	_gather = null
	if is_instance_valid(_aim_line):
		_aim_line.queue_free()
	_aim_line = null


func _update_charge_visual() -> void:
	var def := definition as SandstormDefinition
	var ratio := charge_ratio()
	var radius := lerpf(def.min_radius, def.max_radius, ratio)
	if not is_instance_valid(caster):
		return
	if is_instance_valid(_gather):
		_gather.global_position = Vector3(caster.global_position.x, 0.0, caster.global_position.z)
		_gather.scale = Vector3(radius, 1.0, radius)
	if not is_instance_valid(_aim_line):
		return
	var from := caster.global_position
	var dir := _aim - from
	dir.y = 0.0
	if dir.length() < 0.1:
		_aim_line.visible = false
		return
	dir = dir.normalized()
	var distance := lerpf(def.min_distance, def.max_distance, ratio)
	var end := AbilityUtil.clip_spell_to_lane(caster, from, from + dir * distance)
	var length := AbilityUtil.flat_distance(from, end)
	_aim_line.visible = true
	_aim_line.global_position = Vector3((from.x + end.x) * 0.5, 0.06, (from.z + end.z) * 0.5)
	_aim_line.scale = Vector3(maxf(radius * 2.0, 0.2), 1.0, maxf(length, 0.2))
	if length > 0.2:
		_aim_line.look_at(Vector3(end.x, 0.06, end.z), Vector3.UP)


func _make_gathering() -> Node3D:
	var root := Node3D.new()
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.86, 0.74, 0.5, 0.28)
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.03
	disc.radial_segments = 40
	var disc_mesh := MeshInstance3D.new()
	disc_mesh.mesh = disc
	disc_mesh.material_override = disc_mat
	disc_mesh.position.y = 0.04
	disc_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc_mesh)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.95, 0.85, 0.62, 0.8)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	ring.rings = 40
	ring.ring_segments = 6
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = ring
	ring_mesh.material_override = ring_mat
	ring_mesh.scale = Vector3(1.0, 0.15, 1.0)
	ring_mesh.position.y = 0.05
	ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring_mesh)
	return root


func _make_aim_line() -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.8, 0.55, 0.28)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.03, 1.0)
	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.material_override = mat
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.visible = false
	return line


func _exit_tree() -> void:
	if _charging:
		_cancel()
