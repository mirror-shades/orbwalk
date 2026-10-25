class_name ProtoJungleMonster
extends Entity
## A neutral jungle monster. It stands in its camp until someone hits it, then
## fights back. If its attacker runs out of the camp (past `leash`), it walks home
## and heals to full. Whoever lands the kill gets the camp's buff (see ProtoGame).
## Minions and towers ignore it.

const HealthBarScript := preload("res://scripts/health_bar.gd")
const NEUTRAL_COLOR := Color(0.95, 0.8, 0.3)

var game: ProtoGame
var camp_id: String = ""
var data: Dictionary = {}
var radius: float = 1.0
var home: Vector3 = Vector3.ZERO

var _height: float = 2.4
var _leash: float = 9.0
var _returning: bool = false
var _pivot: Node3D
var _ring: MeshInstance3D
var _anim: AnimationPlayer
var _current_anim: String = ""


## Call before add_child().
func setup(p_game: ProtoGame, p_camp_id: String, p_home: Vector3) -> void:
	game = p_game
	camp_id = p_camp_id
	data = ProtoConfig.JUNGLE_CAMPS[p_camp_id]
	radius = data["radius"]
	_height = data["height"]
	_leash = data["leash"]
	home = p_home
	position = p_home

	var def := EntityDefinition.new()
	def.entity_id = "jungle_" + p_camp_id
	def.entity_name = data["name"]
	def.entity_type = EntityDefinition.EntityType.MINION
	def.team = EntityDefinition.Team.NEUTRAL
	def.stats_max_health = data["hp"]
	def.stats_health_regen = 0.0
	def.stats_attack_damage = data["ad"]
	def.stats_armor = data["armor"]
	def.stats_magic_resist = data["mr"]
	def.stats_attack_speed = data["attack_speed"]
	def.stats_attack_range = data["range"]
	def.stats_movement_speed = data["speed"]
	definition = def
	_build_nodes()


func top_height() -> float:
	return _height


## True while walking back to camp after losing its target.
func is_resetting() -> bool:
	return _returning


func _build_nodes() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = maxf(_height, radius * 2.0 + 0.1)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	add_child(cs)

	_pivot = Node3D.new()
	_pivot.name = "VisualPivot"
	# Face the lane.
	_pivot.rotation.y = atan2(0.0, -signf(home.z))
	add_child(_pivot)
	var ps := load(str(data["model"])) as PackedScene
	if ps:
		var model := ps.instantiate() as Node3D
		ProtoUtil.fit_model(model, _height)
		_pivot.add_child(model)
		_anim = ProtoUtil.find_anim_player(model)

	_ring = ProtoUtil.make_ring(radius + 0.2, NEUTRAL_COLOR)
	add_child(_ring)

	var hb := Node3D.new()
	hb.name = "HealthBar"
	hb.set_script(HealthBarScript)
	hb.set("bar_width", 2.0)
	hb.set("bar_height", 0.2)
	hb.set("show_segments", false)
	hb.set("fill_color", NEUTRAL_COLOR)
	hb.position.y = _height + 0.6
	add_child(hb)


func _on_entity_ready() -> void:
	collision_mask = 0
	add_to_group("proto_jungle_monster")
	stats.damaged.connect(_on_hit)
	_play(str(data["anim_idle"]), true)


func _on_hit(_amount: float, source: Node) -> void:
	if _returning or stats.is_dead:
		return
	if source is CharacterBody3D and is_instance_valid(source) and source != self:
		var ss := EntityData.get_stats_of(source)
		if ss and not ss.is_dead and not is_attack_target_valid():
			set_attack_target(source as CharacterBody3D)


