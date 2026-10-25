class_name ProtoHUD
extends CanvasLayer
## On-screen UI for the prototype, built in code so it's easy to change.

signal champions_chosen(player_id: String, enemy_id: String, loadout: Dictionary)


## Shared look.
const PANEL_BG := Color(0.06, 0.07, 0.1, 0.82)
const PANEL_BORDER := Color(1.0, 1.0, 1.0, 0.08)
const ACCENT := Color(1.0, 0.82, 0.4)
const ALLY_COLOR := Color(0.45, 0.7, 1.0)
const ENEMY_COLOR := Color(1.0, 0.5, 0.45)
const DIM := Color(1.0, 1.0, 1.0, 0.6)

## Help page sections: [title, [[key(s), what it does], ...]]. A key entry can be
## a literal string (mouse controls) or an array of Controls action names.
const HELP_SECTIONS := [
	["Moving and fighting", [
		["Mouse right-click", "Move, or attack what you click"],
		[["ability_1", "ability_2", "ability_3", "ability_4"], "Cast abilities at the cursor"],
		[["ability_level_1", "ability_level_2", "ability_level_3", "ability_level_4"], "Spend a skill point. Slots 1-3 go to rank 5; slot 4 unlocks at 6 / 11 / 16"],
	]],
	["Spawners", [
		["Slots", "You have 5 spawner slots. Your champion's spawner starts in the first"],
		["Rolls", "Every level-up banks a roll: 3 random cards, each a new spawner (while a slot is open) or an upgrade (up to 3 per spawner)"],
		[["open_roll"], "Open a banked roll (or click the Rolls button). The game keeps running; hiding it keeps the same cards"],
	]],
	["Camera", [
		[["Mouse screen edge", "camera_left", "camera_right", "camera_up", "camera_down"], "Move the camera"],
		["Mouse wheel", "Zoom"],
		[["camera_lock"], "Lock the camera to your champion"],
		[["camera_center"], "Center on your champion (hold)"],
	]],
	["Screens", [
		[["ui_info"], "Match info: teams, jungle timers, your stats and build"],
		[["ui_menu"], "This menu"],
		[["toggle_mouse"], "Lock / unlock the mouse to the window"],
		[["change_champion"], "Change champion and equipment (restarts)"],
	]],
	["How a match works", [
		["Waves", "Every 30 seconds each spawner sends its minions down the lane"],
		["Jungle", "North Yeti: attack speed + health regen. South Mushroom King: mana regen + cooldowns"],
		["Fog of war", "You only see near your champion, minions, towers and orb. Enemy towers are always visible"],
		["Win", "Destroy the enemy orb. It shoots any champion in range first and kills them in about 3 shots, so it's your wave that has to break it"],
	]],
]

signal restart_requested()
signal change_champion_requested()
signal main_menu_requested()

var _phase_label: Label
var _sub_label: Label
var _gold_label: Label
## Top-right scoreboard: team kills, your K/D/A, your minion score, match clock.
var _scoreboard: Control
var _score_label: RichTextLabel
var _kda_label: Label
var _cs_label: Label
var _clock_label: Label
var _perf_label: Label
var _buff_label: Label
var _message_label: Label
var _death_overlay: ColorRect
var _death_label: Label
var _over: ColorRect
var _over_label: Label
var _message_tween: Tween
var _slots: Array[Dictionary] = []
var _passive_slot: Dictionary = {}
var _select: Control
var _pick_player: String = ""
var _pick_enemy: String = ""
## Equipment picked on the champion select screen: slot -> item id.
var _pick_loadout: Dictionary = {}
## slot -> {"option": OptionButton, "desc": Label}
var _slot_pickers: Dictionary = {}
## Champion select preview: the 3D model and the stats / abilities column.
var _preview: ChampionPreview
var _detail_box: VBoxContainer
var _ability_box: VBoxContainer
var _detail_shown: String = ""
var _hp_bar: ProgressBar
var _hp_text: Label
var _mana_bar: ProgressBar
var _mana_text: Label
var _xp_bar: ProgressBar
var _portrait: Portrait
var _hp_regen: Label
var _mana_regen: Label
var _status_row: HBoxContainer
var _status_icons: Array[Dictionary] = []
var _menu: Control
var _menu_main: Control
var _menu_help: Control
var _info: Control
## Tab screen sections: id -> RichTextLabel.
var _info_text: Dictionary[String, RichTextLabel] = {}


## Center-screen messages ("The world wakes!", "Not enough mana"...). Off to keep
## the screen clean; set true to bring them back.
const SHOW_MESSAGES := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Grey wash while the player is dead. Added first so the HUD stays readable.
	_death_overlay = ColorRect.new()
	_death_overlay.color = Color(0.34, 0.35, 0.38, 0.68)
	_death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_overlay.visible = false
	root.add_child(_death_overlay)
	_death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_label = _make_label(_death_overlay, 46, HORIZONTAL_ALIGNMENT_CENTER)
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# ---- Bottom right: just the gold total, above the minimap ----
	var gold_panel := _panel(root, Vector2(10.0, 3.0), 0.82)
	gold_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	gold_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gold_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	gold_panel.offset_right = -ProtoMinimap.MARGIN
	gold_panel.offset_bottom = -(ProtoMinimap.MARGIN + ProtoMinimap.SIDE + 6.0)
	var gold_row := HBoxContainer.new()
	gold_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_row.add_theme_constant_override("separation", 6)
	gold_panel.add_child(gold_row)
	var coin := StatIcon.new()
	coin.kind = StatIcon.GOLD
	coin.color = ACCENT
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_row.add_child(coin)
	_gold_label = _make_label(gold_row, 19, HORIZONTAL_ALIGNMENT_LEFT)
	_gold_label.add_theme_color_override("font_color", ACCENT)

	var top_center := VBoxContainer.new()
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center.add_theme_constant_override("separation", 4)
	root.add_child(top_center)
	top_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_center.offset_top = 12.0
	var phase_panel := _panel(top_center, Vector2(18.0, 6.0))
	phase_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_phase_label = _make_label(phase_panel, 19, HORIZONTAL_ALIGNMENT_CENTER)
	_sub_label = _make_label(top_center, 14, HORIZONTAL_ALIGNMENT_CENTER)
	_sub_label.modulate = Color(1.0, 1.0, 1.0, 0.8)
	_message_label = _make_label(top_center, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_message_label.modulate.a = 0.0

	_build_scoreboard(root)

	# ---- Bottom: hints, ability bar, build buttons ----
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 6)
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -3.0

	_buff_label = _make_label(bottom, 14, HORIZONTAL_ALIGNMENT_CENTER)
	_buff_label.add_theme_color_override("font_color", ACCENT)
	_buff_label.visible = false

	_status_row = HBoxContainer.new()
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_row.add_theme_constant_override("separation", 4)
	_status_row.visible = false
	bottom.add_child(_status_row)

	_build_ability_bar(bottom)

	_over = ColorRect.new()
	_over.color = Color(0.0, 0.0, 0.0, 0.55)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.visible = false
	root.add_child(_over)
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over_label = _make_label(_over, 56, HORIZONTAL_ALIGNMENT_CENTER)
	_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_over_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_info(root)
	_build_menu(root)


