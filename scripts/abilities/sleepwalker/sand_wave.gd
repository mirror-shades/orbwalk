class_name SandWave
extends Node3D
## The Sleepwalker's Q wave. Rolls straight to `dest`, damaging, rooting and
## adding a Grit stack to every enemy it passes, once each.

signal finished

const COLOR := Color(0.86, 0.74, 0.5)

var team: int = 0
var source: Node3D
var dest := Vector3.ZERO
var speed: float = 14.0
var width: float = 1.2
var damage: float = 100.0
var root_duration: float = 0.75

## Instance ids of enemies already hit this cast.
var _hit: Dictionary = {}


func _ready() -> void:
	_build_visual()


## Call after adding to the scene: places the wave at `from` and points it at `dest`.
func launch(from: Vector3) -> void:
	global_position = Vector3(from.x, 0.0, from.z)
	var to := dest - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		look_at(global_position + to, Vector3.UP)


func _physics_process(delta: float) -> void:
	var to := dest - global_position
	to.y = 0.0
	var step := speed * delta
	var previous := global_position
	if to.length() <= step:
		global_position = Vector3(dest.x, 0.0, dest.z)
		_hit_segment(previous, global_position)
		finish()
		return
	global_position += to.normalized() * step
	_hit_segment(previous, global_position)


## Damages, roots and stacks every enemy the wave crossed this frame, once each.
func _hit_segment(a: Vector3, b: Vector3) -> void:
	var src: Node = source if is_instance_valid(source) else null
	var grit := GritAbility.of(source)
	for node in get_tree().get_nodes_in_group("entity"):
		if not (node is Node3D) or node == source:
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
		if _hit.has(id):
			continue
		var body := node as Node3D
		if AbilityUtil.segment_distance_xz(body.global_position, a, b) > width * 0.5 + AbilityUtil.unit_radius(body):
			continue
		_hit[id] = true
		st.take_magic_damage(damage, src)
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx and not st.is_dead:
			fx.apply_root(root_duration)
		if grit:
			grit.add(body)


func finish() -> void:
	if is_queued_for_deletion():
		return
	finished.emit()
	queue_free()


## A wide, low sand wall with a brighter leading lip.
func _build_visual() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(COLOR, 0.55)
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(width, 0.7, 0.55)
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = body_mat
	body.position.y = 0.35
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)

	var lip_mat := StandardMaterial3D.new()
	lip_mat.albedo_color = Color(0.95, 0.86, 0.62, 0.85)
	lip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lip_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var lip_mesh := BoxMesh.new()
	lip_mesh.size = Vector3(width * 1.05, 0.18, 0.16)
	var lip := MeshInstance3D.new()
	lip.mesh = lip_mesh
	lip.material_override = lip_mat
	lip.position = Vector3(0.0, 0.7, -0.24)
	lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lip)
