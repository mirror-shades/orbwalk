class_name ThrownKnife
extends Node3D
## Cat's Paw's Q knife. Flies out in a straight line, sits in the ground, and can
## be recalled to his hand. Each flight (out, and back) damages and slows every
## enemy it passes through once. Towers and the orb are ignored.
## A rope (visual only) connects it to the thrower while it's out.

signal finished

enum State { OUT, GROUND, RECALL }

const SLOW_ID := "cats_paw_q_slow"

var thrower: Node3D
var team: int = 0
var damage: float = 0.0
var slow: float = 0.3
var slow_duration: float = 1.5
var width: float = 0.8
var lifetime: float = 5.0
var throw_speed: float = 25.0
var recall_speed: float = 30.0

var state: State = State.OUT
var _end := Vector3.ZERO
## A recall pressed while the knife is still flying waits for it to land.
var _recall_queued: bool = false
var _ground_left: float = 0.0
var _hit_ids: Dictionary = {}
var _blade: Node3D
var _rope: MeshInstance3D
var _marker: MeshInstance3D


func _ready() -> void:
	_build_visuals()


## Call after adding to the scene: starts the throw from `from` toward `to`.
func launch(from: Vector3, to: Vector3) -> void:
	global_position = from
	_end = to
	_face(to - from)


func is_in_ground() -> bool:
	return state == State.GROUND


func ground_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)


## Requests a recall. While the knife is still flying this is buffered until it
## lands, so a double Q never cuts the throw short.
func request_recall() -> void:
	if state == State.RECALL:
		return
	if state == State.OUT:
		_recall_queued = true
		return
	recall()


## Pulls the knife back toward the thrower. Enemies it passes get hit again.
func recall() -> void:
	if state == State.RECALL:
		return
	state = State.RECALL
	_recall_queued = false
	_hit_ids.clear()
	_marker.visible = false
	_blade.rotation.x = 0.0


## Removes the knife (recalled to the hand, expired, or picked up by R).
func remove() -> void:
	if is_queued_for_deletion():
		return
	finished.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	match state:
		State.OUT:
			_fly_toward(_end, throw_speed, delta, true)
		State.GROUND:
			_ground_left -= delta
			if _ground_left <= 0.0:
				remove()
				return
		State.RECALL:
			if not _thrower_alive():
				remove()
				return
			_fly_toward(thrower.global_position + Vector3(0.0, 1.0, 0.0), recall_speed, delta, false)
	_update_rope()


func _fly_toward(target: Vector3, speed: float, delta: float, landing: bool) -> void:
	var prev := global_position
	var to := target - global_position
	var step := speed * delta
	if to.length() <= step:
		global_position = target
		_hit_segment(prev, global_position)
		if landing:
			_land()
		else:
			remove()
		return
	global_position += to.normalized() * step
	_hit_segment(prev, global_position)
	_face(to if landing else -to)


func _land() -> void:
	state = State.GROUND
	_ground_left = lifetime
	_hit_ids.clear()
	# Tip stuck into the ground.
	_blade.rotation.x = -0.9
	_marker.visible = true
	if _recall_queued:
		recall()


# ---- Hits ----

func _hit_segment(a: Vector3, b: Vector3) -> void:
	for node in get_tree().get_nodes_in_group("entity"):
		if not (node is CharacterBody3D) or node == thrower:
			continue
		var st := node.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead or st.invulnerable:
			continue
		var kind := st.get_entity_type()
		if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB:
			continue
		if not EntityData.is_enemy(team, st.get_team()):
			continue
		var id := (node as Node).get_instance_id()
		if _hit_ids.has(id):
			continue
		var body := node as Node3D
		if _segment_distance_xz(body.global_position, a, b) > width * 0.5 + _radius_of(body):
			continue
		_hit_ids[id] = true
		st.take_physical_damage(damage, thrower if _thrower_alive() else null)
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			fx.apply_slow(slow, slow_duration, SLOW_ID)


static func _segment_distance_xz(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var len2 := ab.length_squared()
	var t := 0.0 if len2 < 0.000001 else clampf(ap.dot(ab) / len2, 0.0, 1.0)
	return (ap - ab * t).length()


static func _radius_of(body: Node3D) -> float:
	var cs := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs:
		var s := absf(cs.scale.x)
		if cs.shape is CapsuleShape3D:
			return (cs.shape as CapsuleShape3D).radius * s
		if cs.shape is CylinderShape3D:
			return (cs.shape as CylinderShape3D).radius * s
	return 0.5


func _thrower_alive() -> bool:
	if not is_instance_valid(thrower):
		return false
	var st := thrower.get_node_or_null("Stats") as StatsComponent
	return st != null and not st.is_dead


# ---- Visuals (placeholder shapes) ----

func _build_visuals() -> void:
	_blade = Node3D.new()
	add_child(_blade)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.85, 0.87, 0.9)
	steel.metallic = 0.8
	steel.roughness = 0.3
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.25, 0.12)
	_add_box(_blade, Vector3(0.07, 0.025, 0.7), Vector3(0.0, 0.0, -0.35), steel)
	_add_box(_blade, Vector3(0.25, 0.05, 0.05), Vector3(0.0, 0.0, 0.0), wood)
	_add_box(_blade, Vector3(0.07, 0.07, 0.25), Vector3(0.0, 0.0, 0.14), wood)

	# Ground marker while the knife is stuck (where R will pull to).
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.7
	torus.rings = 40
	torus.ring_segments = 6
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.6, 0.2, 0.8)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker = MeshInstance3D.new()
	_marker.mesh = torus
	_marker.material_override = ring_mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.top_level = true
	_marker.scale = Vector3(1.0, 0.15, 1.0)
	_marker.visible = false
	add_child(_marker)

	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.75, 0.62, 0.4)
	var rope_box := BoxMesh.new()
	rope_box.size = Vector3(0.04, 0.04, 1.0)
	_rope = MeshInstance3D.new()
	_rope.mesh = rope_box
	_rope.material_override = rope_mat
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rope.top_level = true
	add_child(_rope)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _face(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	look_at(global_position + dir, Vector3.UP)


func _update_rope() -> void:
	if _marker.visible:
		_marker.global_position = Vector3(global_position.x, 0.05, global_position.z)
	if not is_instance_valid(thrower):
		_rope.visible = false
		return
	var hand := thrower.global_position + Vector3(0.0, 1.0, 0.0)
	var tail := global_position
	var length := hand.distance_to(tail)
	if length < 0.3:
		_rope.visible = false
		return
	_rope.visible = true
	var mid := (hand + tail) * 0.5
	var xf := Transform3D(Basis.IDENTITY, mid).looking_at(tail, Vector3.UP if absf((tail - hand).normalized().y) < 0.99 else Vector3.RIGHT)
	_rope.global_transform = xf.scaled_local(Vector3(1.0, 1.0, length))
