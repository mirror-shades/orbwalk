class_name ArtificerRobot
extends Node3D
## One clockwork robot placed by the Artificer (by Q or R, they behave the same). It
## crawls to a spot, arms, bursts once, then sits dormant until its lifetime runs out
## or W sends it at the nearest enemy to burst again.
##
## Robots are not Entities: they are untargetable, unkillable and have no collision.

enum State { CRAWLING, ACTIVE, DORMANT, SEEKING }

## A seeking robot bursts once it is this close to its target.
const SEEK_TRIGGER := 1.2

const MODEL := preload("res://assets/models/monsters/Flying/FBX/Goleling.fbx")
const TIN := Color(0.62, 0.68, 0.74)
const DORMANT_TIN := Color(0.34, 0.37, 0.4)

var source: Entity
var manager: ArtificerRobots
var team: int = EntityDefinition.Team.TEAM_1
var state: State = State.CRAWLING
## Seconds the robot stays on the board, counted from when it was placed.
var lifetime: float = 15.0

var crawl_speed: float = 12.0
var pulse_damage: float = 0.0
var pulse_radius: float = 1.75
var slow: float = 0.0
var slow_duration: float = 1.0
var pulse_interval: float = 1.0
var pulses_left: int = 3
var seek_damage: float = 0.0
var seek_radius: float = 2.5
var seek_bleed: int = 0
var seek_speed: float = 14.0
var seek_range: float = 14.0

var _target := Vector3.ZERO
var _timer: float = 0.0
var _visual: Node3D
var _anim: AnimationPlayer
var _mesh_material: StandardMaterial3D
var _ring: MeshInstance3D


## Call before manager.add_robot(). `target` is the spot the robot crawls to.
func setup(p_source: Entity, p_manager: ArtificerRobots, target: Vector3, p_pulse_damage: float, p_pulse_radius: float, p_slow: float, p_slow_duration: float) -> void:
	source = p_source
	manager = p_manager
	team = p_source.stats.get_team()
	_target = Vector3(target.x, 0.0, target.z)
	pulse_damage = p_pulse_damage
	pulse_radius = p_pulse_radius
	slow = p_slow
	slow_duration = p_slow_duration


func _ready() -> void:
	_build_visual()
	_face_toward(_target)


## Starts crawling to `target` from the robot's current position.
func start_crawl(target: Vector3) -> void:
	_target = Vector3(target.x, 0.0, target.z)
	state = State.CRAWLING
	_timer = 0.0
	_face_toward(_target)


## Starts at its current position with the first pulse one interval away.
func start_active() -> void:
	state = State.ACTIVE
	_timer = pulse_interval
	_play_anim("Flying_Idle")


func is_live() -> bool:
	return is_instance_valid(self) and not is_queued_for_deletion()


