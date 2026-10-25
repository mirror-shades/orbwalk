class_name StatusEffects
extends Node
## Timed crowd control and buffs on one entity: slows, fear, stun, knock-ups,
## attack and move speed buffs, slow immunity, timed stat buffs (any stat, via
## StatsComponent modifiers), poison (magic damage over time), bleed (stacking
## true damage and anti-heal), blind/dodge (auto-attacks miss), and forced
## movement (dashes and pulls) that locks normal movement.
##
## Every Entity gets one automatically as a child named "StatusEffects".
## The entity's controller (mover.gd, the minion AI, ...) calls
## Entity.process_crowd_control() each frame so fear and dashes take over.

signal forced_move_finished

enum Type { SLOW, FEAR, ATTACK_SPEED, STUN, KNOCKUP, MOVE_SPEED, SLOW_IMMUNE, ROOT, BLIND, CHANNEL, DODGE, STEALTH }

const FEAR_COLOR := Color(0.8, 0.45, 1.0)
const SLOW_COLOR := Color(0.55, 0.8, 1.0)
const HASTE_COLOR := Color(1.0, 0.7, 0.3)
const STUN_COLOR := Color(1.0, 0.9, 0.3)
const KNOCKUP_COLOR := Color(0.45, 0.85, 1.0)
const SPEED_COLOR := Color(0.6, 1.0, 0.6)
const POISON_COLOR := Color(0.55, 0.95, 0.3)
const BUFF_COLOR := Color(1.0, 0.85, 0.45)
const BLEED_COLOR := Color(0.82, 0.16, 0.12)
## Bleed: one stack is consumed every BLEED_TICK seconds, each dealing 1% max HP
## true damage, and healing is reduced while any stacks remain.
const BLEED_MAX_STACKS := 6
const BLEED_TICK := 1.0
const BLEED_HEALING_MULT := 0.6
const BLEED_HP_RATIO := 0.01
## Text labels over units ("Slowed", "Feared", buff names). Off to keep the screen clean.
const SHOW_LABELS := false
## Prefix for the StatsComponent modifier ids that timed stat buffs use.
const STAT_BUFF_PREFIX := "buff:"
## How high a knocked-up unit's model is lifted at the top of the arc.
const KNOCKUP_HEIGHT := 1.4

var _body: Node3D
var _stats: StatsComponent
## Each effect: {type, value, time_left, id, origin}
var _effects: Array[Dictionary] = []
## Each poison: {per_tick, tick, tick_left, ticks_left, source_id, id}
var _poisons: Array[Dictionary] = []
## Bleed stacks left and the time until the next one drains.
var _bleed_stacks: int = 0
var _bleed_timer: float = 0.0
var _bleed_source_id: int = 0
## Timed stat buffs: id -> {time_left, duration, label}. The bonuses live in StatsComponent as modifier "buff:<id>".
var _stat_buffs: Dictionary = {}
## Cosmetic stack sources from abilities (Grit, Tide): id -> {label, color, stacks, time_left, duration}.
var _badges: Dictionary = {}
var _forced_to := Vector3.ZERO
var _forced_speed: float = 0.0
var _forced: bool = false
var _label: Label3D
## The model node lifted during a knock-up ("Models" on champions, "VisualPivot" on minions).
var _visual: Node3D
var _visual_base_y: float = 0.0


func _ready() -> void:
	_body = get_parent() as Node3D
	_stats = _body.get_node_or_null("Stats") as StatsComponent
	if _stats:
		_stats.died.connect(clear_all)
	if SHOW_LABELS:
		_create_label()
	_visual = _body.get_node_or_null("Models") as Node3D
	if _visual == null:
		_visual = _body.get_node_or_null("VisualPivot") as Node3D
	if _visual:
		_visual_base_y = _visual.position.y
	_attach_status_strip()


## A small thumbnail row above this unit's health bar (hidden with the unit by fog).
func _attach_status_strip() -> void:
	var hb := _body.get_node_or_null("HealthBar") as Node3D
	if hb == null or _stats == null:
		return
	var kind := _stats.get_entity_type()
	if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB:
		return
	var strip := load("res://scripts/status_strip.gd").new() as Node3D
	if strip == null:
		return
	strip.name = "StatusStrip"
	hb.add_child(strip)
	var bar_height := 0.2
	var stored: Variant = hb.get("bar_height")
	if stored != null:
		bar_height = float(stored)
	strip.position = Vector3(0.0, bar_height * 0.5 + 0.17, 0.0)
	strip.call("setup", self)


