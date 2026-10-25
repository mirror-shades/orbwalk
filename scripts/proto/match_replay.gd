class_name MatchReplay
extends RefCounted
## Plays a saved MatchLog back. ProtoGame takes its setup from here, ignores
## commands from the player and bots, and instead runs the recorded commands on
## the ticks they originally ran. At every checkpoint the live game state is
## compared with the recorded checksum; the first mismatch is reported as a
## desync (the replay no longer matches the original match).

var recording: Dictionary = {}
var path: String = ""
## The recorded seats: [{team, champion, bot, loadout}, ...] (see MatchLog).
var _seats: Array = []
var _player_seat: int = 0
## tick -> [[seat, cmd], ...] in the order they originally ran.
var _commands: Dictionary[int, Array] = {}
## tick -> [checksum, readable values]
var _checks: Dictionary[int, Array] = {}
var end_tick: int = 0

var checks_matched: int = 0
var desync_tick: int = -1
var finished: bool = false


static func open(p_path: String) -> MatchReplay:
	var log_data := MatchLog.load_file(p_path)
	if log_data.is_empty():
		return null
	var r := MatchReplay.new()
	r.path = p_path
	r.recording = log_data
	# Version 1 logs had one champion per team and commands keyed by team.
	# Turn each team into a seat (in team order, as the match numbers them).
	var team_to_seat := {}
	if log_data.has("seats"):
		r._seats = log_data["seats"]
		r._player_seat = int(log_data.get("player_seat", 0))
	else:
		var keys: Array = log_data.get("teams", {}).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a) < int(b))
		for k in keys:
			var info: Dictionary = log_data["teams"][k].duplicate()
			info["team"] = int(k)
			team_to_seat[int(k)] = r._seats.size()
			r._seats.append(info)
		var setup: Dictionary = log_data.get("setup", {})
		var frozen := {}
		for k in setup.get("frozen_champions", {}):
			if team_to_seat.has(int(k)):
				frozen[str(team_to_seat[int(k)])] = setup["frozen_champions"][k]
		setup["frozen_champions"] = frozen
		# The old match always put the player on Blue (TEAM_1).
		r._player_seat = int(team_to_seat.get(EntityDefinition.Team.TEAM_1, 0))
	for c: Array in log_data["commands"]:
		var tick := int(c[0])
		if not r._commands.has(tick):
			r._commands[tick] = []
		var seat := int(team_to_seat.get(int(c[1]), int(c[1]))) if not team_to_seat.is_empty() else int(c[1])
		r._commands[tick].append([seat, MatchLog.decode_command(c[2])])
	for c: Array in log_data["checks"]:
		r._checks[int(c[0])] = [int(c[1]), c[2]]
	var result: Dictionary = log_data.get("result", {})
	r.end_tick = int(result.get("end_tick", 0))
	if r.end_tick == 0 and not log_data["checks"].is_empty():
		r.end_tick = int(log_data["checks"][-1][0])
	return r


func match_seed() -> int:
	return int(recording["seed"])


## [{team, champion, bot, loadout}, ...], one per seat.
func seats() -> Array:
	return _seats


func player_seat() -> int:
	return _player_seat


func seat_info(seat: int) -> Dictionary:
	return _seats[seat] if seat >= 0 and seat < _seats.size() else {}


## The seat's item loadout. JSON turned its slot keys (ints) into strings.
func loadout(seat: int) -> Dictionary:
	var out := {}
	var saved: Dictionary = seat_info(seat).get("loadout", {})
	for k in saved:
		out[int(k) if str(k).is_valid_int() else k] = saved[k]
	return out


func setup() -> Dictionary:
	return recording["setup"]


## The commands that ran on `tick`, as [[seat, cmd], ...].
func commands_at(tick: int) -> Array:
	return _commands.get(tick, [])


## Compares the live state with the recording at `tick`. Prints the first desync.
func check(tick: int, checksum: int, values: PackedFloat64Array) -> void:
	if not _checks.has(tick) or desync_tick >= 0:
		return
	var expected: Array = _checks[tick]
	if int(expected[0]) == checksum:
		checks_matched += 1
		return
	desync_tick = tick
	print("[replay] DESYNC at tick %d (%.1fs) after %d matching checkpoints" % [tick, tick / float(Engine.physics_ticks_per_second), checks_matched])
	print("[replay]   recorded: %s" % [expected[1]])
	print("[replay]   replayed: %s" % [Array(values.slice(0, 12))])


## One line saying whether the replay matched.
func verdict() -> String:
	if desync_tick >= 0:
		return "[replay] FAILED: desync at tick %d; %d checkpoints matched before it" % [desync_tick, checks_matched]
	return "[replay] OK: all %d checkpoints matched (to tick %d)" % [checks_matched, end_tick]
