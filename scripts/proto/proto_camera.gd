class_name ProtoCamera
extends Camera3D
## League-style camera. Free by default: it pans when the mouse touches the screen
## edge (or with the camera actions). The camera_lock action toggles following the
## champion, camera_center centers while held, and the mouse wheel zooms.

## The camera looks across the map at 45° so the lane runs diagonally on screen,
## like League's mid lane: Blue's base bottom-left, Red's top-right. The minimap
## (proto_minimap.gd) uses the same orientation.
const VIEW_YAW := -PI / 4.0
const OFFSET := Vector3(0.0, 24.0, 15.0)
## Screen right and screen up as directions on the ground.
const SCREEN_RIGHT := Vector3(0.70710678, 0.0, 0.70710678)
const SCREEN_UP := Vector3(0.70710678, 0.0, -0.70710678)

var target: Node3D
var locked: bool = false
## Area the camera focus may move in (x, z).
var bounds := Rect2(-60.0, -15.0, 120.0, 30.0)
var pan_speed: float = 35.0
var edge_margin: float = 10.0

var _zoom: float = 0.8
var _focus := Vector3.ZERO


func _ready() -> void:
	fov = 50.0
	far = 400.0
	if is_instance_valid(target):
		_focus = target.global_position
	_apply()


func _process(delta: float) -> void:
	var follow := locked or Input.is_action_pressed("camera_center")
	if follow:
		if is_instance_valid(target):
			_focus = _focus.lerp(target.global_position, minf(8.0 * delta, 1.0))
	else:
		# Camera actions only, so the ability bindings stay free.
		var move := Vector2(
			Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left"),
			Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up"))
		var vp := get_viewport()
		var mouse := vp.get_mouse_position()
		var rect := vp.get_visible_rect()
		if rect.has_point(mouse):
			if mouse.x <= edge_margin:
				move.x -= 1.0
			elif mouse.x >= rect.size.x - edge_margin:
				move.x += 1.0
			if mouse.y <= edge_margin:
				move.y -= 1.0
			elif mouse.y >= rect.size.y - edge_margin:
				move.y += 1.0
		# `move` is in screen terms (x right, y down); turn it into a world direction.
		var world_move := SCREEN_RIGHT * move.x - SCREEN_UP * move.y
		_focus += world_move * pan_speed * _zoom * delta
	_focus.x = clampf(_focus.x, bounds.position.x, bounds.end.x)
	_focus.z = clampf(_focus.z, bounds.position.y, bounds.end.y)
	_focus.y = 0.0
	_apply()


## Moves the view to look at `pos` (the minimap uses this). Stops following the champion.
func focus_on(pos: Vector3) -> void:
	locked = false
	_focus = Vector3(clampf(pos.x, bounds.position.x, bounds.end.x), 0.0, clampf(pos.z, bounds.position.y, bounds.end.y))
	_apply()


func _apply() -> void:
	global_position = _focus + (Basis(Vector3.UP, VIEW_YAW) * OFFSET) * _zoom
	look_at(_focus, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(_zoom - 0.08, 0.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(_zoom + 0.08, 1.6)
	elif Controls.pressed(event, "camera_lock"):
		locked = not locked
