class_name ArtificerRobots
extends Node3D
## The Artificer's robot board: owns every robot he has out, the Formation burst
## bonus, and the W/E board-wide effects.
##
## One manager lives per champion, in the scene (not under the champion, so the
## robots stay where they were placed when he moves).

var source: Entity
var team: int = EntityDefinition.Team.TEAM_1
var robots: Array[ArtificerRobot] = []


## The manager for `p_source`, if it already exists.
static func find(p_source: Entity) -> ArtificerRobots:
	if p_source == null or not is_instance_valid(p_source) or p_source.get_tree() == null:
		return null
	for node in p_source.get_tree().get_nodes_in_group("artificer_robots"):
		var manager := node as ArtificerRobots
		if manager and manager.source == p_source:
			return manager
	return null


## The manager for `p_source`, creating it at the scene root if needed.
static func get_or_create(p_source: Entity) -> ArtificerRobots:
	var existing := find(p_source)
	if existing:
		return existing
	if p_source == null or not is_instance_valid(p_source) or p_source.get_parent() == null:
		return null
	var manager := ArtificerRobots.new()
	manager.name = "ArtificerRobots"
	manager.source = p_source
	manager.team = p_source.stats.get_team()
	manager.add_to_group("artificer_robots")
	p_source.get_parent().add_child(manager)
	return manager


## Robots currently on the board (including dormant and returning ones).
func board_count() -> int:
	_prune()
	return robots.size()



func add_robot(robot: ArtificerRobot) -> void:
	robots.append(robot)
	add_child(robot)


func forget(robot: ArtificerRobot) -> void:
	robots.erase(robot)


## +20% burst damage per other robot within 6, capped at +40%.
func formation_bonus(robot: ArtificerRobot) -> float:
	var def := _formation_definition()
	if def == null:
		return 0.0
	_prune()
	var nearby := 0
	for other in robots:
		if other == robot or not other.is_live():
			continue
		if ProtoUtil.flat_distance(other.global_position, robot.global_position) <= def.radius:
			nearby += 1
	return minf(float(nearby) * def.bonus_per_robot, def.max_bonus)


## Every enemy hit by at least one robot's burst radius. Used by W and the bot.
func enemies_in_burst(radius: float) -> Array[Node3D]:
	var tree := get_tree()
	var out: Array[Node3D] = []
	if tree == null:
		return out
	var seen := {}
	_prune()
	for robot in robots:
		for body in AbilityUtil.enemies_in_radius(tree, team, robot.global_position, radius):
			var id := body.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			out.append(body)
	return out


## True when any robot is close enough for a burst centered on `pos` to hit it.
func robot_covers(pos: Vector3, radius: float) -> bool:
	_prune()
	for robot in robots:
		if ProtoUtil.flat_distance(robot.global_position, pos) <= radius:
			return true
	return false


## W: every robot on the board runs at its nearest enemy and bursts there (a robot with
## nothing in range bursts where it stands). Returns how many were sent.
func seek_all(damage: float, radius: float, bleed_stacks: int, speed: float, seek_range: float) -> int:
	_prune()
	var sent := 0
	for robot in robots.duplicate():
		if robot.seek(damage, radius, bleed_stacks, speed, seek_range):
			sent += 1
	return sent


## E: every live robot fires a ray at the Artificer. Each ray hurts each enemy it
## crosses once; robots stay where they are. Returns how many robots fired.
func fire_rays(damage: float, width: float) -> int:
	_prune()
	var tree := get_tree()
	if tree == null or source == null:
		return 0
	var fired := 0
	var to := source.global_position
	for robot in robots:
		if not robot.is_live():
			continue
		fired += 1
		var from := robot.global_position
		var mid := (from + to) * 0.5
		var reach := ProtoUtil.flat_distance(from, to) * 0.5 + width + 2.0
		for body in AbilityUtil.enemies_in_radius(tree, team, mid, reach):
			if AbilityUtil.segment_distance_xz(body.global_position, from, to) > width + AbilityUtil.unit_radius(body):
				continue
			var st := body.get_node_or_null("Stats") as StatsComponent
			if st and not st.is_dead:
				st.take_magic_damage(damage, source)
		_ray_flash(from, to)
	return fired


func _ray_flash(from: Vector3, to: Vector3) -> void:
	var a := Vector3(from.x, 0.6, from.z)
	var b := Vector3(to.x, 0.6, to.z)
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, length)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.8, 1.0, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ray := MeshInstance3D.new()
	ray.mesh = box
	ray.material_override = mat
	ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(ray)
	ray.global_position = (a + b) * 0.5
	ray.look_at(b, Vector3.UP)
	var tw := ray.create_tween()
	tw.tween_property(ray, "transparency", 1.0, 0.3)
	tw.tween_callback(ray.queue_free)


func _formation_definition() -> FormationDefinition:
	if source == null or not is_instance_valid(source) or source.definition == null:
		return null
	return source.definition.passive as FormationDefinition


func _prune() -> void:
	for i in range(robots.size() - 1, -1, -1):
		if not is_instance_valid(robots[i]) or robots[i].is_queued_for_deletion():
			robots.remove_at(i)


func _physics_process(_delta: float) -> void:
	if source == null or not is_instance_valid(source):
		queue_free()
