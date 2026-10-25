class_name MatchLog
extends RefCounted
## Records one match: the seed and starting setup, every command applied (with
## the tick it ran on), every hit and death, and a checksum of the game state
## every CHECK_EVERY ticks. Saved as JSON when the match ends.
##
## Two uses:
##   - Replays: the seed + setup + commands are everything that drives the
##     simulation, so playing them back should rebuild the same match. The
##     checksums show the first tick where a replay goes out of sync.
##     See MatchReplay and ProtoGame (--replay=<file>).
##   - Diagnostics: who dealt how much damage to what, and with what.
##     tools/match_report.gd prints a breakdown of a saved log.
##
## Hits are stored as arrays (field names in "hit_fields") to keep files small.
## Units are stored once in "units" (id -> label, kind, team); hits and deaths
## refer to them by unit id. Id 0 = unknown (e.g. a shot whose shooter died).

## 2: champions are stored per seat ("seats", "player_seat") and commands
## carry the seat that sent them. MatchReplay still reads version 1 logs.
const VERSION := 2
## Ticks between state checksums (60 = once a second at the default tick rate).
const CHECK_EVERY := 30
const DIR_IN_PROJECT := "res://match_logs"
const DIR_IN_USER := "user://match_logs"
const HIT_FIELDS := ["tick", "source", "victim", "hp_lost", "dealt", "damage_type", "auto_attack", "cause"]
const DAMAGE_TYPES := ["physical", "magic", "true"]

var data: Dictionary = {}
var saved_path: String = ""

var _game: ProtoGame
## Unit ids already written to data["units"].
var _known: Dictionary[int, bool] = {}
## HP a unit just lost (from `damaged`), waiting for its `hit_taken` to log it.
var _pending_hp: Dictionary[int, float] = {}
var _can_trace: bool = Engine.has_method("capture_script_backtraces")
## Set around a damage call to name its cause directly, for code shared by several
## abilities (one projectile script fired by different spells). Empty = read the stack.
static var cause_override: String = ""


func _init(game: ProtoGame, p_seed: int) -> void:
	_game = game
	data = {
		"version": VERSION,
		"seed": p_seed,
		"tick_rate": Engine.physics_ticks_per_second,
		"started": Time.get_datetime_string_from_system(),
		"seats": [],
		"player_seat": 0,
		"setup": {},
		"units": {},
		"commands": [],
		"events": [],
		"hit_fields": HIT_FIELDS,
		"hits": [],
		"deaths": [],
		"checks": [],
		"result": {},
	}


## Team, champion, bot flag and loadout per seat. Called once the champions exist.
func record_seats() -> void:
	var seats := []
	for s in _game.seats.size():
		var champ: CharacterBody3D = _game.champions.get(s)
		var gear: Equipment = champ.get_node_or_null("Equipment") as Equipment if champ else null
		seats.append({
			"team": _game.seat_team(s),
			"champion": _game.seat_champion_id(s),
			"bot": champ.has_method("_brain") if champ else true,
			"loadout": gear.loadout.duplicate() if gear and "loadout" in gear else {},
		})
	data["seats"] = seats
	data["player_seat"] = _game.player_seat


## Everything set up before the first tick that commands don't cover: drafts,
## gold, spawners already on the boards, frozen champions.
func record_setup() -> void:
	var gold := {}
	var boards := {}
	var frozen := {}
	for team: int in [_game.player_team, _game.enemy_team]:
		gold[str(team)] = _game._gold.get(team, 0.0)
	for s: int in _game.spawner_rolls:
		var board := []
		for slot: Dictionary in _game.spawner_rolls[s].slots:
			# A copy: the board keeps changing after this, the setup must not.
			board.append({"id": slot["id"], "upgrades": (slot["upgrades"] as Array).duplicate()})
		boards[str(s)] = board
	for s: int in _game.champions:
		frozen[str(s)] = _game.champions[s].process_mode == Node.PROCESS_MODE_DISABLED
	data["setup"] = {"gold": gold, "boards": boards, "frozen_champions": frozen}


func record_command(tick: int, seat: int, cmd: Dictionary, problem: String) -> void:
	data["commands"].append([tick, seat, encode(cmd), problem])


## Things that change the match but aren't commands (e.g. "wave": every
## spawner sent its minions). For reading the log; replays don't need them.
func record_event(tick: int, kind: String) -> void:
	data["events"].append([tick, kind])


func record_check(tick: int, checksum: int, values: PackedFloat64Array) -> void:
	# A few readable numbers next to the hash help find what drifted.
	data["checks"].append([tick, checksum, Array(values.slice(0, 12))])


func record_result(winner: int, tick: int) -> void:
	data["result"] = {
		"winner": winner,
		"end_tick": tick,
		"waves": _game.wave_number,
		"kills": {str(_game.player_team): _game.team_score(_game._kills, _game.player_team), str(_game.enemy_team): _game.team_score(_game._kills, _game.enemy_team)},
	}


# ---- Hits and deaths ----

## Starts logging hits and the death of `entity`.
func track(entity: Node) -> void:
	var st := EntityData.get_stats_of(entity)
	if st == null:
		return
	_note_unit(entity)
	st.damaged.connect(_on_damaged.bind(entity))
	st.hit_taken.connect(_on_hit.bind(entity))
	st.died.connect(_on_died.bind(entity))


