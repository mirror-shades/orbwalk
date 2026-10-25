extends Control
## Main menu: pick a map, set up both teams' slots, then start.
## Each team holds 1 to Session.MAX_TEAM_SIZE slots. One is the player, the rest
## are bots. Picking "You" in a bot's dropdown swaps the player into that slot.

const BG := Color(0.05, 0.06, 0.09)
const PANEL_BG := Color(0.08, 0.09, 0.13, 0.95)
const PANEL_BORDER := Color(1.0, 1.0, 1.0, 0.08)
const ACCENT := Color(1.0, 0.82, 0.4)
const DIM := Color(1.0, 1.0, 1.0, 0.6)
const ALLY_COLOR := Color(0.45, 0.7, 1.0)
const ENEMY_COLOR := Color(1.0, 0.5, 0.45)

## Dropdown metadata for the "move the player here" entry.
const PLAYER_ITEM := "__player"

var _map_picker: OptionButton
var _map_id: String = Session.map_id
## Working copy of Session.teams, committed on Start.
var _teams: Array = Session.teams.duplicate(true)
var _teams_box: HBoxContainer
var _controls_overlay: ColorRect
var _controls_list: VBoxContainer
var _binding_buttons: Dictionary[String, Button] = {}
var _listening_action: String = ""
var _status_label: Label
var _status_timer: Timer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if not Controls.bindings_changed.is_connected(_refresh_bindings):
		Controls.bindings_changed.connect(_refresh_bindings)
	# Dev/CI shortcuts: start with the default selection, or go straight to the
	# prototype when it was launched with its own command-line options.
	var args := OS.get_cmdline_user_args()
	if "--quick-start" in args:
		_start.call_deferred()
	elif "--spectate" in args or _has_arg(args, "--champ=") or _has_arg(args, "--enemy="):
		get_tree().call_deferred("change_scene_to_file", "res://scenes/proto_1v1.tscn")


func _has_arg(args: PackedStringArray, prefix: String) -> bool:
	for arg in args:
		if arg.begins_with(prefix):
			return true
	return false


