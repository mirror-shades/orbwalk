class_name ProtoStructure
extends Entity
## A tower or an orb. Shoots the closest threat in range.
## Towers prefer minions. The orb shoots any enemy champion in range first, for true
## damage scaled to their max health, and also hits minions hard: champions can't
## end the game by diving it, so the game is won by the wave.
## A structure can't be damaged while its `prerequisite` (the one in front of it) stands.

enum Kind { TOWER, ORB }

const HealthBarScript := preload("res://scripts/health_bar.gd")
const ORB_MODEL := "res://assets/models/orb/crystal_ball.glb"
## Seconds between searches for a new target. The current target is still checked
## every tick, and losing it searches again right away.
const SCAN_INTERVAL := 0.1

var game: ProtoGame
var kind: Kind = Kind.TOWER
var team: int = 0
var display_name: String = ""
var radius: float = 1.5
var attack_range: float = 9.0
var damage_vs_champion: float = 120.0
var damage_vs_minion: float = 110.0
var champion_damage_is_true: bool = false
## Orb only: each shot at a champion deals at least this fraction of its max health.
var champion_health_ratio: float = 0.0
var prerequisite: ProtoStructure = null

var _model_path: String = ""
var _height: float = 5.5
var _cooldown: float = 0.0
var _target: CharacterBody3D = null
var _forced_target: CharacterBody3D = null
var _forced_time: float = 0.0
var _scan_timer: float = 0.0
var _visual: Node3D
var _shield: MeshInstance3D
var _range_ring: MeshInstance3D
var _orb_anim: AnimationPlayer


func setup(p_game: ProtoGame, p_kind: Kind, p_team: int, p_model_path: String, p_name: String) -> void:
	game = p_game
	kind = p_kind
	team = p_team
	display_name = p_name
	_model_path = p_model_path
	var cfg: Dictionary = ProtoConfig.ORB if kind == Kind.ORB else ProtoConfig.TOWER
	radius = cfg["radius"]
	attack_range = cfg["range"]
	damage_vs_champion = cfg["dmg_champion"]
	damage_vs_minion = cfg["dmg_minion"]
	champion_health_ratio = float(cfg.get("champion_health_ratio", 0.0))
	champion_damage_is_true = kind == Kind.ORB
	_height = cfg["height"]

	var def := EntityDefinition.new()
	def.entity_id = "orb" if kind == Kind.ORB else "tower"
	def.entity_name = p_name
	def.entity_type = EntityDefinition.EntityType.ORB if kind == Kind.ORB else EntityDefinition.EntityType.TOWER
	def.stats_sight_range = 15.0 if kind == Kind.ORB else 13.0
	def.team = p_team as EntityDefinition.Team
	def.stats_max_health = cfg["hp"]
	def.stats_health_regen = 0.0
	def.stats_armor = cfg["armor"]
	def.stats_magic_resist = cfg["armor"]
	def.stats_attack_speed = cfg["attack_speed"]
	def.stats_attack_range = cfg["range"]
	def.stats_movement_speed = 0.0
	definition = def
	_build_nodes()


func _build_nodes() -> void:
	var color := ProtoConfig.team_color(team)

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = _height
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = shape
	cs.position.y = _height * 0.5
	add_child(cs)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	if kind == Kind.ORB:
		_build_orb_visual(color)
	else:
		_build_tower_visual(color)

	add_child(ProtoUtil.make_ring(radius + 0.3, color, 0.2))

	_range_ring = ProtoUtil.make_ring(attack_range, Color(color, 0.4), 0.12)
	_range_ring.visible = false
	add_child(_range_ring)

	_shield = MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = radius + 0.9
	dome.height = (radius + 0.9) * 2.0
	_shield.mesh = dome
	_shield.material_override = ProtoUtil.flat_material(Color(0.6, 0.85, 1.0, 0.16))
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield.position.y = _height * 0.5
	_shield.scale = Vector3(1.0, maxf(_height * 0.55 / (radius + 0.9), 1.0), 1.0)
	_shield.visible = false
	add_child(_shield)

	var hb := Node3D.new()
	hb.name = "HealthBar"
	hb.set_script(HealthBarScript)
	hb.set("bar_width", 3.0)
	hb.set("bar_height", 0.3)
	hb.set("fill_color", color)
	hb.position.y = _height + 1.2
	add_child(hb)


func _build_tower_visual(color: Color) -> void:
	var ps := load(_model_path) as PackedScene
	if ps:
		var tower := ps.instantiate() as Node3D
		ProtoUtil.fit_model(tower, _height, radius * 2.3)
		_visual.add_child(tower)
	# A glowing team-colored gem on top so you can tell the sides apart.
	var gem := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	gem.mesh = sm
	gem.material_override = ProtoUtil.flat_material(color)
	gem.position.y = _height + 0.4
	_visual.add_child(gem)


func _build_orb_visual(color: Color) -> void:
	var pedestal := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.8
	cyl.bottom_radius = radius * 1.1
	cyl.height = 1.2
	pedestal.mesh = cyl
	pedestal.material_override = ProtoUtil.lit_material(Color(0.55, 0.55, 0.6))
	pedestal.position.y = 0.6
	_visual.add_child(pedestal)

	var ps := load(ORB_MODEL) as PackedScene
	if ps:
		var orb := ps.instantiate() as Node3D
		ProtoUtil.fit_model(orb, _height - 1.2)
		var holder := Node3D.new()
		holder.position.y = 1.2
		holder.add_child(orb)
		_visual.add_child(holder)
		_orb_anim = ProtoUtil.find_anim_player(orb)

	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 8.0
	light.light_energy = 2.0
	light.position.y = _height * 0.7
	_visual.add_child(light)


