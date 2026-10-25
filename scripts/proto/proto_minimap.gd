class_name ProtoMinimap
extends Control
## Bottom-right minimap, laid out like League's ARAM one: a square frame with the
## lane running diagonally from the bottom-left base (Blue) to the top-right base
## (Red). Shows champions, minions, towers, orbs and camps; units the player's
## team can't see are left out (unless spectating). The white outline is what the
## camera shows. Left-click or drag to move the camera there.

const SIDE := 224.0
const MARGIN := 8.0
## Space kept between the bases and the frame, in pixels.
const PAD := 22.0
const DIAG := 0.70710678
const BG := Color(0.04, 0.05, 0.07, 0.88)
const BORDER := Color(0.85, 0.7, 0.35, 0.9)
const LANE := Color(0.17, 0.2, 0.25, 1.0)
const JUNGLE := Color(0.1, 0.17, 0.12, 1.0)
const ALLY := Color(0.45, 0.7, 1.0)
const ENEMY := Color(1.0, 0.5, 0.45)
## Seconds between redraws. Drawing every unit each frame is costly with many minions.
const REDRAW_INTERVAL := 0.1

var _game: ProtoGame
var _camera: ProtoCamera
## Pixels per world unit.
var _k: float = 1.0
var _dragging: bool = false
var _redraw_timer: float = 0.0


func setup(game: ProtoGame, camera: ProtoCamera) -> void:
	_game = game
	_camera = camera
	custom_minimum_size = Vector2(SIDE, SIDE)
	size = custom_minimum_size
	# The lane's two ends sit on the square's diagonal, PAD pixels from the corners.
	_k = (SIDE * 0.5 - PAD) / (DIAG * game.lane_half_length)


func _ready() -> void:
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -(MARGIN + custom_minimum_size.x)
	offset_top = -(MARGIN + custom_minimum_size.y)
	offset_right = -MARGIN
	offset_bottom = -MARGIN


func _process(delta: float) -> void:
	# Not during champion select or the spawner draft.
	visible = not _game.is_picking()
	if not visible:
		return
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		queue_redraw()


# ---- Coordinates ----
# The world's x axis (Blue base to Red base) runs up and to the right; the world's
# z axis (north/south of the lane) runs down and to the right.

func _to_map(world: Vector3) -> Vector2:
	return size * 0.5 + Vector2(world.x + world.z, world.z - world.x) * (DIAG * _k)


func _to_world(map_pos: Vector2) -> Vector3:
	var d := (map_pos - size * 0.5) / (DIAG * _k)  # d.x = x + z, d.y = z - x
	return Vector3((d.x - d.y) * 0.5, 0.0, (d.x + d.y) * 0.5)


## Fills a world-space rectangle (it's a tilted shape on the map).
func _fill_world_rect(x0: float, z0: float, x1: float, z1: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		_to_map(Vector3(x0, 0.0, z0)), _to_map(Vector3(x1, 0.0, z0)),
		_to_map(Vector3(x1, 0.0, z1)), _to_map(Vector3(x0, 0.0, z1))]), color)


# ---- Drawing ----

func _draw() -> void:
	if _game == null or not is_instance_valid(_game):
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, BG)
	_draw_terrain()
	_draw_camps()
	_draw_structures()
	_draw_minions()
	_draw_champions()
	_draw_camera_view()
	draw_rect(rect, BORDER, false, 2.0)


func _draw_terrain() -> void:
	var g := _game
	# Jungle paths and clearings.
	for camp_id: String in ProtoConfig.JUNGLE_CAMPS:
		var c := g.camp_position(camp_id)
		var hw := g.jungle_path_half_width
		var z_edge := signf(c.z) * g.lane_half_width
		_fill_world_rect(c.x - hw, minf(c.z, z_edge), c.x + hw, maxf(c.z, z_edge), JUNGLE)
		draw_circle(_to_map(c), g.jungle_clearing_radius * _k, JUNGLE)
	# The lane.
	_fill_world_rect(-g.lane_half_length, -g.lane_half_width, g.lane_half_length, g.lane_half_width, LANE)
	# Halfway line.
	draw_line(_to_map(Vector3(0.0, 0.0, -g.lane_half_width)), _to_map(Vector3(0.0, 0.0, g.lane_half_width)), Color(1.0, 1.0, 1.0, 0.1), 1.0)


