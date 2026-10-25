class_name ProtoMinion
extends Entity
## A lane minion. Marches toward the enemy orb and fights what it meets.
## Target priority: enemy minions, then champions, then towers / orb.

const HealthBarScript := preload("res://scripts/health_bar.gd")
## Seconds between target searches while fighting (to switch to something closer)
## and while marching with no target. Losing a target searches again right away.
const RETARGET_INTERVAL := 0.3
const IDLE_SCAN_INTERVAL := 0.1

var game: ProtoGame
var minion_id: String = ""
var team: int = 0
var data: Dictionary = {}
var radius: float = 0.6
var stat_mult: float = 1.0
## The z position the minion drifts toward while marching (its spawn hex row).
var lane_z: float = 0.0

var _march_dir: float = 1.0
var _height: float = 1.5
var _pivot: Node3D
var _ring: MeshInstance3D
var _anim: AnimationPlayer
var _current_anim: String = ""
var _retarget_timer: float = 0.0
var _had_target: bool = false
var _heal_timer: float = 1.0
var _shield_timer: float = 1.0
var _rally_timer: float = 0.0
## What killing this minion is worth (set by ProtoGame from its spawner's value).
var bounty_gold: float = 0.0
var bounty_xp: float = 0.0
## Extra death explosion damage from the spawner's synergy (fraction).
var _burst_bonus: float = 0.0


## Call before add_child(). `buffs` is ProtoGame.NO_BUFFS for now (no placement synergies): hp / ad / as
## are fractions (0.3 = +30%), armor / mr are flat, burst is extra explosion damage.
func setup(p_game: ProtoGame, p_id: String, p_team: int, p_stat_mult: float, buffs: Dictionary) -> void:
	var hp_bonus := float(buffs["hp"])
	var ad_bonus := float(buffs["ad"])
	var as_bonus := float(buffs["as"])
	_burst_bonus = float(buffs["burst"])
	game = p_game
	minion_id = p_id
	team = p_team
	data = ProtoConfig.MINIONS[p_id]
	stat_mult = p_stat_mult
	radius = data["radius"]
	_height = data["height"]
	_march_dir = 1.0 if team == EntityDefinition.Team.TEAM_1 else -1.0

	var def := EntityDefinition.new()
	def.entity_id = p_id
	def.entity_name = data["name"]
	def.entity_type = EntityDefinition.EntityType.MINION
	def.stats_sight_range = float(data.get("sight", 9.0))
	def.team = p_team as EntityDefinition.Team
	def.stats_max_health = float(data["hp"]) * stat_mult * (1.0 + hp_bonus)
	def.stats_health_regen = 0.0
	def.stats_attack_damage = float(data["ad"]) * stat_mult * (1.0 + ad_bonus)
	def.stats_armor = float(data["armor"]) + float(buffs["armor"])
	def.stats_magic_resist = float(data["mr"]) + float(buffs["mr"])
	def.stats_attack_speed = float(data["attack_speed"]) * (1.0 + as_bonus)
	def.stats_attack_range = data["range"]
	def.stats_movement_speed = data["speed"]
	definition = def
	_build_nodes()


func top_height() -> float:
	return _height


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
	_pivot.rotation.y = atan2(_march_dir, 0.0)
	add_child(_pivot)
	var ps := load(str(data["model"])) as PackedScene
	if ps:
		var model := ps.instantiate() as Node3D
		var grow := 1.0 + 0.12 * (stat_mult - 1.0)
		ProtoUtil.fit_model(model, _height * grow)
		_pivot.add_child(model)
		_anim = ProtoUtil.find_anim_player(model)

	_ring = ProtoUtil.make_ring(radius + 0.15, ProtoConfig.team_color(team))
	add_child(_ring)

	var hb := Node3D.new()
	hb.name = "HealthBar"
	hb.set_script(HealthBarScript)
	hb.set("bar_width", 1.1 + 0.3 * (stat_mult - 1.0))
	hb.set("bar_height", 0.13)
	hb.set("show_segments", false)
	hb.set("fill_color", ProtoConfig.team_color(team))
	hb.position.y = _height + 0.45
	add_child(hb)


func _on_entity_ready() -> void:
	collision_mask = 0
	add_to_group("proto_minion")
	_heal_timer = SimRng.randf_range(0.5, 1.5)
	_shield_timer = SimRng.randf_range(0.5, 1.5)
	_retarget_timer = SimRng.randf() * RETARGET_INTERVAL
	if data.has("stealth"):
		# FogOfWar only reveals this unit to enemies within this distance.
		set_meta("stealth", float(data["stealth"]))
	_play(str(data["anim_walk"]), true)


