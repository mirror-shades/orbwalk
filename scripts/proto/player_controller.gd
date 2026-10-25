class_name PlayerController
extends Node
## The local player's hands. Reads mouse and keyboard, turns them into
## PlayerCommands, and hands those to ProtoGame.execute_command(). It never
## changes game state itself, so a bot (ai_champion.gd, ai_builder.gd) and a
## person go through exactly the same rules. Commands apply at the start of the
## next tick; refusals come back through ProtoGame.command_refused.
## Spawner roll picks are sent by RollMenu.
##
## It also owns the purely local feedback: the click marker.
##
## Keys:
##   right click      move, or attack the enemy under the cursor
##   left click       inspect a champion
##   ability_1..4     cast at the cursor (Q W E R)
##   ability_level_N  spend a skill point (Ctrl+Q etc.)

const CLICK_RAY_LENGTH := 1000.0
const ABILITY_ACTIONS := ["ability_1", "ability_2", "ability_3", "ability_4"]

var game: ProtoGame
## The match seat this player controls, and that seat's team.
var seat: int
var team: int
var champion: CharacterBody3D
var camera: Camera3D
var hud: ProtoHUD

var _indicator: MeshInstance3D
var _indicator_tween: Tween


func setup(p_game: ProtoGame, p_seat: int, p_champion: CharacterBody3D, p_camera: Camera3D, p_hud: ProtoHUD) -> void:
	game = p_game
	seat = p_seat
	team = p_game.seat_team(p_seat)
	champion = p_champion
	camera = p_camera
	hud = p_hud


func _ready() -> void:
	game.command_refused.connect(_on_command_refused)


func _process(_delta: float) -> void:
	_update_live_aim()


## While a charged cast (R) is being held, keep sending the cursor as its aim.
func _update_live_aim() -> void:
	if champion == null or game == null:
		return
	var caster := champion.get_node_or_null("Abilities") as AbilityCaster
	var ability := caster.get_ability(AbilityCaster.ULT_SLOT) if caster else null
	if ability == null or not ability.has_method("is_charging"):
		return
	if not bool(ability.call("is_charging")):
		return
	game.execute_command(seat, PlayerCommand.aim(AbilityCaster.ULT_SLOT, _mouse_ground_point()))


# ---- Sending commands ----

## Queues `cmd` for this player. It's applied (or refused) at the start of the next tick.
func send(cmd: Dictionary) -> void:
	game.execute_command(seat, cmd)


func _on_command_refused(p_seat: int, cmd: Dictionary, reason: String) -> void:
	if p_seat != seat:
		return
	hud.show_message(reason, Color(0.6, 0.75, 1.0))


# ---- Input ----

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_right_click(mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			# Left-click a champion to inspect it; click elsewhere to close the card.
			var clicked := _champion_under_cursor(mb.position)
			game.select_seat(game.seat_of(clicked) if clicked else -1)
		return

	for i in 4:
		# Check level-up first: Ctrl+Q also matches the plain Q action.
		if Controls.pressed(event, AbilityCaster.LEVEL_ACTIONS[i]):
			send(PlayerCommand.rank_up(i))
			get_viewport().set_input_as_handled()
			return
		if Controls.pressed(event, ABILITY_ACTIONS[i]):
			send(PlayerCommand.cast(i, _mouse_ground_point()))
			get_viewport().set_input_as_handled()
			return


## Attack the enemy under the cursor, or walk to the clicked ground.
func _right_click(screen_pos: Vector2) -> void:
	if _champion_dead():
		return
	# The marker shows right away (the order lands next tick) so clicks feel instant.
	var target := _enemy_under_cursor(screen_pos)
	if target:
		send(PlayerCommand.attack(target))
		_show_indicator(target.global_position, true)
		# Attacking a champion opens its info card too.
		if game.seat_of(target) >= 0:
			game.select_seat(game.seat_of(target))
		return
	var ground := _screen_to_ground(screen_pos)
	send(PlayerCommand.move(ground))
	_show_indicator(ground)


## Any champion (ally, enemy or you) under `screen_pos` that you can see, or null.
func _champion_under_cursor(screen_pos: Vector2) -> Node:
	var space := champion.get_world_3d().direct_space_state if champion.get_world_3d() else null
	if space == null:
		return null
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * CLICK_RAY_LENGTH)
	query.collision_mask = Entity.ENTITY_LAYER
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	var node := hit.collider as Node
	while node:
		if node is CharacterBody3D:
			return node if game.seat_of(node) >= 0 and FogOfWar.can_see(team, node) else null
		node = node.get_parent()
	return null


## The attackable unit under `screen_pos`, or null.
func _enemy_under_cursor(screen_pos: Vector2) -> Node:
	var space := champion.get_world_3d().direct_space_state if champion.get_world_3d() else null
	if space == null:
		return null
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * CLICK_RAY_LENGTH)
	query.collision_mask = Entity.ENTITY_LAYER
	query.exclude = [champion.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	# The collider may be a child of the unit: walk up to the body.
	var node := hit.collider as Node
	while node:
		if node is CharacterBody3D and node != champion:
			return node if champion.call("can_target", node) else null
		node = node.get_parent()
	return null


# ---- Helpers ----

func _champion_dead() -> bool:
	var st := EntityData.get_stats_of(champion)
	return st == null or st.is_dead


func _mouse_ground_point() -> Vector3:
	var p := _screen_to_ground(get_viewport().get_mouse_position())
	return champion.global_position if p.x > 9000.0 else p


func _screen_to_ground(screen_pos: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector3(9999.0, 0.0, 9999.0)
	var p := from + dir * (-from.y / dir.y)
	p.y = 0.0
	return p


## The click marker, like League's: a ring snaps in on the spot you clicked and
## fades away after a moment (green for a move, red for an attack target).
func _show_indicator(pos: Vector3, is_attack: bool = false) -> void:
	if not _indicator:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.42
		ring.outer_radius = 0.58
		ring.rings = 24
		ring.ring_segments = 8
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		_indicator = MeshInstance3D.new()
		_indicator.name = "ClickIndicator"
		_indicator.mesh = ring
		_indicator.material_override = mat
		_indicator.visible = false
		game.add_child(_indicator)
	var material := _indicator.material_override as StandardMaterial3D
	var color := Color(1.0, 0.35, 0.3, 0.9) if is_attack else Color(0.3, 1.0, 0.4, 0.9)
	material.albedo_color = color
	_indicator.global_position = Vector3(pos.x, 0.08, pos.z)
	_indicator.visible = true
	if _indicator_tween:
		_indicator_tween.kill()
	# Snap in from large to normal size, hold a moment, then shrink and fade out.
	_indicator.scale = Vector3(2.0, 0.2, 2.0)
	_indicator_tween = create_tween()
	_indicator_tween.tween_property(_indicator, "scale", Vector3(1.0, 0.2, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	_indicator_tween.tween_interval(0.15)
	_indicator_tween.tween_property(_indicator, "scale", Vector3(0.6, 0.2, 0.6), 0.25)
	_indicator_tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.25)
	_indicator_tween.tween_callback(func() -> void: _indicator.visible = false)
