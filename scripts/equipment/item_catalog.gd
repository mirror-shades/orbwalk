class_name ItemCatalog
extends RefCounted
## Every piece of equipment, and the default build for each champion.
## Equipment is picked before the match (one item per slot) and works like
## League's runes and masteries: no gold is spent on it, so in-game gold goes to spawners.
## See docs/equipment.md.
##
## Slot themes:
##   Breastplate - armor / resists plus a big passive. Shapes the build.
##   Hand        - a weapon (offense) or a shield (defense). Shapes the build.
##   Gloves      - unique mechanics (economy, on-hit tricks, takedowns).
##   Leggings    - anything: resists, movement, health, utility.
##   Boots       - always move speed, plus an archetype stat or passive.
##
## Each item can have:
##   "stats":     {Stat: amount}  flat bonuses
##   "per_level": {Stat: amount}  bonus x champion level (so 10 at level 1, 180 at 18)
##   "gold_per_last_hit", "mana_per_last_hit"
##   "on_hit_magic" (+ "on_hit_magic_per_level")   magic damage on every auto-attack
##   "nth_hit" + "nth_hit_magic" (+ "_per_level")  magic damage on every Nth auto-attack
##   "spellblade"       after casting an ability, the next auto deals this x base AD bonus physical
##   "takedown_heal"    fraction of max health and mana restored on a champion takedown
##   "takedown_haste"   move speed bonus for a few seconds after a champion takedown
##   "thorns"           fraction of auto-attack damage taken dealt back as magic damage
##   "idle_regen"       fraction of max health regenerated per second when out of combat
##   "last_stand"       shield (fraction of max health) when dropping low, on a long cooldown
##   "ward" (+ "ward_per_level")  a shield that refills every WARD_REFRESH seconds
##   "rage_attack_speed"  bonus attack speed that grows with missing health (full value at 0 hp)
##   "note"             extra description text
## Descriptions are generated from these numbers (describe()), so they can't go stale.

enum Slot { BREASTPLATE, HAND, GLOVES, LEGGINGS, BOOTS }

## Display order. The two build-shaping slots come first.
const SLOT_ORDER: Array[Slot] = [Slot.BREASTPLATE, Slot.HAND, Slot.GLOVES, Slot.LEGGINGS, Slot.BOOTS]
const SLOT_NAMES := {
	Slot.BREASTPLATE: "Breastplate",
	Slot.HAND: "Hand",
	Slot.GLOVES: "Gloves",
	Slot.LEGGINGS: "Leggings",
	Slot.BOOTS: "Boots",
}
const SLOT_HINTS := {
	Slot.BREASTPLATE: "Armor and a big passive",
	Slot.HAND: "A weapon or a shield",
	Slot.GLOVES: "Unique mechanics",
	Slot.LEGGINGS: "Anything goes",
	Slot.BOOTS: "Movement plus a specialty",
}

## Tuning for the item mechanics (shared by every item that uses them).
const IDLE_DELAY := 6.0           ## seconds without taking damage before idle_regen starts
const LAST_STAND_THRESHOLD := 0.3 ## health fraction that triggers last_stand
const LAST_STAND_DURATION := 4.0
const LAST_STAND_COOLDOWN := 60.0
const WARD_REFRESH := 20.0
const SPELLBLADE_WINDOW := 6.0    ## seconds after a cast the empowered auto waits
const SPELLBLADE_COOLDOWN := 1.5
const TAKEDOWN_HASTE_DURATION := 3.0

const S := StatsComponent.Stat