func _physics_process(delta: float) -> void:
	if stats.is_dead or game == null:
		return
	if process_crowd_control(delta):
		return
	if process_attack(delta):
		_land_hit()

	_retarget_timer -= delta
	var has_target := is_attack_target_valid()
	if _retarget_timer <= 0.0 or (_had_target and not has_target):
		_pick_target()
		has_target = is_attack_target_valid()
		_retarget_timer = RETARGET_INTERVAL if has_target else IDLE_SCAN_INTERVAL
	_had_target = has_target

	if data.has("heal"):
		_heal_timer -= delta
		if _heal_timer <= 0.0:
			_try_heal()
	if data.has("shield"):
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			_try_shield()
	if data.has("rally_attack_speed"):
		_rally_timer -= delta
		if _rally_timer <= 0.0:
			_rally()

	var speed := stats.get_movement_speed()
	var rooted := status_effects() != null and status_effects().is_rooted()
	if is_attack_target_valid():
		var t := _attack_target
		var dist := ProtoUtil.flat_distance(global_position, t.global_position)
		var reach := stats.get_attack_range() + game.radius_of(t)
		if dist <= reach:
			_face(t.global_position, delta)
			if can_attack():
				start_attack_cooldown()
				_start_swing()
			elif not is_attack_anim_active():
				_play(str(data["anim_idle"]), true)
			if not rooted:
				_move(_separation() * speed * 0.5, delta)
			return
		# Out of reach mid-windup: hold still until the swing resolves, no chasing.
		if is_attack_anim_active() and not _damage_dealt_this_swing:
			_face(t.global_position, delta)
			return
		var chase := t.global_position - global_position
		chase.y = 0.0
		if rooted:
			_face(t.global_position, delta)
			if not is_attack_anim_active():
				_play(str(data["anim_idle"]), true)
			return
		_move_and_face(chase.normalized() * speed + _separation() * speed, delta)
		return
	if rooted:
		if not is_attack_anim_active():
			_play(str(data["anim_idle"]), true)
		return
	_move_and_face(_march_velocity(speed) + _separation() * speed, delta)


## Feared minions flee (Entity moves them); keep them in the lane and animate.
func _on_feared(dir: Vector3, delta: float) -> void:
	_move(Vector3.ZERO, delta)
	_face(global_position + dir, delta)
	_play(str(data["anim_walk"]), true)


func _on_stunned(_delta: float) -> void:
	_play(str(data["anim_idle"]), true)


## Removes the minion without giving anyone gold or XP (used when the awake phase times out).
func despawn() -> void:
	set_meta("despawned", true)
	stats.take_damage(stats.current_health + 1.0, null)


# ---- Targeting ----

func _pick_target() -> void:
	var aggro: float = data["aggro"]
	var best: CharacterBody3D = null
	var best_score := INF
	for node in game.get_enemies(team, true, global_position, aggro):
		var kind := game.kind_of(node)
		if kind == ProtoGame.KIND_CHAMPION and not game.minions_target_champions:
			continue
		var gap := ProtoUtil.flat_distance(global_position, node.global_position) - game.radius_of(node)
		if gap > aggro:
			continue
		var score := gap + float(kind) * 100.0
		if node == _attack_target:
			score -= 2.0
		if score < best_score:
			best_score = score
			best = node
	if best != _attack_target:
		clear_attack_target()
		if best:
			set_attack_target(best)


func _start_swing() -> void:
	var anim_name := str(data["anim_attack"])
	var length := 0.5
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
	# Blind and dodge miss unit targets; structures bypass the miss check.
	if attack_misses_target(t) and game.kind_of(t) != ProtoGame.KIND_STRUCTURE:
		return
	var dmg := stats.get_attack_damage() * _damage_mult(t)
	if bool(data["ranged"]):
		var muzzle := global_position + Vector3(0.0, _height * 0.6, 0.0)
		game.fire_projectile(muzzle, t, dmg, false, self, data["projectile_color"], 0.16, 20.0)
		return
	var reach := stats.get_attack_range() + game.radius_of(t) + 1.0
	if ProtoUtil.flat_distance(global_position, t.global_position) > reach:
		return
	EntityData.get_stats_of(t).take_physical_damage(dmg, self, true)
	attack_landed.emit(t)
	if data.has("cleave"):
		_cleave(t, stats.get_attack_damage() * float(data["cleave"]))


## Siege beasts hit structures harder; Delvers hit champions harder.
func _damage_mult(t: Node) -> float:
	match game.kind_of(t):
		ProtoGame.KIND_STRUCTURE:
			return float(data.get("siege", 1.0))
		ProtoGame.KIND_CHAMPION:
			return float(data.get("champion_mult", 1.0))
	return 1.0


## Knight: part of each hit lands on every other enemy minion and champion near the target.
func _cleave(t: Node3D, dmg: float) -> void:
	var radius := float(data.get("cleave_radius", 2.0))
	for node in game.get_enemies(team, false):
		if node == t or game.kind_of(node) == ProtoGame.KIND_STRUCTURE:
			continue
		if ProtoUtil.flat_distance(node.global_position, t.global_position) <= radius:
			EntityData.get_stats_of(node).take_physical_damage(dmg, self)