func _on_damaged(amount: float, _source: Node, victim: Node) -> void:
	_pending_hp[EntityData.id_of(victim)] = amount


func _on_hit(dealt: float, type: int, source: Node, from_attack: bool, victim: Node) -> void:
	var vid := EntityData.id_of(victim)
	var hp := float(_pending_hp.get(vid, 0.0))
	_pending_hp.erase(vid)
	var sid := _note_unit(source)
	data["hits"].append([_game.sim_tick, sid, vid, snappedf(hp, 0.01), snappedf(dealt, 0.01), type, 1 if from_attack else 0, _cause()])


func _on_died(victim: Node) -> void:
	var killer := 0
	if victim.has_meta("last_hitter"):
		killer = _note_unit(instance_from_id(int(victim.get_meta("last_hitter"))) as Node)
	data["deaths"].append([_game.sim_tick, EntityData.id_of(victim), killer])


## Adds `node` to the unit table if it's new. Returns its unit id (0 if none).
func _note_unit(node: Node) -> int:
	var id := EntityData.id_of(node)
	if id == 0 or _known.has(id):
		return id
	_known[id] = true
	data["units"][str(id)] = [label_of(node), kind_name(node), _game.team_of(node)]
	return id


func label_of(node: Node) -> String:
	if node is ProtoMinion:
		return (node as ProtoMinion).minion_id
	if node is UnioneerTurret:
		return "unioneer_turret"
	if node is ProtoStructure:
		return (node as ProtoStructure).display_name.to_lower().replace(" ", "_")
	if node is ProtoJungleMonster:
		return "camp_" + (node as ProtoJungleMonster).camp_id
	var seat := _game.seat_of(node)
	if seat >= 0:
		return _game.seat_champion_id(seat)
	return str(node.name)


func kind_name(node: Node) -> String:
	if node is ProtoMinion or node is UnioneerTurret:
		return "minion"
	if node is ProtoStructure:
		return "structure"
	if node is ProtoJungleMonster:
		return "jungle"
	if _game.champions.values().has(node):
		return "champion"
	return "other"


## What dealt the damage: the first script frame outside the damage plumbing,
## as "file:function" (e.g. "thrown_knife:_hit", "entity:deal_attack_damage").
## Read from the call stack, so no ability has to report it.
func _cause() -> String:
	if cause_override != "":
		return cause_override
	if not _can_trace:
		return ""
	for bt: ScriptBacktrace in Engine.capture_script_backtraces(false):
		for i in bt.get_frame_count():
			var file := bt.get_frame_file(i).get_file().get_basename()
			if file == "match_log" or file == "stats_component":
				continue
			return "%s:%s" % [file, bt.get_frame_function(i)]
	return ""


# ---- Saving ----

## Writes the log as JSON. Returns the absolute path ("" on failure).
func save(file_name: String = "") -> String:
	var dir := DIR_IN_PROJECT if OS.has_feature("editor") else DIR_IN_USER
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		dir = DIR_IN_USER
		DirAccess.make_dir_recursive_absolute(dir)
	if dir == DIR_IN_PROJECT and not FileAccess.file_exists(dir + "/.gdignore"):
		# Keep Godot from importing the logs as project resources.
		FileAccess.open(dir + "/.gdignore", FileAccess.WRITE)
	if file_name == "":
		var stamp := str(data["started"]).replace(":", "-").replace("T", "_")
		var champs := []
		for s: Dictionary in data["seats"]:
			champs.append(s["champion"])
		file_name = "%s_%s_seed%d.json" % [stamp, "_vs_".join(champs), int(data["seed"])]
	var path := dir + "/" + file_name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Couldn't write match log %s" % path)
		return ""
	f.store_string(JSON.stringify(data, "", false, true))
	f.close()
	saved_path = ProjectSettings.globalize_path(path)
	return saved_path


static func load_file(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("Couldn't read match log %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Match log %s isn't valid JSON" % path)
		return {}
	return parsed


# ---- Command encoding ----
# Commands hold Vector3 / Vector2i, which JSON can't. They're written as
# {"v3": [x, y, z]} / {"v2i": [q, r]} and turned back on load.

static func encode(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR3:
			return {"v3": [v.x, v.y, v.z]}
		TYPE_VECTOR2I:
			return {"v2i": [v.x, v.y]}
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = encode(v[k])
			return out
		TYPE_ARRAY:
			return (v as Array).map(encode)
	return v


static func decode(v: Variant) -> Variant:
	if v is Dictionary:
		if v.has("v3"):
			return Vector3(v["v3"][0], v["v3"][1], v["v3"][2])
		if v.has("v2i"):
			return Vector2i(int(v["v2i"][0]), int(v["v2i"][1]))
		var out := {}
		for k in v:
			out[k] = decode(v[k])
		return out
	if v is Array:
		return (v as Array).map(decode)
	return v


## A decoded command, with the numeric fields JSON turned into floats made ints again.
static func decode_command(v: Variant) -> Dictionary:
	var cmd: Dictionary = decode(v)
	for k in ["type", "slot", "target"]:
		if cmd.has(k):
			cmd[k] = int(cmd[k])
	return cmd
