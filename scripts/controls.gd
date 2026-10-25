extends Node
## One source of truth for keyboard bindings. Defines the default action map,
## loads/saves user overrides, and powers the controls screen in the main menu.
##
## Everything gameplay-facing reads InputMap actions by name, so adding a new
## control means adding one entry here (and using its action name).

signal bindings_changed

const SAVE_PATH := "user://controls.cfg"

const GROUPS: Array[String] = ["Camera", "Abilities", "Spawners", "Interface"]

## action -> {group, label, key, optional ctrl/shift/alt/meta}
const BINDINGS := {
	"camera_up": {"group": "Camera", "label": "Camera up", "key": KEY_UP},
	"camera_down": {"group": "Camera", "label": "Camera down", "key": KEY_DOWN},
	"camera_left": {"group": "Camera", "label": "Camera left", "key": KEY_LEFT},
	"camera_right": {"group": "Camera", "label": "Camera right", "key": KEY_RIGHT},
	"camera_lock": {"group": "Camera", "label": "Lock on champion", "key": KEY_Y},
	"camera_center": {"group": "Camera", "label": "Center on champion (hold)", "key": KEY_SPACE},

	"ability_1": {"group": "Abilities", "label": "Ability 1", "key": KEY_Q},
	"ability_2": {"group": "Abilities", "label": "Ability 2", "key": KEY_W},
	"ability_3": {"group": "Abilities", "label": "Ability 3", "key": KEY_E},
	"ability_4": {"group": "Abilities", "label": "Ability 4", "key": KEY_R},
	"ability_level_1": {"group": "Abilities", "label": "Level ability 1", "key": KEY_Q, "ctrl": true},
	"ability_level_2": {"group": "Abilities", "label": "Level ability 2", "key": KEY_W, "ctrl": true},
	"ability_level_3": {"group": "Abilities", "label": "Level ability 3", "key": KEY_E, "ctrl": true},
	"ability_level_4": {"group": "Abilities", "label": "Level ability 4", "key": KEY_R, "ctrl": true},

	"open_roll": {"group": "Spawners", "label": "Open spawner roll", "key": KEY_B},

	"ui_menu": {"group": "Interface", "label": "Menu / cancel", "key": KEY_ESCAPE},
	"ui_confirm": {"group": "Interface", "label": "Confirm", "key": KEY_ENTER},
	"ui_info": {"group": "Interface", "label": "Match info (hold)", "key": KEY_TAB},
	"toggle_mouse": {"group": "Interface", "label": "Lock / unlock mouse", "key": KEY_F2},
	"change_champion": {"group": "Interface", "label": "Change champion", "key": KEY_F3},
	"restart_match": {"group": "Interface", "label": "Restart match (game over)", "key": KEY_R},
}

## Restart shares R with the ultimate by default and only fires at game over, so
## it is allowed to overlap another action.
const NO_SWAP: Array[String] = ["restart_match"]


func _ready() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			_set_events(action, _default_events(action))
	_load()


func actions_in_group(group: String) -> Array[String]:
	var out: Array[String] = []
	for action in BINDINGS:
		if str(BINDINGS[action]["group"]) == group:
			out.append(action)
	return out


func action_label(action: String) -> String:
	return str(BINDINGS[action]["label"]) if BINDINGS.has(action) else action


func has_action(action: String) -> bool:
	return BINDINGS.has(action)


## Use this instead of event.is_action_pressed(). Godot's default match ignores
## extra modifiers, so Ctrl+Q would also count as a press of plain Q. This
## requires the modifiers to match the binding exactly.
func pressed(event: InputEvent, action: String) -> bool:
	return event.is_action_pressed(action, false, true)


func binding_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "Unbound"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	var parts: PackedStringArray = []
	for e in events:
		parts.append(_event_text(e))
	return " / ".join(parts)


## Rebinds `action` to `source`. If the key is already used by another action,
## the two bindings swap. Restart is exempt because it only works at game over.
## Returns {} if the key can't be bound. Otherwise "moved" lists every other
## action that lost the key: [{"action": name, "now": its new binding text}].
func rebind(action: String, source: InputEventKey) -> Dictionary:
	if not BINDINGS.has(action) or source == null:
		return {}
	var key := source.physical_keycode if source.physical_keycode != 0 else source.keycode
	if key == 0 or key == KEY_CTRL or key == KEY_SHIFT or key == KEY_ALT or key == KEY_META:
		return {}
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.ctrl_pressed = source.ctrl_pressed
	event.shift_pressed = source.shift_pressed
	event.alt_pressed = source.alt_pressed
	event.meta_pressed = source.meta_pressed

	var old_events := InputMap.action_get_events(action)
	var old_event: InputEvent = old_events[0] if not old_events.is_empty() else null
	var moved: Array[Dictionary] = []
	if old_event != null and _same_binding(old_event, event):
		return {"moved": moved}

	var lost_key: Array[String] = []
	if not NO_SWAP.has(action):
		var swapped := false
		for other in BINDINGS:
			if other == action or NO_SWAP.has(other) or not InputMap.has_action(other):
				continue
			var other_events := InputMap.action_get_events(other)
			var lost := false
			for i in range(other_events.size() - 1, -1, -1):
				if _same_binding(other_events[i], event):
					InputMap.action_erase_event(other, other_events[i])
					other_events.remove_at(i)
					lost = true
			if not lost:
				continue
			lost_key.append(other)
			if other_events.is_empty() and old_event != null and not swapped:
				InputMap.action_add_event(other, old_event.duplicate())
				swapped = true

	_set_events(action, [event])
	for other in lost_key:
		moved.append({"action": other, "now": binding_text(other)})
	_save()
	bindings_changed.emit()
	return {"moved": moved}


