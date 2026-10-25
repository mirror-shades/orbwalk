class_name FanTheHammerAbility
extends Ability
## Q: empty the revolver. Six bullets leave one after another, each from where he is
## standing when it fires, all down the line he aimed at the start. While firing he
## can move but not turn, auto-attack or cast. Each bullet stops at the first living
## enemy it touches, so killing the front target lets the rest reach whoever is behind it.

var _shots_left: int = 0
var _spawn_left: float = 0.0
var _dir := Vector3.RIGHT
var _damage: float = 0.0


func is_active() -> bool:
	return _shots_left > 0


func _cast(target_pos: Vector3) -> void:
	var def := definition as FanTheHammerDefinition
	var dir := target_pos - caster.global_position
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = _facing()
	_dir = dir.normalized()
	_damage = ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	_shots_left = int(round(ranked(def.bullet_count, def.bullet_count_per_rank)))
	_spawn_left = 0.0
	caster.firing_lock = true
	var models := caster.get_node_or_null("Models") as Node3D
	if models:
		models.rotation.y = atan2(-_dir.x, -_dir.z)


func _tick(delta: float) -> void:
	if _shots_left <= 0:
		return
	var fx := caster.status_effects()
	if caster.stats.is_dead or (fx and (fx.is_stunned() or fx.is_feared())):
		_end_volley()
		return

	var def := definition as FanTheHammerDefinition
	_spawn_left -= delta
	while _spawn_left <= 0.0 and _shots_left > 0:
		_fire()
		_shots_left -= 1
		_spawn_left += maxf(def.spacing, 0.01)
	if _shots_left <= 0:
		_end_volley()


func _end_volley() -> void:
	_shots_left = 0
	caster.firing_lock = false


func _fire() -> void:
	var def := definition as FanTheHammerDefinition
	var start := caster.global_position + _dir * 0.6
	var end := AbilityUtil.clip_spell_to_lane(caster, start, start + _dir * def.cast_range)
	var distance := AbilityUtil.flat_distance(start, end)
	if distance < 0.5:
		return
	var bullet := FanBullet.new()
	bullet.team = caster.stats.get_team()
	bullet.damage = _damage
	bullet.speed = def.bullet_speed
	bullet.width = def.width
	bullet.color = caster.definition.attack_projectile_color
	bullet.source_id = caster.get_instance_id()
	caster.get_parent().add_child(bullet)
	bullet.launch(start + Vector3(0.0, 1.1, 0.0), _dir, distance)


func _facing() -> Vector3:
	var models := caster.get_node_or_null("Models") as Node3D
	if models:
		var f := -models.global_basis.z
		f.y = 0.0
		if f.length_squared() > 0.0001:
			return f
	return Vector3.RIGHT
