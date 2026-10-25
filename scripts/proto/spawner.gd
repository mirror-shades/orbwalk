class_name ProtoSpawner
extends Node3D
## A permanent, indestructible building in one of a player's 5 slots.
## Every wave it sends its minions (see ProtoGame._spawn_wave).

var type_id: String = ""
var team: int = 0
## The seat that owns it.
var seat: int = -1
## Buildings don't level up any more; the model just uses its level 1 look.
var level: int = 1
var hex: Vector2i = Vector2i.ZERO
var hex_size: float = 1.7

var _model: Node3D
var _label: Label3D
## Level / synergy text over the building. Off to keep the screen clean (the
## building model already grows with level).
const SHOW_LABEL := false
var _buff_text: String = ""


func setup(p_type: String, p_team: int, p_hex: Vector2i, p_hex_size: float) -> void:
	type_id = p_type
	team = p_team
	hex = p_hex
	hex_size = p_hex_size


func _ready() -> void:
	if SHOW_LABEL:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.font_size = 30
		_label.outline_size = 8
		_label.pixel_size = 0.01
		_label.position = Vector3(0.0, 3.4, 0.0)
		add_child(_label)
	_rebuild_model()
	_refresh_label()
	_pop()


## Small bounce when an upgrade is picked for it.
func on_upgraded() -> void:
	_pop()


func display_name() -> String:
	return str(SpawnerPool.SPAWNERS[type_id]["name"])


func set_buff_text(text: String) -> void:
	_buff_text = text
	_refresh_label()


func spawn_point() -> Vector3:
	return global_position + Vector3(SimRng.randf_range(-0.4, 0.4), 0.0, SimRng.randf_range(-0.4, 0.4))


func _refresh_label() -> void:
	if _label == null:
		return
	var lines: PackedStringArray = []
	if _buff_text != "":
		lines.append(_buff_text)
	_label.text = "\n".join(lines)
	_label.modulate = Color(1.0, 0.9, 0.45) if _buff_text != "" else Color.WHITE


func _rebuild_model() -> void:
	if _model:
		_model.queue_free()
		_model = null
	var ps := load(ProtoConfig.building_path(type_id, level)) as PackedScene
	if ps:
		_model = ps.instantiate() as Node3D
	if _model == null:
		# Fallback block if the model can't be loaded.
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.6, 1.6, 1.6)
		mi.mesh = box
		mi.material_override = ProtoUtil.lit_material(ProtoConfig.team_color(team))
		_model = mi
	ProtoUtil.fit_model(_model, 1.6 + 0.4 * level, hex_size * 1.5)
	add_child(_model)


func _pop() -> void:
	scale = Vector3.ONE * 0.3
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