func _input(event: InputEvent) -> void:
	if _controls_overlay == null or not _controls_overlay.visible:
		return
	if _listening_action != "":
		# Any click cancels, so every key (Escape included) can be bound.
		# The wheel is left alone so the list can still scroll.
		var mouse := event as InputEventMouseButton
		if mouse and mouse.pressed and mouse.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_stop_listening()
			get_viewport().set_input_as_handled()
			return
		var key := event as InputEventKey
		if key:
			if key.pressed and not key.echo and not _is_modifier_key(key):
				var action := _listening_action
				_stop_listening()
				_show_moves(action, Controls.rebind(action, key))
			get_viewport().set_input_as_handled()
		return
	# Escape always closes the panel, even if the menu action was rebound.
	if Controls.pressed(event, "ui_menu") \
			or (event is InputEventKey and (event as InputEventKey).pressed and _event_keycode(event) == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_close_controls()


func _unhandled_input(event: InputEvent) -> void:
	if _controls_overlay != null and _controls_overlay.visible:
		return
	if Controls.pressed(event, "ui_confirm"):
		get_viewport().set_input_as_handled()
		_start()


func _event_keycode(event: InputEvent) -> int:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.physical_keycode if key.physical_keycode != 0 else key.keycode
	return 0


func _is_modifier_key(key: InputEventKey) -> bool:
	var code := _event_keycode(key)
	return code == KEY_CTRL or code == KEY_SHIFT or code == KEY_ALT or code == KEY_META


func _build() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	margin.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := _label("orbwalk", 56, ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	box.add_child(title)
	var subtitle := _label("League of Legends + Auto Chess", 16, DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	box.add_child(subtitle)

	box.add_child(_map_row())
	_teams_box = HBoxContainer.new()
	_teams_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_teams_box.add_theme_constant_override("separation", 20)
	box.add_child(_teams_box)
	_rebuild_teams()

	var start := Button.new()
	start.text = "Start"
	start.focus_mode = Control.FOCUS_NONE
	start.custom_minimum_size = Vector2(240.0, 56.0)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.add_theme_font_size_override("font_size", 24)
	var normal := _button_style(Color(0.2, 0.4, 0.22, 0.95), Color(0.6, 0.95, 0.6))
	var hover := _button_style(Color(0.26, 0.5, 0.28, 0.95), Color(0.7, 1.0, 0.7))
	start.add_theme_stylebox_override("normal", normal)
	start.add_theme_stylebox_override("hover", hover)
	start.add_theme_stylebox_override("pressed", hover)
	start.pressed.connect(_start)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	actions.add_child(start)
	var controls := _action_button("Controls", 160.0, 56.0)
	controls.add_theme_font_size_override("font_size", 20)
	controls.tooltip_text = "Rebind keyboard controls"
	controls.pressed.connect(_open_controls)
	actions.add_child(controls)
	box.add_child(actions)

	_build_controls_overlay()


func _map_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var title := _label("Map", 18, DIM)
	title.add_theme_font_size_override("font_size", 18)
	row.add_child(title)
	_map_picker = OptionButton.new()
	_map_picker.focus_mode = Control.FOCUS_NONE
	_map_picker.custom_minimum_size = Vector2(220.0, 40.0)
	_map_picker.add_theme_font_size_override("font_size", 17)
	for m in Session.MAPS:
		_map_picker.add_item(str(m["name"]))
		_map_picker.set_item_metadata(_map_picker.item_count - 1, str(m["id"]))
	_select_metadata(_map_picker, _map_id, 0)
	_map_picker.item_selected.connect(func(index: int) -> void:
		_map_id = str(_map_picker.get_item_metadata(index)))
	row.add_child(_map_picker)
	return row


func _rebuild_teams() -> void:
	# Called deferred from slot buttons, so it never frees the button whose
	# signal is still running. Removing first stops a one-frame double layout.
	for child in _teams_box.get_children():
		_teams_box.remove_child(child)
		child.queue_free()
	for side in _teams.size():
		_teams_box.add_child(_team_panel(side))


func _team_panel(side: int) -> PanelContainer:
	var color := ALLY_COLOR if side == 0 else ENEMY_COLOR
	var slots: Array = _teams[side]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380.0, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var head := HBoxContainer.new()
	var header := _label(Session.TEAM_NAMES[side], 22, color)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(header)
	var count := _label("%d / %d" % [slots.size(), Session.MAX_TEAM_SIZE], 14, DIM)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(count)
	column.add_child(head)

	for i in slots.size():
		column.add_child(_slot_row(side, i, color))

	# Push the add button to the bottom so both columns line up when lopsided.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var add := _action_button("+ Add bot", 0.0, 36.0)
	add.disabled = slots.size() >= Session.MAX_TEAM_SIZE
	add.tooltip_text = "Team is full" if add.disabled else "Add a random bot to this team"
	add.pressed.connect(_add_slot.bind(side))
	column.add_child(add)
	return panel


func _slot_row(side: int, index: int, color: Color) -> PanelContainer:
	var slot: Dictionary = _teams[side][index]
	var is_player: bool = slot["kind"] == "player"
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(0.0, 56.0)
	box.add_theme_stylebox_override("panel",
		_panel_style(Color(0.11, 0.12, 0.16, 0.95), color if is_player else PANEL_BORDER))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	var number := _label(str(index + 1), 20, DIM)
	number.custom_minimum_size = Vector2(22.0, 0.0)
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(number)

	if is_player:
		var name := _label("You", 20, Color.WHITE)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name)
		return box

	var picker := OptionButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0.0, 36.0)
	picker.add_theme_font_size_override("font_size", 16)
	picker.add_item("You (move here)")
	picker.set_item_metadata(0, PLAYER_ITEM)
	picker.add_item("Bot - Random")
	picker.set_item_metadata(1, "random")
	# A champion can only be on a team once, so ones teammates already have are greyed out.
	var taken := _team_champions(side, index)
	for id in ProtoConfig.CHAMPION_ORDER:
		picker.add_item("Bot - %s" % ProtoConfig.champion_name(id))
		picker.set_item_metadata(picker.item_count - 1, id)
		picker.set_item_disabled(picker.item_count - 1, taken.has(id))
	_select_metadata(picker, str(slot["champion"]), 1)
	picker.item_selected.connect(_on_slot_picked.bind(side, index, picker))
	row.add_child(picker)

	var remove := _action_button("X", 36.0, 36.0)
	remove.disabled = _teams[side].size() <= 1
	remove.tooltip_text = "A team needs at least one slot" if remove.disabled else "Remove this bot"
	remove.pressed.connect(_remove_slot.bind(side, index))
	row.add_child(remove)
	return box


func _on_slot_picked(item: int, side: int, index: int, picker: OptionButton) -> void:
	var id := str(picker.get_item_metadata(item))
	if id == PLAYER_ITEM:
		_move_player_to(side, index)
	else:
		_teams[side][index]["champion"] = id
		# Teammates' dropdowns grey out the new pick (and free the old one).
		_rebuild_teams.call_deferred()


## Champions picked by the other bots on `side` (not "random"), skipping `skip_index`.
## The player's champion isn't known until champion select; the match re-rolls a
## bot that ends up sharing it, or that moved to a team that already has its pick.
func _team_champions(side: int, skip_index: int) -> Dictionary:
	var out := {}
	var slots: Array = _teams[side]
	for i in slots.size():
		if i != skip_index and str(slots[i]["kind"]) == "bot" and str(slots[i]["champion"]) != "random":
			out[str(slots[i]["champion"])] = true
	return out


## The player takes this slot, and the bot that was in it takes the player's
## old slot (keeping its champion pick). Works within a team or across teams.
func _move_player_to(side: int, index: int) -> void:
	for s in _teams.size():
		var slots: Array = _teams[s]
		for i in slots.size():
			if slots[i]["kind"] == "player":
				slots[i] = _teams[side][index]
				_teams[side][index] = {"kind": "player"}
				_rebuild_teams.call_deferred()
				return


func _add_slot(side: int) -> void:
	if _teams[side].size() >= Session.MAX_TEAM_SIZE:
		return
	_teams[side].append({"kind": "bot", "champion": "random"})
	_rebuild_teams.call_deferred()


func _remove_slot(side: int, index: int) -> void:
	var slots: Array = _teams[side]
	if slots.size() <= 1 or slots[index]["kind"] == "player":
		return
	slots.remove_at(index)
	_rebuild_teams.call_deferred()


func _start() -> void:
	get_tree().paused = false
	Session.configure(_map_id, _teams)
	get_tree().change_scene_to_file(Session.map_scene())


func _build_controls_overlay() -> void:
	_controls_overlay = ColorRect.new()
	_controls_overlay.color = Color(0.02, 0.025, 0.04, 0.96)
	_controls_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_controls_overlay.visible = false
	add_child(_controls_overlay)
	_controls_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760.0, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := _label("Controls", 32, ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var help := _label("Click a binding, then press the new key. Click anywhere to cancel.", 14, DIM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(help)
	# Says which action gave up its key after a swap. Keeps its height when
	# empty so the list doesn't jump.
	_status_label = _label("", 15, ACCENT)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0.0, 22.0)
	column.add_child(_status_label)
	_status_timer = Timer.new()
	_status_timer.one_shot = true
	_status_timer.wait_time = 5.0
	_status_timer.timeout.connect(func() -> void: _status_label.text = "")
	add_child(_status_timer)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720.0, 400.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_controls_list = VBoxContainer.new()
	_controls_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_controls_list)
	_rebuild_controls_rows()

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var reset := _action_button("Reset defaults")
	reset.pressed.connect(_reset_controls)
	buttons.add_child(reset)
	var back := _action_button("Back")
	back.pressed.connect(_close_controls)
	buttons.add_child(back)
	column.add_child(buttons)


func _rebuild_controls_rows() -> void:
	_binding_buttons.clear()
	for child in _controls_list.get_children():
		child.queue_free()
	for group in Controls.GROUPS:
		var header := _label(group, 21, ACCENT)
		_controls_list.add_child(header)
		for action in Controls.actions_in_group(group):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var name := _label(Controls.action_label(action), 16, Color.WHITE)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name)
			var button := _action_button("", 200.0, 34.0)
			button.pressed.connect(_listen_for.bind(action))
			_binding_buttons[action] = button
			row.add_child(button)
			_controls_list.add_child(row)
	_refresh_bindings()


