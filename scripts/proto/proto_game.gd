class_name ProtoGame
extends Node3D
## 1v1 prototype of the core loop: one lane, you (blue, left) vs a bot (red, right).
##
## Sleep phase: no minions. Build spawners on your hex grid (only now).
## Awake phase: every spawner releases its minion at once and the waves fight
## down the lane. It ends when the last minion dies (or after a time cap).
## Destroy the outer tower, then the inner tower, then the orb to win.
##
## The project starts in the menu (scenes/menu.tscn). Open this scene directly and
## press F6 to skip it, or run the project with -- --quick-start.
## Run with  -- --spectate  to watch two bots play each other.

## A queued command was applied at the start of a tick (see execute_command).
signal command_applied(seat: int, cmd: Dictionary)
## A queued command was refused; `reason` says why. Sent to whoever is listening
## for that seat (the PlayerController for a person).
signal command_refused(seat: int, cmd: Dictionary, reason: String)

const KIND_MINION := 0
const KIND_CHAMPION := 1
const KIND_STRUCTURE := 2

const GOLD_COLOR := Color(1.0, 0.85, 0.3)
const LAST_HIT_GOLD_COLOR := Color(1.0, 0.95, 0.6)

## Match lighting.
const DAY_LOOK := {
	"sun_energy": 1.2,
	"sun_color": Color(1.0, 0.97, 0.9),
	"ambient_energy": 0.8,
	"sky_top": Color(0.35, 0.55, 0.85),
	"sky_horizon": Color(0.72, 0.8, 0.9),
	"ground_horizon": Color(0.72, 0.8, 0.9),
	"ground_bottom": Color(0.2, 0.25, 0.2),
}

const AIChampionScript := preload("res://scripts/proto/ai_champion.gd")
const TREE_MODEL := "res://assets/models/buildings/FBX/Resource_PineTree_Group.fbx"
const OUTER_TOWER_MODEL := "res://assets/models/buildings/FBX/WatchTower_SecondAge_Level1.fbx"
const INNER_TOWER_MODEL := "res://assets/models/buildings/FBX/WatchTower_SecondAge_Level2.fbx"

enum Phase { PLAY, OVER }

@export_group("Lane")
## Distance from the middle of the lane to each end. The orb sits 6 from the end.
@export var lane_half_length: float = 85.0
## Distance from the middle of the lane to each team's towers and build grid.
@export var outer_tower_distance: float = 24.0
@export var inner_tower_distance: float = 44.0
@export var grid_distance: float = 62.0
@export var lane_half_width: float = 11.0
@export var hex_size: float = 1.7
@export var grid_cols: int = 5
@export var grid_rows: int = 5

@export_group("Jungle")
## How far north / south of the lane center each jungle camp sits.
@export var jungle_camp_distance: float = 23.0
## Radius of the open clearing around each camp.
@export var jungle_clearing_radius: float = 7.0
## Half the width of the path from the lane into each clearing.
@export var jungle_path_half_width: float = 3.5

@export_group("Waves")
## Seconds before the first wave. After that every spawner sends a wave every wave_interval.
@export var first_wave_time: float = 10.0
@export var wave_interval: float = 30.0
## Base minions each spawner sends every wave, unless the minion overrides it with "count".
@export var minions_per_spawner: int = 2
## Every minion's health and attack damage is multiplied by this.
@export var minion_stat_mult: float = 1.5

@export_group("Economy")
@export var start_gold: int = 300
## Spawners now come from level-up rolls, so gold has nothing to buy yet. It's
## still earned the old way (passive income, kills).
@export var passive_gold_per_sec: float = 1.5
## Minion rewards come from what their spawner's wave is worth (ProtoConfig
## SPAWNERS "value"). Each wave a spawner's minions carry, in total, value x
## these ratios, split evenly between however many it sent. Gold goes to the killer's team when a
## champion or minion lands the kill (towers and the orb give nothing); XP goes to
## the enemy champion if it's nearby.
@export var minion_gold_ratio: float = 0.1
@export var minion_xp_ratio: float = 0.25
## Extra gold when your champion lands the killing blow (last hit).
@export var last_hit_bonus_gold: int = 8
## Gold moved off a minion's standard reward when a champion does not last-hit it.
@export var last_hit_shift_gold: int = 5
@export var champion_kill_gold: int = 100
## Gold for champions that damaged the victim but did not land the killing blow.
@export var assist_gold: int = 40
## XP for the killer of an enemy champion, before the level-gap adjustment.
@export var champion_kill_xp: float = 300.0
## Kill XP changes by this much per level the victim is above (+) or below (-) the killer.
@export var kill_xp_per_level_gap: float = 0.15
## Seconds dead: respawn_base + respawn_per_minute x match minutes, capped at respawn_max.
@export var respawn_base: float = 8.0
@export var respawn_per_minute: float = 1.0
@export var respawn_max: float = 35.0
## Towers and the orb deal this much more damage per match minute (0.05 = +5%
## a minute), so they keep up with growing waves.
@export var structure_damage_per_minute: float = 0.05
## The most that bonus can reach (0.5 = +50%, after 10 minutes). Without a cap,
## late towers and the orb melt whole waves and a won lane can't finish.
@export var structure_damage_max_bonus: float = 0.5

@export_group("Rules")
## The design doc leaves this TBD. Turn off to make minions ignore champions.
@export var minions_target_champions: bool = true
@export var enemy_champion_enabled: bool = true
@export var enemy_builder_enabled: bool = true
## Both sides are bots; you just watch. Also enabled by the --spectate command line arg.
@export var spectate: bool = false
## Hide what your team can't see. Always off while spectating.
@export var fog_of_war: bool = true
## Champion ids from ProtoConfig.CHAMPIONS. The enemy can also be "random".
## Overridden by the champion select screen and by --champ=<id> / --enemy=<id>.
@export var player_champion_id: String = "cats_paw"
@export var enemy_champion_id: String = "random"
## Show the champion select screen the first time the scene runs.
@export var show_champion_select: bool = true
## Keep the mouse inside the game window (for edge-panning the camera). F2 toggles it.
@export var confine_mouse: bool = true

var player_team: int = EntityDefinition.Team.TEAM_1
var enemy_team: int = EntityDefinition.Team.TEAM_2

var phase: Phase = Phase.PLAY
## Seconds until the next wave spawns.
var wave_time_left: float = 0.0
## Waves sent so far.
var wave_number: int = 0
## Simulation ticks since the match started (counts while unpaused).
var sim_tick: int = 0
## Commands waiting for the next tick: [{seat, cmd, tick}] in arrival order.
var _command_queue: Array[Dictionary] = []
## Most commands one seat may have waiting at once; more are refused (spam guard).
const MAX_QUEUED_PER_SEAT := 32
## Seeds all game randomness (SimRng). -1 picks one at random; --seed=<n> sets it.
## The same seed and the same commands play out the same match.
var match_seed: int = -1
## Records this match (commands, hits, checksums). Null while replaying.
var match_log: MatchLog
## Set when playing back a saved log (--replay=<file>). Live commands are ignored.
var replay: MatchReplay
## Unit id the first unit of this match got (replays must hand out the same ids).
var _unit_id_base: int = 1

var minions: Array[ProtoMinion] = []
var structures: Array[ProtoStructure] = []
var grids: Dictionary[int, ProtoHexGrid] = {}
## Every champion in the match has a seat (0, 1, 2, ...), numbered in lobby
## order: Blue's slots first, then Red's. seats[seat] = {"team", "champion"
## (id), "bot"}. Champion state below is keyed by seat, not by team, because a
## team can hold several champions.
var seats: Array[Dictionary] = []
## seat -> champion node (only seats that have spawned).
var champions: Dictionary[int, CharacterBody3D] = {}
## seat -> that player's spawner board and banked rolls (docs/spawner_system.md).
var spawner_rolls: Dictionary[int, SpawnerRolls] = {}
## seat -> its spawner buildings, in slot order (matches spawner_rolls[seat].slots).
var seat_spawners: Dictionary[int, Array] = {}
## The local player's seat. While spectating it's still the seat the camera
## follows and the HUD shows, even though a bot plays it.
var player_seat: int = 0
var player_champion: CharacterBody3D
## The champion whose info card is open (left-click or attack one); -1 = none.
var selected_seat: int = -1

var _gold: Dictionary[int, float] = {}
## seat -> seconds until that champion respawns.
var _respawn_left: Dictionary[int, float] = {}
var _orbs: Dictionary[int, ProtoStructure] = {}
var _builders: Array[ProtoAIBuilder] = []
var _camera: ProtoCamera
var _hud: ProtoHUD
var _controller: PlayerController
## Living jungle monster per camp id (missing while the camp is respawning).
var _camps: Dictionary[String, ProtoJungleMonster] = {}
var _camp_respawn_left: Dictionary[String, float] = {}
## Active jungle buffs per seat: camp id -> seconds left.
var _jungle_buffs: Dictionary[int, Dictionary] = {}
## Champion kills, deaths and assists per seat. Team totals: team_score().
var _kills: Dictionary[int, int] = {}
var _deaths: Dictionary[int, int] = {}
var _assists: Dictionary[int, int] = {}
## Minions and jungle monsters each champion has killed (the "CS" on the HUD).
var _cs: Dictionary[int, int] = {}
## Lighting (set up in _build_environment).
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D

## The menu, champion select, and scene reloads all share their picks through Session.


func _ready() -> void:
	# The director ticks before every unit (lower = earlier).
	process_physics_priority = -100
	_init_seed_and_replay()
	if "--spectate" in OS.get_cmdline_user_args():
		spectate = true
	_resolve_seats()
	_gold[player_team] = float(start_gold)
	_gold[enemy_team] = float(start_gold)
	_build_environment()
	_build_ground()
	_build_structures()
	_build_grids()
	_build_navigation()
	_spawn_champions()
	_show_slots()
	for camp_id: String in ProtoConfig.JUNGLE_CAMPS:
		_spawn_camp(camp_id)
	_build_camera_and_hud()
	_build_fog()
	# A replay runs the recorded roll picks instead of live bots. Every bot seat
	# (and, while spectating, the player's seat) gets a bot that picks its rolls.
	if replay == null:
		for s in seats.size():
			var bot_seat := s != player_seat or spectate
			if bot_seat and (enemy_builder_enabled or seat_team(s) == player_team):
				_builders.append(ProtoAIBuilder.new(self, s))
	wave_time_left = first_wave_time
	_apply_mouse_confine()
	var picked_on_cmdline := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--champ="):
			picked_on_cmdline = true
	if replay == null and show_champion_select and not spectate and Session.player_champion == "" and not picked_on_cmdline:
		_open_champion_select()