## A rounded dark box that sizes to its content.
func _panel(parent: Control, padding: Vector2 = Vector2(14.0, 6.0), bg_alpha: float = PANEL_BG.a) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_BG, bg_alpha)
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p


## A BBCode label that sizes to its text.
func _rich(parent: Control, font_px: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", font_px)
	r.add_theme_font_size_override("bold_font_size", font_px)
	parent.add_child(r)
	return r


func _make_button(parent: Control, text: String, min_size: Vector2, font_px: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_px)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.12, 0.16, 0.92)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.1)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.17, 0.18, 0.23, 0.95)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.22, 0.19, 0.1, 0.95)
	pressed.border_color = ACCENT
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	parent.add_child(b)
	return b


# ---- Tab screen ----

func _build_info(root: Control) -> void:
	_info = ColorRect.new()
	(_info as ColorRect).color = Color(0.0, 0.0, 0.0, 0.6)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	root.add_child(_info)
	_info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	center.add_child(grid)
	for id in ["teams", "jungle", "stats", "build"]:
		var p := _panel(grid, Vector2(18.0, 14.0), 0.96)
		p.custom_minimum_size = Vector2(380.0, 0.0)
		_info_text[id] = _rich(p, 15)


func is_info_open() -> bool:
	return _info.visible


## Fills the Tab screen. Keys: "teams", "jungle", "stats", "build" -> BBCode text.
func set_info(sections: Dictionary) -> void:
	for id in sections:
		if _info_text.has(id):
			_info_text[id].text = sections[id]


# ---- Esc menu ----

func _build_menu(root: Control) -> void:
	_menu = ColorRect.new()
	(_menu as ColorRect).color = Color(0.02, 0.03, 0.05, 0.75)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.visible = false
	root.add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Main page.
	var main_panel := _panel(center, Vector2(28.0, 22.0), 0.96)
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_main = main_panel
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	main_panel.add_child(col)
	var title := _make_label(col, 30, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "Paused"
	title.add_theme_color_override("font_color", ACCENT)
	for entry in [["Resume", close_menu], ["Help", _show_help], ["Change champion", func() -> void: change_champion_requested.emit()], ["Restart match", func() -> void: restart_requested.emit()], ["Main menu", func() -> void: main_menu_requested.emit()], ["Quit", func() -> void: get_tree().quit()]]:
		var b := _make_button(col, entry[0], Vector2(260.0, 44.0))
		b.pressed.connect(entry[1])

	# Help page.
	var help_panel := _panel(center, Vector2(28.0, 22.0), 0.96)
	help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	help_panel.visible = false
	_menu_help = help_panel
	var help_col := VBoxContainer.new()
	help_col.add_theme_constant_override("separation", 12)
	help_panel.add_child(help_col)
	var help_title := _make_label(help_col, 30, HORIZONTAL_ALIGNMENT_CENTER)
	help_title.text = "How to play"
	help_title.add_theme_color_override("font_color", ACCENT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(720.0, 420.0)
	help_col.add_child(scroll)
	var body := _rich(scroll, 16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = _help_bbcode()
	var back := _make_button(help_col, "Back", Vector2(200.0, 40.0))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_show_main_menu)


func _help_bbcode() -> String:
	# One table for every section, so the key column lines up all the way down.
	var out := "[table=2]"
	var accent := ACCENT.to_html(false)
	var top := 0
	for section in HELP_SECTIONS:
		out += "[cell padding=0,%d,0,4][font_size=19][color=#%s]%s[/color][/font_size][/cell][cell][/cell]" % [top, accent, section[0]]
		top = 18
		for row in section[1]:
			out += "[cell padding=0,3,28,3][b]%s[/b][/cell][cell padding=0,3,0,3][color=#c8ccd4]%s[/color][/cell]" % [_help_key_text(row[0]), row[1]]
	return out + "[/table]"


func _help_key_text(key) -> String:
	if key is Array:
		var parts: PackedStringArray = []
		for item in key:
			var action := str(item)
			parts.append(Controls.binding_text(action) if Controls.has_action(action) else action)
		return "  ".join(parts)
	return str(key)


func is_menu_open() -> bool:
	return _menu.visible


func open_menu() -> void:
	_menu.visible = true
	_info.visible = false
	_show_main_menu()
	get_tree().paused = true


func close_menu() -> void:
	_menu.visible = false
	get_tree().paused = false


func _show_help() -> void:
	_menu_main.visible = false
	_menu_help.visible = true


func _show_main_menu() -> void:
	_menu_main.visible = true
	_menu_help.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if _select != null and is_instance_valid(_select) and _select.visible:
		return
	# Hold the info action for the info screen (not while paused).
	if event.is_action("ui_info"):
		_info.visible = Controls.pressed(event, "ui_info") and not _menu.visible and not _over.visible
		get_viewport().set_input_as_handled()
		return
	if Controls.pressed(event, "ui_menu") and _menu.visible:
		if _menu_help.visible:
			_show_main_menu()
		else:
			close_menu()
		get_viewport().set_input_as_handled()


func _make_label(parent: Control, font_px: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	parent.add_child(l)
	return l


## Bottom-center bar: portrait + level, then (passive, Q, W, E, R) with rank pips
## under each, then health and mana bars with values on the left and regen on
## the right. Every icon spot has a hover tooltip and a setter for its image.
func _build_ability_bar(parent: Control) -> void:
	var bar_panel := _panel(parent, Vector2(4.0, 0.0))
	bar_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# No backdrop: the bar floats over the game.
	var clear := StyleBoxEmpty.new()
	clear.content_margin_left = 4.0
	clear.content_margin_right = 4.0
	bar_panel.add_theme_stylebox_override("panel", clear)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	bar_panel.add_child(row)

	# Portrait with the level badge, and a thin XP bar under it.
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 2)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)
	_portrait = Portrait.new()
	left.add_child(_portrait)
	var xp := _make_bar(left, Color(0.75, 0.55, 1.0), 6.0)
	_xp_bar = xp[0]
	(xp[1] as Label).visible = false

	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 0)
	right.custom_minimum_size = Vector2(400.0, 0.0)
	row.add_child(right)

	var slots_row := HBoxContainer.new()
	slots_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.add_theme_constant_override("separation", 10)
	right.add_child(slots_row)
	_passive_slot = _make_slot(slots_row, "P", 36.0)
	(_passive_slot["style"] as StyleBoxFlat).border_color = Color(0.45, 0.85, 0.5)
	for i in 4:
		_slots.append(_make_slot(slots_row, Controls.binding_text("ability_%d" % (i + 1)), 50.0))
	set_passive("")

	var hp := _bar_row(right, Color(0.25, 0.75, 0.3), 6.0)
	_hp_bar = hp[0]
	_hp_text = hp[1]
	_hp_regen = hp[2]
	var mana := _bar_row(right, Color(0.25, 0.5, 0.95), 6.0)
	_mana_bar = mana[0]
	_mana_text = mana[1]
	_mana_regen = mana[2]
	_hp_text.tooltip_text = "Health"
	_mana_text.tooltip_text = "Mana"


