class_name ProtoConfig
extends RefCounted
## Tuning data for the 1v1 prototype (scenes/proto_1v1.tscn).
## Change the numbers here to rebalance spawners, minions and structures.

const BUILDING_DIR := "res://assets/models/buildings/FBX/"

## Playable champions: scene + definition. The order is the champion select order.
const CHAMPION_ORDER := ["cats_paw", "potion_seller", "argonaut", "drill_sergeant", "broom_rider", "hired_blade", "sleepwalker", "artificer", "wrangler", "wakeman", "unioneer", "gunslinger"]
const CHAMPIONS := {
	"cats_paw": {
		"scene": "res://scenes/cats_paw.tscn",
		"definition": "res://resources/definitions/cats_paw.tres",
		"blurb": "Melee assassin. Knife, dash, pull in and fear.",
	},
	"potion_seller": {
		"scene": "res://scenes/potion_seller.tscn",
		"definition": "res://resources/definitions/potion_seller.tres",
		"blurb": "Ranged artillery mage. Cheap potion poke, glue or poison mixes, and a rolling jug.",
	},
	"argonaut": {
		"scene": "res://scenes/argonaut.tscn",
		"definition": "res://resources/definitions/argonaut.tres",
		"blurb": "Melee tank / support. Rope pull, an undertow auto that slows harder over time, a wide lash, and a whale-song knock-up with shields.",
	},
	"drill_sergeant": {
		"scene": "res://scenes/drill_sergeant.tscn",
		"definition": "res://resources/definitions/drill_sergeant.tres",
		"blurb": "Melee bruiser / wave pusher. Cleave, a war banner your wave carries, shield rush, and a wave-wide charge.",
	},
	"broom_rider": {
		"scene": "res://scenes/broom_rider.tscn",
		"definition": "res://resources/definitions/broom_rider.tres",
		"blurb": "Ranged duelist mage. Broom dives she can blink back from, shield and missiles, a hex-charged auto that slows, and a huge slow orb that nukes and stuns.",
	},
	"sleepwalker": {
		"scene": "res://scenes/sleepwalker.tscn",
		"definition": "res://resources/definitions/sleepwalker.tres",
		"blurb": "Ranged control mage. Grit slows, Q roots, E stuns for 0.4s per stack, and R is a charged blinding sandstorm.",
	},
	"hired_blade": {
		"scene": "res://scenes/hired_blade.tscn",
		"definition": "res://resources/definitions/hired_blade.tres",
		"blurb": "Melee skirmisher. Twin Cut bleeds, Hamstring slows, a point-and-click grapple, and a smoke bomb that makes enemy autos miss.",
	},
	"artificer": {
		"scene": "res://scenes/artificer.tscn",
		"definition": "res://resources/definitions/artificer.tres",
		"blurb": "Ranged control mage. Plant clockwork robots that burst and slow, detonate them for burst and Bleed, or fire rays from them for a shield.",
	},
	"wrangler": {
		"scene": "res://scenes/wrangler.tscn",
		"definition": "res://resources/definitions/wrangler.tres",
		"blurb": "Melee skirmisher with a pug. Autos send it pouncing, Q latches it on, W barks from wherever it is, E dashes with a delayed pug charge, and R sends a giant pug through the fight.",
	},
	"wakeman": {
		"scene": "res://scenes/wakeman.tscn",
		"definition": "res://resources/definitions/wakeman.tres",
		"blurb": "Fragile ranged marksman. Tumble-charged last hits and takedowns stack permanent damage, W grows her range, E blinds, and R rains fire down the lane.",
	},
	"unioneer": {
		"scene": "res://scenes/unioneer.tscn",
		"definition": "res://resources/definitions/unioneer.tres",
		"blurb": "Ranged poke mage / turret control. Deploy turrets, chain lightning through them, cloak away from divers, and overload tethered champions.",
	},
	"gunslinger": {
		"scene": "res://scenes/gunslinger.tscn",
		"definition": "res://resources/definitions/gunslinger.tres",
		"blurb": "Slow-hand revolver marksman. Fan the hammer for burst, crits to sprint, a guaranteed-crit Bleed shot, and a big recoiling slug.",
	},
}


static func champion_name(id: String) -> String:
	var def := load(str(CHAMPIONS[id]["definition"])) as EntityDefinition
	return def.entity_name if def else id