## Picks the match seed (or loads the replay that sets it) and seeds all game
## randomness. Runs first in _ready, before anything random happens.
func _init_seed_and_replay() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--replay="):
			replay = MatchReplay.open(arg.trim_prefix("--replay="))
			if replay == null:
				push_error("Couldn't load the replay; playing a normal match instead.")
		elif arg.begins_with("--seed=") and match_seed < 0:
			match_seed = int(arg.trim_prefix("--seed="))
	if replay != null:
		match_seed = replay.match_seed()
		# Watch both sides with no fog, no build UI, no player control.
		spectate = true
		show_champion_select = false
		print("[replay] playing %s (seed %d)" % [replay.path, match_seed])
	elif match_seed < 0:
		var r := RandomNumberGenerator.new()
		r.randomize()
		match_seed = r.randi() & 0x7fffffff
	SimRng.reseed(match_seed)
	var base := int(replay.recording.get("unit_id_base", 1)) if replay != null else 1
	_unit_id_base = EntityData.restart_unit_ids(base)
	if replay != null and _unit_id_base != base:
		push_warning("Replay unit ids start at %d instead of %d; targeted commands will miss." % [_unit_id_base, base])
	if replay == null:
		match_log = MatchLog.new(self, match_seed)
		match_log.data["unit_id_base"] = _unit_id_base


## Decides who sits where and which champion each seat plays: from the replay,
## from the lobby (Session.teams), or a plain 1v1 when the scene runs on its own
## (or with --champ= / --enemy=).
func _resolve_seats() -> void:
	seats.clear()
	if replay != null:
		for info: Dictionary in replay.seats():
			seats.append({"team": int(info["team"]), "champion": str(info["champion"]), "bot": bool(info.get("bot", true))})
		player_seat = replay.player_seat()
	else:
		var p := player_champion_id
		var e := enemy_champion_id
		if Session.player_champion != "":
			p = Session.player_champion
		if Session.opponent_champion != "":
			e = Session.opponent_champion
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--champ="):
				p = arg.trim_prefix("--champ=")
			elif arg.begins_with("--enemy="):
				e = arg.trim_prefix("--enemy=")
		if not ProtoConfig.CHAMPIONS.has(p):
			p = "cats_paw"
		var layout: Array = Session.teams if Session.configured else _solo_layout(e)
		for side in layout.size():
			var team := EntityDefinition.Team.TEAM_1 if side == 0 else EntityDefinition.Team.TEAM_2
			for slot: Dictionary in layout[side]:
				if str(slot["kind"]) == "player":
					player_seat = seats.size()
					seats.append({"team": team, "champion": p, "bot": spectate})
				else:
					seats.append({"team": team, "champion": str(slot.get("champion", "random")), "bot": true})
		_pick_bot_champions(Session.seat_champions if Session.configured else [])
		if Session.configured:
			# Champion select reloads the scene; keep the same bots after it.
			Session.seat_champions = seats.map(func(s: Dictionary) -> String: return str(s["champion"]))
	player_team = seat_team(player_seat)
	enemy_team = other_team(player_team)


## The 1v1 used when there's no lobby: the player on Blue against one bot.
func _solo_layout(enemy_id: String) -> Array:
	var red: Array = [{"kind": "bot", "champion": enemy_id}] if enemy_champion_enabled else []
	return [[{"kind": "player"}], red]


## Gives every bot a champion nobody else on its team plays. Bots with a
## specific pick keep it unless a teammate (or the player) already has it;
## "random" bots roll from what's left. `rolled` is the result of the last
## resolve (before a champion-select reload): reused for random bots when it's
## still free, so they don't change behind the player's back.
func _pick_bot_champions(rolled: Array) -> void:
	var taken := {}
	for team: int in [EntityDefinition.Team.TEAM_1, EntityDefinition.Team.TEAM_2]:
		taken[team] = {}
	if player_seat < seats.size():
		taken[seat_team(player_seat)][str(seats[player_seat]["champion"])] = true
	# Specific picks first, so random bots can't take them.
	for random_pass: bool in [false, true]:
		for i in seats.size():
			if i == player_seat:
				continue
			var want := str(seats[i]["champion"])
			var is_random := not ProtoConfig.CHAMPIONS.has(want)
			if is_random != random_pass:
				continue
			var team_taken: Dictionary = taken[seat_team(i)]
			if is_random and i < rolled.size():
				want = str(rolled[i])
			if not ProtoConfig.CHAMPIONS.has(want) or team_taken.has(want):
				want = _random_free_champion(team_taken)
			seats[i]["champion"] = want
			team_taken[want] = true


func _random_free_champion(taken: Dictionary) -> String:
	var pool: Array = ProtoConfig.CHAMPION_ORDER.filter(func(id: String) -> bool: return not taken.has(id))
	if pool.is_empty():
		pool = ProtoConfig.CHAMPION_ORDER.duplicate()
	return str(pool[SimRng.randi_range(0, pool.size() - 1)])


func _open_champion_select() -> void:
	get_tree().paused = true
	var options: Array = []
	for id in ProtoConfig.CHAMPION_ORDER:
		options.append([id, ProtoConfig.champion_name(id), ProtoConfig.CHAMPIONS[id]["blurb"]])
	var enemy_id := enemy_champion_id
	var enemy_label := ""
	if Session.configured and Session.opponent_is_bot:
		# The lobby already picked the bots, so only the player chooses here.
		var enemies := seats_of(enemy_team)
		enemy_id = str(seats[enemies[0]]["champion"]) if not enemies.is_empty() else ""
		enemy_label = _bot_list_label()
	_hud.show_champion_select(options, str(seats[player_seat]["champion"]), enemy_id, enemy_label)
	_hud.champions_chosen.connect(_on_champions_chosen, CONNECT_ONE_SHOT)


## "Allies: Bot - X" / "Enemies: Bot - Y, Bot - Z" for champion select.
func _bot_list_label() -> String:
	var lines: PackedStringArray = []
	for team: int in [player_team, enemy_team]:
		var names: PackedStringArray = []
		for s in seats_of(team):
			if s != player_seat:
				names.append("Bot - %s" % ProtoConfig.champion_name(str(seats[s]["champion"])))
		if not names.is_empty():
			lines.append("%s: %s" % ["Allies" if team == player_team else "Enemies", ", ".join(names)])
	return "\n".join(lines)


func _on_champions_chosen(player_id: String, enemy_id: String, loadout: Dictionary) -> void:
	Session.player_champion = player_id
	if not Session.configured:
		# Without a lobby the champion select also picks the single opponent.
		Session.opponent_champion = enemy_id
	Session.loadout = loadout
	ItemCatalog.save_loadout(player_id, loadout)
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---- Seats ----

## True while the champion-select or spawner-draft screen is up.
func is_picking() -> bool:
	return _hud != null and _hud.is_picking()


## Opens the info card for `seat`'s champion (-1 closes it).
func select_seat(seat: int) -> void:
	selected_seat = seat


## [kills, deaths, assists] for a seat.
func kda_of(seat: int) -> Array:
	return [_kills.get(seat, 0), _deaths.get(seat, 0), _assists.get(seat, 0)]


func seat_team(seat: int) -> int:
	if seat < 0 or seat >= seats.size():
		return EntityDefinition.Team.NEUTRAL
	return int(seats[seat]["team"])


func seat_champion_id(seat: int) -> String:
	return str(seats[seat]["champion"]) if seat >= 0 and seat < seats.size() else ""


## Seats on `team`, in seat order.
func seats_of(team: int) -> Array[int]:
	var out: Array[int] = []
	for s in seats.size():
		if int(seats[s]["team"]) == team:
			out.append(s)
	return out


## Spawned champions on `team` (dead ones too), in seat order.
func champions_of(team: int) -> Array[CharacterBody3D]:
	var out: Array[CharacterBody3D] = []
	for s in seats_of(team):
		if champions.has(s):
			out.append(champions[s])
	return out


## The seat a champion node sits in, or -1 if it isn't a champion.
func seat_of(node: Node) -> int:
	if node == null:
		return -1
	for s: int in champions:
		if champions[s] == node:
			return s
	return -1


## Sum of a per-seat score (_kills, _deaths, _assists) over `team`.
func team_score(score: Dictionary, team: int) -> int:
	var n := 0
	for s in seats_of(team):
		n += int(score.get(s, 0))
	return n