## "688/848  [=====bar=====]  +2.1": value on the left, regen on the right.
func _bar_row(parent: Control, color: Color, height: float) -> Array:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var text := _make_label(row, 11, HORIZONTAL_ALIGNMENT_RIGHT)
	text.custom_minimum_size = Vector2(66.0, 0.0)
	text.mouse_filter = Control.MOUSE_FILTER_STOP
	var made := _make_bar(row, color, height)
	var bar := made[0] as ProgressBar
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var regen := _make_label(row, 10, HORIZONTAL_ALIGNMENT_LEFT)
	regen.custom_minimum_size = Vector2(40.0, 0.0)
	regen.modulate = Color(1.0, 1.0, 1.0, 0.8)
	return [bar, text, regen]


func _make_bar(parent: Control, color: Color, height: float) -> Array:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	var text := _make_label(bar, 12, HORIZONTAL_ALIGNMENT_CENTER)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.visible = false  # "680 / 680": the bar already shows it
	return [bar, text]


## One icon spot: a square with the key letter, cost, cooldown shade and a "+"
## when a point can be spent, plus (for the bigger ones) rank pips under it.
## `size` is the square's side. The spot's hover tooltip is set by set_ability().
func _make_slot(parent: Control, key: String, size: float) -> Dictionary:
	var wrapper := VBoxContainer.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_theme_constant_override("separation", 2)
	parent.add_child(wrapper)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(size, size)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # needed for the hover tooltip
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.15, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	wrapper.add_child(panel)

	# The ability's picture goes here (see set_ability_icon).
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panel.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 2.0
	icon.offset_top = 2.0
	icon.offset_right = -2.0
	icon.offset_bottom = -2.0

	var name_label := _make_label(panel, 12, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.visible = false  # the key letter identifies the slot

	var key_label := _make_label(panel, 14 if size >= 50.0 else 11, HORIZONTAL_ALIGNMENT_LEFT)
	key_label.position = Vector2(5.0, 0.0)
	key_label.text = key
	if key.length() > 2:
		key_label.add_theme_font_size_override("font_size", 11)

	var cost_label := _make_label(panel, 12, HORIZONTAL_ALIGNMENT_RIGHT)
	cost_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	cost_label.offset_right = -4.0
	cost_label.offset_bottom = -1.0
	cost_label.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))

	# Dark cover that shrinks as the cooldown runs out.
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false

	var cd_label := _make_label(panel, 21, HORIZONTAL_ALIGNMENT_CENTER)
	cd_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Rank pips under the square (filled = learned ranks). The passive has none.
	var pips: Array[ColorRect] = []
	if size >= 50.0:
		var pips_row := HBoxContainer.new()
		pips_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips_row.alignment = BoxContainer.ALIGNMENT_CENTER
		pips_row.add_theme_constant_override("separation", 3)
		wrapper.add_child(pips_row)
		for i in 5:
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(6.0, 3.0)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips_row.add_child(pip)
			pips.append(pip)

	# Shown when a skill point can go into this ability (Ctrl + key).
	var plus_label := _make_label(panel, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	plus_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	plus_label.offset_left = -24.0
	plus_label.offset_right = -4.0
	plus_label.offset_top = -4.0
	plus_label.text = "+"
	plus_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.5))
	plus_label.visible = false
	return {"panel": panel, "style": style, "name": name_label, "cost": cost_label, "shade": shade, "cd": cd_label, "pips": pips, "plus": plus_label, "icon": icon, "key": key}


