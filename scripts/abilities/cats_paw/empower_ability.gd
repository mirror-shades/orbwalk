class_name EmpowerAbility
extends Ability
## W: the next auto-attack within the window deals bonus damage, and the attack
## timer resets so it can start right away. The bonus also splashes onto every
## other enemy near the target.

var _time_left: float = 0.0
var _glow: MeshInstance3D


func _ready() -> void:
	caster.empowered_hit.connect(_on_empowered_hit)


func is_active() -> bool:
	return _time_left > 0.0


func _cast(_target_pos: Vector3) -> void:
	var def := definition as EmpowerDefinition
	var bonus := ranked(def.bonus_damage, def.bonus_damage_per_rank) + def.ad_ratio * ad()
	caster.empower_next_attack(bonus)
	caster.reset_attack_timer()
	_time_left = def.window
	_set_glow(true)


func _tick(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	if _time_left <= 0.0 or caster.stats.is_dead or not caster.has_empowered_attack():
		_time_left = 0.0
		caster.clear_empowered_attack()
		_set_glow(false)


func _on_empowered_hit(target: Node, bonus_damage: float) -> void:
	_time_left = 0.0
	_set_glow(false)
	if target is Node3D:
		_pop_text((target as Node3D).global_position + Vector3(0.0, 2.6, 0.0), "-%d" % roundi(bonus_damage))
		_splash(target as Node3D, bonus_damage)


## The bonus damage also hits every other enemy near the target.
func _splash(target: Node3D, bonus_damage: float) -> void:
	var radius := (definition as EmpowerDefinition).splash_radius
	if radius <= 0.0 or bonus_damage <= 0.0:
		return
	var center := target.global_position
	for body in AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), center, radius):
		if body == target:
			continue
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st:
			st.take_physical_damage(bonus_damage, caster)
	AbilityUtil.ring_flash(get_tree().current_scene, center, radius, Color(1.0, 0.55, 0.15, 0.8))


## An orange ring under the champion while the empowered attack is ready.
func _set_glow(on: bool) -> void:
	if _glow == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.95
		torus.outer_radius = 1.15
		torus.rings = 48
		torus.ring_segments = 6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.55, 0.15)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow = MeshInstance3D.new()
		_glow.mesh = torus
		_glow.material_override = mat
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.scale = Vector3(1.0, 0.15, 1.0)
		_glow.position.y = 0.08
		caster.add_child(_glow)
	_glow.visible = on


func _pop_text(pos: Vector3, text: String) -> void:
	if not AbilityUtil.SHOW_FLOATING_TEXT:
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = 52
	label.outline_size = 10
	label.modulate = Color(1.0, 0.6, 0.2)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	caster.get_parent().add_child(label)
	label.global_position = pos
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position", pos + Vector3(0.0, 1.4, 0.0), 0.9)
	tw.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.chain().tween_callback(label.queue_free)
