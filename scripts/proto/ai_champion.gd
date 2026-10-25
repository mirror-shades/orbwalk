extends "res://scripts/mover.gd"
## Bot that plays a champion in the 1v1 prototype.
## Reuses all of mover.gd's movement and attack code; only the decisions differ.
##
## Each think tick, in order:
##   1. Low HP -> walk back to the fountain until healed.
##   2. Enemy champion close, weaker, and not under its towers -> fight it.
##   3. Enemy minion nearby (and safe to reach) -> farm it, preferring last hits.
##   4. Enemy tower with 2+ of our minions tanking it -> hit the tower.
##   (Between 2 and 3: while the enemy champion is dead or running home, push -
##   clear their wave and hit towers under minion cover. See _should_push().)
##   5. Otherwise wait just behind our front minion, or near our front tower.
## Ability use is per champion (see "Ability use, per champion" below).
##
## Like the human player, the bot only acts through PlayerCommands sent to
## ProtoGame.execute_command() (see _send). It reads game state to decide, but
## never changes it directly.

var game: ProtoGame

## Starts at a random point so two bots don't always decide on the same frame
## (the one updated first would always react first).
var _think_timer: float = SimRng.bot_rng().randf() * 0.25
var _retreating: bool = false
## Cat's Paw: seconds left of a committed all-in (0 = not committed).
var _cp_commit_left: float = 0.0
## This bot's match seat (looked up on the first command it sends).
var _seat: int = -1


# ---- Turn off the player-only parts of mover.gd ----

func _scan_for_nearby_enemy() -> void:
	pass


# ---- Brain ----

func _physics_process(delta: float) -> void:
	_brain(delta)
	super(delta)


func _brain(delta: float) -> void:
	if game == null or stats == null or stats.is_dead or game.is_game_over():
		return
	# In a replay the recorded commands drive this champion.
	if game.replay != null:
		return
	_spend_skill_points()
	if status_effects() and status_effects().is_disabled():
		return
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = 0.25
	_think()


func _think() -> void:
	var my_team := stats.get_team()
	var hp_frac := stats.current_health / stats.get_max_health()

	# The closest enemy champion it can see. The bot plays by the same fog
	# rules: an unseen champion is ignored.
	var foe := game.nearest_enemy_champion(global_position, my_team)

	if _retreating:
		if hp_frac >= 0.9:
			_retreating = false
		else:
			_kit_escape(foe)
			_go_to(game.fountain_position(my_team))
			return
	elif hp_frac < 0.3:
		_retreating = true
		_go_to(game.fountain_position(my_team))
		return

	# The enemy orb kills champions in a few shots: back out before anything else.
	if game.is_in_enemy_orb_range(global_position, my_team, 1.5):
		_go_to(global_position + Vector3(-game.forward_of(my_team) * 6.0, 0.0, 0.0))
		return

	if _kit_engage(foe, hp_frac):
		return
	if _kite_step(foe):
		return
	if _foe_is_fair_game(foe, hp_frac):
		_attack(foe)
		_kit_in_fight(foe)
		return

	if _should_push(hp_frac):
		_push()
		return

	var minion := _pick_minion()
	if minion:
		_attack(minion)
		return

	# Towers can be hit under minion cover; the orb is left to the wave.
	var structure := game.nearest_enemy_structure(global_position, my_team, 14.0)
	if structure and structure.kind != ProtoStructure.Kind.ORB and game.allied_minions_near(structure.global_position, my_team, structure.attack_range) >= 2:
		_attack(structure)
		return

	var monster := _pick_jungle_monster(foe, hp_frac)
	if monster:
		# A camp out of sight can't be attacked yet (the order is refused): walk there first.
		if FogOfWar.can_see(my_team, monster):
			_attack(monster)
		else:
			_go_to(monster.global_position)
		return

	_go_to(_hold_position())


## Ranged bots orbwalk a melee champion: hit, step back while the next attack
## loads, hit again. Without this a melee champion walks up and wins every auto
## trade against a ranged one. Only between attacks: a ready attack or a swing in
## its windup is left alone.
func _kite_step(foe: CharacterBody3D) -> bool:
	if not _alive(foe) or stats.get_attack_range() < 4.0:
		return false
	var fs := EntityData.get_stats_of(foe)
	var foe_range := fs.get_attack_range()
	if foe_range >= 4.0:
		return false
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	if d > foe_range + 2.0:
		return false
	if can_attack() or (is_attack_anim_active() and not _damage_dealt_this_swing):
		return false
	var away := global_position - foe.global_position
	away.y = 0.0
	var home := Vector3(-game.forward_of(stats.get_team()), 0.0, 0.0)
	if away.length() < 0.1:
		away = home
	away = (away.normalized() + home * 0.5).normalized()
	var step := maxf(stats.get_attack_range() - d + 0.5, 1.5)
	var dest := global_position + away * step
	# Never kite back into the enemy's tower or orb.
	if game.is_in_enemy_tower_range(dest, stats.get_team()):
		return false
	_go_to(dest)
	return true


## True while every enemy champion is dead or running home to heal: the window
## a human uses to turn kills into towers. Not when we're hurt ourselves.
func _should_push(hp_frac: float) -> bool:
	if hp_frac < 0.4:
		return false
	# Uses the real champions, not fog-filtered ones: an unseen champion isn't a dead one.
	var foes := game.champions_of(game.other_team(stats.get_team()))
	if foes.is_empty():
		return false
	for foe in foes:
		if not is_instance_valid(foe):
			continue
		var fs := EntityData.get_stats_of(foe)
		if fs != null and not fs.is_dead and foe.get("_retreating") != true:
			return false
	return true


## Press the advantage: kill the enemy wave, then hit their nearest tower while at
## least one of our minions is in its range to take the shots, otherwise walk up
## with the front of our wave. The orb is still left alone (it kills champions).
func _push() -> void:
	var my_team := stats.get_team()
	var minion := _pick_minion()
	if minion:
		_attack(minion)
		return
	var structure := game.nearest_enemy_structure(global_position, my_team, 30.0)
	if structure and structure.kind != ProtoStructure.Kind.ORB 			and game.allied_minions_near(structure.global_position, my_team, structure.attack_range) >= 1:
		_attack(structure)
		return
	var front := game.frontmost_allied_minion(my_team)
	if front and not game.is_in_enemy_orb_range(front.global_position, my_team, 2.0):
		_go_to(front.global_position)
		return
	_go_to(_hold_position())


## A jungle monster worth taking now: between waves (or one we're already
## finishing), when healthy, the enemy champion isn't nearby, and we don't
## already have most of that camp's buff left.
func _pick_jungle_monster(foe: CharacterBody3D, hp_frac: float) -> ProtoJungleMonster:
	var my_team := stats.get_team()
	# The target can already be freed (a monster that died while our swing wound down).
	var busy_with: ProtoJungleMonster = null
	if _attacking and is_instance_valid(_attack_target):
		busy_with = _attack_target as ProtoJungleMonster
	if busy_with and _alive(busy_with) and hp_frac > 0.35:
		return busy_with
	# Waves never stop now, so "between waves" means a fresh wave isn't due soon.
	if game.wave_time_left < 15.0 or hp_frac < 0.6:
		return null
	# Each side has a home camp it goes for first, and only takes the other one when
	# its own is down and the enemy champion isn't there. The two camps give different
	# buffs, so which side gets which is decided by the match seed: over many matches
	# each side gets each camp half the time. (Picking by distance flip-flopped as
	# the bots walked out, and sent both to the same camp.)
	var home := _home_camp()
	var order: Array[String] = [home]
	for camp_id: String in ProtoConfig.JUNGLE_CAMPS:
		if camp_id != home:
			order.append(camp_id)
	for camp_id in order:
		var m := game.camp_monster(camp_id)
		if m == null or m.is_resetting():
			continue
		if game.jungle_buff_time_left(my_team, camp_id) > 30.0:
			continue
		if _alive(foe) and ProtoUtil.flat_distance(foe.global_position, m.global_position) < 12.0:
			continue
		return m
	return null


## This side's first-choice jungle camp for the match (see _pick_jungle_monster).
func _home_camp() -> String:
	var camps: Array = ProtoConfig.JUNGLE_CAMPS.keys()
	camps.sort()
	var flip := (game.match_seed + stats.get_team()) % 2
	return str(camps[flip])