## Updates one Q/W/E/R slot. An empty `ability_name` means nothing is in that slot yet.
## `rank` 0 = not learned. `can_level` shows a "+" (a skill point can go in).
func set_ability(slot: int, ability_name: String, cd_left: float, cd_total: float, cost: float, has_mana: bool, active: bool, rank: int, max_rank: int, can_level: bool, description: String = "") -> void:
	var d: Dictionary = _slots[slot]
	var panel := d["panel"] as Panel
	_set_slot_tooltip(d, slot, ability_name, cd_total, cost, rank, max_rank, can_level, description)
	var style := d["style"] as StyleBoxFlat
	var shade := d["shade"] as ColorRect
	var cd_label := d["cd"] as Label
	(d["name"] as Label).text = ability_name if ability_name != "" else "-"
	(d["cost"] as Label).text = str(roundi(cost)) if ability_name != "" and rank > 0 and cost > 0.0 else ""
	(d["plus"] as Label).visible = can_level
	var pips: Array[ColorRect] = d["pips"]
	for i in pips.size():
		pips[i].visible = ability_name != "" and i < max_rank
		pips[i].color = Color(0.95, 0.8, 0.35) if i < rank else Color(0.25, 0.25, 0.3)
	if ability_name == "":
		panel.modulate = Color(1.0, 1.0, 1.0, 0.4)
		style.border_color = Color(0.3, 0.3, 0.35)
		shade.visible = false
		cd_label.text = ""
		return
	if rank <= 0:
		panel.modulate = Color(1.0, 1.0, 1.0, 0.75)
		style.border_color = Color(0.45, 1.0, 0.5) if can_level else Color(0.3, 0.3, 0.35)
		shade.visible = true
		shade.anchor_top = 0.0
		cd_label.text = ""
		return
	panel.modulate = Color.WHITE if has_mana else Color(0.6, 0.7, 1.0)
	if can_level:
		style.border_color = Color(0.45, 1.0, 0.5)
	elif active:
		style.border_color = Color(1.0, 0.55, 0.15)
	elif cd_left > 0.0:
		style.border_color = Color(0.35, 0.35, 0.4)
	else:
		style.border_color = Color(0.9, 0.75, 0.35)
	shade.visible = cd_left > 0.0
	if cd_left > 0.0:
		shade.anchor_top = 1.0 - clampf(cd_left / maxf(cd_total, 0.01), 0.0, 1.0)
		cd_label.text = str(ceili(cd_left))
	else:
		cd_label.text = ""


## Hover text for a Q/W/E/R spot: name and key, rank, cost, cooldown, description.
func _set_slot_tooltip(d: Dictionary, slot: int, ability_name: String, cd_total: float, cost: float, rank: int, max_rank: int, can_level: bool, description: String) -> void:
	var tip := ""
	if ability_name == "":
		tip = "Empty ability slot  [%s]" % d["key"]
	else:
		tip = "%s  [%s]" % [ability_name, d["key"]]
		if rank <= 0:
			tip += "\nNot learned yet"
			if can_level:
				tip += "  -  %s to learn it" % Controls.binding_text("ability_level_%d" % (slot + 1))
		else:
			tip += "\nRank %d/%d    Mana %d    Cooldown %.1fs" % [rank, max_rank, roundi(cost), cd_total]
			if can_level:
				tip += "\n%s to rank up" % Controls.binding_text("ability_level_%d" % (slot + 1))
		if description != "":
			tip += "\n\n" + description
	var panel := d["panel"] as Panel
	if panel.tooltip_text != tip:
		panel.tooltip_text = tip


## Shows the champion's passive in its spot (dimmed when there is none).
func set_passive(passive_name: String, description: String = "") -> void:
	var panel := _passive_slot["panel"] as Panel
	panel.modulate = Color.WHITE if passive_name != "" else Color(1.0, 1.0, 1.0, 0.4)
	(_passive_slot["name"] as Label).text = passive_name
	var tip := "Passive  [P]" if passive_name == "" else "%s  (passive)" % passive_name
	if description != "":
		tip += "\n\n" + description
	if panel.tooltip_text != tip:
		panel.tooltip_text = tip


## Pictures for the icon spots. Pass null to clear one.
func set_ability_icon(slot: int, texture: Texture2D) -> void:
	(_slots[slot]["icon"] as TextureRect).texture = texture


func set_passive_icon(texture: Texture2D) -> void:
	(_passive_slot["icon"] as TextureRect).texture = texture


func set_portrait(texture: Texture2D) -> void:
	_portrait.texture = texture
	_portrait.queue_redraw()


## Shows the player's active jungle buffs above the ability bar ("" hides it).
func set_buffs(text: String) -> void:
	_buff_label.visible = text != ""
	_buff_label.text = text


## Shows the player's buffs/debuffs as a row of thumbnails above the ability bar.
## Each entry is {key, label, color, stacks, fraction}; extra entries are dropped.
func set_statuses(entries: Array) -> void:
	var shown: Array = entries.slice(0, 10)
	while _status_icons.size() < shown.size():
		_status_icons.append(_make_status_icon())
	for i in _status_icons.size():
		var icon: Dictionary = _status_icons[i]
		var panel := icon["panel"] as Panel
		if i >= shown.size():
			panel.visible = false
			continue
		var e: Dictionary = shown[i]
		panel.visible = true
		var color := StatusVisuals.color_for(str(e["key"]), e.get("color", Color(0, 0, 0, 0)))
		var style := icon["style"] as StyleBoxFlat
		style.border_color = color
		style.bg_color = Color(color, 0.14)
		(icon["label"] as Label).text = str(e["label"])
		var stacks := int(e["stacks"])
		(icon["count"] as Label).text = str(stacks) if stacks > 1 else ""
		var fraction := clampf(float(e["fraction"]), 0.0, 1.0)
		var bar := icon["bar"] as ColorRect
		bar.size = Vector2(30.0 * fraction, 2.0)
		bar.visible = fraction < 0.999
		(icon["bar_bg"] as ColorRect).visible = bar.visible
	_status_row.visible = not shown.is_empty()