## Shieldbearer: shields the most hurt ally minion nearby.
func _try_shield() -> void:
	_shield_timer = float(data["shield_interval"])
	var best: ProtoMinion = null
	var best_frac := 0.95
	for m in game.minions:
		if m.team != team or m.stats.is_dead:
			continue
		if ProtoUtil.flat_distance(global_position, m.global_position) > float(data["shield_range"]):
			continue
		var frac := m.stats.current_health / m.stats.get_max_health()
		if frac < best_frac:
			best_frac = frac
			best = m
	if best == null:
		_shield_timer = 0.5
		return
	var amount := float(data["shield"]) * stat_mult
	best.stats.add_shield(amount, 3.0, "shieldbearer")
	ProtoUtil.float_text(game, best.global_position + Vector3(0.0, best.top_height() + 0.7, 0.0), "+%d" % int(amount), Color(0.7, 0.85, 1.0), 26)


## Knight: nearby allied minions attack faster while it lives.
func _rally() -> void:
	_rally_timer = 0.5
	var radius := float(data["rally_radius"])
	var bonus := float(data["rally_attack_speed"])
	for m in game.minions:
		if m == self or m.team != team or m.stats.is_dead:
			continue
		if ProtoUtil.flat_distance(global_position, m.global_position) > radius:
			continue
		var fx := m.status_effects()
		if fx:
			fx.apply_attack_speed(bonus, 0.75, "knight_rally")


## Bomber: magic damage to every enemy minion and champion nearby.
func _explode() -> void:
	var radius := float(data["death_radius"])
	var dmg := float(data["death_burst"]) * stat_mult * (1.0 + _burst_bonus)
	for node in game.get_enemies(team, false):
		if game.kind_of(node) == ProtoGame.KIND_STRUCTURE:
			continue
		if ProtoUtil.flat_distance(node.global_position, global_position) <= radius + game.radius_of(node):
			EntityData.get_stats_of(node).take_magic_damage(dmg, self)
	AbilityUtil.ring_flash(game, global_position, radius, Color(1.0, 0.55, 0.2, 0.9))


func _try_heal() -> void:
	_heal_timer = float(data["heal_interval"])
	var heal_range: float = data["heal_range"]
	var best: ProtoMinion = null
	var best_frac := 0.9
	for m in game.minions:
		if m.team != team or m.stats.is_dead:
			continue
		if ProtoUtil.flat_distance(global_position, m.global_position) > heal_range:
			continue
		var frac := m.stats.current_health / m.stats.get_max_health()
		if frac < best_frac:
			best_frac = frac
			best = m
	if best == null:
		_heal_timer = 0.4
		return
	var amount := float(data["heal"]) * stat_mult
	best.stats.heal(amount)
	var pos := best.global_position + Vector3(0.0, best.top_height() + 0.7, 0.0)
	ProtoUtil.float_text(game, pos, "+%d" % int(amount), Color(0.45, 1.0, 0.55), 28)


# ---- Movement ----

func _march_velocity(speed: float) -> Vector3:
	var orb_x := game.enemy_orb_x(team)
	if (orb_x - global_position.x) * _march_dir < 2.0:
		return Vector3.ZERO
	var goal_z := clampf(lane_z, -3.5, 3.5)
	var dir := Vector3(_march_dir, 0.0, clampf((goal_z - global_position.z) * 0.25, -0.6, 0.6))
	return dir.normalized() * speed


## Soft push away from nearby minions and structures so units don't stack.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in game.minions:
		if other == self or not is_instance_valid(other):
			continue
		var off := global_position - other.global_position
		off.y = 0.0
		var min_d := radius + other.radius
		var d := off.length()
		if d >= min_d:
			continue
		if d < 0.01:
			off = Vector3(SimRng.randf() - 0.5, 0.0, SimRng.randf() - 0.5)
			d = 0.01
		push += off / d * ((min_d - d) / min_d)
	for s in game.structures:
		if s.stats.is_dead:
			continue
		var off2 := global_position - s.global_position
		off2.y = 0.0
		var min_d2 := radius + s.radius + 0.2
		var d2 := off2.length()
		if d2 < min_d2 and d2 > 0.01:
			push += off2 / d2 * ((min_d2 - d2) / min_d2) * 2.0
	return push


func _move(v: Vector3, delta: float) -> void:
	var p := global_position + v * delta
	p.y = 0.0
	p.z = clampf(p.z, -game.lane_half_width + radius, game.lane_half_width - radius)
	p.x = clampf(p.x, -game.lane_half_length, game.lane_half_length)
	global_position = p


func _move_and_face(v: Vector3, delta: float) -> void:
	_move(v, delta)
	if v.length_squared() > 0.01:
		_face(global_position + v, delta)
		if not is_attack_anim_active():
			_play(str(data["anim_walk"]), true)
	elif not is_attack_anim_active():
		_play(str(data["anim_idle"]), true)


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
	if data.has("death_burst") and not has_meta("despawned"):
		_explode()
	var hb := get_node_or_null("HealthBar") as Node3D
	if hb:
		hb.visible = false
	if _ring:
		_ring.visible = false
	var wait := 0.8
	var death := str(data["anim_death"])
	if _anim and _anim.has_animation(death):
		_play(death, false)
		wait = minf(_anim.get_animation(death).length, 1.6)
	# On the simulation clock (physics ticks), and paused with the game.
	await get_tree().create_timer(wait, false, true).timeout
	queue_free()