## The closest living enemy champion of `team` to `pos`. With `seen_only`,
## champions hidden by fog are skipped.
func nearest_enemy_champion(pos: Vector3, team: int, seen_only: bool = true) -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_d := INF
	for c in champions_of(other_team(team)):
		var st := EntityData.get_stats_of(c)
		if st == null or st.is_dead or (seen_only and not FogOfWar.can_see(team, c)):
			continue
		var d := ProtoUtil.flat_distance(pos, c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


func _notification(what: int) -> void:
	# Re-apply after alt-tabbing back into the game.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_apply_mouse_confine()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Matches that end without a winner (quit, time limit) still get their log.
	_save_match_log(-1)


func _apply_mouse_confine() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED if confine_mouse else Input.MOUSE_MODE_VISIBLE


# ---- Layout helpers ----

## +1 for Blue (TEAM_1, base on the left, marches toward +X), -1 for Red.
## Fixed per team, not per player, so minions (minion.gd) and bases agree
## whichever side the player is on.
func forward_of(team: int) -> float:
	return 1.0 if team == EntityDefinition.Team.TEAM_1 else -1.0


## Which end of the lane a team's base is on (-1 = left, +1 = right).
func _side(team: int) -> float:
	return -forward_of(team)


func other_team(team: int) -> int:
	return EntityDefinition.Team.TEAM_2 if team == EntityDefinition.Team.TEAM_1 else EntityDefinition.Team.TEAM_1


## "blue" / "red", for logs and node names.
static func team_name(team: int) -> String:
	return "blue" if team == EntityDefinition.Team.TEAM_1 else "red"


func orb_x(team: int) -> float:
	return _side(team) * (lane_half_length - 6.0)


func enemy_orb_x(team: int) -> float:
	return orb_x(other_team(team))


func fountain_position(team: int) -> Vector3:
	return Vector3(_side(team) * (lane_half_length - 2.0), 0.0, 0.0)


## Where a straight spell's travel ends: the lane edge. Towers and the orb don't
## block spells (only movement is blocked by them), so this uses the lane bounds
## instead of the navmesh.
func clip_spell_to_lane(from: Vector3, to: Vector3) -> Vector3:
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := d.length()
	if length <= 0.001:
		return Vector3(from.x, 0.0, from.z)
	var dir := d / length
	var max_x := lane_half_length
	var t := length
	if absf(dir.x) > 0.0001:
		var x_wall := max_x if dir.x > 0.0 else -max_x
		t = minf(t, maxf((x_wall - from.x) / dir.x, 0.0))
	if absf(dir.z) > 0.0001:
		var z_wall := lane_half_width if dir.z > 0.0 else -lane_half_width
		t = minf(t, maxf((z_wall - from.z) / dir.z, 0.0))
	var end := from + dir * t
	end.y = 0.0
	return end


# ---- World building ----

func _build_environment() -> void:
	_environment = Environment.new()
	var env := _environment
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_material = ProceduralSkyMaterial.new()
	sky.sky_material = _sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 90.0
	add_child(_sun)

	_apply_lighting(DAY_LOOK)


func _apply_lighting(look: Dictionary) -> void:
	_sun.light_energy = float(look["sun_energy"])
	_sun.light_color = look["sun_color"]
	_environment.ambient_light_energy = float(look["ambient_energy"])
	_sky_material.sky_top_color = look["sky_top"]
	_sky_material.sky_horizon_color = look["sky_horizon"]
	_sky_material.ground_horizon_color = look["ground_horizon"]
	_sky_material.ground_bottom_color = look["ground_bottom"]


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	add_child(body)
	var size := Vector3(lane_half_length * 2.0 + 40.0, 1.0, lane_half_width * 2.0 + 40.0)
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = -0.5
	body.add_child(cs)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	floor_mesh.mesh = box
	floor_mesh.material_override = ProtoUtil.lit_material(Color(0.22, 0.34, 0.2))
	floor_mesh.position.y = -0.5
	body.add_child(floor_mesh)

	var lane := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(lane_half_length * 2.0, lane_half_width * 2.0)
	lane.mesh = plane
	lane.material_override = ProtoUtil.lit_material(Color(0.52, 0.45, 0.33))
	lane.position.y = 0.01
	add_child(lane)

	var mid := MeshInstance3D.new()
	var mid_plane := PlaneMesh.new()
	mid_plane.size = Vector2(0.4, lane_half_width * 2.0)
	mid.mesh = mid_plane
	mid.material_override = ProtoUtil.flat_material(Color(1.0, 1.0, 1.0, 0.25))
	mid.position.y = 0.02
	add_child(mid)

	for team: int in [player_team, enemy_team]:
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 5.0
		cyl.bottom_radius = 5.0
		cyl.height = 0.04
		disc.mesh = cyl
		disc.material_override = ProtoUtil.lit_material(ProtoConfig.team_color(team).darkened(0.6))
		disc.position = Vector3(fountain_position(team).x, 0.02, 0.0)
		add_child(disc)

	var dirt := ProtoUtil.lit_material(Color(0.36, 0.33, 0.24))
	for camp_id: String in ProtoConfig.JUNGLE_CAMPS:
		var center := camp_position(camp_id)
		var path := MeshInstance3D.new()
		var path_plane := PlaneMesh.new()
		var path_len := absf(center.z) - lane_half_width
		path_plane.size = Vector2(jungle_path_half_width * 2.0, path_len)
		path.mesh = path_plane
		path.material_override = dirt
		path.position = Vector3(center.x, 0.008, signf(center.z) * (lane_half_width + path_len * 0.5))
		add_child(path)
		var clearing := MeshInstance3D.new()
		var clearing_cyl := CylinderMesh.new()
		clearing_cyl.top_radius = jungle_clearing_radius
		clearing_cyl.bottom_radius = jungle_clearing_radius
		clearing_cyl.height = 0.02
		clearing.mesh = clearing_cyl
		clearing.material_override = dirt
		clearing.position = Vector3(center.x, 0.009, center.z)
		add_child(clearing)

	_plant_trees()


func _plant_trees() -> void:
	var ps := load(TREE_MODEL) as PackedScene
	if ps == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := -lane_half_length - 6.0
	while x <= lane_half_length + 6.0:
		for side: float in [-1.0, 1.0]:
			var pos := Vector3(x + rng.randf_range(-2.0, 2.0), 0.0, side * (lane_half_width + rng.randf_range(3.0, 7.0)))
			if _is_jungle_open(pos, 3.0):
				continue
			_plant_tree(ps, pos, rng)
		x += 8.0
	# A ring of trees around each clearing, open toward the lane path.
	for camp_id: String in ProtoConfig.JUNGLE_CAMPS:
		var center := camp_position(camp_id)
		for i in 14:
			var a := TAU * float(i) / 14.0
			var r := jungle_clearing_radius + rng.randf_range(2.5, 4.5)
			var pos := center + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if _is_jungle_open(pos, 3.0):
				continue
			_plant_tree(ps, pos, rng)


func _plant_tree(ps: PackedScene, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var tree := ps.instantiate() as Node3D
	ProtoUtil.fit_model(tree, rng.randf_range(4.5, 7.0))
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rng.randf() * TAU
	holder.add_child(tree)
	add_child(holder)


## Center of a jungle camp (north is -z, south is +z).
func camp_position(camp_id: String) -> Vector3:
	var side: float = ProtoConfig.JUNGLE_CAMPS[camp_id]["side"]
	return Vector3(0.0, 0.0, side * jungle_camp_distance)


## True if `pos` is on a jungle path or in a clearing (plus `margin`), so trees stay out.
func _is_jungle_open(pos: Vector3, margin: float) -> bool:
	for camp_id: String in ProtoConfig.JUNGLE_CAMPS:
		var center := camp_position(camp_id)
		if ProtoUtil.flat_distance(pos, center) < jungle_clearing_radius + margin:
			return true
		var toward_camp := signf(pos.z) == signf(center.z) and absf(pos.z) <= absf(center.z)
		if toward_camp and absf(pos.x - center.x) < jungle_path_half_width + margin:
			return true
	return false


func _build_structures() -> void:
	var order: Array[int] = [player_team, enemy_team]
	SimRng.shuffle(order)
	for team: int in order:
		var side := _side(team)
		var outer := _add_structure(team, ProtoStructure.Kind.TOWER, OUTER_TOWER_MODEL, "Outer tower", side * outer_tower_distance, null)
		var inner := _add_structure(team, ProtoStructure.Kind.TOWER, INNER_TOWER_MODEL, "Inner tower", side * inner_tower_distance, outer)
		_orbs[team] = _add_structure(team, ProtoStructure.Kind.ORB, "", "Orb", orb_x(team), inner)


func _add_structure(team: int, kind: ProtoStructure.Kind, model: String, label: String, x: float, prereq: ProtoStructure) -> ProtoStructure:
	var s := ProtoStructure.new()
	s.name = team_name(team).capitalize() + label.replace(" ", "")
	s.setup(self, kind, team, model, label)
	s.prerequisite = prereq
	s.position = Vector3(x, 0.0, 0.0)
	add_child(s)
	structures.append(s)
	_track(s)
	return s


func _build_grids() -> void:
	for team: int in [player_team, enemy_team]:
		var grid := ProtoHexGrid.new()
		grid.name = team_name(team).capitalize() + "Grid"
		grid.setup(team, int(forward_of(team)), grid_cols, grid_rows, hex_size)
		grid.position = Vector3(_side(team) * grid_distance, 0.0, 0.0)
		add_child(grid)
		grids[team] = grid


## Bakes a navmesh over the lane with holes for towers and orbs (used by champions).
func _build_navigation() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.25
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	var geo := NavigationMeshSourceGeometryData3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(lane_half_length * 2.0, 1.0, lane_half_width * 2.0)
	geo.add_mesh_array(floor_box.get_mesh_arrays(), Transform3D(Basis.IDENTITY, Vector3(0.0, -0.5, 0.0)))
	for camp_id: String in ProtoConfig.JUNGLE_CAMPS:
		var center := camp_position(camp_id)
		# Overlap the lane a little so the path joins it cleanly.
		var path_len := absf(center.z) - lane_half_width + 1.0
		var path_box := BoxMesh.new()
		path_box.size = Vector3(jungle_path_half_width * 2.0, 1.0, path_len)
		var path_z := signf(center.z) * (lane_half_width - 1.0 + path_len * 0.5)
		geo.add_mesh_array(path_box.get_mesh_arrays(), Transform3D(Basis.IDENTITY, Vector3(center.x, -0.5, path_z)))
		var clearing := CylinderMesh.new()
		clearing.top_radius = jungle_clearing_radius
		clearing.bottom_radius = jungle_clearing_radius
		clearing.height = 1.0
		clearing.radial_segments = 24
		geo.add_mesh_array(clearing.get_mesh_arrays(), Transform3D(Basis.IDENTITY, Vector3(center.x, -0.5, center.z)))
	for s in structures:
		geo.add_projected_obstruction(_circle_points(s.position, s.radius), 0.0, 4.0, true)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, geo)
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = nav_mesh
	add_child(region)


func _circle_points(center: Vector3, r: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector3(center.x + cos(a) * r, 0.0, center.z + sin(a) * r))
	return pts


## Spawns every seat's champion in a random order. Nodes update in the order
## they were added, so a fixed order would let one seat always act first.
func _spawn_champions() -> void:
	var order: Array[int] = []
	for s in seats.size():
		order.append(s)
	SimRng.shuffle(order)
	for s in order:
		var champ := _spawn_champion(s)
		if s == player_seat:
			player_champion = champ


## Where a seat's champion starts and respawns: its team's fountain, spread out
## across the lane so teammates don't stack on one point.
func seat_spawn_position(seat: int) -> Vector3:
	var team := seat_team(seat)
	var mates := seats_of(team)
	var offset := float(mates.find(seat)) - float(mates.size() - 1) * 0.5
	return fountain_position(team) + Vector3(0.0, 0.0, offset * 1.8)


func _spawn_champion(seat: int) -> CharacterBody3D:
	var team := seat_team(seat)
	var is_bot := bool(seats[seat]["bot"])
	var champion_id := seat_champion_id(seat)
	var info: Dictionary = ProtoConfig.CHAMPIONS[champion_id]
	var champ := (load(str(info["scene"])) as PackedScene).instantiate() as CharacterBody3D
	# Cat's Paw scene carries its own follow camera; the prototype uses ProtoCamera instead.
	var cam := champ.get_node_or_null("Camera3D")
	if cam:
		champ.remove_child(cam)
		cam.free()
	var def := (load(str(info["definition"])) as EntityDefinition).duplicate() as EntityDefinition
	def.team = team as EntityDefinition.Team
	# mover.gd measures range center-to-center, so give melee enough reach to hit
	# towers and orbs past their navmesh hole.
	def.stats_attack_range = maxf(def.stats_attack_range, 2.8)
	if is_bot:
		champ.set_script(AIChampionScript)
		champ.set("game", self)
	champ.set("definition", def)
	champ.name = "PlayerChampion" if seat == player_seat else "Seat%d%s" % [seat, champion_id.to_pascal_case()]
	var hb := champ.get_node_or_null("HealthBar")
	if hb:
		hb.set("fill_color", Color(0.2, 0.85, 0.3) if seat == player_seat else ProtoConfig.team_color(team))
	champ.add_child(ProtoUtil.make_ring(0.9, ProtoConfig.team_color(team), 0.15))
	champ.position = seat_spawn_position(seat)
	add_child(champ)
	var caster := AbilityCaster.new()
	caster.name = "Abilities"
	champ.add_child(caster)
	var gear := Equipment.new()
	gear.name = "Equipment"
	champ.add_child(gear)
	gear.equip(_loadout_for(seat, champion_id, is_bot))
	champions[seat] = champ
	_respawn_left[seat] = 0.0
	_track(champ)
	var st := EntityData.get_stats_of(champ)
	st.leveled_up.connect(_on_champion_leveled.bind(champ))
	var rolls := SpawnerRolls.new()
	rolls.setup(champion_id, match_seed * 31 + seat)
	spawner_rolls[seat] = rolls
	rebuild_board(seat)
	return champ


## Bots use the champion's default build. The player uses what they picked (or their saved build).
func _loadout_for(seat: int, champion_id: String, is_bot: bool) -> Dictionary:
	if replay != null:
		return replay.loadout(seat)
	if is_bot or seat != player_seat:
		return ItemCatalog.default_loadout(champion_id)
	if not Session.loadout.is_empty() and champion_id == Session.player_champion:
		return Session.loadout
	return ItemCatalog.load_loadout(champion_id)


func equipment_of(seat: int) -> Equipment:
	var champ: CharacterBody3D = champions.get(seat)
	return champ.get_node_or_null("Equipment") as Equipment if champ else null


## Passive gold per second for a team.
func gold_income(_team: int) -> float:
	return passive_gold_per_sec


func _build_camera_and_hud() -> void:
	_camera = ProtoCamera.new()
	_camera.target = player_champion
	var reach_z := jungle_camp_distance + 2.0
	_camera.bounds = Rect2(-lane_half_length, -reach_z, lane_half_length * 2.0, reach_z * 2.0)
	add_child(_camera)
	_camera.make_current()

	_hud = ProtoHUD.new()
	add_child(_hud)
	_hud.restart_requested.connect(_restart)
	_hud.change_champion_requested.connect(_change_champion)
	_hud.main_menu_requested.connect(_open_main_menu)

	# Added to the HUD's main layer (not the HUD itself) so the champion-select and
	# draft screens, which are added later, draw on top of them.
	var hud_root := _hud.get_node("Root")
	var minimap := ProtoMinimap.new()
	minimap.setup(self, _camera)
	hud_root.add_child(minimap)

	var target_panel := ProtoTargetPanel.new()
	target_panel.setup(self)
	hud_root.add_child(target_panel)

	if not spectate and spawner_rolls.has(player_seat):
		var roll_menu := RollMenu.new()
		roll_menu.name = "RollMenu"
		roll_menu.setup(self, player_seat)
		hud_root.add_child(roll_menu)

	# The local player's input. While spectating, both champions are bots.
	if not spectate:
		_controller = PlayerController.new()
		_controller.name = "PlayerController"
		_controller.setup(self, player_seat, player_champion, _camera, _hud)
		add_child(_controller)


## Fog of war over the whole map, drawn from the player's side. While spectating,
## the bots still play by fog rules but nothing is darkened or hidden.
func _build_fog() -> void:
	if not fog_of_war:
		return
	var half := Vector2(lane_half_length + 20.0, lane_half_width + 20.0)
	var fog := FogOfWar.new()
	fog.name = "FogOfWar"
	fog.setup(Rect2(-half, half * 2.0), player_team, not spectate)
	add_child(fog)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Back to the champion select screen.
func _change_champion() -> void:
	Session.player_champion = ""
	Session.loadout = {}
	_restart()


## Back to the main menu.
func _open_main_menu() -> void:
	get_tree().paused = false
	Session.clear_match()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ---- Waves ----

## The simulation tick. All game logic runs in _physics_process at the fixed rate
## set in project.godot (physics/common/physics_ticks_per_second), so it doesn't
## depend on frame rate. ProtoGame ticks first (see _ready), FogOfWar last.
## _process is only for things the player looks at (HUD, camera, previews).
func _physics_process(delta: float) -> void:
	sim_tick += 1
	if sim_tick == 1:
		_start_recording()
	if sim_tick % MatchLog.CHECK_EVERY == 0:
		_checkpoint()
	if replay != null and not replay.finished and sim_tick > replay.end_tick:
		_finish_replay()
	_drain_commands()
	_step_builders()
	_tick_economy(delta)
	_tick_champions(delta)
	_tick_jungle(delta)
	if phase == Phase.PLAY:
		wave_time_left -= delta
		if wave_time_left <= 0.0:
			wave_time_left += wave_interval
			_spawn_wave()


func _process(_delta: float) -> void:
	_update_hud()


## Bots pick their banked rolls (one command at a time, see ProtoAIBuilder).
func _step_builders() -> void:
	for b in _builders:
		b.step()


func _tick_economy(delta: float) -> void:
	if phase == Phase.OVER:
		return
	for team: int in [player_team, enemy_team]:
		_gold[team] += gold_income(team) * delta


func _tick_champions(delta: float) -> void:
	for seat: int in champions:
		var champ: CharacterBody3D = champions[seat]
		var st := EntityData.get_stats_of(champ)
		if st.is_dead:
			if phase == Phase.OVER:
				continue
			_respawn_left[seat] -= delta
			if _respawn_left[seat] <= 0.0:
				_respawn(champ, seat)
			continue
		var regen := st.get_health_regen()
		if ProtoUtil.flat_distance(champ.global_position, fountain_position(seat_team(seat))) < 8.0:
			regen += st.get_max_health() * 0.15
			if st.current_mana < st.get_max_mana():
				st.restore_mana(st.get_max_mana() * 0.15 * delta)
		if st.current_health < st.get_max_health():
			st.heal(regen * delta)


## Every spawner of every seat sends its minions.
func _spawn_wave() -> void:
	wave_number += 1
	# Alternate which team's minions spawn (and so update) first each wave.
	var order: Array[int] = [player_team, enemy_team]
	if wave_number % 2 == 0:
		order.reverse()
	for team: int in order:
		for seat in seats_of(team):
			var rolls: SpawnerRolls = spawner_rolls.get(seat)
			if rolls == null:
				continue
			var nodes: Array = seat_spawners.get(seat, [])
			for i in mini(rolls.slots.size(), nodes.size()):
				_spawn_from(nodes[i] as ProtoSpawner, rolls.upgrades_of(i))
	if match_log:
		match_log.record_event(sim_tick, "wave")


## How many minions a spawner sends each wave: its minion's "count" (or
## minions_per_spawner). Each "doubles" upgrade adds that base count again.
func wave_size(spawner_id: String, upgrades: Array) -> int:
	var minion_id: String = ProtoConfig.SPAWNERS[spawner_id]["minion"]
	var base := int(ProtoConfig.MINIONS[minion_id].get("count", minions_per_spawner))
	var count := base
	for u in upgrades:
		if u in SpawnerPool.EXTRA_UNIT_UPGRADES:
			count += base
	return count


func _spawn_from(sp: ProtoSpawner, upgrades: Array) -> void:
	var minion_id: String = ProtoConfig.SPAWNERS[sp.type_id]["minion"]
	var count := wave_size(sp.type_id, upgrades)
	var bounty := minion_bounty(sp, count)
	for i in count:
		var m := ProtoMinion.new()
		m.setup(self, minion_id, sp.team, minion_stat_mult, NO_BUFFS)
		m.bounty_gold = bounty.x
		m.bounty_xp = bounty.y
		m.lane_z = sp.global_position.z
		m.position = to_local(sp.spawn_point())
		add_child(m)
		minions.append(m)
		_track(m)


## Minion setup still takes placement buffs (the old hex synergies). The new
## spawners have none yet.
const NO_BUFFS := {"hp": 0.0, "ad": 0.0, "as": 0.0, "armor": 0.0, "mr": 0.0, "count": 0, "burst": 0.0}


# ---- Spawner board (picked from rolls) ----

func get_gold(team: int) -> int:
	return int(_gold.get(team, 0.0))


## The hex for a seat's slot `index` (0-4). Each seat on a team gets one row of
## its team's grid, slots running from the middle of the row outward.
func slot_hex(seat: int, index: int) -> Vector2i:
	var mates := seats_of(seat_team(seat))
	var row_order := [2, 1, 3, 0, 4]
	var r: int = row_order[mates.find(seat) % row_order.size()]
	var col_order := [2, 3, 1, 4, 0]
	var c: int = col_order[index]
	return Vector2i(c - ((r - (r & 1)) >> 1), r)


## Puts a building for the seat's next slot. Called after the roll board already has it.
func _place_spawner(seat: int, type_id: String) -> void:
	var team := seat_team(seat)
	var nodes: Array = seat_spawners.get(seat, [])
	var sp := ProtoSpawner.new()
	var hex := slot_hex(seat, nodes.size())
	sp.setup(type_id, team, hex, hex_size)
	sp.seat = seat
	grids[team].add_spawner(sp, hex)
	nodes.append(sp)
	seat_spawners[seat] = nodes


## Rebuilds a seat's buildings from its roll board (start of match, replays, balance runner).
func rebuild_board(seat: int) -> void:
	for sp in seat_spawners.get(seat, []):
		var grid: ProtoHexGrid = grids[(sp as ProtoSpawner).team]
		grid.spawners.erase((sp as ProtoSpawner).hex)
		(sp as ProtoSpawner).free()
	seat_spawners[seat] = []
	var rolls: SpawnerRolls = spawner_rolls.get(seat)
	if rolls == null:
		return
	for s in rolls.slots:
		_place_spawner(seat, str(s["id"]))


## Only the slots in use show on the grid.
func _show_slots() -> void:
	for team: int in grids:
		var used: Array[Vector2i] = []
		for seat in seats_of(team):
			for i in SpawnerPool.SLOTS:
				used.append(slot_hex(seat, i))
		grids[team].show_only(used)


## Applies a roll pick for `seat`. Returns "" or why it can't.
func _pick_roll(seat: int, index: int) -> String:
	var rolls: SpawnerRolls = spawner_rolls.get(seat)
	if rolls == null or rolls.banked <= 0:
		return "No roll to open."
	var cards := rolls.open_roll()
	if index < 0 or index >= cards.size():
		return "No such card."
	var card := cards[index]
	rolls.pick(index)
	if card["kind"] == "spawner":
		_place_spawner(seat, str(card["spawner"]))
	else:
		for sp in seat_spawners.get(seat, []):
			if (sp as ProtoSpawner).type_id == card["spawner"]:
				(sp as ProtoSpawner).on_upgraded()
	return ""


# ---- Match log and replays ----

## First tick: everything set up before now (boards, gold) is final.
## Records it (or, in a replay, restores the recorded one), then re-seeds the
## game's dice so the match itself starts from the same point either way, no
## matter how much setup code rolled before it.
func _start_recording() -> void:
	if replay != null:
		_apply_replay_setup()
	SimRng.reseed(hash([match_seed, "match"]))
	if match_log:
		match_log.record_seats()
		match_log.record_setup()


func _apply_replay_setup() -> void:
	var setup := replay.setup()
	for team: int in [player_team, enemy_team]:
		_gold[team] = float(setup["gold"].get(str(team), start_gold))
	# Boards are keyed by seat: [{"id", "upgrades"}, ...] in slot order.
	var boards: Dictionary = setup.get("boards", {})
	for s: int in spawner_rolls:
		if boards.has(str(s)):
			spawner_rolls[s].set_board(boards[str(s)])
			rebuild_board(s)
	# Keyed by seat (MatchReplay converts older, per-team logs).
	var frozen: Dictionary = setup.get("frozen_champions", {})
	for s: int in champions:
		if bool(frozen.get(str(s), false)):
			var c: CharacterBody3D = champions[s]
			c.global_position = seat_spawn_position(s)
			c.process_mode = Node.PROCESS_MODE_DISABLED
			EntityData.get_stats_of(c).invulnerable = true


## Numbers that pin down the game state: champions, gold, structures, minions,
## jungle camps, phase. They start with champion x/z/hp/mana per seat, then
## gold per team (in a 1v1 the first 12 are those, and they're what the log
## prints); the hash of all of them is the checksum.
func state_values() -> PackedFloat64Array:
	var v := PackedFloat64Array()
	for s in seats.size():
		var c: CharacterBody3D = champions.get(s)
		if c == null:
			v.append_array([0.0, 0.0, 0.0, 0.0])
			continue
		var st := EntityData.get_stats_of(c)
		v.append_array([c.global_position.x, c.global_position.z, st.current_health, st.current_mana])
	for team: int in [player_team, enemy_team]:
		v.append(_gold.get(team, 0.0))
	v.append_array([float(phase), float(wave_number), float(minions.size())])
	for s in structures:
		v.append(s.stats.current_health)
	for m in minions:
		if is_instance_valid(m):
			v.append_array([m.global_position.x, m.global_position.z, m.stats.current_health])
	for camp_id: String in _camps:
		var j: Variant = _camps[camp_id]
		if is_instance_valid(j):
			v.append_array([j.global_position.x, j.global_position.z, EntityData.get_stats_of(j).current_health])
	return v


func _checkpoint() -> void:
	var v := state_values()
	var h := hash(v)
	if match_log:
		match_log.record_check(sim_tick, h, v)
	if replay != null:
		replay.check(sim_tick, h, v)


func _finish_replay() -> void:
	if replay.finished:
		return
	replay.finished = true
	print(replay.verdict())
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if replay.desync_tick < 0 else 1)