func detonate(damage: float, radius: float, bleed_stacks: int) -> void:
	if not is_live():
		return
	var tree := get_tree()
	if tree == null:
		return
	for body in AbilityUtil.enemies_in_radius(tree, team, global_position, radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead:
			continue
		st.take_magic_damage(damage, source)
		if st.is_dead:
			continue
		if bleed_stacks > 0:
			var fx := body.get_node_or_null("StatusEffects") as StatusEffects
			if fx:
				fx.apply_bleed(bleed_stacks, source)
	AbilityUtil.ring_flash(tree.current_scene, global_position, radius, Color(1.0, 0.62, 0.25, 0.9))
	manager.forget(self)
	queue_free()


## W: the robot (whatever it is doing) runs at the nearest enemy and bursts on it. It is
## always consumed: with nothing in range it bursts where it stands. False only when
## it is already on its way.
func seek(damage: float, radius: float, bleed_stacks: int, speed: float, p_range: float) -> bool:
	if state == State.SEEKING or not is_live():
		return false
	seek_damage = damage
	seek_radius = radius
	seek_bleed = bleed_stacks
	seek_speed = speed
	seek_range = p_range
	state = State.SEEKING
	_set_tint(TIN)
	_set_ring_visible(true)
	return true


func nearest_enemy(radius: float) -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var best: Node3D = null
	var best_d := INF
	for body in AbilityUtil.enemies_in_radius(tree, team, global_position, radius):
		var d := ProtoUtil.flat_distance(global_position, body.global_position)
		if d < best_d:
			best = body
			best_d = d
	return best


func _physics_process(delta: float) -> void:
	if source == null or not is_instance_valid(source):
		manager.forget(self)
		queue_free()
		return
	if state != State.SEEKING:
		lifetime -= delta
		if lifetime <= 0.0:
			AbilityUtil.ring_flash(get_tree().current_scene, global_position, 1.0, Color(0.6, 0.6, 0.65, 0.5))
			manager.forget(self)
			queue_free()
			return
	match state:
		State.CRAWLING:
			_step_toward(_target, crawl_speed, delta, true)
			if ProtoUtil.flat_distance(global_position, _target) <= 0.12:
				global_position = Vector3(_target.x, 0.0, _target.z)
				start_active()
		State.ACTIVE:
			_timer -= delta
			if _timer <= 0.0:
				_pulse()
				pulses_left -= 1
				if pulses_left <= 0:
					state = State.DORMANT
					_set_tint(DORMANT_TIN)
					_play_anim("Flying_Idle")
					_set_ring_visible(false)
				else:
					_timer += pulse_interval
		State.SEEKING:
			var foe := nearest_enemy(seek_range)
			if foe == null:
				detonate(seek_damage, seek_radius, seek_bleed)
				return
			_step_toward(foe.global_position, seek_speed, delta, true)
			if ProtoUtil.flat_distance(global_position, foe.global_position) <= SEEK_TRIGGER:
				detonate(seek_damage, seek_radius, seek_bleed)


func _step_toward(dest: Vector3, speed: float, delta: float, show_motion: bool) -> void:
	var flat := Vector3(dest.x - global_position.x, 0.0, dest.z - global_position.z)
	if flat.length_squared() <= 0.0001:
		return
	global_position += flat.normalized() * minf(speed * delta, flat.length())
	_face_toward(dest)
	if show_motion and _anim and _anim.has_animation("Fast_Flying") and _anim.current_animation != "Fast_Flying":
		_play_anim("Fast_Flying")


func _pulse() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var damage := pulse_damage
	if manager:
		damage *= 1.0 + manager.formation_bonus(self)
	for body in AbilityUtil.enemies_in_radius(tree, team, global_position, pulse_radius):
		var st := body.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead:
			continue
		st.take_magic_damage(damage, source)
		if st.is_dead or slow <= 0.0:
			continue
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			fx.apply_slow(slow, slow_duration, "artificer_robot_slow")
	AbilityUtil.ring_flash(tree.current_scene, global_position, pulse_radius, Color(1.0, 0.72, 0.28, 0.55))


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var model := MODEL.instantiate() as Node3D
	if model:
		ProtoUtil.fit_model(model, 0.9, 0.9)
		_mesh_material = StandardMaterial3D.new()
		_mesh_material.albedo_color = TIN
		_mesh_material.metallic = 0.45
		_mesh_material.roughness = 0.45
		for node in model.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = _mesh_material
		_visual.add_child(model)
		_anim = ProtoUtil.find_anim_player(model)
		_play_anim("Flying_Idle")
	_ring = ProtoUtil.make_ring(0.45, ProtoConfig.team_color(team), 0.06)
	_ring.position.y = 0.02
	add_child(_ring)


func _play_anim(anim_name: String) -> void:
	if _anim == null:
		return
	for candidate: String in [anim_name, "CharacterArmature|" + anim_name]:
		if _anim.has_animation(candidate):
			if _anim.current_animation != candidate:
				_anim.play(candidate)
			return


func _set_tint(color: Color) -> void:
	if _mesh_material:
		_mesh_material.albedo_color = color


func _set_ring_visible(visible_now: bool) -> void:
	if _ring:
		_ring.visible = visible_now


func _face_toward(dest: Vector3) -> void:
	var dir := dest - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		rotation.y = atan2(-dir.x, -dir.z)
