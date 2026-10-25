class_name ProtoTargetPanel
extends PanelContainer
## Top-left info card for the selected champion (left-click one, or attack one):
## portrait and level, name, K/D/A, health and mana, core stats, items and
## active statuses. Hidden when nothing is selected or an enemy leaves your vision.
## The game keeps the selection in ProtoGame.selected_seat.

const ALLY := Color(0.45, 0.7, 1.0)
const ENEMY := Color(1.0, 0.5, 0.45)
const GOLD := Color(1.0, 0.82, 0.4)
const DIM := Color(1.0, 1.0, 1.0, 0.6)
const WIDTH := 196.0
const ITEM_SIZE := 22.0
const MAX_CHIPS := 8

## (key, label, colour) for the stat grid, two per row.
const STATS := [
	["ad", "AD", Color(1.0, 0.65, 0.3)],
	["ap", "AP", Color(0.65, 0.6, 1.0)],
	["armor", "Armor", Color(1.0, 0.85, 0.4)],
	["mr", "MR", Color(0.5, 0.85, 1.0)],
	["as", "Atk spd", Color(1.0, 0.8, 0.5)],
	["cdr", "CDR", Color(0.8, 0.85, 1.0)],
	["crit", "Crit", Color(1.0, 0.5, 0.45)],
	["ms", "Move", Color(0.8, 0.95, 0.8)],
]

var _game: ProtoGame
var _portrait: ProtoHUD.Portrait
var _name: Label
var _kda: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _mana_bar: ProgressBar
var _mana_text: Label
var _stat_values: Dictionary[String, Label] = {}
var _items: Array[Dictionary] = []
var _chip_row: HBoxContainer
var _chips: Array[Dictionary] = []
var _shown_level: int = -1


func setup(game: ProtoGame) -> void:
	_game = game


