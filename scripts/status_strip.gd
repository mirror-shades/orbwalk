class_name StatusStrip
extends Node3D
## A small row of status thumbnails above a unit's health bar. It reads the
## unit's StatusEffects and shows the effect keys plus stack counts (Grit, Tide,
## and so on). Purely cosmetic; the health bar already faces the camera, so this
## row does too. Fog hides the whole unit (and therefore this strip).

const MAX_ICONS := 4
const POLL := 0.08
const ICON_SIZE := 0.2
const GAP := 0.025

var _fx: Node
var _slots: Array[Dictionary] = []
var _timer: float = 0.0
var _signature: String = ""


## `fx` is the entity's StatusEffects node (methods are called dynamically to
## avoid a script reference cycle).
func setup(fx: Node) -> void:
	_fx = fx
	_timer = randf() * POLL
	_refresh_now()


func _process(delta: float) -> void:
	if _fx == null or not is_instance_valid(_fx):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = POLL
	_refresh()


func _refresh() -> void:
	var entries: Array = _fx.call("active_statuses")
	if entries.size() > MAX_ICONS:
		entries = entries.slice(0, MAX_ICONS)
	var signature := ""
	for e: Dictionary in entries:
		signature += "%s:%d:%s|" % [str(e["key"]), int(e["stacks"]), str(e["label"])]
	if signature == _signature:
		return
	_signature = signature
	_apply(entries)


func _refresh_now() -> void:
	_signature = ""
	_refresh()


func _apply(entries: Array) -> void:
	while _slots.size() < entries.size():
		_slots.append(_make_slot())
	var total := entries.size() * ICON_SIZE + maxf(float(entries.size() - 1), 0.0) * GAP
	var x := -total * 0.5 + ICON_SIZE * 0.5
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		var root := slot["root"] as Node3D
		if i >= entries.size():
			root.visible = false
			continue
		var e: Dictionary = entries[i]
		root.visible = true
		root.position = Vector3(x + float(i) * (ICON_SIZE + GAP), 0.0, 0.0)
		(slot["mat"] as StandardMaterial3D).albedo_color = Color(e["color"], 0.92)
		(slot["label"] as Label3D).text = str(e["label"])
		var stacks := int(e["stacks"])
		(slot["count"] as Label3D).text = str(stacks) if stacks > 1 else ""


func _make_slot() -> Dictionary:
	var root := Node3D.new()
	add_child(root)

	# Dark backing so the tile reads on any background.
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.7)
	back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	back_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var back_mesh := QuadMesh.new()
	back_mesh.size = Vector2(ICON_SIZE + 0.03, ICON_SIZE + 0.03)
	var back := MeshInstance3D.new()
	back.mesh = back_mesh
	back.material_override = back_mat
	back.position.z = -0.002
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(back)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := QuadMesh.new()
	mesh.size = Vector2(ICON_SIZE, ICON_SIZE)
	var tile := MeshInstance3D.new()
	tile.mesh = mesh
	tile.material_override = mat
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tile)

	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.pixel_size = 0.0024
	label.outline_size = 12
	label.position.z = 0.01
	root.add_child(label)

	var count := Label3D.new()
	count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	count.no_depth_test = true
	count.font_size = 40
	count.pixel_size = 0.0024
	count.outline_size = 12
	count.modulate = Color(1.0, 1.0, 0.72)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.position = Vector3(ICON_SIZE * 0.33, -ICON_SIZE * 0.33, 0.01)
	root.add_child(count)

	return {"root": root, "mat": mat, "label": label, "count": count}