func _make_status_icon() -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(34.0, 34.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	_status_row.add_child(panel)

	var label := _make_label(panel, 10, HORIZONTAL_ALIGNMENT_CENTER)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var count := _make_label(panel, 13, HORIZONTAL_ALIGNMENT_RIGHT)
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.offset_right = -2.0
	count.offset_bottom = -1.0
	count.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bar_bg.position = Vector2(2.0, 2.0)
	bar_bg.size = Vector2(30.0, 2.0)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bar_bg)

	var bar := ColorRect.new()
	bar.color = Color(1.0, 1.0, 1.0, 0.85)
	bar.position = Vector2(2.0, 2.0)
	bar.size = Vector2(30.0, 2.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bar)

	return {"panel": panel, "style": style, "label": label, "count": count, "bar": bar, "bar_bg": bar_bg}


## Full-screen champion and equipment pick. `options` is a list of [id, name, blurb].
## `enemy_locked_label` is set when the menu already chose the opponent (e.g.
## "Bot - Cat's Paw"); the enemy picker is then hidden.
## Emits champions_chosen(player_id, enemy_id, loadout) when Start is pressed.
func show_champion_select(options: Array, player_id: String, enemy_id: String, enemy_locked_label: String = "") -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pick_player = player_id
	_pick_enemy = enemy_id
	var root := get_node("Root") as Control
	_select = ColorRect.new()
	(_select as ColorRect).color = Color(0.05, 0.06, 0.09, 0.96)
	_select.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_select)
	_select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Three columns that fit on one screen: champions + opponent | preview |
	# equipment + Start. The scroll only kicks in on very small windows.
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24 if side in ["left", "right"] else 16)
	_select.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	scroll.add_child(page)

	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	page.add_child(columns)

	# Left: roster, then the opponent.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(240.0, 0.0)
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	_section_label(left, "Champions")
	left.add_child(_champion_roster(options, player_id))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 12.0)
	left.add_child(gap)
	_section_label(left, "Opponent")
	if enemy_locked_label != "":
		var enemy_label := _make_label(left, 18, HORIZONTAL_ALIGNMENT_LEFT)
		enemy_label.text = enemy_locked_label
		enemy_label.add_theme_color_override("font_color", ENEMY_COLOR)
	else:
		left.add_child(_enemy_picker(options, enemy_id))

	# Middle: the preview.
	columns.add_child(_champion_preview_panel())
	_show_champion_details(player_id)

	# Right: equipment, with Start at the bottom.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300.0, 0.0)
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	_section_label(right, "Equipment")
	right.add_child(_equipment_list())
	_load_loadout_for(player_id)
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(push)

	var start := Button.new()
	start.text = "Start"
	start.focus_mode = Control.FOCUS_NONE
	start.custom_minimum_size = Vector2(0.0, 56.0)
	start.add_theme_font_size_override("font_size", 24)
	var start_style := StyleBoxFlat.new()
	start_style.bg_color = Color(0.25, 0.45, 0.25, 0.95)
	start_style.border_color = Color(0.6, 0.95, 0.6)
	start_style.set_border_width_all(2)
	start_style.set_corner_radius_all(8)
	var start_hover := start_style.duplicate() as StyleBoxFlat
	start_hover.bg_color = Color(0.3, 0.55, 0.3, 0.95)
	start.add_theme_stylebox_override("normal", start_style)
	start.add_theme_stylebox_override("hover", start_hover)
	start.add_theme_stylebox_override("pressed", start_hover)
	start.pressed.connect(_start_match)
	right.add_child(start)


## Small gold column heading on the champion select screen.
func _section_label(parent: Control, text: String) -> void:
	var l := _make_label(parent, 18, HORIZONTAL_ALIGNMENT_LEFT)
	l.text = text.to_upper()
	l.add_theme_color_override("font_color", ACCENT)


func _start_match() -> void:
	champions_chosen.emit(_pick_player, _pick_enemy, _pick_loadout.duplicate())


## The confirm action starts the match from the champion select screen.
func _unhandled_input(event: InputEvent) -> void:
	if _select == null or not is_instance_valid(_select) or not _select.visible:
		return
	if Controls.pressed(event, "ui_confirm"):
		get_viewport().set_input_as_handled()
		_start_match()


## The player's champion list. Hovering a card previews it, clicking picks it.
func _champion_roster(options: Array, selected: String) -> VBoxContainer:
	var roster := VBoxContainer.new()
	roster.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for opt in options:
		var id: String = opt[0]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(240.0, 62.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 16)
		b.text = "  %s
  %s" % [opt[1], _role_of(str(opt[2]))]
		_style_pick_button(b)
		b.set_pressed_no_signal(id == selected)
		b.pressed.connect(func() -> void:
			_pick_player = id
			_load_loadout_for(id)
			_show_champion_details(id))
		b.mouse_entered.connect(_show_champion_details.bind(id))
		b.mouse_exited.connect(func() -> void: _show_champion_details(_pick_player))
		roster.add_child(b)
	return roster