## The 12 signature spawners (docs/spawner_system.md). Names, ability text and
## upgrades live in SpawnerPool; this is the tuning side.
##   building: model (with %d for the level, buildings stay level 1 for now)
##   minion:   what it sends every wave (see MINIONS)
##   value:    what one wave is worth; minion gold and XP are shares of it
const SPAWNERS := {
	"wharf": {"building": "Port_FirstAge_Level%d.fbx", "minion": "dockhand", "value": 180},
	"workshop": {"building": "Storage_SecondAge_Level%d.fbx", "minion": "clockwork_soldier", "value": 180},
	"witchs_hut": {"building": "Temple_FirstAge_Level%d.fbx", "minion": "coven_witch", "value": 180},
	"thieves_den": {"building": "Mine.fbx", "minion": "cutpurse", "value": 180},
	"drill_yard": {"building": "Barracks_FirstAge_Level%d.fbx", "minion": "corporal", "value": 180},
	"shooting_gallery": {"building": "Archery_FirstAge_Level%d.fbx", "minion": "deputy", "value": 180},
	"dojo": {"building": "Houses_FirstAge_1_Level%d.fbx", "minion": "initiate", "value": 180},
	"apothecary": {"building": "Market_FirstAge_Level%d.fbx", "minion": "peddler", "value": 180},
	"dune_spire": {"building": "WatchTower_FirstAge_Level%d.fbx", "minion": "sandcaller", "value": 180},
	"union_hall": {"building": "TownCenter_FirstAge_Level%d.fbx", "minion": "riveter", "value": 180},
	"hunters_lodge": {"building": "Farm_FirstAge_Level%d.fbx", "minion": "tracker", "value": 180},
	"kennel": {"building": "Wonder_FirstAge_Level%d.fbx", "minion": "kennelmaster", "value": 180},
}

## Minion stats. Optional behavior keys:
##   ranged + projectile_color    shoots instead of hitting in melee
##   heal, heal_interval, heal_range          heals the most hurt ally
##   count                         base units per wave (overrides ProtoGame.minions_per_spawner)
##   cleave, cleave_radius         melee hits also hit enemies near the target (fraction of damage)
##   rally_attack_speed, rally_radius         attack speed aura for nearby allied minions
##   shield, shield_interval, shield_range    shields the most hurt nearby ally
##   siege                         damage multiplier against towers and the orb
##   champion_mult                 damage multiplier against champions
##   death_burst, death_radius     magic damage to every enemy nearby on death
##   stealth                       enemies only see it within this distance
##   sight                         fog of war sight range (default 9)
const _WALK := "CharacterArmature|Walk"
const _IDLE := "CharacterArmature|Idle"
const _DEATH := "CharacterArmature|Death"
const _BIG := "res://assets/models/monsters/Big/FBX/"
const _BLOB := "res://assets/models/monsters/Blob/FBX/"
const _FLY := "res://assets/models/monsters/Flying/FBX/"