func _physics_process(delta: float) -> void:
	if stats.is_dead or game == null:
		return
	if process_crowd_control(delta):
		return
	if process_attack(delta):
		_land_hit()

	var rooted := status_effects() != null and status_effects().is_rooted()
	if _returning:
		if rooted:
			_face(home, delta)
			_play_idle()
			return
		_walk_home(delta)
		return

	if not is_attack_target_valid():
		clear_attack_target()
		if ProtoUtil.flat_distance(global_position, home) > 0.5:
			_start_return()
		else:
			_play_idle()
		return

	var t := _attack_target
	# Leash: give up if the target or the monster leaves the camp.
	if ProtoUtil.flat_distance(t.global_position, home) > _leash + 2.0 or ProtoUtil.flat_distance(global_position, home) > _leash:
		_start_return()
		return

	var dist := ProtoUtil.flat_distance(global_position, t.global_position)
	var reach := stats.get_attack_range() + game.radius_of(t) + radius * 0.5
	_face(t.global_position, delta)
	if dist <= reach:
		if can_attack():
			start_attack_cooldown()
			_start_swing()
		elif not is_attack_anim_active():
			_play_idle()
		return
	# Out of reach mid-windup: hold still until the swing resolves, no chasing.
	if is_attack_anim_active() and not _damage_dealt_this_swing:
		return
	if rooted:
		_play_idle()
		return
	var dir := t.global_position - global_position
	dir.y = 0.0
	_step(dir.normalized() * stats.get_movement_speed(), delta)


func _start_return() -> void:
	clear_attack_target()
	_returning = true


## Walks back to the camp, healing fast on the way, and is ready to fight again once home.
func _walk_home(delta: float) -> void:
	stats.heal(stats.get_max_health() * 0.25 * delta)
	var dir := home - global_position
	dir.y = 0.0
	if dir.length() <= 0.3:
		global_position = home
		_returning = false
		stats.heal(stats.get_max_health())
		_play_idle()
		return
	_face(home, delta)
	_step(dir.normalized() * stats.get_movement_speed() * 1.4, delta)


func _step(v: Vector3, delta: float) -> void:
	var p := global_position + v * delta
	p.y = 0.0
	global_position = p
	if not is_attack_anim_active():
		_play(str(data["anim_walk"]), true)


func _play_idle() -> void:
	if not is_attack_anim_active():
		_play(str(data["anim_idle"]), true)


func _start_swing() -> void:
	var anim_name := str(data["anim_attack"])
	var length := 0.6
	if _anim and _anim.has_animation(anim_name):
		var raw := _anim.get_animation(anim_name).length
		var interval := 1.0 / maxf(stats.get_attack_speed(), 0.01)
		var speed_scale := maxf(1.0, raw / (interval * 0.85))
		length = raw / speed_scale
		_play(anim_name, false, speed_scale)
	begin_attack_anim(length, 0.45)


func _land_hit() -> void:
	if not is_attack_target_valid():
		return
	var t := _attack_target
	var reach := stats.get_attack_range() + game.radius_of(t) + radius * 0.5 + 1.0
	if ProtoUtil.flat_distance(global_position, t.global_position) <= reach:
		deal_attack_damage()


## These models face +Z, so point the pivot's +Z at the target.
func _face(pos: Vector3, delta: float) -> void:
	var dir := pos - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	_pivot.rotation.y = lerp_angle(_pivot.rotation.y, atan2(dir.x, dir.z), minf(10.0 * delta, 1.0))


func _play(anim_name: String, loop: bool, speed_scale: float = 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if loop and _current_anim == anim_name and _anim.is_playing():
		return
	_current_anim = anim_name
	var a := _anim.get_animation(anim_name)
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_anim.stop()
	_anim.play(anim_name, -1.0, speed_scale)


func _on_entity_died() -> void:
	set_physics_process(false)
	var hb := get_node_or_null("HealthBar") as Node3D
	if hb:
		hb.visible = false
	if _ring:
		_ring.visible = false
	var wait := 1.0
	var death := str(data["anim_death"])
	if _anim and _anim.has_animation(death):
		_play(death, false)
		wait = minf(_anim.get_animation(death).length, 1.8)
	# On the simulation clock (physics ticks), and paused with the game.
	await get_tree().create_timer(wait, false, true).timeout
	queue_free()