func _on_entity_ready() -> void:
	collision_mask = 0
	add_to_group("proto_structure")
	if _orb_anim and _orb_anim.has_animation("Take 001"):
		_orb_anim.get_animation("Take 001").loop_mode = Animation.LOOP_LINEAR
		_orb_anim.play("Take 001")
	_update_shield()


func _process(_delta: float) -> void:
	if stats.is_dead or game == null:
		return
	# Show the attack range of enemy structures when the player gets close (like LoL).
	var near := false
	var player := game.player_champion
	if team != game.player_team and is_instance_valid(player):
		near = ProtoUtil.flat_distance(global_position, player.global_position) < attack_range + 6.0
	_range_ring.visible = near


func _update_shield() -> void:
	var shielded := prerequisite != null and is_instance_valid(prerequisite) and not prerequisite.stats.is_dead
	if stats.invulnerable != shielded:
		stats.invulnerable = shielded
		# Leave the "entity" group while shielded so auto-attacks don't waste hits on it.
		if shielded:
			remove_from_group("entity")
		else:
			add_to_group("entity")
	_shield.visible = shielded


func _physics_process(delta: float) -> void:
	if stats.is_dead or game == null:
		return
	_update_shield()
	_cooldown = maxf(_cooldown - delta, 0.0)
	_forced_time = maxf(_forced_time - delta, 0.0)
	_scan_timer -= delta
	_target = _choose_target()
	if _target and _cooldown <= 0.0:
		_cooldown = 1.0 / maxf(stats.get_attack_speed(), 0.01)
		_shoot(_target)


## Called when an enemy champion hits one of our champions near this structure.
func force_target(attacker: CharacterBody3D, victim_pos: Vector3) -> void:
	if stats.is_dead or not _valid(attacker) or not _in_range(attacker):
		return
	if ProtoUtil.flat_distance(global_position, victim_pos) > attack_range + 1.0:
		return
	_forced_target = attacker
	_forced_time = 3.0
	_target = attacker


func covers(pos: Vector3, margin: float = 0.0) -> bool:
	return ProtoUtil.flat_distance(global_position, pos) <= attack_range + margin


func _valid(t: CharacterBody3D) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	var ts := EntityData.get_stats_of(t)
	return ts != null and not ts.is_dead and EntityData.is_enemy(team, ts.get_team()) and FogOfWar.can_see(team, t)


func _in_range(t: Node3D) -> bool:
	return ProtoUtil.flat_distance(global_position, t.global_position) - game.radius_of(t) <= attack_range


func _choose_target() -> CharacterBody3D:
	var keep := _valid(_target) and _in_range(_target)
	# Search on the timer, or right away when the current target was just lost.
	var scan := _scan_timer <= 0.0 or (_target != null and not keep)
	if scan:
		_scan_timer = SCAN_INTERVAL
	if kind == Kind.ORB and scan:
		# Like League's fountain: any enemy champion in range is shot first, even mid-wave.
		var champ := _nearest_champion_in_range()
		if champ:
			return champ
	if _forced_time > 0.0 and _valid(_forced_target) and _in_range(_forced_target):
		return _forced_target
	# Towers always switch to an enemy Unioneer turret, even with a minion target.
	if kind == Kind.TOWER and scan:
		var turret := _nearest_turret_in_range()
		if turret:
			return turret
	if keep:
		return _target
	if not scan:
		return null
	var prefer_champions := kind == Kind.ORB
	var best: CharacterBody3D = null
	var best_score := INF
	for node in game.get_enemies(team, true, global_position, attack_range):
		var k := game.kind_of(node)
		if k == ProtoGame.KIND_STRUCTURE or not _in_range(node):
			continue
		var score := ProtoUtil.flat_distance(global_position, node.global_position)
		if (k == ProtoGame.KIND_CHAMPION) != prefer_champions:
			score += 1000.0
		if score < best_score:
			best_score = score
			best = node
	return best


func _nearest_turret_in_range() -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_d := INF
	for node in game.get_enemies(team, true, global_position, attack_range):
		if not (node is UnioneerTurret) or not _in_range(node):
			continue
		var d := ProtoUtil.flat_distance(global_position, node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _nearest_champion_in_range() -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_d := INF
	for node in game.get_enemies(team, true, global_position, attack_range):
		if game.kind_of(node) != ProtoGame.KIND_CHAMPION or not _in_range(node):
			continue
		var d := ProtoUtil.flat_distance(global_position, node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _shoot(t: CharacterBody3D) -> void:
	var is_champ := game.kind_of(t) == ProtoGame.KIND_CHAMPION
	var dmg := (damage_vs_champion if is_champ else damage_vs_minion) * game.structure_damage_mult()
	if is_champ and champion_health_ratio > 0.0:
		# The orb's champion damage scales with the target, so it stays deadly at any level.
		dmg = maxf(dmg, EntityData.get_stats_of(t).get_max_health() * champion_health_ratio)
	var muzzle := global_position + Vector3(0.0, _height * 0.9, 0.0)
	var col := ProtoConfig.team_color(team).lightened(0.45)
	var shot_size := 0.5 if kind == Kind.ORB else 0.35
	game.fire_projectile(muzzle, t, dmg, champion_damage_is_true and is_champ, self, col, shot_size, 28.0)


func _on_entity_died() -> void:
	_shield.visible = false
	_range_ring.visible = false
	var hb := get_node_or_null("HealthBar") as Node3D
	if hb:
		hb.visible = false
	remove_from_group("entity")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "position:y", -_height * 0.75, 1.5).set_ease(Tween.EASE_IN)
	tw.tween_property(_visual, "rotation:z", 0.25, 1.5)