## Saves this match's log once (at game over, or when the match is closed).
func _save_match_log(winner: int) -> void:
	if match_log == null or match_log.saved_path != "" or sim_tick == 0:
		return
	match_log.record_result(winner, sim_tick)
	var path: String = match_log.save()
	if path != "":
		print("[proto] match log saved: %s" % path)


# ---- Commands ----

## True if a person (not a bot) plays `seat`. In a replay this is whoever
## played it in the recording, so the same rules apply.
func is_human(seat: int) -> bool:
	if seat < 0 or seat >= seats.size():
		return false
	return not bool(seats[seat]["bot"])


## The single way players and bots change the game. Queues `cmd` (see
## PlayerCommand) for the champion in `seat`; it's checked and applied at the
## start of the next tick, in arrival order. The result comes back as
## command_applied or command_refused. Never trusts the sender: every rule is
## checked when applied.
func execute_command(seat: int, cmd: Dictionary) -> void:
	if replay != null:
		# During a replay only the recorded commands run (see _drain_commands).
		return
	var waiting := 0
	for entry in _command_queue:
		if int(entry["seat"]) == seat:
			waiting += 1
	if waiting >= MAX_QUEUED_PER_SEAT:
		command_refused.emit(seat, cmd, "Too many commands at once.")
		return
	_command_queue.append({"seat": seat, "cmd": cmd, "tick": sim_tick})