## Opponent dropdown, used when the menu didn't already lock in a bot.
func _enemy_picker(options: Array, selected: String) -> OptionButton:
	var picker := OptionButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	picker.custom_minimum_size = Vector2(0.0, 40.0)
	picker.add_theme_font_size_override("font_size", 16)
	var choices := options.duplicate()
	choices.append(["random", "Random", ""])
	for opt in choices:
		picker.add_item(str(opt[1]))
		picker.set_item_metadata(picker.item_count - 1, str(opt[0]))
		if str(opt[0]) == selected:
			picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index: int) -> void:
		_pick_enemy = str(picker.get_item_metadata(index)))
	return picker


## Middle column: model and stats on top, every ability below at full width.
func _champion_preview_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.14, 0.95)
	style.border_color = Color(1.0, 1.0, 1.0, 0.1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	column.add_child(top)
	_preview = ChampionPreview.new()
	# A bigger model on taller screens, as long as everything still fits.
	var model_h := clampf(get_viewport().get_visible_rect().size.y * 0.3, 210.0, 300.0)
	_preview.custom_minimum_size = Vector2(model_h * 0.85, model_h)
	top.add_child(_preview)
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail_box.add_theme_constant_override("separation", 8)
	top.add_child(_detail_box)
	var sep := HSeparator.new()
	sep.modulate = Color(1.0, 1.0, 1.0, 0.3)
	column.add_child(sep)
	_ability_box = VBoxContainer.new()
	_ability_box.add_theme_constant_override("separation", 7)
	column.add_child(_ability_box)
	_detail_shown = ""
	return panel


## Gold border when picked, shared by the champion buttons.
func _style_pick_button(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.14, 0.18, 0.95)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.3, 0.3, 0.35)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(0.6, 0.6, 0.66)
	var picked := normal.duplicate() as StyleBoxFlat
	picked.bg_color = Color(0.2, 0.18, 0.1, 0.95)
	picked.border_color = Color(1.0, 0.8, 0.3)
	picked.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", picked)
	b.add_theme_stylebox_override("hover_pressed", picked)


## "Melee assassin. Knife, dash..." -> "Melee assassin"
func _role_of(blurb: String) -> String:
	var dot := blurb.find(".")
	return blurb.substr(0, dot) if dot > 0 else blurb


func _show_champion_details(id: String) -> void:
	if id == _detail_shown or _detail_box == null or not is_instance_valid(_detail_box):
		return
	if not ProtoConfig.CHAMPIONS.has(id):
		return
	_detail_shown = id
	_preview.show_champion(id)
	for box: Control in [_detail_box, _ability_box]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	var def := load(str(ProtoConfig.CHAMPIONS[id]["definition"])) as EntityDefinition
	if def == null:
		return

	var title := _make_label(_detail_box, 30, HORIZONTAL_ALIGNMENT_LEFT)
	title.text = def.entity_name
	title.add_theme_color_override("font_color", ACCENT)
	var blurb := _wrapped_label(_detail_box, 15)
	blurb.text = str(ProtoConfig.CHAMPIONS[id]["blurb"])
	blurb.modulate = Color(1.0, 1.0, 1.0, 0.75)

	var stats := GridContainer.new()
	stats.columns = 4
	stats.add_theme_constant_override("h_separation", 14)
	stats.add_theme_constant_override("v_separation", 2)
	_detail_box.add_child(stats)
	var ranged := def.attack_projectile_speed > 0.0
	for entry in [
		["Health", "%s  (+%s)" % [_num(def.stats_max_health), _num(def.growth_health)]],
		["Mana", "%s  (+%s)" % [_num(def.stats_max_mana), _num(def.growth_mana)]],
		["Attack", "%s  (+%s)" % [_num(def.stats_attack_damage), _num(def.growth_attack_damage)]],
		["Attack speed", _num(def.stats_attack_speed, 2)],
		["Armor", "%s  (+%s)" % [_num(def.stats_armor), _num(def.growth_armor)]],
		["Magic resist", "%s  (+%s)" % [_num(def.stats_magic_resist), _num(def.growth_magic_resist)]],
		["Range", "%s  (%s)" % [_num(def.stats_attack_range), "ranged" if ranged else "melee"]],
		["Move speed", _num(def.stats_movement_speed)],
	]:
		var key := _make_label(stats, 14, HORIZONTAL_ALIGNMENT_LEFT)
		key.text = entry[0]
		key.modulate = DIM
		var value := _make_label(stats, 14, HORIZONTAL_ALIGNMENT_LEFT)
		value.text = entry[1]
		value.custom_minimum_size = Vector2(120.0, 0.0)

	if def.passive:
		_ability_card(def.passive, "P", 0)
	var slots := [def.ability_1, def.ability_2, def.ability_3, def.ability_4]
	for i in slots.size():
		var ability := slots[i] as AbilityDefinition
		if ability:
			_ability_card(ability, Controls.binding_text("ability_%d" % (i + 1)), 3 if i == 3 else 5)