func _foe_is_fair_game(foe: CharacterBody3D, hp_frac: float) -> bool:
	if foe == null or not is_instance_valid(foe):
		return false
	var fs := EntityData.get_stats_of(foe)
	if fs == null or fs.is_dead:
		return false
	if ProtoUtil.flat_distance(global_position, foe.global_position) > 8.0:
		return false
	if game.is_in_enemy_tower_range(foe.global_position, stats.get_team(), 1.0):
		return false
	var foe_frac := fs.current_health / fs.get_max_health()
	return foe_frac <= hp_frac + 0.1 or foe_frac < 0.35


func _pick_minion() -> CharacterBody3D:
	var my_team := stats.get_team()
	var my_hit := stats.get_attack_damage()
	var best: CharacterBody3D = null
	var best_score := INF
	for m in game.minions:
		if m.team == my_team or m.stats.is_dead or not FogOfWar.can_see(my_team, m):
			continue
		var d := ProtoUtil.flat_distance(global_position, m.global_position)
		if d > 10.0 or game.is_in_enemy_orb_range(m.global_position, my_team, 2.5):
			continue
		var unsafe := game.is_in_enemy_tower_range(m.global_position, my_team, 0.5)
		if unsafe and game.allied_minions_near(m.global_position, my_team, 6.0) < 2:
			continue
		var score := d + m.stats.current_health / 50.0
		if m.stats.current_health <= my_hit:
			score -= 10.0
		if score < best_score:
			best_score = score
			best = m
	return best


func _hold_position() -> Vector3:
	var my_team := stats.get_team()
	var back := -game.forward_of(my_team)
	var front := game.frontmost_allied_minion(my_team)
	var pos := game.guard_position(my_team)
	if front:
		pos = front.global_position + Vector3(back * 3.0, 0.0, 0.0)
	# Never wait inside an enemy tower's range.
	var guard := 0
	while game.is_in_enemy_tower_range(pos, my_team, 1.5) and guard < 30:
		pos.x += back * 1.5
		guard += 1
	pos.y = 0.0
	return pos


# ---- Ability use, per champion ----

func _champion_id() -> String:
	return stats.definition.entity_id


## Abilities used whenever the bot thinks. Returns true if it committed to something
## that should end this think tick.
func _kit_engage(foe: CharacterBody3D, hp_frac: float) -> bool:
	match _champion_id():
		"cats_paw":
			return _cp_use_kit(foe, hp_frac)
		"potion_seller":
			_ps_use_kit(foe, hp_frac)
		"argonaut":
			_wf_use_kit(foe, hp_frac)
		"drill_sergeant":
			_ds_use_kit(foe, hp_frac)
		"broom_rider":
			return _br_use_kit(foe, hp_frac)
		"hired_blade":
			return _hb_use_kit(foe, hp_frac)
		"sleepwalker":
			_sw_use_kit(foe, hp_frac)
		"artificer":
			_ar_use_kit(foe, hp_frac)
		"wrangler":
			return _wr_use_kit(foe, hp_frac)
		"wakeman":
			return _bh_use_kit(foe, hp_frac)
		"unioneer":
			return _en_use_kit(foe, hp_frac)
		"gunslinger":
			return _gs_use_kit(foe, hp_frac)
	return false


## Abilities used while trading blows with the enemy champion.
func _kit_in_fight(foe: CharacterBody3D) -> void:
	match _champion_id():
		"cats_paw":
			_try_dash_to(foe)
			_try_empower(foe)
		"hired_blade":
			_hb_riders(foe)


## Abilities used while running home at low health.
func _kit_escape(foe: CharacterBody3D) -> void:
	match _champion_id():
		"cats_paw":
			_reel_to_escape(foe)
		"potion_seller":
			_ps_escape(foe)
		"argonaut":
			_wf_escape(foe)
		"drill_sergeant":
			_ds_escape(foe)
		"broom_rider":
			_br_escape(foe)
		"hired_blade":
			_hb_escape(foe)
		"sleepwalker":
			_sw_escape(foe)
		"artificer":
			_ar_escape(foe)
		"wrangler":
			_wr_escape(foe)
		"wakeman":
			_bh_escape(foe)
		"unioneer":
			_en_escape(foe)
		"gunslinger":
			_gs_escape(foe)


# ---- Broom Rider ----

## Her main combo: Q dive onto the enemy champion, W (shield + missiles) on
## arrival, then Q again to blink back out. E charges her next auto (bonus magic
## damage + a slow). R (the big slow orb) goes out when they're stunned/slowed
## or close, and is burst on them as it passes.
## She's the squishiest champion, so outside the combo she keeps her distance:
## W shields her when she's taking damage, and with her dive down she backs off
## instead of trading autos inside the enemy wave. Returns true when she's
## backing off (that ends the think).
func _br_use_kit(foe: CharacterBody3D, hp_frac: float) -> bool:
	var c := _abilities()
	if c == null:
		return false
	var my_team := stats.get_team()
	_br_burst_orb(foe)
	_br_ride_out(foe, hp_frac)
	_br_hex_bolt(foe)
	_br_shield_up(hp_frac)
	if not _alive(foe):
		_br_wave_clear()
		return false
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	var under_tower := game.is_in_enemy_tower_range(foe.global_position, my_team, 2.0)
	var fs := EntityData.get_stats_of(foe)
	var foe_frac := fs.current_health / fs.get_max_health()
	# Finish them: a low enemy champion she's healthier than gets chased down with
	# everything, instead of being let go when they turn to run.
	if _br_finishing(foe, hp_frac):
		var qf := _ready_ability(0) as RideAbility
		if qf and d > 2.0 and d <= (qf.definition as RideDefinition).distance + stats.get_attack_range():
			_cast(0, foe.global_position)
		var wf := _ready_ability(1) as HexSwarmAbility
		if wf and d <= (wf.definition as HexSwarmDefinition).missile_range - 0.3:
			_cast(1, global_position)
		_attack(foe)
		return true
	# Poke: auto -> E -> auto (the E resets the attack) when they're in her range.
	if _ready_ability(2) and d <= stats.get_attack_range() + 0.3 and hp_frac > 0.4 and not under_tower:
		if _auto_reset_combo(2, foe):
			return true
	var w := _ready_ability(1) as HexSwarmAbility
	# W: as soon as the enemy champion is in missile range (right after the dive lands).
	if w and d <= (w.definition as HexSwarmDefinition).missile_range - 0.3:
		_cast(1, global_position)
	# Q: dive when W is ready to follow up, she's healthy (or healthier than them),
	# and they're not under their towers. The blink back keeps it safe.
	var q := _ready_ability(0) as RideAbility
	if q and w and (hp_frac > 0.45 or (hp_frac > 0.3 and foe_frac < hp_frac)) and not under_tower:
		var reach := (q.definition as RideDefinition).distance
		if d > 3.0 and d <= reach + 4.5:
			_cast(0, foe.global_position)
	# R: roll the orb at them when they can't easily step out of its path
	# (stunned or slowed), or when they're close.
	var r := _ready_ability(3) as HeavyOrbAbility
	if r and d <= 10.0:
		var fx := foe.get_node_or_null("StatusEffects") as StatusEffects
		var stuck := fx != null and (fx.is_stunned() or fx.slow_amount() >= 0.2)
		if stuck or d <= 4.0:
			_cast(3, foe.global_position)
	# Keep W for the dive (or her shield) while the enemy champion is anywhere near.
	if d > 12.0:
		_br_wave_clear()
	return _br_keep_distance(foe, d, hp_frac, foe_frac)


## True when the enemy champion is low (under 35%), she's clearly healthier, and
## they're close enough to catch and not under their towers.
func _br_finishing(foe: CharacterBody3D, hp_frac: float) -> bool:
	if not _alive(foe):
		return false
	var fs := EntityData.get_stats_of(foe)
	var foe_frac := fs.current_health / fs.get_max_health()
	if foe_frac >= 0.35 or hp_frac < foe_frac + 0.1 or hp_frac < 0.3:
		return false
	if ProtoUtil.flat_distance(global_position, foe.global_position) > 14.0:
		return false
	return not game.is_in_enemy_tower_range(foe.global_position, stats.get_team(), 1.0)


## W as a shield: when she's below 60% and an enemy (champion or minion) is on
## her, even if it isn't the combo.
func _br_shield_up(hp_frac: float) -> void:
	if hp_frac >= 0.6:
		return
	var w := _ready_ability(1) as HexSwarmAbility
	if w and not w.targets_in_range().is_empty():
		_cast(1, global_position)