func _open_controls() -> void:
	_listening_action = ""
	_controls_overlay.visible = true
	_refresh_bindings()


func _close_controls() -> void:
	_listening_action = ""
	_set_status("")
	_controls_overlay.visible = false


func _listen_for(action: String) -> void:
	_listening_action = action
	_refresh_bindings()


func _stop_listening() -> void:
	_listening_action = ""
	_refresh_bindings()


func _reset_controls() -> void:
	_listening_action = ""
	Controls.reset_defaults()
	_set_status("")
	_refresh_bindings()


## e.g. "W moved to Ability 1. Ability 2 is now Q."
func _show_moves(action: String, result: Dictionary) -> void:
	var moved: Array = result.get("moved", [])
	if moved.is_empty():
		_set_status("")
		return
	var parts: PackedStringArray = []
	for m in moved:
		parts.append("%s is now %s" % [Controls.action_label(str(m["action"])), str(m["now"])])
	_set_status("%s moved to %s. %s." % [Controls.binding_text(action), Controls.action_label(action), "; ".join(parts)])


func _set_status(text: String) -> void:
	_status_label.text = text
	if text == "":
		_status_timer.stop()
	else:
		_status_timer.start()


func _refresh_bindings() -> void:
	for action in _binding_buttons:
		var button: Button = _binding_buttons[action]
		button.text = "Press a key..." if action == _listening_action else Controls.binding_text(action)


func _select_metadata(option: OptionButton, value: String, fallback: int) -> void:
	for i in option.item_count:
		if str(option.get_item_metadata(i)) == value:
			option.select(i)
			return
	option.select(fallback)


func _action_button(text: String, min_width: float = 160.0, height: float = 40.0) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(min_width, height)
	button.add_theme_font_size_override("font_size", 17)
	var normal := _button_style(Color(0.12, 0.13, 0.17, 0.95), Color(0.3, 0.3, 0.35))
	var hover := _button_style(Color(0.18, 0.2, 0.26, 0.95), ACCENT)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.09, 0.1, 0.13, 0.8), Color(0.2, 0.2, 0.24)))
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.3))
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	return label


func _panel_style(bg: Color, border: Color = PANEL_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
