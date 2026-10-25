class_name RideAbility
extends Ability
## Q: fly forward on the broom, over units, damaging every enemy she passes once.
## Pressing Q again within the return window blinks her back to where she took
## off, facing the same way. If the window runs out she just stays put.
## Every enemy the dash hits heals her (Witch's Tithe).

const COLOR := Color(0.65, 0.4, 0.95)

var _riding: bool = false
var _hit: Dictionary = {}
var _damage: float = 0.0
var _start := Vector3.ZERO
var _start_facing: float = 0.0
var _window_left: float = 0.0


func display_name() -> String:
	return "Ride Out" if _window_left > 0.0 else definition.ability_name


func is_active() -> bool:
	return _riding or _window_left > 0.0


func wants_recast() -> bool:
	return _window_left > 0.0


## Seconds left to blink back (0 = no return waiting). Used by the bot.
func return_time_left() -> float:
	return _window_left


## Where the blink would put her. Used by the bot.
func return_point() -> Vector3:
	return _start


func _cast_problem() -> String:
	var fx := caster.status_effects()
	if fx == null or fx.is_movement_locked():
		return "Already dashing."
	if fx.is_rooted():
		return "Rooted."
	return ""


func _cast(target_pos: Vector3) -> void:
	var def := definition as RideDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	var models := caster.get_node_or_null("Models") as Node3D
	if dir.length() < 0.1:
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	dir = dir.normalized()
	_start = from
	_start_facing = models.rotation.y if models else 0.0
	var dest := DashAbility.clip_to_navmesh(caster, from, from + dir * def.distance)
	_damage = ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
	_hit.clear()
	_riding = true
	_window_left = def.return_window
	caster.status_effects().start_forced_move(dest, def.dash_speed)
	_puff(from)
	_hit_around()


func recast(_target_pos: Vector3) -> void:
	if _window_left <= 0.0:
		return
	_window_left = 0.0
	_riding = false
	var fx := caster.status_effects()
	if fx:
		fx.stop_forced_move()
	_puff(caster.global_position)
	caster.global_position = Vector3(_start.x, caster.global_position.y, _start.z)
	caster.velocity = Vector3.ZERO
	var models := caster.get_node_or_null("Models") as Node3D
	if models:
		models.rotation.y = _start_facing
	# Drop any walk order so she doesn't run straight back to where she was.
	if caster.has_method("_stop_moving"):
		caster.call("_stop_moving")
	_puff(_start)


func _tick(delta: float) -> void:
	if _window_left > 0.0:
		_window_left = maxf(_window_left - delta, 0.0)
		if caster.stats.is_dead:
			_window_left = 0.0
	if not _riding:
		return
	if caster.stats.is_dead:
		_riding = false
		return
	_hit_around()
	if not caster.status_effects().is_movement_locked():
		_riding = false


func _hit_around() -> void:
	var def := definition as RideDefinition
	for body in AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), caster.global_position, def.hit_radius):
		var id := body.get_instance_id()
		if _hit.has(id):
			continue
		_hit[id] = true
		var st := body.get_node_or_null("Stats") as StatsComponent
		st.take_magic_damage(_damage, caster)
		WitchsTitheAbility.spell_hit(caster, body)


## A puff of leaves where she takes off or lands.
func _puff(at: Vector3) -> void:
	AbilityUtil.ring_flash(get_tree().current_scene, at, 1.6, Color(COLOR, 0.85))