## With no dive ready (and no blink waiting), don't let the enemy champion stand
## on top of her unless they're the one losing: when they're within melee reach,
## step back to her own attack range and keep farming from there. She holds the
## lane otherwise; giving ground costs the wave.
## How close the enemy champion can get before she steps back (melee reach plus a little).
const KITE_TRIGGER := 4.0


func _br_keep_distance(foe: CharacterBody3D, d: float, hp_frac: float, foe_frac: float) -> bool:
	var c := _abilities()
	var q := c.get_ability(0) as RideAbility
	if q == null or q.wants_recast() or _ready_ability(0) != null:
		return false
	if foe_frac < hp_frac - 0.15 or d > KITE_TRIGGER:
		return false
	var away := global_position - foe.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(-game.forward_of(stats.get_team()), 0.0, 0.0)
	# Lean toward our own side of the lane so she backs into her wave, not along it.
	away = (away.normalized() + Vector3(-game.forward_of(stats.get_team()), 0.0, 0.0)).normalized()
	# Just far enough to be back at her own attack range.
	var step := maxf(stats.get_attack_range() + 0.5 - d, 1.0)
	_go_to(global_position + away * step)
	return true

## The orb is rolling: burst it when the enemy champion is in the blast, or on a
## big crowd when the champion is nowhere near.
func _br_burst_orb(foe: CharacterBody3D) -> void:
	var c := _abilities()
	var r := c.get_ability(3) as HeavyOrbAbility if c else null
	if r == null or not r.wants_recast():
		return
	var o := r.orb()
	if o == null:
		return
	var foe_d := ProtoUtil.flat_distance(o.global_position, foe.global_position) if _alive(foe) else INF
	if foe_d <= o.burst_radius - 0.5:
		_cast(3, o.global_position)
		return
	var crowd := AbilityUtil.enemies_in_radius(get_tree(), stats.get_team(), o.global_position, o.burst_radius).size()
	if crowd >= 4 and foe_d > 10.0:
		_cast(3, o.global_position)


## After a Q dive: blink back once W has gone out, or right away if the dive went
## wrong (low health, or she landed in enemy tower range). Never blink into tower range.
func _br_ride_out(_foe: CharacterBody3D, hp_frac: float) -> void:
	var c := _abilities()
	var q := c.get_ability(0) as RideAbility if c else null
	if q == null or not q.wants_recast() or status_effects().is_movement_locked():
		return
	if game.is_in_enemy_tower_range(q.return_point(), stats.get_team()):
		return
	# Don't blink out on a kill: stay and finish a low champion she's healthier than.
	if _br_finishing(_foe, hp_frac) and not game.is_in_enemy_tower_range(global_position, stats.get_team()):
		return
	var w := c.get_ability(1)
	var w_spent := w == null or not w.is_learned() or w.cooldown_left > 0.0
	var in_danger := hp_frac < 0.4 or game.is_in_enemy_tower_range(global_position, stats.get_team())
	# Without danger, stay as long as W hasn't gone out yet, but don't let the window lapse.
	if in_danger or (w_spent and q.return_time_left() < 2.5) or q.return_time_left() < 0.4:
		_cast(0, q.return_point())


## E: charge the next auto when she's about to hit the enemy champion, or a
## mercenary when the enemy champion isn't close. The slow sets up her R.
func _br_hex_bolt(foe: CharacterBody3D) -> void:
	var e := _ready_ability(2)
	if e == null or not _attacking or not is_instance_valid(_attack_target) or not _alive(_attack_target):
		return
	if ProtoUtil.flat_distance(global_position, _attack_target.global_position) > stats.get_attack_range() + 0.5:
		return
	var on_champion := _attack_target == foe
	var foe_close := _alive(foe) and ProtoUtil.flat_distance(global_position, foe.global_position) <= 10.0
	# In the gap after a hit, so the bolt auto starts at once (auto -> E -> auto).
	if (on_champion or not foe_close or stats.current_mana < stats.get_max_mana() * 0.7) and _in_attack_gap():
		_cast(2, _attack_target.global_position)


## W into 3+ enemies in range when there's mana to spare.
func _br_wave_clear() -> void:
	if stats.current_mana < stats.get_max_mana() * 0.5:
		return
	var w := _ready_ability(1) as HexSwarmAbility
	if w and w.targets_in_range().size() >= 3:
		_cast(1, global_position)


## Running home: blink back if a Q return is waiting and is closer to home,
## otherwise Q toward home; shield up.
func _br_escape(foe: CharacterBody3D) -> void:
	var c := _abilities()
	if c == null:
		return
	var home := game.fountain_position(stats.get_team())
	var q := c.get_ability(0) as RideAbility
	if q and q.wants_recast() and not status_effects().is_movement_locked():
		if ProtoUtil.flat_distance(q.return_point(), home) < ProtoUtil.flat_distance(global_position, home):
			_cast(0, q.return_point())
	if not _alive(foe):
		return
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	if d > 7.0:
		return
	if _ready_ability(1):
		_cast(1, global_position)
	if _ready_ability(0) and d <= 7.0:
		_cast(0, home)


# ---- Hired Blade ----

## Opens with Grapple when the champion is outside melee, then rides his autos:
## Q and W each buff the next two swings. Smoke is saved for a dive or a crowd.
func _hb_use_kit(foe: CharacterBody3D, hp_frac: float) -> bool:
	var c := _abilities()
	if c == null:
		return false
	_hb_smoke(foe, hp_frac)
	_hb_recast_smoke(foe)
	if not _alive(foe):
		return false
	var my_team := stats.get_team()
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	var e := _ready_ability(2) as GrappleAbility
	if e and hp_frac > 0.35 and d > stats.get_attack_range() + 0.5 \
			and d <= (e.definition as GrappleDefinition).cast_range - 0.5 \
			and not game.is_in_enemy_tower_range(foe.global_position, my_team):
		return _cast(2, foe.global_position)
	_hb_riders(foe)
	return false


## Q and W are riders: fire both right before trading autos.
func _hb_riders(foe: CharacterBody3D) -> void:
	if not _alive(foe):
		return
	if ProtoUtil.flat_distance(global_position, foe.global_position) > stats.get_attack_range() + 1.0:
		return
	for slot: int in [0, 1]:
		var a := _ready_ability(slot)
		if a and not a.is_active():
			_cast(slot, foe.global_position)


## R when dived by the champion or when several enemies are on him.
func _hb_smoke(foe: CharacterBody3D, hp_frac: float) -> void:
	var r := _ready_ability(3)
	if r == null:
		return
	var def := r.definition as SmokeBombDefinition
	var close := _alive(foe) and ProtoUtil.flat_distance(global_position, foe.global_position) <= stats.get_attack_range() + 1.5
	var crowd := AbilityUtil.enemies_in_radius(get_tree(), stats.get_team(), global_position, def.radius).size()
	if (close and hp_frac < 0.7) or (crowd >= 3 and hp_frac < 0.8):
		_cast(3, global_position)


## Pop the smoke early once two or more enemies are inside it (or the champion is).
func _hb_recast_smoke(foe: CharacterBody3D) -> void:
	var c := _abilities()
	var r := c.get_ability(3) as SmokeBombAbility if c else null
	if r == null or not r.wants_recast():
		return
	var def := r.definition as SmokeBombDefinition
	var crowd := AbilityUtil.enemies_in_radius(get_tree(), stats.get_team(), global_position, def.radius).size()
	var on_foe := _alive(foe) and ProtoUtil.flat_distance(global_position, foe.global_position) <= def.radius - 0.5
	if crowd >= 2 or on_foe:
		_cast(3, global_position)


## Running home: smoke the chaser so their autos whiff while he escapes.
func _hb_escape(foe: CharacterBody3D) -> void:
	if not _alive(foe):
		return
	var r := _ready_ability(3)
	if r and ProtoUtil.flat_distance(global_position, foe.global_position) <= (r.definition as SmokeBombDefinition).radius - 0.5:
		_cast(3, global_position)


# ---- Sleepwalker ----