func _draw_camps() -> void:
	for camp_id: String in ProtoConfig.JUNGLE_CAMPS:
		var p := _to_map(_game.camp_position(camp_id))
		var alive := _game.camp_monster(camp_id) != null
		if alive:
			draw_circle(p, 4.5, Color(0.95, 0.78, 0.3))
			draw_arc(p, 4.5, 0.0, TAU, 16, Color(0.0, 0.0, 0.0, 0.8), 1.0, true)
		else:
			draw_arc(p, 4.0, 0.0, TAU, 16, Color(0.6, 0.55, 0.4, 0.7), 1.2, true)


func _draw_structures() -> void:
	for s in _game.structures:
		if not is_instance_valid(s):
			continue
		var p := _to_map(s.global_position)
		var color := _team_color(s.team)
		var dead := s.stats.is_dead
		if s.kind == ProtoStructure.Kind.ORB:
			if dead:
				draw_arc(p, 6.0, 0.0, TAU, 16, Color(color, 0.5), 1.5, true)
			else:
				draw_circle(p, 6.0, color)
				draw_arc(p, 6.0, 0.0, TAU, 16, Color(0.0, 0.0, 0.0, 0.85), 1.2, true)
		else:
			var r := Rect2(p - Vector2(4.0, 4.0), Vector2(8.0, 8.0))
			if dead:
				draw_rect(r, Color(color, 0.5), false, 1.2)
			else:
				draw_rect(r, color)
				draw_rect(r, Color(0.0, 0.0, 0.0, 0.85), false, 1.2)


func _draw_minions() -> void:
	for m in _game.minions:
		if not is_instance_valid(m) or m.stats.is_dead or not _seen(m):
			continue
		draw_circle(_to_map(m.global_position), 2.0, _team_color(m.team))


func _draw_champions() -> void:
	for seat: int in _game.champions:
		var champ: CharacterBody3D = _game.champions[seat]
		if not is_instance_valid(champ):
			continue
		var st := EntityData.get_stats_of(champ)
		if st == null or st.is_dead or not _seen(champ):
			continue
		var p := _to_map(champ.global_position)
		var color := _team_color(_game.seat_team(seat))
		draw_circle(p, 5.5, Color(0.0, 0.0, 0.0, 0.9))
		draw_circle(p, 4.3, color)
		if seat == _game.player_seat:
			draw_arc(p, 6.5, 0.0, TAU, 20, Color.WHITE, 1.6, true)


## The ground area the camera currently shows, as a white outline.
func _draw_camera_view() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var vp := _camera.get_viewport()
	var rect := vp.get_visible_rect()
	var plane := Plane(Vector3.UP, 0.0)
	var pts := PackedVector2Array()
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var origin := _camera.project_ray_origin(corner)
		var dir := _camera.project_ray_normal(corner)
		var hit: Variant = plane.intersects_ray(origin, dir)
		if hit == null:
			return
		pts.append(_to_map(hit as Vector3).clamp(Vector2.ZERO, size))
	pts.append(pts[0])
	draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.85), 1.4)


func _team_color(team: int) -> Color:
	return ALLY if team == _game.player_team else ENEMY


## Spectators see everything; players only what their team can see.
func _seen(node: Node) -> bool:
	return _game.spectate or FogOfWar.can_see(_game.player_team, node)


# ---- Clicking ----

func _gui_input(event: InputEvent) -> void:
	if _camera == null:
		return
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		if button.pressed:
			_move_camera_to(button.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_move_camera_to((event as InputEventMouseMotion).position)
		accept_event()


func _move_camera_to(map_pos: Vector2) -> void:
	_camera.focus_on(_to_world(map_pos.clamp(Vector2.ZERO, size)))
	# Redraw now so the camera outline follows the mouse while dragging.
	queue_redraw()
