class_name SmokeBombAbility
extends Ability
## R: he vanishes into smoke. For the duration every enemy auto-attack aimed at
## him misses; abilities and structure shots still land. At the end (or on recast)
## a stun bursts around him. Dying cancels the stun.

const DODGE_ID := "hired_blade_smoke"
const COLOR := Color(0.45, 0.45, 0.52)

var _pending: bool = false
var _time_left: float = 0.0
var _visual: MeshInstance3D


func _ready() -> void:
	caster.stats.died.connect(_cancel_smoke)


func display_name() -> String:
	return "Detonate" if _pending else definition.ability_name


func is_active() -> bool:
	return _pending


func wants_recast() -> bool:
	return _pending


func recast(_target_pos: Vector3) -> void:
	if _pending:
		_burst()


func _cast(_target_pos: Vector3) -> void:
	var def := definition as SmokeBombDefinition
	_pending = true
	_time_left = def.duration
	caster.status_effects().apply_dodge(def.duration, DODGE_ID)
	_show_smoke(def.radius)


func _tick(delta: float) -> void:
	if not _pending:
		return
	if caster.stats.is_dead:
		_cancel_smoke()
		return
	_time_left -= delta
	if _visual and is_instance_valid(_visual):
		_visual.global_position = Vector3(caster.global_position.x, 0.06, caster.global_position.z)
	if _time_left <= 0.0:
		_burst()


func _burst() -> void:
	if not _pending:
		return
	_pending = false
	_time_left = 0.0
	_hide_smoke()
	caster.status_effects().remove_effect(DODGE_ID)
	if caster.stats.is_dead:
		return
	var def := definition as SmokeBombDefinition
	var stun := ranked(def.stun_duration, def.stun_duration_per_rank)
	var center := caster.global_position
	var count := 0
	for body in AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), center, def.radius):
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			fx.apply_stun(stun)
			count += 1
	var scene := get_tree().current_scene
	AbilityUtil.ring_flash(scene, center, def.radius, Color(COLOR, 0.95))
	AbilityUtil.pop_text(scene, center + Vector3(0.0, 3.2, 0.0), "Smoke!", COLOR, 40)
	if count > 0:
		AbilityUtil.pop_text(scene, center + Vector3(0.0, 2.8, 0.0), "Stunned %d" % count, Color(1.0, 0.9, 0.4), 32)


## A dark disc on the ground that follows him while the smoke lasts.
func _show_smoke(radius: float) -> void:
	_hide_smoke()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 48
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(COLOR, 0.32)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_visual = MeshInstance3D.new()
	_visual.mesh = disc
	_visual.material_override = mat
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(_visual)
	_visual.global_position = Vector3(caster.global_position.x, 0.06, caster.global_position.z)


func _hide_smoke() -> void:
	if _visual and is_instance_valid(_visual):
		_visual.queue_free()
	_visual = null


## Dying removes the smoke without firing the stun.
func _cancel_smoke() -> void:
	if not _pending:
		return
	_pending = false
	_time_left = 0.0
	_hide_smoke()
	caster.status_effects().remove_effect(DODGE_ID)


func _exit_tree() -> void:
	_hide_smoke()