## Grit first, then spend it: W on a stuck foe (or the wave), Q through them to
## root, E once they have 3+ stacks. R is charged for a wall when the fight is far.
func _sw_use_kit(foe: CharacterBody3D, hp_frac: float) -> void:
	var c := _abilities()
	if c == null:
		return
	var storm := c.get_ability(3) as SandstormAbility
	if storm and storm.is_charging():
		var aim := global_position + Vector3(-game.forward_of(stats.get_team()) * 10.0, 0.0, 0.0)
		if _alive(foe):
			aim = foe.global_position
		var close := _alive(foe) and ProtoUtil.flat_distance(global_position, foe.global_position) <= 6.0
		if storm.charge_ratio() >= 0.6 or close:
			_cast(3, aim)
		return
	_sw_sandblast(foe)
	if not _alive(foe):
		_sw_wave_clear()
		return
	var grit := GritAbility.of(self)
	if grit == null:
		return
	var stacks := grit.stacks_of(foe)
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	var fx := foe.get_node_or_null("StatusEffects") as StatusEffects
	var stuck := fx != null and (fx.is_rooted() or fx.is_stunned() or fx.slow_amount() >= 0.2)
	# Q: root through the wave whenever the foe is in range.
	var q := _ready_ability(0)
	if q and d <= q.definition.cast_range - 0.5 and stacks < 5:
		_cast(0, foe.global_position)
	# W: a whirlwind on a stuck foe, or on the wave when the foe is far.
	var w := _ready_ability(1)
	if w and d <= (w.definition as DustDevilDefinition).cast_range - 0.5 and (stuck or stacks > 0):
		_cast(1, _lead(foe, 0.3))
	elif w and d > 9.0:
		_sw_wave_clear()
	# R: charge it when the foe is out of reach (or gone) and it's safe to stand.
	var r := _ready_ability(3)
	if r and hp_frac > 0.45:
		var aim := foe.global_position if _alive(foe) else global_position + Vector3(-game.forward_of(stats.get_team()) * 12.0, 0.0, 0.0)
		if not _alive(foe) or d > 9.0:
			_cast(3, aim)


## E when the foe has 3+ stacks in range, or when a stacked wave is nearby.
func _sw_sandblast(foe: CharacterBody3D) -> bool:
	var e := _ready_ability(2)
	if e == null:
		return false
	var grit := GritAbility.of(self)
	if grit == null:
		return false
	var def := e.definition as SandblastDefinition
	if _alive(foe) and grit.stacks_of(foe) >= 3:
		if ProtoUtil.flat_distance(global_position, foe.global_position) <= def.radius:
			return _cast(2, foe.global_position)
	var stacked := 0
	for body in grit.stacked_in_radius(global_position, def.radius):
		if body is ProtoMinion and grit.stacks_of(body) >= 2:
			stacked += 1
	if stacked >= 3:
		return _cast(2, global_position)
	return false


## W onto the biggest cluster of enemy minions.
func _sw_wave_clear() -> void:
	if stats.current_mana < stats.get_max_mana() * 0.5:
		return
	var w := _ready_ability(1)
	if w == null:
		return
	var radius := (w.definition as DustDevilDefinition).radius
	var best := Vector3.ZERO
	var best_count := 0
	for m in game.minions:
		if m.team == stats.get_team() or m.stats.is_dead:
			continue
		var count := AbilityUtil.enemies_in_radius(get_tree(), stats.get_team(), m.global_position, radius).size()
		if count > best_count:
			best_count = count
			best = m.global_position
	if best_count >= 3:
		_cast(1, best)


## No escape tool: root the chaser and drop a whirlwind under himself.
func _sw_escape(foe: CharacterBody3D) -> void:
	if not _alive(foe):
		return
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	if d > 12.0:
		return
	if _ready_ability(0):
		_cast(0, foe.global_position)
	if d <= 6.0 and _ready_ability(1):
		_cast(1, global_position)


# ---- Artificer ----

## Keeps the board stocked with Q, detonates it when enemies stand in the bursts,
## and fires rays for the shield when dived. R goes across a committed wave clash,
## never into empty ground.
func _ar_use_kit(foe: CharacterBody3D, hp_frac: float) -> void:
	var c := _abilities()
	if c == null:
		return
	var manager := ArtificerRobots.find(self)
	_ar_production_line(foe)
	_ar_demolition(foe, manager)
	_ar_reel(foe, hp_frac, manager)
	_ar_crawler(foe)


## R: across the enemy champion's group, or a full minion cluster near him.
func _ar_production_line(foe: CharacterBody3D) -> void:
	var r := _ready_ability(3)
	if r == null:
		return
	if _alive(foe):
		var d := ProtoUtil.flat_distance(global_position, foe.global_position)
		var clustered := AbilityUtil.enemies_in_radius(get_tree(), stats.get_team(), foe.global_position, 3.0).size()
		if d <= (r.definition as ProductionLineDefinition).start_distance + 9.0 and clustered >= 3:
			_cast(3, foe.global_position)
			return
	var near := AbilityUtil.enemies_in_radius(get_tree(), stats.get_team(), global_position, 12.0)
	if near.size() < 4:
		return
	var center := Vector3.ZERO
	for body in near:
		center += body.global_position
	center /= float(near.size())
	if ProtoUtil.flat_distance(global_position, center) > 0.5:
		_cast(3, center)


## W: the nuke. Send every robot when the enemy champion, or two enemies, are within
## their seek range (each runs at the nearest enemy and bursts).
func _ar_demolition(foe: CharacterBody3D, manager: ArtificerRobots) -> void:
	var w := _ready_ability(1)
	if w == null or manager == null or manager.board_count() == 0:
		return
	var def := w.definition as DemolitionDefinition
	if manager.board_count() < 2:
		return
	var foe_near := _alive(foe) and manager.robot_covers(foe.global_position, def.seek_range)
	if foe_near or manager.enemies_in_burst(def.seek_range).size() >= 2:
		_cast(1, global_position)


## E: an enemy champion (or three enemies) inside the shove radius. It shields him,
## shoves the diver back and slows it; the robots' rays sting whoever they cross.
func _ar_reel(foe: CharacterBody3D, _hp_frac: float, _manager: ArtificerRobots) -> void:
	var e := _ready_ability(2)
	if e == null:
		return
	var radius := (e.definition as ReelInDefinition).push_radius
	var foe_close := _alive(foe) and ProtoUtil.flat_distance(global_position, foe.global_position) <= radius + 0.5
	if foe_close or AbilityUtil.enemies_in_radius(get_tree(), stats.get_team(), global_position, radius).size() >= 3:
		_cast(2, global_position)


## Q: plant robots on the enemy champion, ahead of the enemy wave, or stock them
## in front of himself (behind his tower when the front is unsafe). There is no
## board cap, so he can keep adding robots while he has charges.
func _ar_crawler(foe: CharacterBody3D) -> void:
	var q := _ready_ability(0)
	if q == null:
		return
	var def := q.definition as CrawlerDefinition
	# Keep mana back for E and W so planting robots doesn't leave him without his shield.
	var board := ArtificerRobots.find(self)
	if board and board.board_count() >= 2 and stats.current_mana < q.mana_cost() + 75.0:
		return
	var aim := Vector3.ZERO
	if _alive(foe):
		var d := ProtoUtil.flat_distance(global_position, foe.global_position)
		if d > 0.5 and d <= def.cast_range + 1.5 and not game.is_in_enemy_tower_range(foe.global_position, stats.get_team(), 0.5):
			aim = _lead(foe, 0.25)
	if aim == Vector3.ZERO:
		var cluster := Vector3.ZERO
		var count := 0
		for m in game.minions:
			if m.team == stats.get_team() or m.stats.is_dead:
				continue
			if ProtoUtil.flat_distance(global_position, m.global_position) > def.cast_range:
				continue
			cluster += m.global_position
			count += 1
		if count > 0:
			aim = cluster / float(count)
	if aim == Vector3.ZERO:
		var forward := Vector3(game.forward_of(stats.get_team()), 0.0, 0.0)
		aim = global_position + forward * minf(def.cast_range - 1.0, 5.0)
		if game.is_in_enemy_tower_range(aim, stats.get_team(), 0.0):
			aim = global_position - forward * 3.0
	_cast(0, aim)


## Running home: fire E's rays, shield and shove the chaser.
func _ar_escape(foe: CharacterBody3D) -> void:
	if not _alive(foe):
		return
	if ProtoUtil.flat_distance(global_position, foe.global_position) > 9.0:
		return
	if _ready_ability(2):
		_cast(2, global_position)


