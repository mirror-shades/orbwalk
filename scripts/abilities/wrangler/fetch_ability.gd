class_name FetchAbility
extends Ability
## R: throw a stick down a line. The pug grows giant and charges after it,
## knocking every enemy it hits to the side and briefly stunning them. Each enemy
## is hit once. After reaching the stick the pug runs back to her and shrinks.

const COLOR := Color(0.95, 0.8, 0.4, 0.35)

var _dest := Vector3.ZERO
var _windup := 0.0
var _waiting := false
var _charging := false
var _hit: Dictionary = {}
var _last_pos := Vector3.ZERO
var _telegraph: WranglerTelegraph
## The pug command this cast is using (so E can override it safely).
var _command := 0


func is_active() -> bool:
	return _waiting or _charging


func _cast_problem() -> String:
	var pet := WranglerPounceAbility.pet_of(caster)
	if pet == null:
		return "The pug isn't here."
	return ""


func _cast(target_pos: Vector3) -> void:
	var def := definition as FetchDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	var distance := def.cast_range
	if dir.length() >= 0.1:
		distance = clampf(dir.length(), 0.0, def.cast_range)
	else:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	dir = dir.normalized()
	_dest = AbilityUtil.clip_spell_to_lane(caster, from, from + dir * distance)
	var pet := WranglerPounceAbility.pet_of(caster)
	if pet == null:
		return
	_hit.clear()
	_waiting = true
	_windup = def.cast_time
	_charging = false
	_command = pet.wait_for(def.cast_time)
	if _telegraph == null or not is_instance_valid(_telegraph):
		_telegraph = WranglerTelegraph.make(get_tree().current_scene)
	_update_telegraph(pet, def)


func _tick(delta: float) -> void:
	if not _waiting and not _charging:
		return
	if caster.stats.is_dead:
		_finish()
		return
	var pet := WranglerPounceAbility.pet_of(caster)
	if pet == null:
		_finish()
		return
	if pet.command_id != _command:
		_abandon()
		return
	var def := definition as FetchDefinition
	if _waiting:
		_windup -= delta
		_update_telegraph(pet, def)
		if _windup <= 0.0:
			_waiting = false
			_charging = true
			_last_pos = pet.global_position
			_hide_telegraph()
			pet.set_giant(true)
			_command = pet.start_charge(_dest, def.charge_speed, _on_charge_done)
		return
	if _charging:
		var now := pet.global_position
		_check_hits(_last_pos, now, def)
		_last_pos = now


func _on_charge_done() -> void:
	_charging = false


func _check_hits(from: Vector3, to: Vector3, def: FetchDefinition) -> void:
	if from.distance_to(to) < 0.001:
		return
	var mid := (from + to) * 0.5
	var reach := from.distance_to(to) * 0.5 + def.width * 0.5 + 2.0
	for body in AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), mid, reach):
		var id := body.get_instance_id()
		if _hit.has(id):
			continue
		if AbilityUtil.segment_distance_xz(body.global_position, from, to) > def.width * 0.5 + AbilityUtil.unit_radius(body):
			continue
		_hit[id] = true
		var st := body.get_node_or_null("Stats") as StatsComponent
		st.take_physical_damage(ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad(), caster)
		if st.is_dead:
			continue
		_knock_aside(body, from, to, def)
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			fx.apply_stun(def.stun_duration)
		AbilityUtil.pop_text(get_tree().current_scene, body.global_position + Vector3(0.0, 3.0, 0.0), "Fetch!", Color(1.0, 0.85, 0.4), 38)


## Throws `body` to whichever side of the line it's on, then clips the landing
## point to the lane.
func _knock_aside(body: Node3D, from: Vector3, to: Vector3, def: FetchDefinition) -> void:
	var line := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if line.length_squared() < 0.0001:
		return
	line = line.normalized()
	var rel := body.global_position - from
	rel.y = 0.0
	var side := line.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		return
	side = side.normalized()
	var offset := rel.dot(side)
	var sign_side := 1.0 if offset > 0.001 else (-1.0 if offset < -0.001 else (1.0 if SimRng.randf() < 0.5 else -1.0))
	var dest := body.global_position + side * def.knock_distance * sign_side
	dest = DashAbility.clip_to_navmesh(body, body.global_position, dest)
	var fx := body.get_node_or_null("StatusEffects") as StatusEffects
	if fx:
		fx.start_forced_move(dest, def.knock_speed)


func _update_telegraph(pet: WranglerPet, def: FetchDefinition) -> void:
	if _telegraph == null or not is_instance_valid(_telegraph):
		return
	_telegraph.set_ends(pet.global_position, _dest, def.width, COLOR)


func _hide_telegraph() -> void:
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.visible = false


## Once the pug is already up and running, don't touch it: another command owns it.
func _abandon() -> void:
	_clear_visuals()


func _finish() -> void:
	_clear_visuals()
	var pet := WranglerPounceAbility.pet_of(caster)
	if pet:
		pet.follow()


func _clear_visuals() -> void:
	_waiting = false
	_charging = false
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _exit_tree() -> void:
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