func _create_label() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 26
	_label.outline_size = 8
	_label.pixel_size = 0.01
	var hb := _body.get_node_or_null("HealthBar") as Node3D
	_label.position = Vector3(0.0, (hb.position.y if hb else 2.5) + 0.45, 0.0)
	_label.visible = false
	_body.add_child.call_deferred(_label)


# ---- Applying effects ----

## Slows movement by `strength` (0.3 = 30% slower). Only the strongest slow counts.
## Ignored while the entity is slow immune.
func apply_slow(strength: float, duration: float, id: String = "") -> void:
	if is_slow_immune():
		return
	_add(Type.SLOW, clampf(strength, 0.0, 0.95), duration, id, Vector3.ZERO)


## For `duration`, new slows are ignored and existing ones don't count. Doesn't stop fear or stuns.
func apply_slow_immunity(duration: float, id: String = "") -> void:
	_add(Type.SLOW_IMMUNE, 0.0, duration, id, Vector3.ZERO)


## Adds `bonuses` ({StatsComponent.Stat: amount}) for `duration` seconds, then removes them.
## Applying the same id again replaces the bonuses and refreshes the timer (no stacking),
## so an aura can re-apply a short buff every tick. `label` shows over the unit while active.
func apply_stat_buff(id: String, bonuses: Dictionary, duration: float, label: String = "") -> void:
	if _stats == null or _stats.is_dead or duration <= 0.0:
		return
	_stats.set_modifier(STAT_BUFF_PREFIX + id, bonuses)
	_stat_buffs[id] = {"time_left": duration, "duration": duration, "label": label}
	_update_label()


func remove_stat_buff(id: String) -> void:
	if not _stat_buffs.has(id):
		return
	_stat_buffs.erase(id)
	if _stats:
		_stats.remove_modifier(STAT_BUFF_PREFIX + id)
	_update_label()


## Removes every timed effect with `id` early (e.g. a slow whose source ended).
func remove_effect(id: String) -> void:
	if id == "":
		return
	var removed := false
	for i in range(_effects.size() - 1, -1, -1):
		if str(_effects[i]["id"]) == id:
			_effects.remove_at(i)
			removed = true
	if removed:
		_recompute()


func has_stat_buff(id: String) -> bool:
	return _stat_buffs.has(id)


## Makes the entity run directly away from `from_pos`. It can't attack, cast or be controlled.
func apply_fear(duration: float, from_pos: Vector3) -> void:
	_add(Type.FEAR, 0.0, duration, "", from_pos)


## Freezes the entity in place: no moving, attacking or casting.
func apply_stun(duration: float) -> void:
	_add(Type.STUN, 0.0, duration, "", Vector3.ZERO)


## Knocks the entity into the air: like a stun (no moving, attacking or casting),
## and the model is lifted in an arc. Can't be shortened.
func apply_knockup(duration: float) -> void:
	_add(Type.KNOCKUP, duration, duration, "", Vector3.ZERO)


## Holds the entity in place: no moving or forced moves, but it can still attack
## and cast. Blocks dashes and pulls.
func apply_root(duration: float, id: String = "root") -> void:
	_add(Type.ROOT, 0.0, duration, id, Vector3.ZERO)


## The entity's auto-attacks miss: no damage, no on-hit effects. Abilities work
## normally. Applied to the attacker.
func apply_blind(duration: float, id: String = "blind") -> void:
	_add(Type.BLIND, 0.0, duration, id, Vector3.ZERO)


## Every enemy auto-attack aimed at the entity misses. Abilities and structure
## shots are unaffected. Applied to the defender (Smoke Bomb).
func apply_dodge(duration: float, id: String = "dodge") -> void:
	_add(Type.DODGE, 0.0, duration, id, Vector3.ZERO)


## The entity is invisible to the enemy team and can't be targeted by them.
## Proximity does not reveal it. Damage still lands while it stays in an area.
func apply_stealth(duration: float, id: String = "stealth") -> void:
	_add(Type.STEALTH, 0.0, duration, id, Vector3.ZERO)