# ---- Drill Sergeant ----

func _ds_use_kit(foe: CharacterBody3D, hp_frac: float) -> void:
	var c := _abilities()
	if c == null:
		return
	var my_team := stats.get_team()
	# R: once 4+ of his mercenaries are around him and there's a fight or a tower in reach.
	var r := _ready_ability(3) as ForwardMarchAbility
	if r and r.mercenaries_in_range() >= 4:
		var tower := game.nearest_enemy_structure(global_position, my_team, 16.0)
		var enemies_near := AbilityUtil.enemies_in_radius(get_tree(), my_team, global_position, 8.0).size()
		if tower or enemies_near >= 3:
			_cast(3, global_position)
	# W: hand the banner to his front mercenary as the waves are about to meet,
	# or plant it at his feet when he's dueling the enemy champion.
	var w := _ready_ability(1)
	if w:
		var front := game.frontmost_allied_minion(my_team)
		var reach := w.definition.cast_range + 2.0
		if front and ProtoUtil.flat_distance(global_position, front.global_position) <= reach \
				and not AbilityUtil.enemies_in_radius(get_tree(), my_team, front.global_position, 9.0).is_empty():
			_cast(1, front.global_position)
		elif _alive(foe) and ProtoUtil.flat_distance(global_position, foe.global_position) <= 4.0:
			_cast(1, global_position)
	if _alive(foe):
		# E: rush the enemy champion when it's a few meters away and not under its towers.
		var e := _ready_ability(2)
		var d := ProtoUtil.flat_distance(global_position, foe.global_position)
		if e and hp_frac > 0.35 and d >= 3.0 and d <= (e.definition as ShieldRushDefinition).distance \
				and not game.is_in_enemy_tower_range(foe.global_position, my_team):
			_cast(2, foe.global_position)
	_ds_cleave(foe)


## Q: on the enemy champion when it's in reach, or into 2+ enemies (a wave) in front of him.
func _ds_cleave(foe: CharacterBody3D) -> void:
	var q := _ready_ability(0)
	if q == null:
		return
	var def := q.definition as CleaveDefinition
	var c := _abilities()
	if _alive(foe) and ProtoUtil.flat_distance(global_position, foe.global_position) <= def.reach + 0.6:
		_cast(0, foe.global_position)
		return
	var near := AbilityUtil.enemies_in_radius(get_tree(), stats.get_team(), global_position, def.reach)
	if near.size() < 2:
		return
	var aim := near[0].global_position
	if AbilityUtil.enemies_in_arc(get_tree(), stats.get_team(), global_position, aim - global_position, def.reach, def.angle).size() >= 2:
		_cast(0, aim)


## Running home: Shield Rush away from a chaser.
func _ds_escape(foe: CharacterBody3D) -> void:
	var e := _ready_ability(2)
	if e and _alive(foe) and ProtoUtil.flat_distance(global_position, foe.global_position) <= 5.0:
		_cast(2, game.fountain_position(stats.get_team()))


func _abilities() -> AbilityCaster:
	return get_node_or_null("Abilities") as AbilityCaster


func _ready_ability(slot: int) -> Ability:
	var c := _abilities()
	if c == null:
		return null
	var a := c.get_ability(slot)
	if a == null or a.cast_problem() != "":
		return null
	return a


## Where `t` will roughly be after `seconds`, from its current velocity.
func _lead(t: CharacterBody3D, seconds: float) -> Vector3:
	var v := t.velocity
	v.y = 0.0
	return t.global_position + v * seconds


# ---- Potion Seller ----

## Explode the jug when the enemy is in it. R when they're low or bunched with
## their mercenaries. Load poison (or glue up close) right before a Q at them,
## and Q waves when there's mana to spare.
func _ps_use_kit(foe: CharacterBody3D, hp_frac: float) -> void:
	var c := _abilities()
	if c == null:
		return
	var my_team := stats.get_team()
	_ps_explode(foe)
	if not _alive(foe):
		_ps_wave_clear()
		return
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	var under_tower := game.is_in_enemy_tower_range(foe.global_position, my_team)
	var fs := EntityData.get_stats_of(foe)
	var foe_frac := fs.current_health / fs.get_max_health()
	var r := _ready_ability(3)
	if r and not under_tower:
		var reach := (r.definition as BigJugDefinition).roll_distance
		var crowd := AbilityUtil.enemies_in_radius(get_tree(), my_team, foe.global_position, 3.5).size()
		if d <= reach - 1.0 and (foe_frac < 0.6 or crowd >= 4):
			_cast(3, foe.global_position)
	var q := _ready_ability(0)
	if q and d <= q.definition.cast_range:
		if PotionMixAbility.loaded_on(self) == null and hp_frac > 0.3:
			var mix_slot := 1 if d < 4.0 else 2
			if _ready_ability(mix_slot) == null:
				mix_slot = 3 - mix_slot
			if _ready_ability(mix_slot):
				_cast(mix_slot, global_position)
		var mix := PotionMixAbility.loaded_on(self)
		var flight := (q.definition as TossPotionDefinition).flight_time
		if mix:
			var mf := (mix.definition as PotionMixDefinition).flight_time
			if mf > 0.0:
				flight = mf
		_cast(0, _lead(foe, flight))
	_ps_wave_clear()


## The jug is out: explode it when the enemy champion (or 3+ of their units) is in range of the blast.
func _ps_explode(foe: CharacterBody3D) -> void:
	var c := _abilities()
	var r := c.get_ability(3) as BigJugAbility if c else null
	if r == null or not r.wants_recast():
		return
	var j := r.jug()
	if j == null:
		return
	var foe_inside := _alive(foe) and ProtoUtil.flat_distance(j.global_position, foe.global_position) <= j.radius - 0.3
	var crowd := AbilityUtil.enemies_in_radius(get_tree(), stats.get_team(), j.global_position, j.radius).size()
	if foe_inside or crowd >= 3:
		_cast(3, j.global_position)


## Q into a group of 2+ enemy mercenaries when there's mana to spare (no ingredients).
func _ps_wave_clear() -> void:
	var q := _ready_ability(0)
	if q == null or stats.current_mana < stats.get_max_mana() * 0.4 or PotionMixAbility.loaded_on(self):
		return
	var radius := (q.definition as TossPotionDefinition).radius
	var best := Vector3.ZERO
	var best_count := 0
	for m in game.minions:
		if m.team == stats.get_team() or m.stats.is_dead:
			continue
		if ProtoUtil.flat_distance(global_position, m.global_position) > q.definition.cast_range:
			continue
		var n := AbilityUtil.enemies_in_radius(get_tree(), stats.get_team(), m.global_position, radius).size()
		if n > best_count:
			best_count = n
			best = m.global_position
	if best_count >= 2:
		_cast(0, best)


## Running home: glue the chaser to slow them.
func _ps_escape(foe: CharacterBody3D) -> void:
	if not _alive(foe):
		return
	var c := _abilities()
	var q := _ready_ability(0)
	if c == null or q == null:
		return
	if ProtoUtil.flat_distance(global_position, foe.global_position) > 6.0:
		return
	if PotionMixAbility.loaded_on(self) == null and _ready_ability(1):
		_cast(1, global_position)
	_cast(0, _lead(foe, 0.9))


# ---- Argonaut ----

## Haul them in (Q), drag them under with a charged auto (W), lash them (E), and
## knock them up (R) once the Undertow slow has them pinned.
## R when the enemy champion is inside the spout and slowed (or he's just healthy
## and they're close), or a big group is in it. E when they're in lash range. W as
## soon as they're in reach of his auto. Q when nothing blocks the rope and they're
## not under their towers.
func _wf_use_kit(foe: CharacterBody3D, hp_frac: float) -> void:
	var c := _abilities()
	if c == null or not _alive(foe):
		return
	var my_team := stats.get_team()
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	var fx := foe.get_node_or_null("StatusEffects") as StatusEffects
	var pinned := fx != null and (fx.slow_amount() >= 0.4 or fx.is_stunned())
	var r := _ready_ability(3)
	if r:
		var radius := (r.definition as WhaleSongDefinition).radius
		var crowd := AbilityUtil.enemies_in_radius(get_tree(), my_team, global_position, radius - 0.5).size()
		if (d <= radius - 1.0 and hp_frac > 0.3 and (pinned or d <= 2.0)) or crowd >= 4:
			_cast(3, global_position)
	var w := _ready_ability(1)
	if w and d <= stats.get_attack_range() + 1.0 and not game.is_in_enemy_tower_range(foe.global_position, my_team):
		_auto_reset_combo(1, foe)
	var e := _ready_ability(2)
	if e and d <= (e.definition as RopesEndDefinition).radius - 0.5:
		_cast(2, foe.global_position)
	var q := _ready_ability(0)
	if q and hp_frac > 0.4 and d > 3.0 and d <= q.definition.cast_range - 0.5:
		if not game.is_in_enemy_tower_range(foe.global_position, my_team) and not _wf_rope_blocked(foe):
			_cast(0, _lead(foe, d / (q.definition as HaulInDefinition).rope_speed))


