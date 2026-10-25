class_name DashAbility
extends Ability
## E: dash a fixed distance toward the cursor and gain attack speed for a few seconds.
## The dash stops early instead of passing through towers, the orb, or the lane edge.
## A champion kill or assist (damage within StatsComponent.ASSIST_WINDOW) resets the cooldown.

const BUFF_ID := "cats_paw_e_haste"


func _ready() -> void:
	caster.takedown.connect(_on_takedown)


func _on_takedown(victim: Node) -> void:
	var st := victim.get_node_or_null("Stats") as StatsComponent
	if st == null or st.get_entity_type() != EntityDefinition.EntityType.CHAMPION:
		return
	if cooldown_left <= 0.0:
		return
	cooldown_left = 0.0
	_pop_text("%s reset!" % display_name())


func _pop_text(text: String) -> void:
	if not AbilityUtil.SHOW_FLOATING_TEXT:
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.outline_size = 10
	label.modulate = Color(0.55, 1.0, 0.6)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	caster.get_parent().add_child(label)
	var pos := caster.global_position + Vector3(0.0, 3.4, 0.0)
	label.global_position = pos
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position", pos + Vector3(0.0, 1.2, 0.0), 1.0)
	tw.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)


func is_active() -> bool:
	return caster.status_effects() != null and caster.status_effects().has_effect(BUFF_ID)


func _cast_problem() -> String:
	if caster.status_effects() == null:
		return "Can't dash."
	if caster.status_effects().is_movement_locked():
		return "Already dashing."
	if caster.status_effects().is_rooted():
		return "Rooted."
	return ""


func _cast(target_pos: Vector3) -> void:
	var def := definition as DashDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = _facing()
	dir = dir.normalized()
	var dest := clip_to_navmesh(caster, from, from + dir * def.distance)
	var fx := caster.status_effects()
	fx.start_forced_move(dest, def.dash_speed)
	fx.apply_attack_speed(ranked(def.attack_speed_bonus, def.attack_speed_bonus_per_rank), def.buff_duration, BUFF_ID)


## The direction the champion's model faces (cats_paw models face -Z).
func _facing() -> Vector3:
	var models := caster.get_node_or_null("Models") as Node3D
	if models:
		var f := -models.global_basis.z
		f.y = 0.0
		if f.length_squared() > 0.0001:
			return f
	return Vector3.RIGHT


## Walks from `from` toward `to` and returns the last point that is still on the
## navmesh, so dashes stop at towers, the orb and the lane edge instead of passing through.
static func clip_to_navmesh(body: Node3D, from: Vector3, to: Vector3) -> Vector3:
	var map := body.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return to
	var dist := Vector2(to.x - from.x, to.z - from.z).length()
	var steps := maxi(ceili(dist / 0.25), 1)
	var last := from
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / float(steps))
		var c := NavigationServer3D.map_get_closest_point(map, p)
		if Vector2(c.x - p.x, c.z - p.z).length() > 0.35:
			break
		last = p
	return last