## One ability: key badge, name, cooldown / cost / range, and its description.
## `ranks` is 5 for basic abilities, 3 for the ultimate, 0 for the passive.
func _ability_card(ability: AbilityDefinition, key: String, ranks: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_ability_box.add_child(row)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(40.0, 40.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.16, 0.17, 0.22)
	badge_style.border_color = Color(0.55, 0.5, 0.75) if ranks == 0 else (ACCENT if ranks == 3 else Color(0.4, 0.42, 0.5))
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(6)
	badge.add_theme_stylebox_override("panel", badge_style)
	row.add_child(badge)
	if ability.icon:
		var icon := TextureRect.new()
		icon.texture = ability.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.add_child(icon)
	var key_label := _make_label(badge, 16, HORIZONTAL_ALIGNMENT_CENTER)
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.text = key

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	text.add_child(head)
	var name_label := _make_label(head, 17, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.text = ability.ability_name
	var meta := PackedStringArray()
	if ranks == 0:
		meta.append("Passive")
		if ability.cooldown > 0.0:
			meta.append("%ss cooldown" % _num(ability.cooldown))
	else:
		if ability.cooldown > 0.0:
			meta.append("%ss" % _rank_values(ability.cooldown, ability.cooldown_per_rank, ranks))
		if ability.mana_cost > 0.0:
			meta.append("%s mana" % _rank_values(ability.mana_cost, ability.mana_cost_per_rank, ranks))
		if ability.cast_range > 0.0:
			meta.append("range %s" % _num(ability.cast_range))
	var meta_label := _make_label(head, 13, HORIZONTAL_ALIGNMENT_LEFT)
	meta_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta_label.text = "  ·  ".join(meta)
	meta_label.modulate = DIM
	var desc := _wrapped_label(text, 14)
	var body := ability.description.trim_prefix("Passive: ")
	desc.text = body.left(1).to_upper() + body.substr(1)
	desc.modulate = Color(1.0, 1.0, 1.0, 0.85)


func _wrapped_label(parent: Control, font_px: int) -> Label:
	var l := _make_label(parent, font_px, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_constant_override("outline_size", 0)
	return l


## "14/13/12/11/10" for values that change with rank, "14" for ones that don't.
func _rank_values(base: float, per_rank: float, ranks: int) -> String:
	if is_zero_approx(per_rank):
		return _num(base)
	var parts := PackedStringArray()
	for r in ranks:
		parts.append(_num(base + per_rank * r))
	return "/".join(parts)


## Whole numbers without ".0", others with up to `decimals` places.
func _num(v: float, decimals: int = 1) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return String.num(v, decimals)


## One dropdown per equipment slot, stacked, with the picked item's effect under it.
func _equipment_list() -> VBoxContainer:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	_slot_pickers.clear()
	for slot in ItemCatalog.SLOT_ORDER:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		list.add_child(cell)
		# Breastplate and Hand shape the build, so they stand out.
		var core := slot == ItemCatalog.Slot.BREASTPLATE or slot == ItemCatalog.Slot.HAND
		var title := _make_label(cell, 14, HORIZONTAL_ALIGNMENT_LEFT)
		title.text = "%s  -  %s" % [ItemCatalog.slot_name(slot), ItemCatalog.slot_hint(slot)]
		title.modulate = Color(1.0, 0.8, 0.35) if core else Color(0.75, 0.8, 0.9)
		var option := OptionButton.new()
		option.focus_mode = Control.FOCUS_NONE
		option.add_theme_font_size_override("font_size", 16)
		for id in ItemCatalog.items_for_slot(slot):
			option.add_item(str(ItemCatalog.get_item(id)["name"]))
			option.set_item_metadata(option.item_count - 1, id)
			option.set_item_tooltip(option.item_count - 1, ItemCatalog.describe(id))
		cell.add_child(option)
		var desc := _make_label(cell, 13, HORIZONTAL_ALIGNMENT_LEFT)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(300.0, 0.0)
		desc.add_theme_constant_override("outline_size", 0)
		desc.modulate = Color(1.0, 1.0, 1.0, 0.75)
		option.item_selected.connect(func(index: int) -> void:
			_pick_loadout[slot] = str(option.get_item_metadata(index))
			desc.text = ItemCatalog.describe(_pick_loadout[slot]))
		_slot_pickers[slot] = {"option": option, "desc": desc}
	return list


## Shows the champion's saved (or default) build in the dropdowns.
func _load_loadout_for(champion_id: String) -> void:
	_pick_loadout = ItemCatalog.load_loadout(champion_id)
	for slot in _slot_pickers:
		var option := _slot_pickers[slot]["option"] as OptionButton
		for i in option.item_count:
			if str(option.get_item_metadata(i)) == str(_pick_loadout[slot]):
				option.select(i)
		(_slot_pickers[slot]["desc"] as Label).text = ItemCatalog.describe(_pick_loadout[slot])


## Unspent points show as a "+" on the ability slots themselves, so the HUD
## doesn't need a separate line of instructions.
func set_skill_points(_points: int) -> void:
	pass


func set_champion_bars(hp: float, max_hp: float, mana: float, max_mana: float, hp_regen: float = 0.0, mana_regen: float = 0.0) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_text.text = "%d/%d" % [ceili(hp), roundi(max_hp)]
	_hp_regen.text = "+%.1f" % hp_regen
	_mana_bar.max_value = max_mana
	_mana_bar.value = mana
	_mana_text.text = "%d/%d" % [floori(mana), roundi(max_mana)]
	_mana_regen.text = "+%.1f" % mana_regen


func set_phase_text(main: String, sub: String) -> void:
	_phase_label.text = main
	_sub_label.text = sub


## Tints the wave / timer text.
func set_phase_color(color: Color) -> void:
	_phase_label.add_theme_color_override("font_color", color)


func set_gold(gold: int) -> void:
	_gold_label.text = "%d" % gold


## Grey wash and respawn countdown while the player champion is dead.
func set_dead(dead: bool, seconds_left: int) -> void:
	if _death_overlay == null:
		return
	_death_overlay.visible = dead
	if dead:
		_death_label.text = "Respawning in %d..." % maxi(seconds_left, 0)


func set_level(level: int, xp_fraction: float) -> void:
	_portrait.level = level
	_portrait.queue_redraw()
	_xp_bar.max_value = 1.0
	_xp_bar.value = xp_fraction


## True while the champion-select screen is up.
func is_picking() -> bool:
	return _select != null and is_instance_valid(_select) and _select.visible


## Hides the in-match extras (scoreboard) behind the pick screens. The HUD runs
## while the game is paused, so this works during champion select too.
func _process(_delta: float) -> void:
	if _scoreboard != null:
		_scoreboard.visible = not is_picking()


## Top-right strip: "3 vs 2" team kills, your K/D/A, your minion score, match clock.
func _build_scoreboard(root: Control) -> void:
	var col := VBoxContainer.new()
	_scoreboard = col
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	root.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.offset_right = -14.0
	col.offset_top = 12.0

	var panel := _panel(col, Vector2(14.0, 5.0), 0.82)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	_score_label = _rich(row, 17)
	_score_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_kda_label = _stat(row, StatIcon.SWORD, Color(0.8, 0.82, 0.88))
	_cs_label = _stat(row, StatIcon.MINION, Color(1.0, 0.82, 0.4))
	_clock_label = _stat(row, StatIcon.CLOCK, Color(0.8, 0.82, 0.88))

	_perf_label = _make_label(col, 12, HORIZONTAL_ALIGNMENT_RIGHT)
	_perf_label.modulate = Color(1.0, 1.0, 1.0, 0.75)
	set_scoreboard(0, 0, 0, 0, 0, 0, "0:00")


## An icon followed by a value, added to `row`. Returns the value label.
func _stat(row: HBoxContainer, icon_kind: int, icon_color: Color) -> Label:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)
	var icon := StatIcon.new()
	icon.kind = icon_kind
	icon.color = icon_color
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var label := _make_label(box, 17, HORIZONTAL_ALIGNMENT_LEFT)
	label.add_theme_constant_override("outline_size", 0)
	return label


## Team kills (yours vs theirs), your own K/D/A, your minion score and the clock.
func set_scoreboard(ally_kills: int, enemy_kills: int, kills: int, deaths: int, assists: int, cs: int, clock: String) -> void:
	_score_label.text = "[color=#%s][b]%d[/b][/color] [color=#9aa0ab]vs[/color] [color=#%s][b]%d[/b][/color]" % [
		ALLY_COLOR.to_html(false), ally_kills, ENEMY_COLOR.to_html(false), enemy_kills]
	_kda_label.text = "%d/%d/%d" % [kills, deaths, assists]
	_cs_label.text = str(cs)
	_clock_label.text = clock


## Frames per second and frame time under the scoreboard.
func set_perf(fps: int) -> void:
	_perf_label.text = "%d fps   %d ms" % [fps, roundi(1000.0 / maxf(float(fps), 1.0))]


## The round champion portrait with its level badge (draws a plain disc until
## a texture is set with set_portrait()).
class Portrait extends Control:
	var texture: Texture2D
	var level: int = 1
	## Shrinks the drawing and minimum size together (1.0 = the full 68x72).
	var size_scale: float = 1.0:
		set(value):
			size_scale = value
			custom_minimum_size = Vector2(68.0, 72.0) * size_scale
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(68.0, 72.0)
		mouse_filter = Control.MOUSE_FILTER_STOP  # for the hover tooltip
		tooltip_text = "Your champion"

	func _draw() -> void:
		if size_scale != 1.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(size_scale, size_scale))
		var c := Vector2(34.0, 31.0)
		var r := 29.0
		draw_circle(c, r, Color(0.1, 0.11, 0.15, 0.95))
		if texture != null:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 48:
				var a := TAU * float(i) / 48.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
				uvs.append(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
			draw_colored_polygon(pts, Color.WHITE, uvs, texture)
		draw_arc(c, r, 0.0, TAU, 48, Color(0.9, 0.75, 0.35), 2.5, true)
		# Level badge overlapping the bottom of the ring.
		var badge := Rect2(Vector2(c.x - 12.0, 54.0), Vector2(24.0, 17.0))
		draw_rect(badge, Color(0.08, 0.09, 0.12, 0.97))
		draw_rect(badge, Color(0.9, 0.75, 0.35), false, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(badge.position.x, badge.position.y + 13.5), str(level),
			HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 14, Color(1.0, 0.82, 0.4))


## A small drawn icon (no art files needed) for the scoreboard.
class StatIcon extends Control:
	const SWORD := 0
	const MINION := 1
	const CLOCK := 2
	const GOLD := 3
	var kind: int = SWORD
	var color: Color = Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(18.0, 18.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		match kind:
			SWORD:
				# Blade up and to the right, crossguard and grip at the lower left.
				draw_line(Vector2(3.5, 14.5), Vector2(15.0, 3.0), color, 2.4, true)
				draw_line(Vector2(4.5, 8.5), Vector2(9.5, 13.5), color, 2.0, true)
				draw_line(Vector2(2.0, 16.0), Vector2(5.0, 13.0), color, 3.0, true)
			MINION:
				# A helmeted head over a rounded body.
				draw_circle(Vector2(9.0, 6.0), 3.6, color)
				draw_rect(Rect2(4.5, 10.0, 9.0, 6.0), color)
				draw_rect(Rect2(5.5, 4.0, 7.0, 1.6), Color(color, 0.55))
			CLOCK:
				draw_arc(Vector2(9.0, 9.0), 7.0, 0.0, TAU, 28, color, 1.8, true)
				draw_line(Vector2(9.0, 9.0), Vector2(9.0, 4.0), color, 1.8, true)
				draw_line(Vector2(9.0, 9.0), Vector2(12.5, 11.0), color, 1.8, true)
			GOLD:
				draw_circle(Vector2(9.0, 9.0), 6.8, color)
				draw_circle(Vector2(9.0, 9.0), 4.4, Color(color, 0.45))
				draw_arc(Vector2(9.0, 9.0), 6.8, 0.0, TAU, 24, Color(0.0, 0.0, 0.0, 0.25), 1.0, true)


func show_message(text: String, color: Color = Color.WHITE) -> void:
	if not SHOW_MESSAGES:
		return
	_message_label.text = text
	_message_label.modulate = color
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(2.2)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.6)


func show_game_over(won: bool) -> void:
	_over.visible = true
	_over_label.text = ("VICTORY" if won else "DEFEAT") + "\n%s to restart" % Controls.binding_text("restart_match")
	_over_label.modulate = Color(0.6, 1.0, 0.6) if won else Color(1.0, 0.5, 0.45)