const ITEMS := {
	# ---- Breastplates: armor + big passives ----
	"knights_chainmail": {"slot": Slot.BREASTPLATE, "name": "Knight's Chainmail", "stats": {S.ARMOR: 20.0}, "per_level": {S.ARMOR: 1.5}},
	"spiked_cuirass": {"slot": Slot.BREASTPLATE, "name": "Spiked Cuirass", "stats": {S.ARMOR: 15.0}, "thorns": 0.25},
	"troll_hide": {"slot": Slot.BREASTPLATE, "name": "Troll Hide", "per_level": {S.MAX_HEALTH: 20.0}, "idle_regen": 0.025},
	"last_stand_plate": {"slot": Slot.BREASTPLATE, "name": "Last Stand Plate", "stats": {S.ARMOR: 12.0, S.MAGIC_RESIST: 12.0}, "last_stand": 0.3},
	"spirit_robe": {"slot": Slot.BREASTPLATE, "name": "Spirit Robe", "stats": {S.MAGIC_RESIST: 20.0}, "ward": 40.0, "ward_per_level": 8.0},
	"bloodrage_vest": {"slot": Slot.BREASTPLATE, "name": "Bloodrage Vest", "stats": {S.ARMOR: 12.0}, "rage_attack_speed": 0.5},

	# ---- Hand: weapons (offense) or shields (defense) ----
	"longsword": {"slot": Slot.HAND, "name": "Longsword", "stats": {S.ATTACK_DAMAGE: 8.0}, "per_level": {S.ATTACK_DAMAGE: 0.8}},
	"growing_staff": {"slot": Slot.HAND, "name": "Growing Staff", "per_level": {S.ABILITY_POWER: 10.0}},
	"serrated_dirk": {"slot": Slot.HAND, "name": "Serrated Dirk", "stats": {S.ATTACK_DAMAGE: 5.0, S.ARMOR_PEN_PERCENT: 0.15, S.ARMOR_PEN: 5.0}},
	"void_wand": {"slot": Slot.HAND, "name": "Void Wand", "stats": {S.ABILITY_POWER: 15.0, S.MAGIC_PEN_PERCENT: 0.15, S.MAGIC_PEN: 5.0}},
	"rapier": {"slot": Slot.HAND, "name": "Rapier", "stats": {S.ATTACK_DAMAGE: 5.0, S.CRIT_CHANCE: 0.2}},
	"vampiric_blade": {"slot": Slot.HAND, "name": "Vampiric Blade", "stats": {S.ATTACK_DAMAGE: 6.0, S.LIFE_STEAL: 0.1}},
	"witchs_fang": {"slot": Slot.HAND, "name": "Witch's Fang", "on_hit_magic": 10.0, "on_hit_magic_per_level": 1.5},
	"tower_shield": {"slot": Slot.HAND, "name": "Tower Shield", "stats": {S.ARMOR: 15.0, S.ATTACK_BLOCK: 12.0}},
	"aegis_buckler": {"slot": Slot.HAND, "name": "Aegis Buckler", "stats": {S.MAX_HEALTH: 60.0, S.MAGIC_RESIST: 10.0}, "ward": 30.0, "ward_per_level": 6.0},

	# ---- Gloves: unique mechanics ----
	"pickpocket_gloves": {"slot": Slot.GLOVES, "name": "Pickpocket Gloves", "gold_per_last_hit": 3},
	"harvesters_gloves": {"slot": Slot.GLOVES, "name": "Harvester's Gloves", "mana_per_last_hit": 10.0},
	"brutal_gloves": {"slot": Slot.GLOVES, "name": "Brutal Gloves", "stats": {S.CRIT_DAMAGE: 0.1, S.CRIT_CHANCE: 0.05}},
	"spellthread_gloves": {"slot": Slot.GLOVES, "name": "Spellthread Gloves", "spellblade": 0.75},
	"rhythm_gloves": {"slot": Slot.GLOVES, "name": "Rhythm Gloves", "nth_hit": 3, "nth_hit_magic": 20.0, "nth_hit_magic_per_level": 3.0},
	"hunters_gloves": {"slot": Slot.GLOVES, "name": "Hunter's Gloves", "takedown_heal": 0.15},

	# ---- Leggings: anything ----
	"plated_greaves": {"slot": Slot.LEGGINGS, "name": "Plated Greaves", "per_level": {S.ARMOR: 1.0, S.MAGIC_RESIST: 1.0}},
	"runners_leggings": {"slot": Slot.LEGGINGS, "name": "Runner's Leggings", "stats": {S.MOVE_SPEED: 0.4, S.MAX_HEALTH: 60.0}},
	"sages_leggings": {"slot": Slot.LEGGINGS, "name": "Sage's Leggings", "stats": {S.COOLDOWN_REDUCTION: 0.1, S.MAX_MANA: 100.0}},
	"mossy_leggings": {"slot": Slot.LEGGINGS, "name": "Mossy Leggings", "stats": {S.HEALTH_REGEN: 1.0}, "per_level": {S.HEALTH_REGEN: 0.25}},
	"leech_leggings": {"slot": Slot.LEGGINGS, "name": "Leech Leggings", "stats": {S.LIFE_STEAL: 0.06, S.SPELL_VAMP: 0.06}},
	"heavy_leggings": {"slot": Slot.LEGGINGS, "name": "Heavy Leggings", "stats": {S.MAX_HEALTH: 150.0}},

	# ---- Boots: movement + an archetype stat or passive ----
	"swift_boots": {"slot": Slot.BOOTS, "name": "Swift Boots", "stats": {S.MOVE_SPEED: 0.9}},
	"berserker_boots": {"slot": Slot.BOOTS, "name": "Berserker Boots", "stats": {S.MOVE_SPEED: 0.5, S.ATTACK_SPEED: 0.15}},
	"sandals_of_haste": {"slot": Slot.BOOTS, "name": "Sandals of Haste", "stats": {S.MOVE_SPEED: 0.5, S.COOLDOWN_REDUCTION: 0.1}},
	"sorcerers_shoes": {"slot": Slot.BOOTS, "name": "Sorcerer's Shoes", "stats": {S.MOVE_SPEED: 0.5, S.MAGIC_PEN: 10.0}},
	"plated_boots": {"slot": Slot.BOOTS, "name": "Plated Boots", "stats": {S.MOVE_SPEED: 0.5, S.ARMOR: 10.0}},
	"quicksilver_boots": {"slot": Slot.BOOTS, "name": "Quicksilver Boots", "stats": {S.MOVE_SPEED: 0.5, S.MAGIC_RESIST: 12.0}},
	"stalkers_boots": {"slot": Slot.BOOTS, "name": "Stalker's Boots", "stats": {S.MOVE_SPEED: 0.5}, "takedown_haste": 0.3},
}

