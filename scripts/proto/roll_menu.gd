class_name RollMenu
extends Control
## Spawner roll menu, like augments in League's Mayhem mode. Rolls bank up as a
## counter above the gold; opening one shows its cards over the game, which keeps
## running. Pick one card, or hide the menu and come back to the same cards later.

const ACCENT := ProtoHUD.ACCENT
const CARD_SIZE := Vector2(230.0, 210.0)

var _game: ProtoGame
var _seat: int = -1
var _rolls: SpawnerRolls
var _button: Button
var _panel: Control
var _cards_row: HBoxContainer
var _board_label: RichTextLabel


func setup(game: ProtoGame, seat: int) -> void:
	_game = game
	_seat = seat
	_rolls = game.spawner_rolls[seat]
	_rolls.changed.connect(_refresh)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Counter button, just above the gold total.
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(150.0, 34.0)
	_button.add_theme_font_size_override("font_size", 16)
	_style(_button, Color(0.2, 0.16, 0.06, 0.92), ACCENT, 2)
	add_child(_button)
	_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_button.offset_right = -ProtoMinimap.MARGIN
	_button.offset_bottom = -(ProtoMinimap.MARGIN + ProtoMinimap.SIDE + 48.0)
	_button.pressed.connect(toggle)

	# Card panel: upper middle of the screen, no backdrop so the fight stays visible.
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.offset_top = 110.0
	_panel = center
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)
	var title := Label.new()
	title.text = "Choose one"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	col.add_child(title)
	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", 12)
	col.add_child(_cards_row)
	_board_label = RichTextLabel.new()
	_board_label.bbcode_enabled = true
	_board_label.fit_content = true
	_board_label.scroll_active = false
	_board_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_label.custom_minimum_size = Vector2(CARD_SIZE.x * 3.0 + 24.0, 0.0)
	_board_label.add_theme_font_size_override("normal_font_size", 14)
	_board_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_board_label.add_theme_constant_override("outline_size", 4)
	col.add_child(_board_label)
	var hide_button := Button.new()
	hide_button.text = "Hide  (%s)" % Controls.binding_text("open_roll")
	hide_button.focus_mode = Control.FOCUS_NONE
	hide_button.custom_minimum_size = Vector2(160.0, 34.0)
	hide_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style(hide_button, Color(0.1, 0.11, 0.15, 0.92), Color(1.0, 1.0, 1.0, 0.15), 1)
	hide_button.pressed.connect(close)
	col.add_child(hide_button)
	_panel.visible = false
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if Controls.pressed(event, "open_roll"):
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	if _panel.visible:
		close()
	else:
		open()


func open() -> void:
	if _rolls == null or (_rolls.banked <= 0 and not _rolls.has_open_roll()):
		return
	if _rolls.open_roll().is_empty():
		return
	_panel.visible = true
	_refresh()


func close() -> void:
	_panel.visible = false
	_refresh()


func _refresh() -> void:
	if _button == null or _rolls == null:
		return
	_button.visible = _rolls.banked > 0
	_button.text = "Rolls: %d  (%s)" % [_rolls.banked, Controls.binding_text("open_roll")]
	if _panel.visible and not _rolls.has_open_roll():
		_panel.visible = false
	if not _panel.visible:
		return
	for c in _cards_row.get_children():
		c.queue_free()
	for i in _rolls.offer.size():
		_cards_row.add_child(_card(i, _rolls.offer[i]))
	_board_label.text = _board_text()


func _card(index: int, card: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD_SIZE
	var is_spawner: bool = card["kind"] == "spawner"
	var edge := Color(0.55, 0.85, 1.0) if is_spawner else ACCENT
	_style(b, Color(0.08, 0.09, 0.13, 0.96), Color(edge, 0.55), 2)
	var hover := (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.13, 0.14, 0.2, 0.98)
	hover.border_color = edge
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)

	var sp: Dictionary = SpawnerPool.SPAWNERS[card["spawner"]]
	var kind_text: String
	var title: String
	var body: String
	if is_spawner:
		kind_text = "NEW SPAWNER  -  slot %d / %d" % [_rolls.slots.size() + 1, SpawnerPool.SLOTS]
		title = "%s\n[font_size=14][color=#c8ccd4]%s[/color][/font_size]" % [sp["name"], sp["unit"]]
		body = sp["ability"]
	else:
		var info := SpawnerPool.upgrade_info(card["spawner"], card["upgrade"])
		kind_text = "UPGRADE  -  %s" % sp["name"]
		title = info[0]
		body = info[1]

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("normal_font_size", 15)
	text.add_theme_font_size_override("bold_font_size", 20)
	text.text = "[font_size=12][color=#%s]%s[/color][/font_size]\n[b]%s[/b]\n\n%s" % [
		edge.to_html(false), kind_text, title, body]
	b.add_child(text)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 14.0
	text.offset_top = 12.0
	text.offset_right = -14.0
	text.offset_bottom = -12.0
	b.pressed.connect(func() -> void:
		# Applied on the next tick, like every other player command.
		_game.execute_command(_seat, PlayerCommand.pick_roll(index))
		close())
	return b


## One line per slot: "Wharf: Double Rope, Crew" (empty slots shown too).
func _board_text() -> String:
	var parts: PackedStringArray = []
	for s in _rolls.slots:
		var sp: Dictionary = SpawnerPool.SPAWNERS[s["id"]]
		var ups: PackedStringArray = []
		for u in s["upgrades"]:
			ups.append(SpawnerPool.upgrade_info(s["id"], u)[0])
		var line := "[b]%s[/b]" % sp["name"]
		line += " [color=#9aa0aa](%d/%d)[/color]" % [ups.size(), SpawnerPool.MAX_UPGRADES]
		if not ups.is_empty():
			line += " " + ", ".join(ups)
		parts.append(line)
	for i in SpawnerPool.SLOTS - _rolls.slots.size():
		parts.append("[color=#6c717a]empty slot[/color]")
	return "[center]%s[/center]" % "   |   ".join(parts)


func _style(b: Button, bg: Color, border: Color, width: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(10)
	s.content_margin_left = 10.0
	s.content_margin_right = 10.0
	b.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = bg.lightened(0.12)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
