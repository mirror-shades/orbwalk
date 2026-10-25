class_name UnioneerTurret
extends Entity

const HealthBarScript := preload("res://scripts/health_bar.gd")
const COLOR := Color(0.35, 0.75, 1.0)

var game: ProtoGame
var owner_champion: Entity
var team: int = 0
var radius: float = 0.55
var attack_range: float = 6.5
var tier: int = 1
var _definition_ref: TurretDefinition
var _cooldown: float = 0.0
var _target: CharacterBody3D
var _retarget: float = 0.0
var _visual: Node3D
var _bar: Node3D


func setup(p_game: ProtoGame, p_owner: Entity, p_definition: TurretDefinition, p_rank: int) -> void:
	game = p_game
	owner_champion = p_owner
	team = p_owner.stats.get_team()
	tier = maxi(p_rank, 1)
	_definition_ref = p_definition
	radius = p_definition.turret_radius
	attack_range = p_definition.turret_range

	var def := EntityDefinition.new()
	def.entity_id = "unioneer_turret"
	def.entity_name = "Turret"
	def.entity_type = EntityDefinition.EntityType.MINION
	def.team = team as EntityDefinition.Team
	def.stats_sight_range = 0.0
	def.stats_max_health = p_definition.health + p_definition.health_per_rank * float(tier - 1)
	def.stats_health_regen = 0.0
	def.stats_attack_damage = 0.0
	def.stats_armor = p_definition.armor
	def.stats_magic_resist = p_definition.magic_resist
	def.stats_attack_speed = p_definition.attack_speed
	def.stats_attack_range = p_definition.turret_range
	def.stats_movement_speed = 0.0
	definition = def
	_build_nodes()


func _build_nodes() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.6
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = shape
	cs.position.y = 0.8
	add_child(cs)

	_visual = Node3D.new()
	_visual.name = "Models"
	add_child(_visual)

	var base_mat := ProtoUtil.lit_material(Color(0.32, 0.34, 0.38))
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = radius * 1.1
	base_mesh.bottom_radius = radius * 1.25
	base_mesh.height = 0.45
	var base := MeshInstance3D.new()
	base.mesh = base_mesh
	base.material_override = base_mat
	base.position.y = 0.23
	_visual.add_child(base)

	var body_mat := ProtoUtil.lit_material(Color(0.42, 0.46, 0.52))
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.7, 0.8, 0.7)
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = body_mat
	body.position.y = 0.85
	_visual.add_child(body)

	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = COLOR
	core_mat.emission_enabled = true
	core_mat.emission = COLOR * 0.8
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.16
	core_mesh.height = 0.32
	var core := MeshInstance3D.new()
	core.mesh = core_mesh
	core.material_override = core_mat
	core.position = Vector3(0.0, 1.02, -0.33)
	_visual.add_child(core)

	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.16, 0.16, 0.95)
	var barrel := MeshInstance3D.new()
	barrel.mesh = barrel_mesh
	barrel.material_override = body_mat
	barrel.position = Vector3(0.0, 0.95, -0.55)
	_visual.add_child(barrel)

	add_child(ProtoUtil.make_ring(radius + 0.15, ProtoConfig.team_color(team), 0.12))

	_bar = Node3D.new()
	_bar.name = "HealthBar"
	_bar.set_script(HealthBarScript)
	_bar.set("bar_width", 1.1)
	_bar.set("bar_height", 0.14)
	_bar.set("show_segments", false)
	_bar.set("fill_color", ProtoConfig.team_color(team))
	_bar.position.y = 2.1
	add_child(_bar)


func _on_entity_ready() -> void:
	collision_mask = 0
	add_to_group("unioneer_turret")
	_retarget = SimRng.randf() * 0.2
	_cooldown = 0.35


func _physics_process(delta: float) -> void:
	if stats.is_dead or game == null:
		return
	var fx := status_effects()
	if fx and fx.is_stunned():
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_retarget -= delta
	if _retarget <= 0.0 or not is_instance_valid(_target) or not _valid_target(_target):
		_retarget = 0.2
		_target = _choose_target()
	if _target == null:
		return
	_face(_target.global_position)
	if _cooldown <= 0.0 and _in_range(_target):
		_cooldown = 1.0 / maxf(stats.get_attack_speed(), 0.01)
		_shoot(_target)


func _choose_target() -> CharacterBody3D:
	var owner_target := _owner_attack_target()
	if owner_target and _valid_target(owner_target) and _in_range(owner_target):
		return owner_target
	var best: CharacterBody3D = null
	var best_d := INF
	for node in game.get_enemies(team, true, global_position, attack_range):
		if not _valid_target(node):
			continue
		var d := ProtoUtil.flat_distance(global_position, node.global_position)
		if d > best_d:
			continue
		best_d = d
		best = node
	return best


func _owner_attack_target() -> CharacterBody3D:
	if owner_champion == null or not is_instance_valid(owner_champion):
		return null
	if not owner_champion.has_method("get_attack_target"):
		return null
	return owner_champion.get_attack_target()


func _valid_target(t: CharacterBody3D) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	var st := EntityData.get_stats_of(t)
	if st == null or st.is_dead or st.invulnerable:
		return false
	return EntityData.is_enemy(team, st.get_team())


func _in_range(t: Node3D) -> bool:
	return ProtoUtil.flat_distance(global_position, t.global_position) - game.radius_of(t) <= attack_range


func _shoot(t: CharacterBody3D) -> void:
	var owner_stats := EntityData.get_stats_of(owner_champion)
	var ap := owner_stats.get_ability_power() if owner_stats else 0.0
	var dmg := _definition_ref.base_damage + _definition_ref.damage_per_rank * float(tier - 1) + _definition_ref.ap_ratio * ap
	var shot := HomingShot.fire(self, t, dmg, 20.0, COLOR)
	shot.magic = true
	shot.cause = "unioneer_turret:shot"


func _face(pos: Vector3) -> void:
	var flat := Vector3(pos.x, _visual.global_position.y, pos.z)
	if flat.distance_squared_to(_visual.global_position) > 0.0001:
		_visual.look_at(flat, Vector3.UP)


func credit_source() -> Node:
	if owner_champion and is_instance_valid(owner_champion):
		return owner_champion
	return self


func on_takedown(victim: Node) -> void:
	super.on_takedown(victim)
	if owner_champion and is_instance_valid(owner_champion) and owner_champion.has_method("on_takedown"):
		owner_champion.on_takedown(victim)


func remove_turret() -> void:
	remove_from_group("unioneer_turret")
	queue_free()


func _on_entity_died() -> void:
	remove_from_group("unioneer_turret")
	remove_from_group("entity")
	if _bar:
		_bar.visible = false
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3(0.1, 0.1, 0.1), 0.25)
	tw.tween_callback(queue_free)