## Ends every active stealth effect and its partner effects with the same ids.
func remove_stealth() -> void:
	var ids: Array[String] = []
	var changed := false
	for i in range(_effects.size() - 1, -1, -1):
		if int(_effects[i]["type"]) != Type.STEALTH:
			continue
		var id := str(_effects[i]["id"])
		_effects.remove_at(i)
		changed = true
		if id != "" and not ids.has(id):
			ids.append(id)
	for id in ids:
		for i in range(_effects.size() - 1, -1, -1):
			if str(_effects[i]["id"]) == id:
				_effects.remove_at(i)
				changed = true
	if changed:
		_recompute()


## A charged cast is being held: no moving and no attacking (AbilityCaster also
## refuses other casts). The ability refreshes this while it charges.
func apply_channel(duration: float, id: String = "channel") -> void:
	_add(Type.CHANNEL, 0.0, duration, id, Vector3.ZERO)


## Deals `total_damage` magic damage spread over `duration`, one hit every `tick` seconds.
## `source` gets the credit. A poison with the same non-empty id is refreshed
## (replaced) instead of stacking.
func apply_poison(total_damage: float, duration: float, source: Node = null, id: String = "", tick: float = 0.5) -> void:
	if _stats == null or _stats.is_dead or duration <= 0.0 or total_damage <= 0.0:
		return
	if id != "":
		for i in range(_poisons.size() - 1, -1, -1):
			if _poisons[i]["id"] == id:
				_poisons.remove_at(i)
	var ticks := maxi(roundi(duration / maxf(tick, 0.05)), 1)
	_poisons.append({
		"per_tick": total_damage / float(ticks), "tick": duration / float(ticks), "tick_left": duration / float(ticks),
		"ticks_left": ticks, "source_id": source.get_instance_id() if source and is_instance_valid(source) else 0, "id": id,
	})
	_update_label()


## Adds Bleed stacks (cap 6). While any remain, the target's healing is reduced,
## and one stack drains each second for 1% of its max health as true damage.
## New stacks don't reset the drain timer. The last source gets kill credit.
func apply_bleed(stacks: int, source: Node = null) -> void:
	if _stats == null or _stats.is_dead or stacks <= 0:
		return
	var was_empty := _bleed_stacks <= 0
	_bleed_stacks = mini(_bleed_stacks + stacks, BLEED_MAX_STACKS)
	if source and is_instance_valid(source):
		_bleed_source_id = source.get_instance_id()
	if was_empty:
		_bleed_timer = BLEED_TICK
	_sync_bleed()
	_update_bleed_badge()


## How many Bleed stacks are left (0 = not bleeding).
func bleed_stacks() -> int:
	return _bleed_stacks


## Raises move speed by `bonus` (0.3 = +30%). Effects with the same id refresh instead of stacking.
func apply_move_speed(bonus: float, duration: float, id: String = "") -> void:
	_add(Type.MOVE_SPEED, bonus, duration, id, Vector3.ZERO)


## Raises attack speed by `bonus` (0.4 = +40%). Effects with the same id refresh instead of stacking.
func apply_attack_speed(bonus: float, duration: float, id: String = "") -> void:
	_add(Type.ATTACK_SPEED, bonus, duration, id, Vector3.ZERO)


## Moves the entity straight to `to` at `speed`, ignoring normal movement until it arrives.
## Refused while rooted (roots block dashes and pulls).
func start_forced_move(to: Vector3, speed: float) -> void:
	if _stats and _stats.is_dead:
		return
	if is_rooted():
		return
	_forced_to = Vector3(to.x, _body.global_position.y, to.z)
	_forced_speed = speed
	_forced = true
	if _body.has_method("_on_forced_move_started"):
		_body.call("_on_forced_move_started")


func stop_forced_move() -> void:
	if _forced:
		_forced = false
		forced_move_finished.emit()


func clear_all() -> void:
	_effects.clear()
	_poisons.clear()
	_bleed_stacks = 0
	_bleed_timer = 0.0
	_bleed_source_id = 0
	_badges.clear()
	for id in _stat_buffs.keys():
		remove_stat_buff(str(id))
	_forced = false
	_sync_bleed()
	_recompute()
	_update_knockup_visual()