## Applies everything queued since the last tick. Runs first in the tick.
func _drain_commands() -> void:
	if replay != null:
		for pair: Array in replay.commands_at(sim_tick):
			_command_queue.append({"seat": pair[0], "cmd": pair[1], "tick": sim_tick})
	if _command_queue.is_empty():
		return
	var batch := _command_queue
	_command_queue = []
	for entry in batch:
		var seat := int(entry["seat"])
		var cmd: Dictionary = entry["cmd"]
		if match_log:
			# Logged before applying, so it's exactly what came in.
			match_log.record_command(sim_tick, seat, cmd, "")
		var problem := _apply_command(seat, cmd)
		if match_log and problem != "":
			match_log.data["commands"][-1][3] = problem
		if problem == "":
			command_applied.emit(seat, cmd)
		else:
			command_refused.emit(seat, cmd, problem)


## Checks `cmd` from `seat` and applies it. Returns "" on success, otherwise
## why it was refused. Moves, attacks and casts go to the seat's champion;
## roll picks act on the seat's spawner board.
func _apply_command(seat: int, cmd: Dictionary) -> String:
	if phase == Phase.OVER:
		return "The match is over."
	var champ: CharacterBody3D = champions.get(seat)
	if champ == null or not is_instance_valid(champ):
		return "You have no champion."
	var dead := EntityData.get_stats_of(champ).is_dead
	match int(cmd.get("type", -1)):
		PlayerCommand.Type.MOVE:
			if dead:
				return "You can't move while dead."
			champ.call("order_move", cmd["pos"] as Vector3)
			return ""
		PlayerCommand.Type.ATTACK:
			if dead:
				return "You can't attack while dead."
			return str(champ.call("order_attack", PlayerCommand.resolve_target(int(cmd["target"]))))
		PlayerCommand.Type.STOP:
			if not dead:
				champ.call("order_stop")
			return ""
		PlayerCommand.Type.CAST, PlayerCommand.Type.RANK_UP:
			var caster := champ.get_node_or_null("Abilities") as AbilityCaster
			var slot := int(cmd["slot"])
			if caster == null or slot < 0 or slot > AbilityCaster.ULT_SLOT:
				return "No such ability."
			if int(cmd["type"]) == PlayerCommand.Type.RANK_UP:
				return caster.rank_up(slot)
			return caster.try_cast(slot, cmd["pos"] as Vector3)
		PlayerCommand.Type.AIM:
			var aim_caster := champ.get_node_or_null("Abilities") as AbilityCaster
			var aim_slot := int(cmd["slot"])
			if aim_caster and aim_slot >= 0 and aim_slot <= AbilityCaster.ULT_SLOT:
				aim_caster.aim(aim_slot, cmd["pos"] as Vector3)
			return ""
		PlayerCommand.Type.PICK_ROLL:
			return _pick_roll(seat, int(cmd["index"]))
	return "Unknown command."


# ---- Player input ----