## Default build per champion. Bots use these; the player starts from them.
const DEFAULT_LOADOUTS := {
	"cats_paw": {Slot.BREASTPLATE: "bloodrage_vest", Slot.HAND: "serrated_dirk", Slot.GLOVES: "hunters_gloves", Slot.LEGGINGS: "runners_leggings", Slot.BOOTS: "stalkers_boots"},
	"potion_seller": {Slot.BREASTPLATE: "spirit_robe", Slot.HAND: "growing_staff", Slot.GLOVES: "harvesters_gloves", Slot.LEGGINGS: "sages_leggings", Slot.BOOTS: "sorcerers_shoes"},
	"broom_rider": {Slot.BREASTPLATE: "spirit_robe", Slot.HAND: "growing_staff", Slot.GLOVES: "harvesters_gloves", Slot.LEGGINGS: "sages_leggings", Slot.BOOTS: "sorcerers_shoes"},
	"sleepwalker": {Slot.BREASTPLATE: "spirit_robe", Slot.HAND: "growing_staff", Slot.GLOVES: "harvesters_gloves", Slot.LEGGINGS: "sages_leggings", Slot.BOOTS: "sorcerers_shoes"},
	"drill_sergeant": {Slot.BREASTPLATE: "knights_chainmail", Slot.HAND: "longsword", Slot.GLOVES: "brutal_gloves", Slot.LEGGINGS: "plated_greaves", Slot.BOOTS: "berserker_boots"},
	"argonaut": {Slot.BREASTPLATE: "last_stand_plate", Slot.HAND: "tower_shield", Slot.GLOVES: "rhythm_gloves", Slot.LEGGINGS: "plated_greaves", Slot.BOOTS: "plated_boots"},
	"hired_blade": {Slot.BREASTPLATE: "bloodrage_vest", Slot.HAND: "serrated_dirk", Slot.GLOVES: "hunters_gloves", Slot.LEGGINGS: "runners_leggings", Slot.BOOTS: "stalkers_boots"},
	"artificer": {Slot.BREASTPLATE: "spirit_robe", Slot.HAND: "growing_staff", Slot.GLOVES: "spellthread_gloves", Slot.LEGGINGS: "sages_leggings", Slot.BOOTS: "sorcerers_shoes"},
	"wrangler": {Slot.BREASTPLATE: "bloodrage_vest", Slot.HAND: "longsword", Slot.GLOVES: "hunters_gloves", Slot.LEGGINGS: "runners_leggings", Slot.BOOTS: "berserker_boots"},
	"wakeman": {Slot.BREASTPLATE: "last_stand_plate", Slot.HAND: "rapier", Slot.GLOVES: "hunters_gloves", Slot.LEGGINGS: "runners_leggings", Slot.BOOTS: "berserker_boots"},
	"unioneer": {Slot.BREASTPLATE: "spirit_robe", Slot.HAND: "growing_staff", Slot.GLOVES: "spellthread_gloves", Slot.LEGGINGS: "sages_leggings", Slot.BOOTS: "sorcerers_shoes"},
	"gunslinger": {Slot.BREASTPLATE: "last_stand_plate", Slot.HAND: "rapier", Slot.GLOVES: "brutal_gloves", Slot.LEGGINGS: "leech_leggings", Slot.BOOTS: "berserker_boots"},
}

