class_name WhaleSongAbility
extends Ability
## R: he sings, and after a short wind-up a whale's spout of water bursts up
## around him. Enemy champions and mercenaries in the area take magic damage and
## are knocked up. Allies in the area (champions, mercenaries and himself) get a
## shield. A water ring on the ground shows the area while he sings.

const COLOR := Color(0.3, 0.7, 1.0)
const SHIELD_ID := "argonaut_r_shield"

var _song_left: float = 0.0
var _telegraph: MeshInstance3D


func is_active() -> bool:
	return _song_left > 0.0


func _cast(_target_pos: Vector3) -> void:
	var def := definition as WhaleSongDefinition
	_song_left = maxf(def.cast_time, 0.001)
	_show_telegraph(def.radius)
	AbilityUtil.pop_text(get_tree().current_scene, caster.global_position + Vector3(0.0, 3.2, 0.0), "~ Whale Song ~", COLOR, 36)


func _tick(delta: float) -> void:
	if _song_left <= 0.0:
		return
	if caster.stats.is_dead:
		_song_left = 0.0
		_hide_telegraph()
		return
	_song_left -= delta
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.global_position = Vector3(caster.global_position.x, 0.05, caster.global_position.z)
	if _song_left <= 0.0:
		_hide_telegraph()
		_erupt()


func _erupt() -> void:
	var def := definition as WhaleSongDefinition
	var center := caster.global_position
	var team := caster.stats.get_team()
	var dmg := ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	for body in AbilityUtil.enemies_in_radius(get_tree(), team, center, def.radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		st.take_magic_damage(dmg, caster)
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx and not st.is_dead:
			fx.apply_knockup(def.knockup_duration)
	var shield := ranked(def.shield_base, def.shield_per_rank) + def.shield_hp_ratio * caster.stats.get_max_health()
	for body in AbilityUtil.allies_in_radius(get_tree(), team, center, def.radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		var kind := st.get_entity_type()
		if kind != EntityDefinition.EntityType.CHAMPION and kind != EntityDefinition.EntityType.MINION:
			continue
		st.add_shield(shield, def.shield_duration, SHIELD_ID)
	var scene := get_tree().current_scene
	AbilityUtil.ring_flash(scene, center, def.radius, Color(COLOR, 0.95))
	_spout(scene, center, def.radius)


func _show_telegraph(radius: float) -> void:
	_hide_telegraph()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 48
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(COLOR, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph = MeshInstance3D.new()
	_telegraph.mesh = disc
	_telegraph.material_override = mat
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(_telegraph)
	_telegraph.global_position = Vector3(caster.global_position.x, 0.05, caster.global_position.z)


func _hide_telegraph() -> void:
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


## A column of water that shoots up and falls away.
func _spout(parent: Node, center: Vector3, radius: float) -> void:
	var col := CylinderMesh.new()
	col.top_radius = radius * 0.35
	col.bottom_radius = radius * 0.6
	col.height = 1.0
	col.radial_segments = 24
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.85, 1.0, 0.6)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = col
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = Vector3(center.x, 0.0, center.z)
	mi.scale = Vector3(1.0, 0.1, 1.0)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.0, 6.0, 1.0), 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position:y", 3.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "transparency", 1.0, 0.5).set_delay(0.3)
	tw.chain().tween_callback(mi.queue_free)


func _exit_tree() -> void:
	_hide_telegraph()