## Placeholder stats and the closest existing behaviors. The signature abilities
## (docs/signature_spawners.md) aren't built yet.
const MINIONS := {
	"dockhand": {
		"name": "Dockhand", "model": _BIG + "Orc.fbx", "height": 1.9, "radius": 0.75,
		"hp": 570.0, "ad": 30.0, "armor": 25.0, "mr": 10.0, "attack_speed": 0.75, "range": 1.4, "speed": 2.8, "aggro": 6.0,
		"ranged": false, "count": 1,
		"anim_walk": _WALK, "anim_idle": _IDLE, "anim_attack": "CharacterArmature|Punch", "anim_death": _DEATH,
	},
	"clockwork_soldier": {
		"name": "Clockwork Soldier", "model": _FLY + "Glub.fbx", "height": 1.3, "radius": 0.55,
		"hp": 420.0, "ad": 28.0, "armor": 10.0, "mr": 5.0, "attack_speed": 1.1, "range": 1.2, "speed": 3.0, "aggro": 6.0,
		"ranged": false, "death_burst": 70.0, "death_radius": 3.0, "count": 1,
		"anim_walk": "CharacterArmature|Fast_Flying", "anim_idle": "CharacterArmature|Flying_Idle", "anim_attack": "CharacterArmature|Headbutt", "anim_death": _DEATH,
	},
	"coven_witch": {
		"name": "Coven Witch", "model": _BLOB + "Wizard.fbx", "height": 1.5, "radius": 0.55,
		"hp": 145.0, "ad": 18.0, "armor": 5.0, "mr": 15.0, "attack_speed": 0.8, "range": 6.5, "speed": 3.0, "aggro": 8.0,
		"ranged": true, "projectile_color": Color(0.75, 0.45, 1.0), "count": 3,
		"anim_walk": _WALK, "anim_idle": _IDLE, "anim_attack": "CharacterArmature|Bite_Front", "anim_death": _DEATH,
	},
	"cutpurse": {
		"name": "Cutpurse", "model": _BLOB + "Ninja.fbx", "height": 1.4, "radius": 0.5,
		"hp": 170.0, "ad": 18.0, "armor": 10.0, "mr": 8.0, "attack_speed": 0.85, "range": 1.2, "speed": 3.2, "aggro": 6.0,
		"ranged": false, "count": 3,
		"anim_walk": _WALK, "anim_idle": _IDLE, "anim_attack": "CharacterArmature|Bite_Front", "anim_death": _DEATH,
	},
	"corporal": {
		"name": "Corporal", "model": _BIG + "Tribal.fbx", "height": 1.7, "radius": 0.6,
		"hp": 250.0, "ad": 17.0, "armor": 20.0, "mr": 10.0, "attack_speed": 0.8, "range": 1.4, "speed": 2.9, "aggro": 6.0,
		"ranged": false, "cleave": 0.15, "cleave_radius": 2.0,
		"anim_walk": _WALK, "anim_idle": _IDLE, "anim_attack": "CharacterArmature|Punch", "anim_death": _DEATH,
	},
	"deputy": {
		"name": "Deputy", "model": _BIG + "Ninja.fbx", "height": 1.8, "radius": 0.6,
		"hp": 190.0, "ad": 26.0, "armor": 5.0, "mr": 5.0, "attack_speed": 0.85, "range": 7.0, "speed": 3.0, "aggro": 8.5,
		"ranged": true, "projectile_color": Color(1.0, 0.85, 0.3),
		"anim_walk": _WALK, "anim_idle": _IDLE, "anim_attack": "CharacterArmature|Weapon", "anim_death": _DEATH,
	},
	"initiate": {
		"name": "Initiate", "model": _BLOB + "Mushnub.fbx", "height": 1.2, "radius": 0.5,
		"hp": 230.0, "ad": 22.0, "armor": 10.0, "mr": 10.0, "attack_speed": 1.0, "range": 1.2, "speed": 3.1, "aggro": 6.0,
		"ranged": false,
		"anim_walk": _WALK, "anim_idle": _IDLE, "anim_attack": "CharacterArmature|Bite_Front", "anim_death": _DEATH,
	},
	"peddler": {
		"name": "Peddler", "model": _FLY + "Goleling.fbx", "height": 1.5, "radius": 0.6,
		"hp": 175.0, "ad": 34.0, "armor": 5.0, "mr": 5.0, "attack_speed": 0.65, "range": 9.0, "speed": 2.8, "aggro": 10.0,
		"ranged": true, "projectile_color": Color(0.5, 1.0, 0.4), "siege": 1.5,
		"anim_walk": "CharacterArmature|Fast_Flying", "anim_idle": "CharacterArmature|Flying_Idle", "anim_attack": "CharacterArmature|Punch", "anim_death": _DEATH,
	},
	"sandcaller": {
		"name": "Sandcaller", "model": _BIG + "Demon.fbx", "height": 1.7, "radius": 0.6,
		"hp": 238.0, "ad": 24.0, "armor": 10.0, "mr": 15.0, "attack_speed": 0.75, "range": 6.0, "speed": 2.9, "aggro": 8.0,
		"ranged": true, "projectile_color": Color(0.95, 0.8, 0.45),
		"anim_walk": _WALK, "anim_idle": _IDLE, "anim_attack": "CharacterArmature|Weapon", "anim_death": _DEATH,
	},
	"riveter": {
		"name": "Riveter", "model": _BIG + "Dino.fbx", "height": 1.8, "radius": 0.7,
		"hp": 480.0, "ad": 36.0, "armor": 20.0, "mr": 10.0, "attack_speed": 0.8, "range": 1.5, "speed": 2.8, "aggro": 6.0,
		"ranged": false, "siege": 1.5, "count": 1,
		"anim_walk": _WALK, "anim_idle": _IDLE, "anim_attack": "CharacterArmature|Punch", "anim_death": _DEATH,
	},
	"tracker": {
		"name": "Tracker", "model": _BIG + "Ninja.fbx", "height": 1.6, "radius": 0.55,
		"hp": 175.0, "ad": 27.0, "armor": 5.0, "mr": 5.0, "attack_speed": 0.85, "range": 7.5, "speed": 3.0, "aggro": 8.5,
		"ranged": true, "projectile_color": Color(1.0, 0.55, 0.3),
		"anim_walk": _WALK, "anim_idle": _IDLE, "anim_attack": "CharacterArmature|Weapon", "anim_death": _DEATH,
	},
	"kennelmaster": {
		"name": "Kennelmaster", "model": _BLOB + "Dog.fbx", "height": 1.1, "radius": 0.5,
		"hp": 275.0, "ad": 20.0, "armor": 15.0, "mr": 10.0, "attack_speed": 0.85, "range": 1.2, "speed": 3.3, "aggro": 6.0,
		"ranged": false,
		"anim_walk": _WALK, "anim_idle": _IDLE, "anim_attack": "CharacterArmature|Bite_Front", "anim_death": _DEATH,
	},
}

