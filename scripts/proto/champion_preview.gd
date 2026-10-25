class_name ChampionPreview
extends SubViewportContainer
## A slowly turning 3D model of a champion for the champion select screen.
## Takes the idle model out of the champion's scene and plays its idle animation
## in a small world of its own, so nothing from the match can see it.

const TURN_SPEED := 0.5

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _model: Node3D
var _shown_id: String = ""


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	key.light_energy = 1.3
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 150.0, 0.0)
	rim.light_energy = 0.6
	rim.light_color = Color(1.0, 0.85, 0.6)
	_viewport.add_child(rim)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)


func _process(delta: float) -> void:
	_pivot.rotate_y(TURN_SPEED * delta)


## Shows the champion with this id (from ProtoConfig.CHAMPIONS).
func show_champion(id: String) -> void:
	if id == _shown_id or not ProtoConfig.CHAMPIONS.has(id):
		return
	_shown_id = id
	if _model != null:
		_model.queue_free()
		_model = null
	var scene := load(str(ProtoConfig.CHAMPIONS[id]["scene"])) as PackedScene
	if scene == null:
		return
	# Only the model is kept; the champion's scripts never run because the
	# instance is freed before it enters the tree.
	var champion := scene.instantiate()
	var model := champion.get_node_or_null("Models/idle_model") as Node3D
	if model == null:
		champion.free()
		return
	var body_top := _capsule_top(champion)
	model.get_parent().remove_child(model)
	champion.free()
	_model = model
	# The champion scenes turn their models 180° to face forward in the match;
	# undo that so each preview starts facing the camera.
	_pivot.rotation = Vector3(0.0, PI, 0.0)
	_pivot.add_child(_model)
	_frame_model(body_top)
	var anim := _model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim:
		var clip := str(_model.get_meta("anim", "Take 001"))
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			anim.play(clip)


## Points the camera so the model fills the view, whatever its size.
## Frames from the skeleton when there is one: imported skinned meshes can
## report bounds far off their visible size, and capsules miss hats.
func _frame_model(body_top: float) -> void:
	var top := _skeleton_top()
	if top > 0.0:
		# The highest bone is the head's base, so leave room for the head and hat.
		_aim_camera(top * 1.3, top * 0.62)
		return
	if body_top > 0.0:
		_aim_camera(body_top * 1.15, body_top * 0.55)
		return
	var box := AABB()
	var first := true
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var b := _to_pivot(mi) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var height := maxf(box.size.y, 1.0) if not first else 2.0
	var center_y := box.get_center().y if not first else 1.0
	_aim_camera(height, center_y)


## Height of the highest bone in the model's rest pose, or 0 without a skeleton.
func _skeleton_top() -> float:
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return 0.0
	var skel := skeletons[0] as Skeleton3D
	var xf := _to_pivot(skel)
	var top := 0.0
	for i in skel.get_bone_count():
		top = maxf(top, (xf * skel.get_bone_global_rest(i).origin).y)
	return top


## Top of the champion's collision capsule, or 0 when the scene has none.
func _capsule_top(champion: Node) -> float:
	var col := champion.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null or not (col.shape is CapsuleShape3D):
		return 0.0
	var capsule := col.shape as CapsuleShape3D
	return col.transform.origin.y + capsule.height * 0.5 * col.transform.basis.get_scale().y


## A node's transform relative to the turning pivot (works before entering the tree).
func _to_pivot(node: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n := node
	while n != null and n != _pivot:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _aim_camera(height: float, center_y: float) -> void:
	# Distance that fits the height in the vertical field of view, plus margin.
	var dist := (height * 0.5) / tan(deg_to_rad(_camera.fov * 0.5)) * 1.15
	_camera.transform = Transform3D.IDENTITY.looking_at(
			Vector3(0.0, -height * 0.1, -dist)).translated(
			Vector3(0.0, center_y + height * 0.1, dist))