## True if an enemy mercenary stands between us and `t` (the rope would hit it first).
func _wf_rope_blocked(t: CharacterBody3D) -> bool:
	var a := global_position
	var b := t.global_position
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var len2 := maxf(ab.length_squared(), 0.0001)
	for m in game.minions:
		if m.team == stats.get_team() or m.stats.is_dead:
			continue
		var ap := Vector2(m.global_position.x - a.x, m.global_position.z - a.z)
		var k := ap.dot(ab) / len2
		if k <= 0.0 or k >= 1.0:
			continue
		if (ap - ab * k).length() <= 0.35 + m.radius:
			return true
	return false


## Running home: lash the chaser (the slow buys distance).
func _wf_escape(foe: CharacterBody3D) -> void:
	var c := _abilities()
	if c == null or not _alive(foe):
		return
	var e := _ready_ability(2)
	if e and ProtoUtil.flat_distance(global_position, foe.global_position) <= (e.definition as RopesEndDefinition).radius - 0.5:
		_cast(2, foe.global_position)


# ---- Wrangler ----

## W when the pug can bark on them, Q to latch it on, then E through them so the
## pug charges out of the latch and stuns. R is saved for a stuck or clustered
## target. Q is skipped while the pug is already charging.
func _wr_use_kit(foe: CharacterBody3D, hp_frac: float) -> bool:
	var c := _abilities()
	if c == null:
		return false
	var pet := WranglerPounceAbility.pet_of(self)
	if not _alive(foe):
		return false
	var my_team := stats.get_team()
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	var under_tower := game.is_in_enemy_tower_range(foe.global_position, my_team)
	var latched := pet != null and pet.is_latched_to(foe)
	if pet:
		var w := _ready_ability(1)
		if w and ProtoUtil.flat_distance(pet.global_position, foe.global_position) <= (w.definition as BarkDefinition).radius - 0.25:
			_cast(1, global_position)
	var r := _ready_ability(3)
	if r and hp_frac > 0.3 and d <= (r.definition as FetchDefinition).cast_range - 1.0 and not under_tower:
		var fx := foe.get_node_or_null("StatusEffects") as StatusEffects
		var stuck := fx != null and (fx.is_stunned() or fx.slow_amount() >= 0.2)
		var crowd := AbilityUtil.enemies_in_radius(get_tree(), my_team, foe.global_position, 4.0).size()
		if stuck or d <= 4.0 or crowd >= 3:
			_cast(3, foe.global_position)
	var q := _ready_ability(0)
	if q and pet and not pet.is_charging() and not latched and hp_frac > 0.35 and not under_tower \
			and d <= q.definition.cast_range - 0.35:
		return _cast(0, foe.global_position)
	var e := _ready_ability(2)
	if e and pet and not pet.is_charging() and d >= 2.5 and d <= (e.definition as HeelDefinition).dash_distance + 1.0 \
			and hp_frac > 0.35 and not under_tower:
		return _cast(2, foe.global_position)
	return false


## Running home: bark from the pug if the chaser is on it, then dash away.
func _wr_escape(foe: CharacterBody3D) -> void:
	if not _alive(foe):
		return
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	if d > 7.0:
		return
	if _ready_ability(1) and d <= 5.0:
		_cast(1, global_position)
	if _ready_ability(2):
		_cast(2, game.fountain_position(stats.get_team()))


# ---- Cat's Paw ----

## Q: throw the knife at the enemy champion when in range, and recall it when the
## champion stands between the knife and us (so the return hits them too).
func _use_knife(foe: CharacterBody3D) -> void:
	var caster := get_node_or_null("Abilities") as AbilityCaster
	if caster == null or foe == null or not is_instance_valid(foe):
		return
	var q := caster.get_ability(0) as KnifeAbility
	var fs := EntityData.get_stats_of(foe)
	if q == null or fs == null or fs.is_dead:
		return
	if q.wants_recast():
		if q.has_knife_in_ground():
			var a := q.knife_position()
			var b := global_position
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var ap := Vector2(foe.global_position.x - a.x, foe.global_position.z - a.z)
			var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if (ap - ab * t).length() < 1.0:
				_cast(0, foe.global_position)
		return
	if q.cast_problem() != "":
		return
	var reach := (q.definition as KnifeDefinition).cast_range - 0.5
	if ProtoUtil.flat_distance(global_position, foe.global_position) <= reach:
		_cast(0, foe.global_position)


# ---- Cat's Paw (assassin) ----

## Commit to the all-in once the combo can take this share of their current HP + shield.
const CP_KILL_SHARE := 0.75

## Waits for knife (Q) and reel (R), then goes all in when the full combo can kill:
## knife thrown past them, reel in (blast + fear), dash to stick, empowered auto in
## the gap, autos. After a takedown the dash resets: he uses it to leave. He commits
## once the combo can take KILL_SHARE of their current HP (the fear, slow and
## follow-up autos usually finish the rest). Outside an all-in he farms and trades
## normally, but only pokes with the knife when the reel is far from ready, so the
## knife is back for the next all-in. Returns true while committed.
func _cp_use_kit(foe: CharacterBody3D, hp_frac: float) -> bool:
	var c := _abilities()
	if c == null:
		return false
	var my_team := stats.get_team()
	_cp_commit_left = maxf(_cp_commit_left - 0.25, 0.0)
	# Exit: the enemy champion just died and the dash came back.
	var real_foe := game.champion_of(game.other_team(my_team))
	if real_foe and EntityData.get_stats_of(real_foe).is_dead:
		if _cp_commit_left > 0.0 and _ready_ability(2):
			_cast(2, game.fountain_position(my_team))
		_cp_commit_left = 0.0
		return false
	if _cp_commit_left <= 0.0:
		_cp_wave_empower()
	if not _alive(foe):
		return false
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	var fs := EntityData.get_stats_of(foe)
	var foe_frac := fs.current_health / fs.get_max_health()
	var under_tower := game.is_in_enemy_tower_range(foe.global_position, my_team, 1.0)
	if _cp_commit_left <= 0.0 and not under_tower and hp_frac > 0.35 and d <= 9.0 \
			and _cp_combo_ready() and _cp_combo_damage(foe) >= (fs.current_health + fs.get_shield()) * CP_KILL_SHARE:
		_cp_commit_left = 5.0
	if _cp_commit_left > 0.0:
		# Bail if it went wrong: he's nearly dead and they aren't.
		if hp_frac < 0.2 and foe_frac > 0.3:
			_cp_commit_left = 0.0
			return false
		_cp_all_in(foe, d)
		return true
	# Knife poke only when the reel won't be ready soon, so the knife is back for the all-in.
	var r := c.get_ability(3)
	if r == null or not r.is_learned() or r.cooldown_left > 8.0:
		_use_knife(foe)
	return false


## W on a minion when 3+ enemies stand in its splash, in the gap after a hit.
func _cp_wave_empower() -> void:
	var w := _ready_ability(1)
	if w == null or not _attacking or not is_instance_valid(_attack_target) or not (_attack_target is ProtoMinion) or not _alive(_attack_target):
		return
	var radius := (w.definition as EmpowerDefinition).splash_radius
	if AbilityUtil.enemies_in_radius(get_tree(), stats.get_team(), _attack_target.global_position, radius).size() >= 3 and _in_attack_gap():
		_cast(1, _attack_target.global_position)