## Neutral jungle camps, one north (-z) and one south (+z) of the lane.
## Killing a camp's monster gives the killer's champion its buff for `buff_time`
## seconds (lost on death). The monster comes back `respawn_time` seconds after dying.
## Buff numbers: regen is per second, attack speed / cooldown reduction are fractions.
const JUNGLE_CAMPS := {
	"north": {
		"name": "Frost Yeti",
		"model": "res://assets/models/monsters/Big/FBX/Yeti.fbx",
		"side": -1.0,
		"height": 2.6,
		"radius": 1.1,
		"hp": 750.0,
		"ad": 24.0,
		"armor": 15.0,
		"mr": 15.0,
		"attack_speed": 0.8,
		"range": 1.8,
		"speed": 4.0,
		"leash": 9.0,
		"respawn_time": 100.0,
		"gold": 10,
		"xp": 150.0,
		"buff_name": "Yeti's Fury",
		"buff_color": Color(1.0, 0.45, 0.3),
		"buff_time": 90.0,
		"attack_speed_bonus": 0.3,
		"health_regen_bonus": 12.0,
		"anim_walk": "CharacterArmature|Walk",
		"anim_idle": "CharacterArmature|Idle",
		"anim_attack": "CharacterArmature|Punch",
		"anim_death": "CharacterArmature|Death",
	},
	"south": {
		"name": "Mushroom King",
		"model": "res://assets/models/monsters/Big/FBX/MushroomKing.fbx",
		"side": 1.0,
		"height": 2.4,
		"radius": 1.1,
		"hp": 700.0,
		"ad": 22.0,
		"armor": 15.0,
		"mr": 15.0,
		"attack_speed": 0.8,
		"range": 1.8,
		"speed": 4.0,
		"leash": 9.0,
		"respawn_time": 100.0,
		"gold": 10,
		"xp": 150.0,
		"buff_name": "Spore Wisdom",
		"buff_color": Color(0.4, 0.65, 1.0),
		"buff_time": 90.0,
		"mana_regen_bonus": 4.0,
		"cooldown_reduction": 0.2,
		"anim_walk": "CharacterArmature|Walk",
		"anim_idle": "CharacterArmature|Idle",
		"anim_attack": "CharacterArmature|Punch",
		"anim_death": "CharacterArmature|Death",
	},
}

## Towers prefer minions.
## The orb works like League's fountain: it shoots any enemy champion in range first,
## for true damage of at least champion_health_ratio x their max health (about 3 shots
## to kill at any level, and it fires 7 times a second). Its hits on minions are
## light, so a wave that reaches it can finish it.
const TOWER := {
	"hp": 1600.0,
	"armor": 40.0,
	"attack_speed": 0.85,
	"range": 9.0,
	"dmg_champion": 160.0,
	"dmg_minion": 160.0,
	"radius": 1.5,
	"height": 5.5,
}

const ORB := {
	"hp": 500.0,
	"armor": 40.0,
	"attack_speed": 7.0,
	"range": 11.0,
	"dmg_champion": 350.0,
	"champion_health_ratio": 0.4,
	"dmg_minion": 20.0,
	"radius": 1.6,
	"height": 3.2,
}


static func team_color(team: int) -> Color:
	if team == EntityDefinition.Team.TEAM_1:
		return Color(0.25, 0.55, 1.0)
	return Color(1.0, 0.3, 0.25)


## Model for a spawner at `level`. Buildings without "%d" in their name use one model for every level.
static func building_path(type_id: String, level: int) -> String:
	var pattern := str(SPAWNERS[type_id]["building"])
	return BUILDING_DIR + (pattern % level if "%d" in pattern else pattern)
