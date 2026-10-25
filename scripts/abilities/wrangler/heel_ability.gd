class_name HeelAbility
extends Ability
## E: she dashes toward the cursor. Two seconds later the pug charges from
## wherever it is to where she landed, damaging and stunning every enemy it runs
## through. If it's latched on with Q, it keeps biting until it charges. The line
## is drawn on the ground during the wait.

const COLOR := Color(0.95, 0.8, 0.4, 0.35)
## `_command` while the pug is still on its Q target and not ours yet.
const LATCHED := -1

var _land := Vector3.ZERO
var _wait_left := 0.0
var _waiting := false
var _charging := false
var _hit: Dictionary = {}
var _last_pos := Vector3.ZERO
var _telegraph: WranglerTelegraph
## The pug command this cast is using (so R can override it safely).
var _command := 0


func is_active() -> bool:
	return _waiting or _charging


func _cast_problem() -> String:
	var fx := caster.status_effects()
	if fx == null:
		return "Can't dash."
	if fx.is_movement_locked():
		return "Already dashing."
	if fx.is_rooted():
		return "Rooted."
	return ""


func _cast(target_pos: Vector3) -> void:
	var def := definition as HeelDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	if dir.length() < 0.1:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	dir = dir.normalized()
	_land = DashAbility.clip_to_navmesh(caster, from, from + dir * def.dash_distance)
	# Drop her attack order so she doesn't run straight back to her old target
	# (e.g. the one the pug was latched on with Q) the moment she lands.
	if caster.has_method("order_stop"):
		caster.call("order_stop")
	caster.status_effects().start_forced_move(_land, def.dash_speed)
	_hit.clear()

	var pet := WranglerPounceAbility.pet_of(caster)
	if pet == null:
		return
	pet.set_giant(false)
	_waiting = true
	_wait_left = def.pug_delay
	_charging = false
	pet.heel_pending = true
	if _on_q_target(pet):
		# Latched (or leaping on) with Q: it keeps biting through the wait and only
		# lets go to charge.
		_command = LATCHED
	else:
		_command = pet.wait_for(def.pug_delay)
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
	if _command == LATCHED:
		if pet.is_following():
			# The Q ended during the wait (bites done, leash, target died): hold here.
			_command = pet.wait_for(_wait_left)
		elif not _on_q_target(pet):
			# R took the pug.
			_abandon()
			return
	elif pet.command_id != _command:
		_abandon()
		return
	var def := definition as HeelDefinition
	if _waiting:
		_wait_left -= delta
		_update_telegraph(pet, def)
		if _wait_left <= 0.0:
			_waiting = false
			_charging = true
			_last_pos = pet.global_position
			_hide_telegraph()
			# Replaces the Q latch, if there still is one.
			pet.heel_pending = false
			_command = pet.start_charge(_land, def.charge_speed, _on_charge_done)
		return
	if _charging:
		var now := pet.global_position
		_check_hits(_last_pos, now, def)
		_last_pos = now


func _on_q_target(pet: WranglerPet) -> bool:
	return pet.state == WranglerPet.State.LATCHED or pet.state == WranglerPet.State.LEAP


func _on_charge_done() -> void:
	_charging = false


func _check_hits(from: Vector3, to: Vector3, def: HeelDefinition) -> void:
	if from.distance_to(to) < 0.001:
		return
	var mid := (from + to) * 0.5
	var reach := from.distance_to(to) * 0.5 + def.width * 0.5 + 1.5
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
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			fx.apply_stun(def.stun_duration)
		AbilityUtil.pop_text(get_tree().current_scene, body.global_position + Vector3(0.0, 3.0, 0.0), "Bash!", Color(1.0, 0.9, 0.3), 34)


func _update_telegraph(pet: WranglerPet, def: HeelDefinition) -> void:
	if _telegraph == null or not is_instance_valid(_telegraph):
		return
	_telegraph.set_ends(pet.global_position, _land, def.width, COLOR)


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
	if _waiting:
		var pet := WranglerPounceAbility.pet_of(caster)
		if pet:
			pet.heel_pending = false
	_waiting = false
	_charging = false
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _exit_tree() -> void:
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