## Game-over only: handle restart before the ability caster can eat the key.
func _input(event: InputEvent) -> void:
	if phase == Phase.OVER and Controls.pressed(event, "restart_match"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	# Gameplay input (moving, casting) lives in PlayerController; roll picks in RollMenu.
	# What's left here is menus and debug keys, which aren't player commands.
	if Controls.pressed(event, "ui_menu"):
		_hud.open_menu()
		get_viewport().set_input_as_handled()
	elif Controls.pressed(event, "change_champion"):
		get_viewport().set_input_as_handled()
		_change_champion()
	elif Controls.pressed(event, "toggle_mouse"):
		confine_mouse = not confine_mouse
		_apply_mouse_confine()
		_hud.show_message("Mouse locked to the window" if confine_mouse else "Mouse unlocked", Color(0.8, 0.85, 1.0))
		get_viewport().set_input_as_handled()


# ---- Damage, kills, rewards ----

## Lets an object built at runtime (like the Unioneer's turrets) join damage,
## kill and match-log tracking.
func track_entity(entity: Node) -> void:
	_track(entity)


func _track(entity: Node) -> void:
	var st := EntityData.get_stats_of(entity)
	if st == null:
		return
	st.damaged.connect(_on_damaged.bind(entity))
	st.died.connect(_on_died.bind(entity))
	if match_log:
		match_log.track(entity)
	if entity is Entity:
		(entity as Entity).takedown.connect(_on_takedown.bind(entity))


func _on_damaged(_amount: float, source: Node, victim: Node) -> void:
	if source == null or not is_instance_valid(source):
		# Unknown source (e.g. a shot from a unit that already died): nobody gets credit.
		victim.remove_meta("last_hitter")
		return
	var credit := source
	var turret_shot := source is UnioneerTurret
	if turret_shot:
		var credited := (source as UnioneerTurret).credit_source()
		if credited and is_instance_valid(credited):
			credit = credited
	victim.set_meta("last_hitter", credit.get_instance_id())
	# Towers protect their champion: hit an enemy champion under its tower and the tower targets you.
	# A turret shot gives the kill credit to its owner but the tower still targets the turret.
	if not turret_shot and _is_champion(victim) and _is_champion(credit):
		var victim_team := team_of(victim)
		var victim_pos := (victim as Node3D).global_position
		for s in structures:
			if s.team == victim_team and not s.stats.is_dead:
				s.force_target(credit as CharacterBody3D, victim_pos)


## A champion that damaged the victim shortly before it died gets an assist if it
## wasn't the killing blow. This also covers a minion finishing off the victim.
func _on_takedown(victim: Node, attacker: Node) -> void:
	if not _is_champion(victim) or not _is_champion(attacker):
		return
	if attacker == victim:
		return
	var victim_team := team_of(victim)
	var attacker_team := team_of(attacker)
	if attacker_team == victim_team:
		return
	var killer: Node = null
	if victim.has_meta("last_hitter"):
		killer = instance_from_id(int(victim.get_meta("last_hitter"))) as Node
	if killer == null or not is_instance_valid(killer) or attacker == killer:
		return
	if team_of(killer) != attacker_team:
		return
	if not (killer is ProtoMinion or _is_champion(killer)):
		return
	var assister := seat_of(attacker)
	_assists[assister] = _assists.get(assister, 0) + 1
	var at := (victim as Node3D).global_position + Vector3(0.0, 2.4, 0.0)
	_add_gold(attacker_team, assist_gold, at)


func _on_died(victim: Node) -> void:
	var victim_team := team_of(victim)
	var killer: Node = null
	if victim.has_meta("last_hitter"):
		killer = instance_from_id(int(victim.get_meta("last_hitter"))) as Node
	var killer_team := -1
	var rewarded := false
	if killer != null and is_instance_valid(killer):
		killer_team = team_of(killer)
		rewarded = killer_team != victim_team and (killer is ProtoMinion or _is_champion(killer))

	if victim is ProtoMinion:
		var m := victim as ProtoMinion
		minions.erase(m)
		if m.has_meta("despawned"):
			return
		_grant_xp_near(m.global_position, other_team(victim_team), m.bounty_xp)
		if rewarded:
			# At least 1 gold, so tiny split shares still feel like something.
			var base_gold := maxi(roundi(m.bounty_gold), 1)
			var head := m.global_position + Vector3(0.0, m.top_height() + 0.7, 0.0)
			if _is_champion(killer):
				var bonus := last_hit_bonus_gold
				var killer_gear := killer.get_node_or_null("Equipment") as Equipment
				if killer_gear:
					bonus += killer_gear.last_hit_gold()
					killer_gear.on_last_hit()
				var cs_seat := seat_of(killer)
				_cs[cs_seat] = _cs.get(cs_seat, 0) + 1
				_add_gold(killer_team, base_gold, head)
				_add_gold(killer_team, bonus, head + Vector3(0.0, 0.7, 0.0), LAST_HIT_GOLD_COLOR)
			else:
				_add_gold(killer_team, maxi(base_gold - last_hit_shift_gold, 1), head)
	elif victim is ProtoJungleMonster:
		_on_monster_died(victim as ProtoJungleMonster, killer)
	elif _is_champion(victim):
		_on_champion_died(victim as CharacterBody3D, victim_team, killer, rewarded)
	elif victim is ProtoStructure:
		_on_structure_died(victim as ProtoStructure)


func _on_champion_died(champ: CharacterBody3D, team: int, killer: Node, rewarded: bool) -> void:
	var seat := seat_of(champ)
	_deaths[seat] = _deaths.get(seat, 0) + 1
	# Only a champion gets the kill; a tower or minion finishing someone off
	# counts as a death with no killer (still pays the team below).
	var killer_seat := seat_of(killer)
	if rewarded and killer_seat >= 0:
		_kills[killer_seat] = _kills.get(killer_seat, 0) + 1
	var wait := respawn_time()
	_respawn_left[seat] = wait
	_clear_jungle_buffs(seat)
	var models := champ.get_node_or_null("Models") as Node3D
	if models:
		create_tween().tween_property(models, "rotation:x", -PI * 0.5, 0.4)
	var hb := champ.get_node_or_null("HealthBar") as Node3D
	if hb:
		hb.visible = false
	if rewarded:
		_add_gold(other_team(team), champion_kill_gold, champ.global_position + Vector3(0.0, 3.0, 0.0))
		if _is_champion(killer):
			var ks := EntityData.get_stats_of(killer)
			ks.add_xp(kill_xp(ks.level, EntityData.get_stats_of(champ).level))
	print("[proto] %s %s died" % [team_name(team), seat_champion_id(seat)])
	var champ_name := ProtoConfig.champion_name(seat_champion_id(seat))
	if seat == player_seat:
		_hud.show_message("You were slain! Respawning in %ds." % ceili(wait), Color(1.0, 0.45, 0.4))
	elif team == player_team:
		_hud.show_message("Your ally %s was slain." % champ_name, Color(1.0, 0.6, 0.45))
	else:
		_hud.show_message("Enemy %s slain!" % champ_name, Color(0.55, 1.0, 0.55))


func _respawn(champ: CharacterBody3D, seat: int) -> void:
	var st := EntityData.get_stats_of(champ)
	st.initialize(st.definition, st.level)
	champ.global_position = seat_spawn_position(seat)
	champ.velocity = Vector3.ZERO
	var cs := champ.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs:
		cs.set_deferred("disabled", false)
	var nav := champ.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav:
		nav.set_deferred("avoidance_enabled", true)
	var models := champ.get_node_or_null("Models") as Node3D
	if models:
		models.rotation.x = 0.0
	var hb := champ.get_node_or_null("HealthBar") as Node3D
	if hb:
		hb.visible = true


func _on_structure_died(s: ProtoStructure) -> void:
	var ours := s.team == player_team
	print("[proto] %s %s destroyed" % [team_name(s.team), s.display_name.to_lower()])
	if s.kind == ProtoStructure.Kind.ORB:
		_game_over(other_team(s.team))
		return
	var text := ("Your " if ours else "Enemy ") + s.display_name.to_lower() + " was destroyed!"
	_hud.show_message(text, Color(1.0, 0.45, 0.4) if ours else Color(0.55, 1.0, 0.55))


func _game_over(winner: int) -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	print("[proto] game over: %s wins after wave %d" % [team_name(winner), wave_number])
	_hud.show_game_over(winner == player_team)
	_save_match_log(winner)
	if replay != null:
		_finish_replay()


## Gold for one enemy mercenary kill this round (before the last-hit bonus).
## Gold and XP each minion from `sp` carries when it's one of `count` sent this wave.
func minion_bounty(sp: ProtoSpawner, count: int) -> Vector2:
	var value := float(ProtoConfig.SPAWNERS[sp.type_id]["value"]) / float(maxi(count, 1))
	return Vector2(value * minion_gold_ratio, value * minion_xp_ratio)


func _add_gold(team: int, amount: int, at: Vector3, color: Color = GOLD_COLOR) -> void:
	_gold[team] += float(amount)
	if team == player_team:
		ProtoUtil.float_text(self, at, "+%dg" % amount, color, 36)


func structure_damage_mult() -> float:
	return 1.0 + minf(structure_damage_per_minute * match_minutes(), structure_damage_max_bonus)


func respawn_time() -> float:
	return minf(respawn_base + respawn_per_minute * match_minutes(), respawn_max)


func match_minutes() -> float:
	return float(sim_tick) / float(Engine.physics_ticks_per_second) / 60.0


## Champion kill XP. Killing someone higher level pays more (a catch-up for the
## player who's behind); killing someone lower pays less. Between 50% and 200%.
func kill_xp(killer_level: int, victim_level: int) -> float:
	var mult := clampf(1.0 + kill_xp_per_level_gap * float(victim_level - killer_level), 0.5, 2.0)
	return champion_kill_xp * mult


## Minion XP is shared like League: every living allied champion in range gets
## a cut. Alone you get all of it; two or more share XP_SHARE_TOTAL of it evenly
## (2 -> 65% each, 3 -> 43%, 4 -> 33%).
const XP_SHARE_RANGE := 15.0
const XP_SHARE_TOTAL := 1.304


func _grant_xp_near(pos: Vector3, team: int, amount: float) -> void:
	var near: Array[StatsComponent] = []
	for champ in champions_of(team):
		var st := EntityData.get_stats_of(champ)
		if not st.is_dead and ProtoUtil.flat_distance(champ.global_position, pos) <= XP_SHARE_RANGE:
			near.append(st)
	if near.is_empty():
		return
	var each := amount if near.size() == 1 else amount * XP_SHARE_TOTAL / float(near.size())
	for st in near:
		st.add_xp(each)


func _on_champion_leveled(new_level: int, champ: CharacterBody3D) -> void:
	ProtoUtil.float_text(self, champ.global_position + Vector3(0.0, 3.6, 0.0), "Level %d" % new_level, Color(0.6, 0.85, 1.0), 44)
	var seat := seat_of(champ)
	if spawner_rolls.has(seat):
		spawner_rolls[seat].bank_roll()


# ---- Jungle ----

func _spawn_camp(camp_id: String) -> void:
	var m := ProtoJungleMonster.new()
	m.name = "Jungle" + camp_id.capitalize()
	m.setup(self, camp_id, camp_position(camp_id))
	add_child(m)
	_camps[camp_id] = m
	_camp_respawn_left.erase(camp_id)
	_track(m)


## The living monster in a camp, or null while it's respawning.
func camp_monster(camp_id: String) -> ProtoJungleMonster:
	var m: ProtoJungleMonster = _camps.get(camp_id)
	if m and is_instance_valid(m) and not m.stats.is_dead:
		return m
	return null


## Longest time left on any `team` champion's buff from `camp_id` (0 if none has it).
func jungle_buff_time_left(team: int, camp_id: String) -> float:
	var best := 0.0
	for s in seats_of(team):
		var buffs: Dictionary = _jungle_buffs.get(s, {})
		best = maxf(best, float(buffs.get(camp_id, 0.0)))
	return best


func _tick_jungle(delta: float) -> void:
	if phase == Phase.OVER:
		return
	for camp_id: String in _camp_respawn_left.keys():
		_camp_respawn_left[camp_id] -= delta
		if _camp_respawn_left[camp_id] <= 0.0:
			_spawn_camp(camp_id)
			_hud.show_message("The %s has returned." % ProtoConfig.JUNGLE_CAMPS[camp_id]["name"], Color(0.95, 0.85, 0.45))
	for seat: int in _jungle_buffs:
		var buffs: Dictionary = _jungle_buffs[seat]
		if buffs.is_empty():
			continue
		var expired := false
		for camp_id: String in buffs.keys():
			buffs[camp_id] = float(buffs[camp_id]) - delta
			if float(buffs[camp_id]) <= 0.0:
				buffs.erase(camp_id)
				expired = true
		# The modifier only changes when a buff runs out (gaining one applies it).
		if expired:
			_apply_jungle_buffs(seat)


func _on_monster_died(m: ProtoJungleMonster, killer: Node) -> void:
	var camp: Dictionary = m.data
	_camps.erase(m.camp_id)
	_camp_respawn_left[m.camp_id] = float(camp["respawn_time"])
	print("[proto] %s camp cleared by %s" % [m.camp_id, team_name(team_of(killer)) if _is_champion(killer) else "nobody"])
	if not _is_champion(killer):
		return
	var team := team_of(killer)
	var seat := seat_of(killer)
	_cs[seat_of(killer)] = _cs.get(seat_of(killer), 0) + 1
	_add_gold(team, int(camp["gold"]), m.global_position + Vector3(0.0, 3.0, 0.0))
	EntityData.get_stats_of(killer).add_xp(float(camp["xp"]))
	_give_jungle_buff(seat, m.camp_id)
	var buff_name: String = camp["buff_name"]
	if seat == player_seat:
		_hud.show_message("You took %s!" % buff_name, camp["buff_color"])
	elif team == player_team:
		_hud.show_message("Your ally took %s." % buff_name, camp["buff_color"])
	else:
		_hud.show_message("The enemy took %s." % buff_name, Color(1.0, 0.6, 0.45))


func _give_jungle_buff(seat: int, camp_id: String) -> void:
	var camp: Dictionary = ProtoConfig.JUNGLE_CAMPS[camp_id]
	var duration: float = camp["buff_time"]
	if not _jungle_buffs.has(seat):
		_jungle_buffs[seat] = {}
	_jungle_buffs[seat][camp_id] = duration
	var champ := champions.get(seat) as Entity
	if champ == null:
		return
	if camp.has("attack_speed_bonus") and champ.status_effects():
		champ.status_effects().apply_attack_speed(float(camp["attack_speed_bonus"]), duration, "jungle_" + camp_id)
	_apply_jungle_buffs(seat)
	ProtoUtil.float_text(self, champ.global_position + Vector3(0.0, 3.6, 0.0), str(camp["buff_name"]), camp["buff_color"], 40)


## Sets the champion's regen and cooldown bonuses from its active jungle buffs.
## (Attack speed goes through StatusEffects so it shows over the champion's head.)
func _apply_jungle_buffs(seat: int) -> void:
	var champ: CharacterBody3D = champions.get(seat)
	if champ == null:
		return
	var st := EntityData.get_stats_of(champ)
	var hp_regen := 0.0
	var mana_regen := 0.0
	var cdr := 0.0
	for camp_id: String in _jungle_buffs.get(seat, {}):
		var camp: Dictionary = ProtoConfig.JUNGLE_CAMPS[camp_id]
		hp_regen += float(camp.get("health_regen_bonus", 0.0))
		mana_regen += float(camp.get("mana_regen_bonus", 0.0))
		cdr += float(camp.get("cooldown_reduction", 0.0))
	st.set_modifier("jungle_buffs", {
		StatsComponent.Stat.HEALTH_REGEN: hp_regen,
		StatsComponent.Stat.MANA_REGEN: mana_regen,
		StatsComponent.Stat.COOLDOWN_REDUCTION: cdr,
	})


func _clear_jungle_buffs(seat: int) -> void:
	if _jungle_buffs.has(seat):
		_jungle_buffs[seat].clear()
	_apply_jungle_buffs(seat)


func _jungle_buff_text(seat: int) -> String:
	var parts: PackedStringArray = []
	var buffs: Dictionary = _jungle_buffs.get(seat, {})
	for camp_id: String in buffs:
		var camp: Dictionary = ProtoConfig.JUNGLE_CAMPS[camp_id]
		parts.append("%s %s" % [camp["buff_name"], _fmt_time(float(buffs[camp_id]))])
	return "    ".join(parts)


# ---- HUD ----

func _update_hud() -> void:
	var main := ""
	var sub := ""
	if phase == Phase.PLAY:
		main = "Wave %d   next %s" % [wave_number + 1, _fmt_time(wave_time_left)]
	_hud.set_phase_color(Color(1.0, 0.75, 0.4))
	var pst := EntityData.get_stats_of(player_champion)
	if pst.is_dead and phase != Phase.OVER:
		sub = "%d" % ceili(_respawn_left[player_seat])
	_hud.set_phase_text(main, sub)
	_hud.set_dead(pst.is_dead and phase != Phase.OVER and not spectate, ceili(_respawn_left[player_seat]))
	_hud.set_gold(get_gold(player_team))
	_hud.set_level(pst.level, pst.get_xp_progress())
	_hud.set_champion_bars(pst.current_health, pst.get_max_health(), pst.current_mana, pst.get_max_mana(), pst.get_health_regen(), pst.get_mana_regen())
	var caster := player_champion.get_node_or_null("Abilities") as AbilityCaster
	_hud.set_passive(caster.passive.display_name() if caster and caster.passive else "", caster.passive.definition.description if caster and caster.passive and caster.passive.definition else "")
	for i in 4:
		var a: Ability = caster.get_ability(i) if caster else null
		if a == null:
			_hud.set_ability(i, "", 0.0, 0.0, 0.0, true, false, 0, 0, false)
		else:
			# A pending recast (like recalling the knife) is free and ready, so don't show the cooldown.
			var recast := a.wants_recast()
			var can_level := not spectate and caster.can_rank_up(i)
			_hud.set_ability(i, a.display_name(), 0.0 if recast else a.cooldown_left, a.effective_cooldown(), 0.0 if recast else a.mana_cost(), recast or pst.current_mana >= a.mana_cost(), a.is_active(), a.rank, caster.max_rank(i), can_level, a.definition.description if a.definition else "")
	_hud.set_skill_points(caster.skill_points() if caster and not spectate else 0)
	if _hud.is_info_open():
		_hud.set_info(_info_sections(pst))
	var seconds := int(float(sim_tick) / float(Engine.physics_ticks_per_second))
	_hud.set_scoreboard(
		team_score(_kills, player_team), team_score(_kills, enemy_team),
		_kills.get(player_seat, 0), _deaths.get(player_seat, 0), _assists.get(player_seat, 0),
		_cs.get(player_seat, 0), "%d:%02d" % [seconds / 60, seconds % 60])
	_hud.set_perf(int(Engine.get_frames_per_second()))
	var status_fx := player_champion.get_node_or_null("StatusEffects") as StatusEffects
	_hud.set_statuses(status_fx.active_statuses() if status_fx else [])
	_hud.set_buffs(_jungle_buff_text(player_seat))


func _minion_count(team: int) -> int:
	var n := 0
	for m in minions:
		if m.team == team:
			n += 1
	return n


# ---- Tab screen ----

const _GOLD := "ffd166"
const _ALLY := "73b3ff"
const _ENEMY := "ff8073"
const _DIM := "9aa0ab"


func _info_sections(st: StatsComponent) -> Dictionary:
	return {
		"teams": _info_teams(),
		"jungle": _info_jungle(),
		"stats": _info_stats(st),
		"build": _info_build(),
	}


func _heading(text: String) -> String:
	return "[font_size=18][color=#%s]%s[/color][/font_size]\n" % [_GOLD, text]


func _info_teams() -> String:
	var out := _heading("Wave %d  -  %s" % [wave_number, "next in " + _fmt_time(wave_time_left) if phase != Phase.OVER else "Over"])
	out += "[table=3]"
	out += "[cell][/cell][cell padding=16,2,16,2][color=#%s][b]Your team[/b][/color][/cell][cell padding=16,2,0,2][color=#%s][b]Enemy team[/b][/color][/cell]" % [_ALLY, _ENEMY]
	var rows := [
		["Champions", func(t: int) -> String: return _per_champion(t, func(_s: int, st: StatsComponent) -> String: return st.definition.entity_name)],
		["Levels", func(t: int) -> String: return _per_champion(t, func(_s: int, st: StatsComponent) -> String: return str(st.level))],
		["K / D / A", func(t: int) -> String: return "%d / %d / %d" % [team_score(_kills, t), team_score(_deaths, t), team_score(_assists, t)]],
		["Gold", func(t: int) -> String: return "%d  (+%s/s)" % [get_gold(t), String.num(gold_income(t), 1)]],
		["Orb", func(t: int) -> String: return str(ceili(_orbs[t].stats.current_health))],
		["Towers", func(t: int) -> String: return "%d / 2" % _towers_left(t)],
		["Minions out", func(t: int) -> String: return str(_minion_count(t))],
		["Respawn", func(t: int) -> String: return _per_champion(t, func(s: int, st: StatsComponent) -> String: return _fmt_time(_respawn_left[s]) if st.is_dead else "-")],
	]
	for row in rows:
		var f: Callable = row[1]
		out += "[cell][color=#%s]%s[/color][/cell][cell padding=16,2,16,2]%s[/cell][cell padding=16,2,0,2]%s[/cell]" % [_DIM, row[0], f.call(player_team), f.call(enemy_team)]
	return out + "[/table]"


## One value per champion on `team` (in seat order), joined with " / ".
## `f` is called as f(seat, stats).
func _per_champion(team: int, f: Callable) -> String:
	var parts: PackedStringArray = []
	for s in seats_of(team):
		var st := EntityData.get_stats_of(champions.get(s))
		if st:
			parts.append(str(f.call(s, st)))
	return " / ".join(parts) if not parts.is_empty() else "-"


func _towers_left(team: int) -> int:
	var n := 0
	for s in structures:
		if s.team == team and s.kind == ProtoStructure.Kind.TOWER and not s.stats.is_dead:
			n += 1
	return n


func _info_jungle() -> String:
	var out := _heading("Jungle")
	out += "[table=2]"
	for camp_id: String in ProtoConfig.JUNGLE_CAMPS:
		var camp: Dictionary = ProtoConfig.JUNGLE_CAMPS[camp_id]
		var status := "[color=#7ee08a]Up[/color]"
		if _camp_respawn_left.has(camp_id):
			status = "Back in [b]%s[/b]" % _fmt_time(_camp_respawn_left[camp_id])
		out += "[cell padding=0,2,24,0][b]%s[/b]  [color=#%s](%s)[/color][/cell][cell]%s[/cell]" % [camp["name"], _DIM, "north" if float(camp["side"]) < 0.0 else "south", status]
		var holder := "[color=#%s]nobody[/color]" % _DIM
		for seat: int in _jungle_buffs:
			var buffs: Dictionary = _jungle_buffs[seat]
			if buffs.has(camp_id):
				var ally := seat_team(seat) == player_team
				var who := "You" if seat == player_seat else ProtoConfig.champion_name(seat_champion_id(seat))
				holder = "[color=#%s]%s[/color] %s" % [_ALLY if ally else _ENEMY, who, _fmt_time(float(buffs[camp_id]))]
		out += "[cell padding=12,0,24,8][color=#%s]%s[/color][/cell][cell padding=0,0,0,8]%s[/cell]" % [_DIM, camp["buff_name"], holder]
	return out + "[/table]"


func _info_stats(st: StatsComponent) -> String:
	var S := StatsComponent.Stat
	var pct := func(v: float) -> String: return "%d%%" % roundi(v * 100.0)
	var rows := [
		["Attack damage", str(roundi(st.get_attack_damage())), "Ability power", str(roundi(st.get_ability_power()))],
		["Armor", str(roundi(st.get_armor())), "Magic resist", str(roundi(st.get_magic_resist()))],
		["Attack speed", String.num(st.get_attack_speed(), 2), "Crit", pct.call(st.get_crit_chance())],
		["Armor pen", "%d | %s" % [roundi(st.get_stat(S.ARMOR_PEN)), pct.call(st.get_stat(S.ARMOR_PEN_PERCENT))], "Magic pen", "%d | %s" % [roundi(st.get_stat(S.MAGIC_PEN)), pct.call(st.get_stat(S.MAGIC_PEN_PERCENT))]],
		["Life steal", pct.call(st.get_life_steal()), "Spell vamp", pct.call(st.get_spell_vamp())],
		["Cooldowns", ("-" if st.get_cooldown_reduction() > 0.0 else "") + pct.call(st.get_cooldown_reduction()), "Move speed", String.num(st.get_movement_speed(), 1)],
		["Health regen", "%s/s" % String.num(st.get_health_regen(), 1), "Mana regen", "%s/s" % String.num(st.get_mana_regen(), 1)],
	]
	var xp := "max level" if st.level >= StatsComponent.MAX_LEVEL else "%d / %d xp" % [floori(st.xp), roundi(st.get_xp_to_level())]
	var out := _heading("%s  -  level %d  [color=#%s][font_size=14](%s)[/font_size][/color]" % [st.definition.entity_name, st.level, _DIM, xp])
	out += "[table=4]"
	for r in rows:
		out += "[cell padding=0,2,10,2][color=#%s]%s[/color][/cell][cell padding=0,2,28,2]%s[/cell][cell padding=0,2,10,2][color=#%s]%s[/color][/cell][cell padding=0,2,0,2]%s[/cell]" % [_DIM, r[0], r[1], _DIM, r[2], r[3]]
	return out + "[/table]"


func _info_build() -> String:
	var out := _heading("Spawners")
	var rolls: SpawnerRolls = spawner_rolls.get(player_seat)
	if rolls:
		for s in rolls.slots:
			var sp: Dictionary = SpawnerPool.SPAWNERS[s["id"]]
			var ups: PackedStringArray = []
			for u in s["upgrades"]:
				ups.append(SpawnerPool.upgrade_info(s["id"], u)[0])
			out += "[b]%s[/b] [color=#%s](%s)[/color]  %s
" % [sp["name"], _DIM, sp["unit"], ", ".join(ups)]
		if rolls.banked > 0:
			out += "[color=#%s]%d roll(s) waiting (%s)[/color]
" % [_GOLD, rolls.banked, Controls.binding_text("open_roll")]
	out += _heading("Equipment")
	var gear := equipment_of(player_seat)
	if gear == null:
		return out
	for slot in ItemCatalog.SLOT_ORDER:
		var id := str(gear.loadout.get(slot, ""))
		var item := ItemCatalog.get_item(id)
		if item.is_empty():
			continue
		out += "[color=#%s]%s[/color]   [b]%s[/b]\n[font_size=13][color=#c8ccd4]%s[/color][/font_size]\n" % [_DIM, ItemCatalog.slot_name(slot), item["name"], ItemCatalog.describe(id)]
	return out


func _fmt_time(seconds: float) -> String:
	var s := maxi(ceili(seconds), 0)
	return "%d:%02d" % [floori(s / 60.0), s % 60]


# ---- Queries used by minions, structures and bots ----

func is_game_over() -> bool:
	return phase == Phase.OVER


func team_of(node: Node) -> int:
	var st := EntityData.get_stats_of(node)
	if st == null:
		return EntityDefinition.Team.NEUTRAL
	return st.get_team()


## The first champion on `team` (dead or alive), or null. Most code wants
## champions_of() or nearest_enemy_champion() instead.
func champion_of(team: int) -> CharacterBody3D:
	var list := champions_of(team)
	if not list.is_empty():
		return list[0]
	return null


func _is_champion(node: Node) -> bool:
	return node != null and champions.values().has(node)


func kind_of(node: Node) -> int:
	if node is ProtoMinion or node is UnioneerTurret:
		return KIND_MINION
	if node is ProtoStructure:
		return KIND_STRUCTURE
	return KIND_CHAMPION


func radius_of(node: Node) -> float:
	if node is ProtoMinion:
		return (node as ProtoMinion).radius
	if node is ProtoStructure:
		return (node as ProtoStructure).radius
	if node is ProtoJungleMonster:
		return (node as ProtoJungleMonster).radius
	if node is UnioneerTurret:
		return (node as UnioneerTurret).radius
	return 0.7


## Living enemies of `team` that can be damaged right now.
## Living enemies of `team`. With `seen_only`, minions and champions hidden in the
## fog (or stealthed) are left out, so minions and towers can't target them.
## With `max_gap`, minions further than that from `near` (edge to edge) are skipped
## before the fog check, which keeps the frequent tower and minion scans cheap.
func get_enemies(team: int, seen_only: bool = true, near: Vector3 = Vector3.ZERO, max_gap: float = INF) -> Array[CharacterBody3D]:
	var out: Array[CharacterBody3D] = []
	var check_gap := max_gap < INF
	for m in minions:
		if m.team != team and not m.stats.is_dead:
			if check_gap and ProtoUtil.flat_distance(near, m.global_position) - m.radius > max_gap:
				continue
			if not seen_only or FogOfWar.can_see(team, m):
				out.append(m)
	for s: int in champions:
		if seat_team(s) == team:
			continue
		var c: CharacterBody3D = champions[s]
		var st := EntityData.get_stats_of(c)
		if st and not st.is_dead and (not seen_only or FogOfWar.can_see(team, c)):
			out.append(c)
	for s in structures:
		if s.team != team and not s.stats.is_dead and not s.stats.invulnerable:
			out.append(s)
	for node in get_tree().get_nodes_in_group("unioneer_turret"):
		var t := node as UnioneerTurret
		if t == null or t.team == team or t.stats.is_dead:
			continue
		if check_gap and ProtoUtil.flat_distance(near, t.global_position) - t.radius > max_gap:
			continue
		if not seen_only or FogOfWar.can_see(team, t):
			out.append(t)
	return out


func is_in_enemy_tower_range(pos: Vector3, team: int, margin: float = 0.0) -> bool:
	for s in structures:
		if s.team != team and not s.stats.is_dead and s.covers(pos, margin):
			return true
	return false


## True if `pos` is inside the enemy orb's range. The orb shoots champions first no
## matter how many minions are around, so bots never stand there.
func is_in_enemy_orb_range(pos: Vector3, team: int, margin: float = 0.0) -> bool:
	var orb: ProtoStructure = _orbs.get(other_team(team))
	return orb != null and not orb.stats.is_dead and orb.covers(pos, margin)


func allied_minions_near(pos: Vector3, team: int, radius: float) -> int:
	var n := 0
	for m in minions:
		if m.team == team and not m.stats.is_dead and ProtoUtil.flat_distance(pos, m.global_position) <= radius:
			n += 1
	return n


func nearest_enemy_structure(pos: Vector3, team: int, max_dist: float) -> ProtoStructure:
	var best: ProtoStructure = null
	var best_d := max_dist
	for s in structures:
		if s.team == team or s.stats.is_dead or s.stats.invulnerable:
			continue
		var d := ProtoUtil.flat_distance(pos, s.global_position)
		if d <= best_d:
			best_d = d
			best = s
	return best


func frontmost_allied_minion(team: int) -> ProtoMinion:
	var best: ProtoMinion = null
	var best_x := -INF
	var f := forward_of(team)
	for m in minions:
		if m.team != team or m.stats.is_dead:
			continue
		var x := m.global_position.x * f
		if x > best_x:
			best_x = x
			best = m
	return best


## Just in front of the team's front-most standing tower (or its orb).
func guard_position(team: int) -> Vector3:
	var f := forward_of(team)
	var best: ProtoStructure = null
	for s in structures:
		if s.team != team or s.stats.is_dead or s.kind != ProtoStructure.Kind.TOWER:
			continue
		if best == null or s.global_position.x * f > best.global_position.x * f:
			best = s
	var base := Vector3(orb_x(team), 0.0, 0.0)
	if best:
		base = best.global_position
	return base + Vector3(f * 3.0, 0.0, 2.5)


func fire_projectile(from: Vector3, target: Node3D, damage: float, true_damage: bool, source: Node, color: Color, shot_size: float, speed: float) -> void:
	var p := ProtoProjectile.new()
	p.target = target
	p.damage = damage
	p.true_damage = true_damage
	p.source_id = source.get_instance_id() if source != null else 0
	p.color = color
	p.size = shot_size
	p.speed = speed
	p.aim_height = 2.0 if target is ProtoStructure else 0.9
	p.position = to_local(from)
	add_child(p)