## Knife and reel ready (or the knife already in the ground), and mana for both.
func _cp_combo_ready() -> bool:
	var c := _abilities()
	var q := c.get_ability(0) as KnifeAbility
	var r := c.get_ability(3)
	if q == null or r == null or not r.is_learned() or r.cooldown_left > 0.0:
		return false
	var knife_ok := q.has_knife_in_ground() or (q.is_learned() and q.cooldown_left <= 0.0)
	var mana_needed := r.mana_cost() + (0.0 if q.has_knife_in_ground() else q.mana_cost())
	return knife_ok and stats.current_mana >= mana_needed


## Rough damage of the full combo on `foe`, after their armor (penetration ignored,
## so it errs low): knife + reel blast + empowered auto (if ready) + three autos.
func _cp_combo_damage(foe: CharacterBody3D) -> float:
	var c := _abilities()
	var ad := stats.get_attack_damage()
	var raw := 0.0
	var q := c.get_ability(0)
	if q and not (q as KnifeAbility).has_knife_in_ground():
		var qd := q.definition as KnifeDefinition
		raw += q.ranked(qd.base_damage, qd.damage_per_rank) + qd.ad_ratio * ad
	var r := c.get_ability(3)
	var rd := r.definition as ReelDefinition
	raw += r.ranked(rd.base_damage, rd.damage_per_rank) + rd.ad_ratio * ad
	var w := _ready_ability(1)
	if w:
		var wd := w.definition as EmpowerDefinition
		raw += w.ranked(wd.bonus_damage, wd.bonus_damage_per_rank) + wd.ad_ratio * ad
	raw += 3.0 * ad
	return raw * StatsComponent.resist_multiplier(EntityData.get_stats_of(foe).get_armor())


## One step of the all-in, in order: knife past them, reel to it (or in place when
## they're on top of him), dash to stick, empowered auto in the gap, attack.
func _cp_all_in(foe: CharacterBody3D, d: float) -> void:
	var c := _abilities()
	var q := c.get_ability(0) as KnifeAbility
	var r := _ready_reel()
	if r:
		var radius := (r.definition as ReelDefinition).radius
		if q.has_knife_in_ground():
			if ProtoUtil.flat_distance(q.knife_position(), foe.global_position) <= radius - 0.5:
				_cast(3, q.knife_position())
				return
		elif _ready_ability(0) and d <= (q.definition as KnifeDefinition).cast_range:
			# Land the knife just behind them so the reel blast covers them.
			var dir := foe.global_position - global_position
			dir.y = 0.0
			var aim := foe.global_position + dir.normalized() * 1.5 if dir.length() > 0.1 else foe.global_position
			_cast(0, AbilityUtil.clamp_to_range(global_position, aim, (q.definition as KnifeDefinition).cast_range))
			return
		elif d <= radius - 1.0:
			_cast(3, global_position)
			return
	var e := _ready_ability(2)
	if e and d > stats.get_attack_range() + 0.5 and d <= 6.0:
		_cast(2, foe.global_position)
		return
	if _ready_ability(1):
		_auto_reset_combo(1, foe)
		return
	_attack(foe)


## R to engage: pull to the knife when the enemy champion stands near it (and it's
## not under their towers), or go off in place when they're right next to us.
func _use_reel(foe: CharacterBody3D, hp_frac: float) -> bool:
	var r := _ready_reel()
	if r == null or not _alive(foe) or hp_frac < 0.35:
		return false
	var radius := (r.definition as ReelDefinition).radius
	var knife := r.pull_target_knife()
	var caster := get_node("Abilities") as AbilityCaster
	if knife:
		var kp := knife.knife_position()
		if ProtoUtil.flat_distance(kp, foe.global_position) <= radius - 0.5 and not game.is_in_enemy_tower_range(kp, stats.get_team()):
			return _cast(3, kp)
		return false
	if ProtoUtil.flat_distance(global_position, foe.global_position) <= radius - 1.0:
		return _cast(3, global_position)
	return false


## R to escape: fear the enemy champion off us while running home.
func _reel_to_escape(foe: CharacterBody3D) -> void:
	var r := _ready_reel()
	if r == null or not _alive(foe) or r.pull_target_knife() != null:
		return
	var radius := (r.definition as ReelDefinition).radius
	if ProtoUtil.flat_distance(global_position, foe.global_position) <= radius - 1.0:
		_cast(3, global_position)


func _ready_reel() -> ReelAbility:
	var caster := get_node_or_null("Abilities") as AbilityCaster
	if caster == null:
		return null
	var r := caster.get_ability(3) as ReelAbility
	if r == null or r.cast_problem() != "":
		return null
	return r


func _alive(t: CharacterBody3D) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	var st := EntityData.get_stats_of(t)
	return st != null and not st.is_dead


## Uses E to close a gap of a few meters to the enemy champion.
func _try_dash_to(t: CharacterBody3D) -> void:
	var caster := get_node_or_null("Abilities") as AbilityCaster
	if caster == null:
		return
	var e := caster.get_ability(2)
	if e == null or e.cast_problem() != "":
		return
	var d := ProtoUtil.flat_distance(global_position, t.global_position)
	if d > stats.get_attack_range() + 1.0 and d < 6.5:
		_cast(2, t.global_position)


## Uses W once the enemy champion is in melee range.
func _try_empower(t: CharacterBody3D) -> void:
	var caster := get_node_or_null("Abilities") as AbilityCaster
	if caster == null:
		return
	var w := caster.get_ability(1)
	if w == null or w.cast_problem() != "":
		return
	if ProtoUtil.flat_distance(global_position, t.global_position) <= stats.get_attack_range() + 0.5:
		_auto_reset_combo(1, t)


# ---- Wakeman ----

func _bh_use_kit(foe: CharacterBody3D, hp_frac: float) -> bool:
	var c := _abilities()
	if c == null:
		return false
	var q := c.get_ability(0) as TumbleAbility
	if q and q.is_active():
		return false
	var r := c.get_ability(3) as RainOfFireAbility
	if r and r.is_charging():
		return false
	if _bh_rain(foe, hp_frac):
		return true
	_bh_flashbang(foe)
	if _ready_ability(0) == null:
		return false
	var minion := _bh_last_hit_minion(q, foe)
	if minion and _bh_safe_spot(minion.global_position, foe):
		_attack(minion)
		return _cast(0, minion.global_position)
	if _alive(foe) and hp_frac > 0.4:
		var fs := EntityData.get_stats_of(foe)
		var foe_frac := fs.current_health / fs.get_max_health()
		var d := ProtoUtil.flat_distance(global_position, foe.global_position)
		var reach := (q.definition as TumbleDefinition).distance + stats.get_attack_range()
		if foe_frac < 0.3 and d <= reach and _bh_safe_spot(foe.global_position, null):
			_attack(foe)
			return _cast(0, foe.global_position)
	return false


func _bh_last_hit_minion(q: TumbleAbility, foe: CharacterBody3D) -> ProtoMinion:
	if q == null:
		return null
	var def := q.definition as TumbleDefinition
	var charged := stats.get_attack_damage() * (1.0 + q.ranked(def.ad_bonus, def.ad_bonus_per_rank))
	var reach := def.distance + stats.get_attack_range()
	var my_team := stats.get_team()
	var best: ProtoMinion = null
	var best_score := INF
	for m in game.minions:
		if m.team == my_team or m.stats.is_dead or not FogOfWar.can_see(my_team, m):
			continue
		var d := ProtoUtil.flat_distance(global_position, m.global_position)
		if d > reach + 0.5:
			continue
		var dealt := charged * StatsComponent.resist_multiplier(m.stats.get_armor())
		if m.stats.current_health > dealt:
			continue
		if not _bh_safe_spot(m.global_position, foe):
			continue
		var score := d + m.stats.current_health / 25.0
		if score < best_score:
			best_score = score
			best = m
	return best


func _bh_safe_spot(pos: Vector3, foe: CharacterBody3D) -> bool:
	var my_team := stats.get_team()
	if game.is_in_enemy_tower_range(pos, my_team, 0.5):
		return false
	if game.is_in_enemy_orb_range(pos, my_team, 1.5):
		return false
	if _alive(foe) and ProtoUtil.flat_distance(foe.global_position, pos) < 5.5:
		return false
	return true


