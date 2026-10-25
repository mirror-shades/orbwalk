extends Node
## Pre-match settings chosen in the main menu. An autoload, so it survives the
## scene change from the menu into the match and the reload after champion select.

const MAP_1V1 := "1v1"

const MAPS: Array[Dictionary] = [
	{"id": MAP_1V1, "name": "1v1 Lane", "scene": "res://scenes/proto_1v1.tscn"},
]

## Most slots one team can have in the lobby.
const MAX_TEAM_SIZE := 4
const TEAM_NAMES: Array[String] = ["Blue Team", "Red Team"]

var map_id: String = MAP_1V1
## Lobby slots: teams[0] is Blue, teams[1] is Red. Each slot is either
## {"kind": "player"} or {"kind": "bot", "champion": "random" or a champion id}.
## Exactly one slot is the player. Teams may be lopsided, 1 to MAX_TEAM_SIZE each.
## The match spawns one champion per slot.
var teams: Array = default_teams()
## The opponent slot supports bots only for now.
var opponent_is_bot: bool = true
## Without the lobby: the single bot opponent ("random" or a champion id; empty = default).
var opponent_champion: String = ""
## The player's champion. Empty means the champion select screen should open.
var player_champion: String = ""
## Champion per match seat as the match last resolved it (random bots rolled).
## Kept across the champion-select reload; cleared for every new lobby setup.
var seat_champions: Array = []
## The player's pre-match equipment (slot -> item id).
var loadout: Dictionary = {}
## True when the menu configured this match (opponent locked to a bot).
var configured: bool = false


static func default_teams() -> Array:
	return [
		[{"kind": "player"}],
		[{"kind": "bot", "champion": "random"}],
	]


## Index of the team the player is on (0 = Blue, 1 = Red).
func player_side() -> int:
	for side in teams.size():
		for slot: Dictionary in teams[side]:
			if slot["kind"] == "player":
				return side
	return 0


func configure(p_map_id: String, p_teams: Array) -> void:
	map_id = p_map_id
	teams = p_teams.duplicate(true)
	opponent_is_bot = true
	# The match spawns every slot in `teams`; the single opponent is only for
	# matches started without the lobby.
	opponent_champion = ""
	# A new match starts with champion select, even if one was played already.
	player_champion = ""
	seat_champions = []
	loadout = {}
	configured = true


## Forget the in-match picks (used when returning to the menu).
func clear_match() -> void:
	configured = false
	player_champion = ""
	seat_champions = []
	loadout = {}


func map_scene() -> String:
	for m in MAPS:
		if str(m["id"]) == map_id:
			return str(m["scene"])
	return str(MAPS[0]["scene"])


func map_name() -> String:
	for m in MAPS:
		if str(m["id"]) == map_id:
			return str(m["name"])
	return str(MAPS[0]["name"])
