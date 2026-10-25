class_name ProtoHexGrid
extends Node3D
## One team's spawner grid: each seat's 5 slots are cells of it (ProtoGame.slot_hex). Pointy-top hexes in axial (q, r) coordinates.
## +q always points toward the enemy: the grid is mirrored for the team that
## marches toward -X, so both teams get exactly the same layout (front row,
## neighbors, lane lines) relative to their own side. The hex "in front" of
## another is one step toward the enemy; "behind" is one step toward your orb.

const SQRT3 := 1.7320508
const DIRS := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

var team: int = 0
## +1 when this team's minions march toward +X, -1 otherwise.
var forward: int = 1
## Hex circumradius in meters.
var hex_size: float = 1.7
var cols: int = 5
var rows: int = 5

var tiles: Dictionary[Vector2i, MeshInstance3D] = {}
var spawners: Dictionary[Vector2i, ProtoSpawner] = {}

var _materials: Dictionary[Vector2i, StandardMaterial3D] = {}
var _offset := Vector3.ZERO
var _base_color := Color.WHITE


func setup(p_team: int, p_forward: int, p_cols: int, p_rows: int, p_hex_size: float) -> void:
	team = p_team
	forward = p_forward
	cols = p_cols
	rows = p_rows
	hex_size = p_hex_size


func _ready() -> void:
	_base_color = ProtoConfig.team_color(team)
	_base_color.a = 0.3

	# Rectangular layout ("odd-r" offset rows), centered on this node.
	var cells: Array[Vector2i] = []
	var sum := Vector3.ZERO
	for r in rows:
		for c in cols:
			var h := Vector2i(c - ((r - (r & 1)) >> 1), r)
			cells.append(h)
			sum += _raw_position(h)
	_offset = sum / float(cells.size())

	var mesh := CylinderMesh.new()
	mesh.top_radius = hex_size * 0.93
	mesh.bottom_radius = hex_size * 0.93
	mesh.height = 0.06
	mesh.radial_segments = 6
	mesh.rings = 1
	for h in cells:
		var tile := MeshInstance3D.new()
		tile.mesh = mesh
		var mat := ProtoUtil.flat_material(_base_color)
		tile.material_override = mat
		tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tile.position = axial_to_local(h) + Vector3(0.0, 0.03, 0.0)
		add_child(tile)
		tiles[h] = tile
		_materials[h] = mat


func _raw_position(h: Vector2i) -> Vector3:
	return Vector3(hex_size * SQRT3 * (h.x + h.y * 0.5), 0.0, hex_size * 1.5 * h.y)


## Position in this node's space. x is flipped for the -X team (the mirror).
func axial_to_local(h: Vector2i) -> Vector3:
	var p := _raw_position(h) - _offset
	p.x *= forward
	return p


func hex_to_world(h: Vector2i) -> Vector3:
	return to_global(axial_to_local(h))


func world_to_hex(world: Vector3) -> Vector2i:
	var p := to_local(world)
	p.x *= forward
	p += _offset
	var qf := (SQRT3 / 3.0 * p.x - p.z / 3.0) / hex_size
	var rf := (2.0 / 3.0 * p.z) / hex_size
	return _axial_round(qf, rf)


static func _axial_round(qf: float, rf: float) -> Vector2i:
	var sf := -qf - rf
	var q := roundf(qf)
	var r := roundf(rf)
	var s := roundf(sf)
	var dq := absf(q - qf)
	var dr := absf(r - rf)
	var ds := absf(s - sf)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(int(q), int(r))


func has_cell(h: Vector2i) -> bool:
	return tiles.has(h)


func is_empty(h: Vector2i) -> bool:
	return tiles.has(h) and not spawners.has(h)


func spawner_at(h: Vector2i) -> ProtoSpawner:
	if spawners.has(h):
		return spawners[h]
	return null


func all_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(tiles.keys())
	return out


func neighbors(h: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var n: Vector2i = h + d
		if tiles.has(n):
			out.append(n)
	return out


func front_of(h: Vector2i) -> Vector2i:
	return h + Vector2i(1, 0)


func behind_of(h: Vector2i) -> Vector2i:
	return h - Vector2i(1, 0)


## Bigger means closer to the enemy.
func frontness(h: Vector2i) -> float:
	return axial_to_local(h).x * forward


func add_spawner(sp: ProtoSpawner, h: Vector2i) -> void:
	spawners[h] = sp
	sp.position = axial_to_local(h)
	add_child(sp)


## Hides every tile except `cells` (the spawner slots in use).
func show_only(cells: Array[Vector2i]) -> void:
	for h in tiles:
		tiles[h].visible = h in cells


func reset_colors() -> void:
	for h in _materials:
		_materials[h].albedo_color = _base_color


func tint(h: Vector2i, color: Color) -> void:
	if _materials.has(h):
		_materials[h].albedo_color = color