func _bh_flashbang(foe: CharacterBody3D) -> bool:
	var e := _ready_ability(2) as FlashbangAbility
	if e == null:
		return false
	var def := e.definition as FlashbangDefinition
	if _alive(foe) and ProtoUtil.flat_distance(global_position, foe.global_position) <= 4.0:
		return _cast(2, _lead(foe, def.flight_time))
	var my_team := stats.get_team()
	var best := Vector3.ZERO
	var best_count := 0
	for m in game.minions:
		if m.team == my_team or m.stats.is_dead or not FogOfWar.can_see(my_team, m):
			continue
		if ProtoUtil.flat_distance(global_position, m.global_position) > def.cast_range:
			continue
		var count := AbilityUtil.enemies_in_radius(get_tree(), my_team, m.global_position, def.radius).size()
		if count > best_count:
			best_count = count
			best = m.global_position
	if best_count >= 3:
		return _cast(2, best)
	return false


func _bh_rain(foe: CharacterBody3D, hp_frac: float) -> bool:
	if hp_frac < 0.35:
		return false
	var r := _ready_ability(3)
	if r == null:
		return false
	if _alive(foe):
		var fs := EntityData.get_stats_of(foe)
		var foe_frac := fs.current_health / fs.get_max_health()
		var d := ProtoUtil.flat_distance(global_position, foe.global_position)
		if foe_frac < 0.4 and d <= 14.0:
			return _cast(3, foe.global_position)
	var my_team := stats.get_team()
	var near := AbilityUtil.enemies_in_radius(get_tree(), my_team, global_position, 12.0)
	if near.size() < 4:
		return false
	var center := Vector3.ZERO
	for body in near:
		center += body.global_position
	center /= float(near.size())
	if ProtoUtil.flat_distance(global_position, center) < 0.5:
		return false
	return _cast(3, center)


func _bh_escape(foe: CharacterBody3D) -> void:
	if not _alive(foe):
		return
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	if d > 7.0:
		return
	if _ready_ability(2):
		_cast(2, _lead(foe, 0.5))
	if d <= 6.0 and _ready_ability(0):
		_cast(0, game.fountain_position(stats.get_team()))


# ---- Unioneer ----

func _en_use_kit(foe: CharacterBody3D, hp_frac: float) -> bool:
	var c := _abilities()
	if c == null:
		return false
	if _en_overload(foe, hp_frac):
		return true
	var w := _ready_ability(1) as ChainLightningAbility
	if w and _alive(foe):
		var reach := (w.definition as ChainLightningDefinition).bolt_range - 0.3
		if ProtoUtil.flat_distance(global_position, foe.global_position) <= reach:
			return _cast(1, _lead(foe, 0.15))
	_en_wave_lightning(w)
	var q := _ready_ability(0) as TurretAbility
	if q and q.turret_count() < (q.definition as TurretDefinition).max_turrets:
		return _cast(0, _en_turret_spot(q, foe))
	return false


func _en_overload(foe: CharacterBody3D, hp_frac: float) -> bool:
	var r := _ready_ability(3)
	if r == null or not _alive(foe):
		return false
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	if d > (r.definition as OverloadDefinition).radius - 0.5:
		return false
	var fs := EntityData.get_stats_of(foe)
	var foe_frac := fs.current_health / fs.get_max_health()
	if d <= 4.0 or hp_frac < 0.55 or foe_frac < 0.4:
		return _cast(3, global_position)
	return false


func _en_wave_lightning(w: ChainLightningAbility) -> void:
	if w == null or stats.current_mana < stats.get_max_mana() * 0.5:
		return
	var my_team := stats.get_team()
	var def := w.definition as ChainLightningDefinition
	var best := Vector3.ZERO
	var best_count := 0
	for m in game.minions:
		if m.team == my_team or m.stats.is_dead or not FogOfWar.can_see(my_team, m):
			continue
		if ProtoUtil.flat_distance(global_position, m.global_position) > def.bolt_range - 1.0:
			continue
		var count := AbilityUtil.enemies_in_radius(get_tree(), my_team, m.global_position, def.chain_range).size()
		if count > best_count:
			best_count = count
			best = m.global_position
	if best_count >= 3:
		_cast(1, best)


func _en_turret_spot(q: TurretAbility, _foe: CharacterBody3D) -> Vector3:
	var my_team := stats.get_team()
	var back := Vector3(-game.forward_of(my_team), 0.0, 0.0)
	var reach := (q.definition as TurretDefinition).cast_range
	var pos := global_position + back * 2.5
	var front := game.frontmost_allied_minion(my_team)
	if front and ProtoUtil.flat_distance(global_position, front.global_position) <= reach - 1.0:
		pos = front.global_position + back * 1.5
	if game.is_in_enemy_tower_range(pos, my_team) or game.is_in_enemy_orb_range(pos, my_team, 0.5):
		pos = global_position + back * 3.5
	return AbilityUtil.clamp_to_range(global_position, pos, reach)


func _en_escape(foe: CharacterBody3D) -> void:
	if not _alive(foe):
		return
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	if d > 7.0:
		return
	var r := _ready_ability(3)
	if r:
		_cast(3, global_position)
	if _ready_ability(2):
		_cast(2, global_position)


# ---- Gunslinger ----

## Finishes with Big Iron when they're low, keeps Hollow Point for an auto-reset
## trade in range, and fans the hammer from range, leading the slow bullets.
## Big Iron doubles as an escape: the recoil shoves him away from them.
func _gs_use_kit(foe: CharacterBody3D, hp_frac: float) -> bool:
	var c := _abilities()
	if c == null:
		return false
	if not _alive(foe):
		return false
	var fs := EntityData.get_stats_of(foe)
	var foe_frac := fs.current_health / fs.get_max_health()
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	if _ready_ability(3) and d <= 11.0 and (foe_frac < 0.45 or hp_frac < 0.35):
		return _cast(3, foe.global_position)
	if d <= stats.get_attack_range() + 0.5 and _ready_ability(2):
		return _auto_reset_combo(2, foe)
	var q := _ready_ability(0)
	if q and d <= 9.0:
		var speed := (q.definition as FanTheHammerDefinition).bullet_speed
		return _cast(0, _lead(foe, d / maxf(speed, 1.0)))
	return false


func _gs_escape(foe: CharacterBody3D) -> void:
	if not _alive(foe):
		return
	var d := ProtoUtil.flat_distance(global_position, foe.global_position)
	if d <= 9.0 and _ready_ability(3):
		_cast(3, foe.global_position)


# ---- Commands ----

## Queues `cmd` as this bot's player. It applies at the start of the next tick;
## the bot re-reads the game state when it next thinks, so it doesn't need the result.
func _send(cmd: Dictionary) -> void:
	if _seat < 0:
		_seat = game.seat_of(self)
	game.execute_command(_seat, cmd)


## Queues a cast. True means "committed to it" (the caller ends its think).
func _cast(slot: int, pos: Vector3) -> bool:
	_send(PlayerCommand.cast(slot, pos))
	return true


## Spends a skill point if there is one: R first, then one rank in each basic,
## then the definition's skill priority. One per tick, since each lands on the
## next tick and changes what the next pick should be.
func _spend_skill_points() -> void:
	var c := _abilities()
	if c == null:
		return
	var slot := c.next_auto_rank_slot()
	if slot >= 0:
		_send(PlayerCommand.rank_up(slot))


## True between an auto's damage point and the next swing. That's when an attack
## reset (Cat's Paw W, Broom Rider E, Argonaut W) is worth the most: the next auto
## starts at once instead of waiting out the backswing and cooldown, so it's an
## animation cancel. Cast before the damage point and the reset is mostly wasted.
func _in_attack_gap() -> bool:
	if can_attack():
		return false
	return not (is_attack_anim_active() and not _damage_dealt_this_swing)


## Uses an attack-reset ability (`slot`) on `t` at the right moment: start
## attacking them first, then fire the reset in the gap after a hit lands.
## Returns true while it's working on it.
func _auto_reset_combo(slot: int, t: CharacterBody3D) -> bool:
	if not _alive(t) or _ready_ability(slot) == null:
		return false
	if not (_attacking and _attack_target == t):
		_attack(t)
		return true
	if _in_attack_gap():
		_cast(slot, t.global_position)
	return true


func _attack(t: CharacterBody3D) -> void:
	if _attack_target != t or not _attacking:
		_send(PlayerCommand.attack(t))


func _go_to(pos: Vector3) -> void:
	pos.y = 0.0
	# Don't re-send the same order every think.
	if not _attacking:
		if _moving and _target.distance_to(pos) < 1.0:
			return
		if not _moving and ProtoUtil.flat_distance(global_position, pos) < 1.2:
			return
	_send(PlayerCommand.move(pos))