func _ready() -> void:
	name = "TargetPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	offset_left = 14.0
	offset_top = 12.0
	custom_minimum_size = Vector2(WIDTH, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.88)
	style.border_color = Color(0.85, 0.7, 0.35, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	add_theme_stylebox_override("panel", style)
	_build()


func _build() -> void:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 3)
	add_child(col)

	# Top: portrait on the left; name, K/D/A and the bars on the right.
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	_portrait = ProtoHUD.Portrait.new()
	_portrait.size_scale = 0.55
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_portrait)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	top.add_child(info)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(head)
	_name = _label(head, 12, Color.WHITE)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kda = _label(head, 11, GOLD)
	_kda.tooltip_text = "Kills / deaths / assists"
	_kda.mouse_filter = Control.MOUSE_FILTER_STOP
	var hp := _bar(info, Color(0.25, 0.75, 0.3), 10.0)
	_hp_bar = hp[0]
	_hp_text = hp[1]
	var mana := _bar(info, Color(0.25, 0.5, 0.95), 10.0)
	_mana_bar = mana[0]
	_mana_text = mana[1]

	# Stats, two per row (label, value, label, value).
	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 0)
	col.add_child(grid)
	for s: Array in STATS:
		var name_label := _label(grid, 9, s[2])
		name_label.text = str(s[1])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := _label(grid, 10, Color.WHITE)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(30.0, 0.0)
		_stat_values[str(s[0])] = value

	# Items (one spot per equipment slot) and, to their right, active statuses.
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 2)
	col.add_child(bottom)
	for i in ItemCatalog.SLOT_ORDER.size():
		_items.append(_make_item_spot(bottom))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(4.0, 0.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(gap)
	_chip_row = HBoxContainer.new()
	_chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_row.add_theme_constant_override("separation", 2)
	bottom.add_child(_chip_row)
	for i in MAX_CHIPS:
		_chips.append(_make_chip(_chip_row))


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	parent.add_child(l)
	return l


## A bar with its "current/max" text centred on it.
func _bar(parent: Control, color: Color, height: float) -> Array:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	var text := _label(bar, 9, Color.WHITE)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return [bar, text]


## One item square: a picture spot (set later), a letter placeholder, and a hover tooltip.
func _make_item_spot(parent: Control) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(ITEM_SIZE, ITEM_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.15, 0.95)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panel.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var letter := _label(panel, 10, Color(1.0, 1.0, 1.0, 0.75))
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return {"panel": panel, "style": style, "icon": icon, "letter": letter}


## One status chip (stun, slow, buff...), shown only while the status is active.
func _make_chip(parent: Control) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(20.0, 20.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	parent.add_child(panel)
	var label := _label(panel, 8, Color.WHITE)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return {"panel": panel, "style": style, "label": label}


# ---- Updating ----

func _process(_delta: float) -> void:
	if _game == null or not is_instance_valid(_game):
		return
	if _game.is_picking():
		visible = false
		return
	var seat := _game.selected_seat
	var champ: CharacterBody3D = _game.champions.get(seat) if seat >= 0 else null
	if champ == null or not is_instance_valid(champ):
		visible = false
		return
	var team := _game.seat_team(seat)
	# An enemy that walks into the fog can't be inspected.
	if not _game.spectate and team != _game.player_team and not FogOfWar.can_see(_game.player_team, champ):
		visible = false
		return
	var st := EntityData.get_stats_of(champ)
	if st == null:
		visible = false
		return
	visible = true
	var ally := team == _game.player_team
	var champ_name := ProtoConfig.champion_name(_game.seat_champion_id(seat))
	_name.text = champ_name + ("  (you)" if seat == _game.player_seat else "")
	_name.add_theme_color_override("font_color", ALLY if ally else ENEMY)
	_portrait.tooltip_text = champ_name
	if _shown_level != st.level:
		_shown_level = st.level
		_portrait.level = st.level
		_portrait.queue_redraw()
	var kda := _game.kda_of(seat)
	_kda.text = "%d/%d/%d" % [kda[0], kda[1], kda[2]]
	_hp_bar.max_value = st.get_max_health()
	_hp_bar.value = st.current_health
	_hp_text.text = "%d/%d" % [ceili(st.current_health), roundi(st.get_max_health())]
	_mana_bar.max_value = maxf(st.get_max_mana(), 1.0)
	_mana_bar.value = st.current_mana
	_mana_text.text = "%d/%d" % [floori(st.current_mana), roundi(st.get_max_mana())]
	modulate = Color(1.0, 1.0, 1.0, 0.6) if st.is_dead else Color.WHITE
	_update_stats(st)
	_update_items(champ)
	_update_statuses(champ)


func _update_stats(st: StatsComponent) -> void:
	_stat_values["ad"].text = str(roundi(st.get_attack_damage()))
	_stat_values["ap"].text = str(roundi(st.get_ability_power()))
	_stat_values["armor"].text = str(roundi(st.get_armor()))
	_stat_values["mr"].text = str(roundi(st.get_magic_resist()))
	_stat_values["as"].text = String.num(st.get_attack_speed(), 2)
	_stat_values["cdr"].text = "%d%%" % roundi(st.get_cooldown_reduction() * 100.0)
	_stat_values["crit"].text = "%d%%" % roundi(st.get_crit_chance() * 100.0)
	_stat_values["ms"].text = str(roundi(st.get_movement_speed()))


func _update_items(champ: Node) -> void:
	var gear := champ.get_node_or_null("Equipment") as Equipment
	for i in _items.size():
		var spot: Dictionary = _items[i]
		var slot: int = ItemCatalog.SLOT_ORDER[i]
		var id := str(gear.loadout.get(slot, "")) if gear else ""
		var item := ItemCatalog.get_item(id)
		var panel := spot["panel"] as Panel
		(spot["letter"] as Label).text = str(item["name"]).substr(0, 1).to_upper() if not item.is_empty() else ""
		(spot["style"] as StyleBoxFlat).border_color = Color(0.9, 0.75, 0.35) if not item.is_empty() else Color(0.3, 0.3, 0.35)
		var tip := "Empty %s slot" % ItemCatalog.slot_name(slot).to_lower()
		if not item.is_empty():
			tip = "%s  (%s)\n%s" % [item["name"], ItemCatalog.slot_name(slot), ItemCatalog.describe(id)]
		if panel.tooltip_text != tip:
			panel.tooltip_text = tip


func _update_statuses(champ: Node) -> void:
	var fx := champ.get_node_or_null("StatusEffects") as StatusEffects
	var entries: Array = fx.active_statuses() if fx else []
	for i in _chips.size():
		var chip: Dictionary = _chips[i]
		var panel := chip["panel"] as Panel
		if i >= entries.size():
			panel.visible = false
			continue
		var e: Dictionary = entries[i]
		panel.visible = true
		var color := StatusVisuals.color_for(str(e["key"]), e.get("color", Color(0, 0, 0, 0)))
		(chip["style"] as StyleBoxFlat).border_color = color
		(chip["style"] as StyleBoxFlat).bg_color = Color(color, 0.14)
		(chip["label"] as Label).text = str(e["label"])
		var tip := str(e["label"])
		if int(e["stacks"]) > 1:
			tip += "  x%d" % int(e["stacks"])
		if panel.tooltip_text != tip:
			panel.tooltip_text = tip
