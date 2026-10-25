class_name OverloadAbility
extends Ability

const COLOR := Color(0.45, 0.85, 1.0)

var _active: bool = false
var _targets: Array[Node3D] = []
var _beams: Dictionary = {}
var _shock_left: float = 0.0
var _shocks_done: int = 0


func _ready() -> void:
	caster.stats.died.connect(_on_caster_died)


func is_active() -> bool:
	return _active


func _cast(_target_pos: Vector3) -> void:
	var def := definition as OverloadDefinition
	_targets.clear()
	for body in AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), caster.global_position, def.radius):
		var st := EntityData.get_stats_of(body)
		if st and st.get_entity_type() == EntityDefinition.EntityType.CHAMPION:
			_targets.append(body)
	if _targets.is_empty():
		return
	_active = true
	_shocks_done = 0
	_shock_left = def.shock_interval
	_make_beams()


func _tick(delta: float) -> void:
	if not _active:
		return
	var def := definition as OverloadDefinition
	if caster.stats.is_dead:
		_stop(false)
		return
	_prune()
	if _targets.is_empty():
		_stop(false)
		return
	_sync_beams()
	_update_beams()
	_shock_left -= delta
	if _shock_left > 0.0:
		return
	_shock_left = def.shock_interval
	var damage := ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
	for body in _targets:
		var st := EntityData.get_stats_of(body)
		if st and not st.is_dead:
			st.take_magic_damage(damage, caster)
	_shocks_done += 1
	if _shocks_done >= def.shock_count:
		_stun_and_stop()


func _prune() -> void:
	var def := definition as OverloadDefinition
	var kept: Array[Node3D] = []
	for body in _targets:
		if not is_instance_valid(body):
			continue
		var st := EntityData.get_stats_of(body)
		if st == null or st.is_dead or AbilityUtil.flat_distance(caster.global_position, body.global_position) > def.leash_range:
			continue
		kept.append(body)
	_targets = kept


func _make_beams() -> void:
	_sync_beams()
	_update_beams()


func _sync_beams() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var wanted: Dictionary = {}
	for body in _targets:
		var id := body.get_instance_id()
		wanted[id] = true
		if not _beams.has(id):
			_beams[id] = UnioneerBeam.make(scene, COLOR)
	for id in _beams.keys():
		if wanted.has(id):
			continue
		var beam := _beams[id] as UnioneerBeam
		if is_instance_valid(beam):
			beam.queue_free()
		_beams.erase(id)


func _update_beams() -> void:
	var from := caster.global_position + Vector3(0.0, 1.4, 0.0)
	for body in _targets:
		var beam := _beams.get(body.get_instance_id()) as UnioneerBeam
		if beam and is_instance_valid(beam):
			beam.set_ends(from, body.global_position + Vector3(0.0, 1.3, 0.0))


func _stun_and_stop() -> void:
	var def := definition as OverloadDefinition
	for body in _targets:
		var st := EntityData.get_stats_of(body)
		if st == null or st.is_dead:
			continue
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			fx.apply_stun(def.stun_duration)
	_stop(true)


func _stop(stunned: bool) -> void:
	_active = false
	var scene := get_tree().current_scene
	if scene and stunned:
		AbilityUtil.ring_flash(scene, caster.global_position, (definition as OverloadDefinition).radius, Color(COLOR, 0.8))
	for id in _beams.keys():
		var beam := _beams[id] as UnioneerBeam
		if is_instance_valid(beam):
			beam.queue_free()
	_beams.clear()
	_targets.clear()


func _on_caster_died() -> void:
	if _active:
		_stop(false)


func _exit_tree() -> void:
	if _active:
		_stop(false)