func reset_defaults() -> void:
	for action in BINDINGS:
		_set_events(action, _default_events(action))
	_save()
	bindings_changed.emit()


func _default_events(action: String) -> Array:
	var info: Dictionary = BINDINGS[action]
	var event := InputEventKey.new()
	event.physical_keycode = int(info["key"])
	event.ctrl_pressed = bool(info.get("ctrl", false))
	event.shift_pressed = bool(info.get("shift", false))
	event.alt_pressed = bool(info.get("alt", false))
	return [event]


func _set_events(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for e in events:
		InputMap.action_add_event(action, e)


func _same_binding(a: InputEvent, b: InputEvent) -> bool:
	if not (a is InputEventKey) or not (b is InputEventKey):
		return false
	var ak := a as InputEventKey
	var bk := b as InputEventKey
	var akey := ak.physical_keycode if ak.physical_keycode != 0 else ak.keycode
	var bkey := bk.physical_keycode if bk.physical_keycode != 0 else bk.keycode
	return akey == bkey \
		and ak.ctrl_pressed == bk.ctrl_pressed \
		and ak.shift_pressed == bk.shift_pressed \
		and ak.alt_pressed == bk.alt_pressed \
		and ak.meta_pressed == bk.meta_pressed


func _event_text(event: InputEvent) -> String:
	if not (event is InputEventKey):
		return event.as_text()
	var key_event := event as InputEventKey
	var parts: PackedStringArray = []
	if key_event.ctrl_pressed:
		parts.append("Ctrl")
	if key_event.shift_pressed:
		parts.append("Shift")
	if key_event.alt_pressed:
		parts.append("Alt")
	if key_event.meta_pressed:
		parts.append("Meta")
	var key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	parts.append(OS.get_keycode_string(key))
	return "+".join(parts)


func _save() -> void:
	var cfg := ConfigFile.new()
	for action in BINDINGS:
		var saved: Array = []
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				saved.append(_event_to_dict(e as InputEventKey))
		cfg.set_value(action, "bindings", saved)
	cfg.save(SAVE_PATH)


func _event_to_dict(event: InputEventKey) -> Dictionary:
	return {
		"key": int(event.physical_keycode if event.physical_keycode != 0 else event.keycode),
		"ctrl": event.ctrl_pressed,
		"shift": event.shift_pressed,
		"alt": event.alt_pressed,
		"meta": event.meta_pressed,
	}


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var from_file := {}
	for action in BINDINGS:
		if not cfg.has_section(action):
			continue
		var saved: Variant = cfg.get_value(action, "bindings", [])
		if not (saved is Array):
			continue
		var saved_array: Array = saved
		if saved_array.is_empty():
			continue
		var events: Array = []
		for d in saved_array:
			if not (d is Dictionary):
				continue
			var data: Dictionary = d
			var key := int(data.get("key", 0))
			if key == 0:
				continue
			var event := InputEventKey.new()
			event.physical_keycode = key
			event.ctrl_pressed = bool(data.get("ctrl", false))
			event.shift_pressed = bool(data.get("shift", false))
			event.alt_pressed = bool(data.get("alt", false))
			event.meta_pressed = bool(data.get("meta", false))
			events.append(event)
		if not events.is_empty():
			_set_events(action, events)
			from_file[action] = true
	if _resolve_conflicts(from_file):
		_save()


## Two actions on one key would both fire, which can happen when a new action's
## default matches a key the player saved earlier (or the file was hand-edited).
## The player's saved choices win over defaults, then earlier actions in
## BINDINGS win over later ones. A losing action goes back to its default key,
## or is left unbound if that is taken too. Returns true if anything changed.
func _resolve_conflicts(from_file: Dictionary) -> bool:
	var order: Array[String] = []
	for action in BINDINGS:
		if from_file.has(action):
			order.append(action)
	for action in BINDINGS:
		if not from_file.has(action):
			order.append(action)

	var taken: Array = []
	var changed := false
	for action in order:
		if NO_SWAP.has(action):
			continue
		var events := InputMap.action_get_events(action)
		var kept: Array = []
		for e in events:
			if not _is_taken(taken, e):
				kept.append(e)
		if kept.size() != events.size():
			if kept.is_empty():
				for e in _default_events(action):
					if not _is_taken(taken, e):
						kept.append(e)
			_set_events(action, kept)
			changed = true
			push_warning("Controls: '%s' clashed with another action and is now %s." % [action, binding_text(action)])
		taken.append_array(kept)
	return changed


func _is_taken(taken: Array, event: InputEvent) -> bool:
	for t in taken:
		if _same_binding(t, event):
			return true
	return false