# ---- Queries ----

func is_feared() -> bool:
	return _has(Type.FEAR)


## True while stunned or knocked up (both stop moving, attacking and casting).
func is_stunned() -> bool:
	return _has(Type.STUN) or _has(Type.KNOCKUP)


func is_knocked_up() -> bool:
	return _has(Type.KNOCKUP)


func is_slow_immune() -> bool:
	return _has(Type.SLOW_IMMUNE)


func is_rooted() -> bool:
	return _has(Type.ROOT)


## True while this entity's auto-attacks are dodged (blind).
func is_blinded() -> bool:
	return _has(Type.BLIND)


## True while auto-attacks aimed at this entity miss (dodge).
func is_dodging() -> bool:
	return _has(Type.DODGE)


## True while the entity is hidden from the enemy team (cloak).
func is_stealthed() -> bool:
	return _has(Type.STEALTH)


## True while a charged cast is being held (no movement or auto-attacks).
func is_channeling() -> bool:
	return _has(Type.CHANNEL)


func is_poisoned() -> bool:
	return not _poisons.is_empty()


## True while normal movement is overridden: mid-dash/pull or holding a charged cast.
func is_movement_locked() -> bool:
	return _forced or is_channeling()


## True while the entity's own controls are switched off (feared, stunned or mid-dash).
func is_disabled() -> bool:
	return _forced or is_feared() or is_stunned()


func has_effect(id: String) -> bool:
	for e in _effects:
		if e["id"] == id:
			return true
	return false


## Registers a cosmetic stack thumbnail (Grit, Tide, ...). The ability keeps it
## updated; clear_badge() removes it when the stacks end.
func set_badge(id: String, label: String, color: Color, stacks: int, time_left: float, duration: float) -> void:
	_badges[id] = {
		"label": label, "color": color, "stacks": maxi(stacks, 1),
		"time_left": maxf(time_left, 0.0), "duration": maxf(duration, 0.01),
	}


func clear_badge(id: String) -> void:
	_badges.erase(id)