## Stats shown as percentages in descriptions.
const PERCENT_STATS := [S.ATTACK_SPEED, S.CRIT_CHANCE, S.CRIT_DAMAGE, S.ARMOR_PEN_PERCENT, S.MAGIC_PEN_PERCENT, S.LIFE_STEAL, S.SPELL_VAMP, S.COOLDOWN_REDUCTION]


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func slot_name(slot: int) -> String:
	return SLOT_NAMES.get(slot, "?")


static func slot_hint(slot: int) -> String:
	return SLOT_HINTS.get(slot, "")


## Item ids for one slot, in catalog order.
static func items_for_slot(slot: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in ITEMS:
		if int(ITEMS[id]["slot"]) == slot:
			out.append(id)
	return out


static func default_loadout(champion_id: String) -> Dictionary:
	var out := {}
	var preset: Dictionary = DEFAULT_LOADOUTS.get(champion_id, {})
	for slot in SLOT_ORDER:
		out[slot] = preset.get(slot, items_for_slot(slot)[0])
	return out


## Description from the item's numbers, e.g. "+10 Ability Power per level (180 at 18)."
static func describe(id: String) -> String:
	var item := get_item(id)
	if item.is_empty():
		return ""
	var parts: PackedStringArray = []
	var stats: Dictionary = item.get("stats", {})
	for stat in stats:
		parts.append("+%s %s" % [_fmt(stat, float(stats[stat])), _stat_name(stat)])
	var per_level: Dictionary = item.get("per_level", {})
	for stat in per_level:
		var v := float(per_level[stat])
		parts.append("+%s %s per level (%s at 18)" % [_fmt(stat, v), _stat_name(stat), _fmt(stat, v * StatsComponent.MAX_LEVEL)])
	if item.has("gold_per_last_hit"):
		parts.append("+%d gold per mercenary last hit" % int(item["gold_per_last_hit"]))
	if item.has("mana_per_last_hit"):
		parts.append("+%d mana per mercenary last hit" % roundi(float(item["mana_per_last_hit"])))
	if item.has("on_hit_magic"):
		parts.append("Auto-attacks deal %s (+%s per level) bonus magic damage" % [_num(float(item["on_hit_magic"])), _num(float(item.get("on_hit_magic_per_level", 0.0)))])
	if item.has("nth_hit"):
		parts.append("Every %s auto-attack deals %s (+%s per level) bonus magic damage" % [_ordinal(int(item["nth_hit"])), _num(float(item.get("nth_hit_magic", 0.0))), _num(float(item.get("nth_hit_magic_per_level", 0.0)))])
	if item.has("spellblade"):
		parts.append("After casting an ability, your next auto-attack within %ss deals %d%% of base AD as bonus physical damage (%ss cooldown)" % [_num(SPELLBLADE_WINDOW), roundi(float(item["spellblade"]) * 100.0), _num(SPELLBLADE_COOLDOWN)])
	if item.has("takedown_heal"):
		parts.append("Champion takedowns restore %d%% of max health and mana" % roundi(float(item["takedown_heal"]) * 100.0))
	if item.has("takedown_haste"):
		parts.append("Champion takedowns give +%d%% move speed for %ss" % [roundi(float(item["takedown_haste"]) * 100.0), _num(TAKEDOWN_HASTE_DURATION)])
	if item.has("thorns"):
		parts.append("Deals %d%% of auto-attack damage taken back to the attacker as magic damage" % roundi(float(item["thorns"]) * 100.0))
	if item.has("idle_regen"):
		parts.append("After %ss without taking damage, regenerate %s%% of max health per second" % [_num(IDLE_DELAY), _num(float(item["idle_regen"]) * 100.0)])
	if item.has("last_stand"):
		parts.append("Dropping below %d%% health grants a shield of %d%% max health for %ss (%ss cooldown)" % [roundi(LAST_STAND_THRESHOLD * 100.0), roundi(float(item["last_stand"]) * 100.0), _num(LAST_STAND_DURATION), _num(LAST_STAND_COOLDOWN)])
	if item.has("ward"):
		parts.append("A %s (+%s per level) shield that refills every %ss" % [_num(float(item["ward"])), _num(float(item.get("ward_per_level", 0.0))), _num(WARD_REFRESH)])
	if item.has("rage_attack_speed"):
		parts.append("Up to +%d%% attack speed the lower your health is" % roundi(float(item["rage_attack_speed"]) * 100.0))
	if item.has("note"):
		parts.append(str(item["note"]))
	return ". ".join(parts) + "."


static func _fmt(stat: int, value: float) -> String:
	if stat in PERCENT_STATS:
		return "%s%%" % _num(value * 100.0)
	return _num(value)


## 8.0 -> "8", 0.25 -> "0.25".
static func _num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return String.num(value, 2)


static func _ordinal(n: int) -> String:
	match n:
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n


## Stat name for descriptions ("Armor Pen %" reads oddly after "+15%").
static func _stat_name(stat: int) -> String:
	return str(StatsComponent.STAT_NAMES[stat]).trim_suffix(" %")


# ---- Saving the player's builds (one per champion) ----

const SAVE_PATH := "user://loadouts.cfg"


## The champion's saved build. Slots with nothing saved use the default item.
static func load_loadout(champion_id: String) -> Dictionary:
	var out := default_loadout(champion_id)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return out
	for slot in SLOT_ORDER:
		var id: String = cfg.get_value(champion_id, slot_name(slot), "")
		if ITEMS.has(id) and int(ITEMS[id]["slot"]) == slot:
			out[slot] = id
	return out


static func save_loadout(champion_id: String, loadout: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	for slot in SLOT_ORDER:
		cfg.set_value(champion_id, slot_name(slot), str(loadout.get(slot, "")))
	cfg.save(SAVE_PATH)