## Everything the status UI should show, ordered debuffs-first. Each entry:
## {key, label, color, stacks, fraction}. `fraction` is the remaining duration.
func active_statuses() -> Array[Dictionary]:
	var entries: Dictionary = {}
	for e in _effects:
		var key := _effect_key(int(e["type"]))
		if key == "":
			continue
		var duration := maxf(float(e.get("duration", 1.0)), 0.01)
		var fraction := clampf(float(e["time_left"]) / duration, 0.0, 1.0)
		if not entries.has(key) or fraction > float(entries[key]["fraction"]):
			var info := StatusVisuals.info(key)
			entries[key] = {
				"key": key, "label": info["label"], "color": info["color"],
				"stacks": 1, "fraction": fraction,
			}
	var out: Array[Dictionary] = []
	for key in entries:
		out.append(entries[key])
	if not _poisons.is_empty():
		var poison := StatusVisuals.info("poison")
		out.append({"key": "poison", "label": poison["label"], "color": poison["color"], "stacks": 1, "fraction": 1.0})
	for id in _stat_buffs:
		var b: Dictionary = _stat_buffs[id]
		var duration := maxf(float(b.get("duration", 1.0)), 0.01)
		out.append({
			"key": "buff:" + str(id),
			"label": StatusVisuals.label_for("buff:" + str(id), str(b.get("label", ""))),
			"color": StatusVisuals.BUFF_COLOR,
			"stacks": 1,
			"fraction": clampf(float(b["time_left"]) / duration, 0.0, 1.0),
		})
	for id in _badges:
		var b: Dictionary = _badges[id]
		var duration := maxf(float(b.get("duration", 1.0)), 0.01)
		out.append({
			"key": "badge:" + str(id),
			"label": StatusVisuals.label_for("badge:" + str(id), str(b.get("label", ""))),
			"color": b.get("color", StatusVisuals.BUFF_COLOR),
			"stacks": maxi(int(b.get("stacks", 1)), 1),
			"fraction": clampf(float(b.get("time_left", 0.0)) / duration, 0.0, 1.0),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return StatusVisuals.priority(str(a["key"])) < StatusVisuals.priority(str(b["key"]))
	)
	return out


func _effect_key(type: int) -> String:
	match type:
		Type.SLOW:
			return "slow"
		Type.FEAR:
			return "fear"
		Type.ATTACK_SPEED:
			return "as"
		Type.STUN:
			return "stun"
		Type.KNOCKUP:
			return "knockup"
		Type.MOVE_SPEED:
			return "ms"
		Type.SLOW_IMMUNE:
			return "slow_immune"
		Type.ROOT:
			return "root"
		Type.BLIND:
			return "blind"
		Type.CHANNEL:
			return "channel"
		Type.DODGE:
			return "dodge"
		Type.STEALTH:
			return "stealth"
	return ""


func slow_amount() -> float:
	if is_slow_immune():
		return 0.0
	var strongest := 0.0
	for e in _effects:
		if e["type"] == Type.SLOW:
			strongest = maxf(strongest, float(e["value"]))
	return strongest


func move_speed_bonus() -> float:
	var total := 0.0
	for e in _effects:
		if e["type"] == Type.MOVE_SPEED:
			total += float(e["value"])
	return total


func attack_speed_bonus() -> float:
	var total := 0.0
	for e in _effects:
		if e["type"] == Type.ATTACK_SPEED:
			total += float(e["value"])
	return total


## Direction to run while feared: away from the most recent fear's source.
func fear_direction() -> Vector3:
	var origin := _body.global_position
	for e in _effects:
		if e["type"] == Type.FEAR:
			origin = e["origin"]
	var dir := _body.global_position - origin
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return Vector3.RIGHT
	return dir.normalized()


# ---- Internals ----

func _add(type: Type, value: float, duration: float, id: String, origin: Vector3) -> void:
	if _stats == null or _stats.is_dead or duration <= 0.0:
		return
	if id != "":
		for i in range(_effects.size() - 1, -1, -1):
			if _effects[i]["id"] == id:
				_effects.remove_at(i)
	_effects.append({"type": type, "value": value, "time_left": duration, "duration": duration, "id": id, "origin": origin})
	_recompute()


func _has(type: Type) -> bool:
	for e in _effects:
		if e["type"] == type:
			return true
	return false


func _recompute() -> void:
	if _stats:
		_stats.move_speed_mult = (1.0 - slow_amount()) * (1.0 + move_speed_bonus())
		# Attack speed buffs are bonus attack speed, added with levels and other bonuses (like League).
		_stats.set_modifier("status_effects", {StatsComponent.Stat.ATTACK_SPEED: attack_speed_bonus()} if attack_speed_bonus() != 0.0 else {})
	_update_label()


func _physics_process(delta: float) -> void:
	if not _effects.is_empty():
		var changed := false
		for i in range(_effects.size() - 1, -1, -1):
			_effects[i]["time_left"] = float(_effects[i]["time_left"]) - delta
			if float(_effects[i]["time_left"]) <= 0.0:
				_effects.remove_at(i)
				changed = true
		if changed:
			_recompute()
		_update_knockup_visual()
	if not _poisons.is_empty():
		_step_poisons(delta)
	if _bleed_stacks > 0:
		_step_bleed(delta)
	if not _stat_buffs.is_empty():
		_step_stat_buffs(delta)
	if _forced:
		_step_forced_move(delta)


func _step_stat_buffs(delta: float) -> void:
	for id in _stat_buffs.keys():
		var b: Dictionary = _stat_buffs[id]
		b["time_left"] = float(b["time_left"]) - delta
		if float(b["time_left"]) <= 0.0:
			remove_stat_buff(str(id))


func _step_poisons(delta: float) -> void:
	for i in range(_poisons.size() - 1, -1, -1):
		if i >= _poisons.size():
			continue
		var p := _poisons[i]
		p["tick_left"] = float(p["tick_left"]) - delta
		if float(p["tick_left"]) > 0.0:
			continue
		p["tick_left"] = float(p["tick_left"]) + float(p["tick"])
		p["ticks_left"] = int(p["ticks_left"]) - 1
		if int(p["ticks_left"]) <= 0:
			_poisons.remove_at(i)
		var src_id := int(p["source_id"])
		var src := instance_from_id(src_id) as Node if src_id != 0 and is_instance_id_valid(src_id) else null
		if _stats and not _stats.is_dead:
			_stats.take_magic_damage(float(p["per_tick"]), src)
		if _poisons.is_empty():
			_update_label()
			return


func _step_bleed(delta: float) -> void:
	_bleed_timer -= delta
	while _bleed_timer <= 0.0 and _bleed_stacks > 0:
		_bleed_timer += BLEED_TICK
		_bleed_stacks -= 1
		var src: Node = null
		if _bleed_source_id != 0 and is_instance_id_valid(_bleed_source_id):
			src = instance_from_id(_bleed_source_id) as Node
		if _stats and not _stats.is_dead:
			_stats.take_true_damage(_stats.get_max_health() * BLEED_HP_RATIO, src)
		if _stats and _stats.is_dead:
			break
	_sync_bleed()
	_update_bleed_badge()


## While any Bleed stacks remain, all healing on the target is reduced.
func _sync_bleed() -> void:
	if _stats:
		_stats.healing_mult = BLEED_HEALING_MULT if _bleed_stacks > 0 else 1.0


## Mirror the stack count onto the target's status strip.
func _update_bleed_badge() -> void:
	if _bleed_stacks <= 0:
		clear_badge("bleed")
		return
	set_badge("bleed", "BLE", BLEED_COLOR, _bleed_stacks, float(_bleed_stacks), float(BLEED_MAX_STACKS))


func _step_forced_move(delta: float) -> void:
	var to := _forced_to - _body.global_position
	to.y = 0.0
	var step := _forced_speed * delta
	if to.length() <= step:
		_body.global_position = _forced_to
		stop_forced_move()
		return
	var dir := to.normalized()
	_body.global_position += dir * step
	if _body.has_method("_on_forced_move"):
		_body.call("_on_forced_move", dir, delta)


## Lifts the model in an arc while knocked up, and puts it back down after.
func _update_knockup_visual() -> void:
	if _visual == null or not is_instance_valid(_visual):
		return
	var lift := 0.0
	for e in _effects:
		if e["type"] == Type.KNOCKUP:
			var total := maxf(float(e["value"]), 0.01)
			var k := clampf(1.0 - float(e["time_left"]) / total, 0.0, 1.0)
			lift = maxf(lift, KNOCKUP_HEIGHT * sin(k * PI))
	_visual.position.y = _visual_base_y + lift


func _update_label() -> void:
	if _label == null:
		return
	var parts: PackedStringArray = []
	var color := Color.WHITE
	if attack_speed_bonus() > 0.0:
		parts.append("+%d%% AS" % roundi(attack_speed_bonus() * 100.0))
		color = HASTE_COLOR
	for id in _stat_buffs:
		var buff_label := str(_stat_buffs[id]["label"])
		if buff_label != "":
			parts.append(buff_label)
			color = BUFF_COLOR
	if move_speed_bonus() > 0.0:
		parts.append("+%d%% MS" % roundi(move_speed_bonus() * 100.0))
		color = SPEED_COLOR
	if is_slow_immune():
		parts.append("Unslowable")
		color = SPEED_COLOR
	if slow_amount() > 0.0:
		parts.append("Slowed")
		color = SLOW_COLOR
	if is_poisoned():
		parts.append("Poisoned")
		color = POISON_COLOR
	if is_feared():
		parts.append("Feared")
		color = FEAR_COLOR
	if _has(Type.STUN):
		parts.append("Stunned")
		color = STUN_COLOR
	if is_knocked_up():
		parts.append("Airborne")
		color = KNOCKUP_COLOR
	if is_rooted():
		parts.append("Rooted")
		color = SLOW_COLOR
	if is_blinded():
		parts.append("Blinded")
		color = Color(0.8, 0.7, 0.5)
	if is_dodging():
		parts.append("Smoke")
		color = Color(0.7, 0.7, 0.8)
	if is_stealthed():
		parts.append("Cloaked")
		color = Color(0.55, 0.8, 1.0)
	if _bleed_stacks > 0:
		parts.append("Bleeding %d" % _bleed_stacks)
		color = BLEED_COLOR
	if is_channeling():
		parts.append("Charging")
		color = HASTE_COLOR
	_label.text = "  ".join(parts)
	_label.modulate = color
	_label.visible = not parts.is_empty()
