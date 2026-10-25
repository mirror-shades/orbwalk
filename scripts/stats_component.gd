class_name StatsComponent
extends Node
## A unit's live numbers. Every stat is:
##   base (EntityDefinition) + growth per level + bonuses (modifiers)
## Modifiers are named bundles of bonuses ("jungle_buffs", "status_effects", an item...)
## that can be set or removed at any time. Also handles damage, healing, shields,
## mana and XP / leveling. See docs/stats.md for the formulas.

signal health_changed(current: float, max_hp: float)
signal mana_changed(current: float, max_mp: float)
signal died()
signal leveled_up(new_level: int)
signal damaged(amount: float, source: Node)
## Total shield changed (shields absorb damage before health).
signal shield_changed(total: float)
## Any stat may have changed (level up or a modifier was set / removed).
signal stats_changed()
## A typed hit landed on this unit (after resists, before shields). Used by thorns-style effects.
signal hit_taken(dealt: float, type: int, source: Node, from_attack: bool)

enum Stat {
	MAX_HEALTH,
	HEALTH_REGEN,
	MAX_MANA,
	MANA_REGEN,
	ATTACK_DAMAGE,
	ABILITY_POWER,
	ARMOR,
	MAGIC_RESIST,
	## Bonus attack speed as a fraction of base (0.3 = +30%).
	ATTACK_SPEED,
	ATTACK_RANGE,
	MOVE_SPEED,
	CRIT_CHANCE,
	CRIT_DAMAGE,
	## Flat armor ignored by this unit's physical damage.
	ARMOR_PEN,
	## Fraction of armor ignored (0.35 = 35%). Applied before flat pen.
	ARMOR_PEN_PERCENT,
	MAGIC_PEN,
	MAGIC_PEN_PERCENT,
	## Fraction of auto-attack damage dealt that heals this unit.
	LIFE_STEAL,
	## Fraction of ability damage dealt that heals this unit.
	SPELL_VAMP,
	## Fraction taken off ability cooldowns. Capped at MAX_COOLDOWN_REDUCTION.
	COOLDOWN_REDUCTION,
	## Flat damage removed from each auto-attack that hits this unit (before resists).
	ATTACK_BLOCK,
	## Fog of war vision radius.
	SIGHT_RANGE,
	## Fraction of all incoming damage ignored (0.15 = takes 15% less). Capped at MAX_DAMAGE_REDUCTION.
	DAMAGE_REDUCTION,
}

enum DamageType { PHYSICAL, MAGIC, TRUE }

const MAX_LEVEL := 18
const MAX_COOLDOWN_REDUCTION := 0.4
const MAX_ATTACK_SPEED := 2.5
const MAX_CRIT_CHANCE := 1.0
const MAX_DAMAGE_REDUCTION := 0.9
## Anyone who damaged this unit within this many seconds before it died gets takedown credit.
const ASSIST_WINDOW := 3.0

## Short names for the HUD and debug prints.
const STAT_NAMES := {
	Stat.MAX_HEALTH: "Health",
	Stat.HEALTH_REGEN: "Health Regen",
	Stat.MAX_MANA: "Mana",
	Stat.MANA_REGEN: "Mana Regen",
	Stat.ATTACK_DAMAGE: "Attack Damage",
	Stat.ABILITY_POWER: "Ability Power",
	Stat.ARMOR: "Armor",
	Stat.MAGIC_RESIST: "Magic Resist",
	Stat.ATTACK_SPEED: "Attack Speed",
	Stat.ATTACK_RANGE: "Attack Range",
	Stat.MOVE_SPEED: "Move Speed",
	Stat.CRIT_CHANCE: "Crit Chance",
	Stat.CRIT_DAMAGE: "Crit Damage",
	Stat.ARMOR_PEN: "Armor Pen",
	Stat.ARMOR_PEN_PERCENT: "Armor Pen %",
	Stat.MAGIC_PEN: "Magic Pen",
	Stat.MAGIC_PEN_PERCENT: "Magic Pen %",
	Stat.LIFE_STEAL: "Life Steal",
	Stat.SPELL_VAMP: "Spell Vamp",
	Stat.COOLDOWN_REDUCTION: "Cooldown Reduction",
	Stat.ATTACK_BLOCK: "Attack Block",
	Stat.SIGHT_RANGE: "Sight Range",
	Stat.DAMAGE_REDUCTION: "Damage Reduction",
}

## stat -> [base property, growth property or ""] on EntityDefinition.
const _DEFINITION_PROPS := {
	Stat.MAX_HEALTH: ["stats_max_health", "growth_health"],
	Stat.HEALTH_REGEN: ["stats_health_regen", "growth_health_regen"],
	Stat.MAX_MANA: ["stats_max_mana", "growth_mana"],
	Stat.MANA_REGEN: ["stats_mana_regen", "growth_mana_regen"],
	Stat.ATTACK_DAMAGE: ["stats_attack_damage", "growth_attack_damage"],
	Stat.ABILITY_POWER: ["stats_ability_power", ""],
	Stat.ARMOR: ["stats_armor", "growth_armor"],
	Stat.MAGIC_RESIST: ["stats_magic_resist", "growth_magic_resist"],
	Stat.ATTACK_RANGE: ["stats_attack_range", ""],
	Stat.MOVE_SPEED: ["stats_movement_speed", ""],
	Stat.CRIT_CHANCE: ["stats_crit_chance", ""],
	Stat.CRIT_DAMAGE: ["stats_crit_damage", ""],
	Stat.SIGHT_RANGE: ["stats_sight_range", ""],
}

var definition: EntityDefinition
var level: int = 1
var xp: float = 0.0
var current_health: float = 0.0
var current_mana: float = 0.0
var is_dead: bool = false
## The last unit to deal damage to this one. Set when this unit dies, so kill
## effects can tell the killer apart from the assists.
var killer: Node = null
## While true, all incoming damage is ignored (e.g. a tower shielded by the one in front of it).
var invulnerable: bool = false

## Multiplier set by StatusEffects (slows and move speed buffs). 1.0 = unchanged.
var move_speed_mult: float = 1.0
## Multiplier on every heal this unit receives (Bleed sets it below 1.0). 1.0 = unchanged.
var healing_mult: float = 1.0

## modifier id -> {Stat: amount}
var _modifiers: Dictionary = {}
## Stat -> summed bonus from all modifiers.
var _bonus: Dictionary = {}
## Active shields: {amount, time_left, id}. Damage takes from the oldest first.
var _shields: Array[Dictionary] = []
## Instance id of each attacker -> physics frame of their last hit (game time, not wall clock).
var _recent_attackers: Dictionary = {}


## Sets the unit to full health and mana at `start_level`. Every unit needs a definition.
func initialize(def: EntityDefinition, start_level: int = 1) -> void:
	assert(def != null, "StatsComponent needs an EntityDefinition.")
	definition = def
	level = clampi(start_level, 1, MAX_LEVEL)
	current_health = get_max_health()
	current_mana = get_max_mana()
	is_dead = false
	killer = null
	healing_mult = 1.0
	_recent_attackers.clear()
	clear_shields()
	health_changed.emit(current_health, get_max_health())
	mana_changed.emit(current_mana, get_max_mana())


# ---- Modifiers ----

## Sets (or replaces) the bonuses from one source, e.g.
## set_modifier("yeti_buff", {Stat.ATTACK_SPEED: 0.3, Stat.HEALTH_REGEN: 12.0}).
## Gaining max health or mana also adds that much current health / mana.
func set_modifier(id: String, bonuses: Dictionary) -> void:
	if bonuses.is_empty():
		remove_modifier(id)
		return
	var old_hp := get_max_health()
	var old_mp := get_max_mana()
	_modifiers[id] = bonuses.duplicate()
	_rebuild_bonus(old_hp, old_mp)


func remove_modifier(id: String) -> void:
	if not _modifiers.has(id):
		return
	var old_hp := get_max_health()
	var old_mp := get_max_mana()
	_modifiers.erase(id)
	_rebuild_bonus(old_hp, old_mp)


func has_modifier(id: String) -> bool:
	return _modifiers.has(id)


## Total bonus to `stat` from all modifiers.
func get_bonus(stat: Stat) -> float:
	return float(_bonus.get(stat, 0.0))


func _rebuild_bonus(old_hp: float, old_mp: float) -> void:
	_bonus.clear()
	for id in _modifiers:
		var bonuses: Dictionary = _modifiers[id]
		for stat in bonuses:
			_bonus[stat] = float(_bonus.get(stat, 0.0)) + float(bonuses[stat])
	_apply_max_change(old_hp, old_mp)
	stats_changed.emit()


## Keeps missing health / mana the same when the max goes up, and clamps when it goes down.
func _apply_max_change(old_hp: float, old_mp: float) -> void:
	var hp := get_max_health()
	var mp := get_max_mana()
	if not is_dead:
		current_health = clampf(current_health + maxf(hp - old_hp, 0.0), 0.0, hp)
	current_mana = clampf(current_mana + maxf(mp - old_mp, 0.0), 0.0, mp)
	if hp != old_hp:
		health_changed.emit(current_health, hp)
	if mp != old_mp:
		mana_changed.emit(current_mana, mp)


# ---- Stat getters ----

## Base + level growth, without bonuses.
func get_base(stat: Stat) -> float:
	if stat == Stat.ATTACK_SPEED:
		return definition.stats_attack_speed
	if not _DEFINITION_PROPS.has(stat):
		return 0.0
	var props: Array = _DEFINITION_PROPS[stat]
	var base: float = definition.get(props[0])
	if props[1] == "":
		return base
	return base + float(definition.get(props[1])) * EntityDefinition.growth_at_level(level)


## The final value of any stat, with caps applied.
func get_stat(stat: Stat) -> float:
	match stat:
		Stat.ATTACK_SPEED:
			return get_attack_speed()
		Stat.MOVE_SPEED:
			return get_movement_speed()
		Stat.CRIT_CHANCE:
			return clampf(get_base(stat) + get_bonus(stat), 0.0, MAX_CRIT_CHANCE)
		Stat.COOLDOWN_REDUCTION:
			return clampf(get_bonus(stat), 0.0, MAX_COOLDOWN_REDUCTION)
		Stat.ARMOR_PEN_PERCENT, Stat.MAGIC_PEN_PERCENT:
			return clampf(get_bonus(stat), 0.0, 1.0)
		Stat.DAMAGE_REDUCTION:
			return clampf(get_bonus(stat), 0.0, MAX_DAMAGE_REDUCTION)
	return get_base(stat) + get_bonus(stat)


func get_max_health() -> float:
	return get_stat(Stat.MAX_HEALTH)

func get_health_regen() -> float:
	return get_stat(Stat.HEALTH_REGEN)

func get_max_mana() -> float:
	return get_stat(Stat.MAX_MANA)

func get_mana_regen() -> float:
	return get_stat(Stat.MANA_REGEN)

func get_attack_damage() -> float:
	return get_stat(Stat.ATTACK_DAMAGE)

## Attack damage from level 1 base + growth only. Abilities that scale with "bonus AD" use the other part.
func get_base_attack_damage() -> float:
	return get_base(Stat.ATTACK_DAMAGE)

func get_bonus_attack_damage() -> float:
	return get_bonus(Stat.ATTACK_DAMAGE)

func get_ability_power() -> float:
	return get_stat(Stat.ABILITY_POWER)

func get_armor() -> float:
	return get_stat(Stat.ARMOR)

func get_magic_resist() -> float:
	return get_stat(Stat.MAGIC_RESIST)

func get_crit_chance() -> float:
	return get_stat(Stat.CRIT_CHANCE)

func get_crit_damage() -> float:
	return get_stat(Stat.CRIT_DAMAGE)

func get_life_steal() -> float:
	return get_stat(Stat.LIFE_STEAL)

func get_spell_vamp() -> float:
	return get_stat(Stat.SPELL_VAMP)

func get_cooldown_reduction() -> float:
	return get_stat(Stat.COOLDOWN_REDUCTION)

## Bonus attack speed from levels and modifiers, as a fraction of base (0.5 = +50%).
func get_bonus_attack_speed() -> float:
	return definition.growth_attack_speed * EntityDefinition.growth_at_level(level) + get_bonus(Stat.ATTACK_SPEED)

## Attacks per second: base * (1 + bonus attack speed), capped at MAX_ATTACK_SPEED.
func get_attack_speed() -> float:
	var base := get_base(Stat.ATTACK_SPEED)
	if base <= 0.0:
		return 0.0
	return clampf(base * (1.0 + get_bonus_attack_speed()), 0.2, MAX_ATTACK_SPEED)

func get_attack_range() -> float:
	return get_base(Stat.ATTACK_RANGE) + get_bonus(Stat.ATTACK_RANGE)

func get_movement_speed() -> float:
	return maxf(get_base(Stat.MOVE_SPEED) + get_bonus(Stat.MOVE_SPEED), 0.0) * move_speed_mult

func get_team() -> int:
	return definition.team

func get_entity_type() -> int:
	return definition.entity_type


# ---- Damage math ----

## Damage multiplier for a given armor or magic resist.
## 100 armor = takes 50%. Negative resist makes the unit take more (down to 2x at -inf).
static func resist_multiplier(resist: float) -> float:
	if resist >= 0.0:
		return 100.0 / (100.0 + resist)
	return 2.0 - 100.0 / (100.0 - resist)


## The armor / magic resist left after the attacker's penetration.
## Percent pen applies first, then flat pen. Pen never pushes resist below 0.
static func resist_after_pen(resist: float, pen_percent: float, pen_flat: float) -> float:
	if resist <= 0.0:
		return resist
	var r := resist * (1.0 - clampf(pen_percent, 0.0, 1.0))
	return maxf(r - maxf(pen_flat, 0.0), 0.0)


## How much `raw` damage of `type` from `attacker` (may be null) would deal to this unit,
## before shields.
func mitigate(raw: float, type: DamageType, attacker: StatsComponent = null) -> float:
	match type:
		DamageType.PHYSICAL:
			var pct := attacker.get_stat(Stat.ARMOR_PEN_PERCENT) if attacker else 0.0
			var flat := attacker.get_stat(Stat.ARMOR_PEN) if attacker else 0.0
			return raw * resist_multiplier(resist_after_pen(get_armor(), pct, flat))
		DamageType.MAGIC:
			var pct := attacker.get_stat(Stat.MAGIC_PEN_PERCENT) if attacker else 0.0
			var flat := attacker.get_stat(Stat.MAGIC_PEN) if attacker else 0.0
			return raw * resist_multiplier(resist_after_pen(get_magic_resist(), pct, flat))
	return raw


## Rolls a crit for an auto-attack. Returns the damage multiplier (1.0 or crit damage).
func roll_crit() -> float:
	var chance := get_crit_chance()
	if chance > 0.0 and SimRng.randf() < chance:
		return get_crit_damage()
	return 1.0


# ---- Taking damage ----

## Applies armor / magic resist (and the source's pen), then deals the damage.
## `from_attack` marks auto-attacks: they heal the source by its life steal;
## everything else heals by spell vamp. Returns the damage dealt.
func take_typed_damage(raw: float, type: DamageType, source: Node = null, from_attack: bool = false) -> float:
	if is_dead or invulnerable or raw <= 0.0:
		return 0.0
	var attacker: StatsComponent = null
	if source and is_instance_valid(source):
		attacker = EntityData.get_stats_of(source)
	if from_attack:
		raw = maxf(raw - get_bonus(Stat.ATTACK_BLOCK), 0.0)
	var dealt := mitigate(raw, type, attacker) * (1.0 - get_stat(Stat.DAMAGE_REDUCTION))
	take_damage(dealt, source)
	hit_taken.emit(dealt, type, source, from_attack)
	if attacker and attacker != self and not attacker.is_dead:
		var vamp := attacker.get_life_steal() if from_attack else attacker.get_spell_vamp()
		if vamp > 0.0:
			attacker.heal(dealt * vamp)
	return dealt


func take_physical_damage(raw_damage: float, source: Node = null, from_attack: bool = false) -> float:
	return take_typed_damage(raw_damage, DamageType.PHYSICAL, source, from_attack)


func take_magic_damage(raw_damage: float, source: Node = null) -> float:
	return take_typed_damage(raw_damage, DamageType.MAGIC, source)


func take_true_damage(raw_damage: float, source: Node = null, from_attack: bool = false) -> float:
	return take_typed_damage(raw_damage, DamageType.TRUE, source, from_attack)


## Removes `amount` health (after shields) with no resist math. Most code should use
## take_physical_damage / take_magic_damage / take_true_damage instead.
func take_damage(amount: float, source: Node = null) -> void:
	if is_dead or invulnerable:
		return
	if source and is_instance_valid(source):
		_recent_attackers[source.get_instance_id()] = Engine.get_physics_frames()
	amount = _absorb_with_shields(amount)
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, get_max_health())
	damaged.emit(amount, source)
	if current_health <= 0.0:
		is_dead = true
		var credited := source
		if source and is_instance_valid(source) and source.has_method("credit_source"):
			var owner: Node = source.call("credit_source")
			if owner and is_instance_valid(owner):
				credited = owner
		killer = credited if credited and is_instance_valid(credited) else null
		clear_shields()
		died.emit()
		_credit_takedowns()


## Everyone who damaged this unit in the last ASSIST_WINDOW seconds (the killer included).
func get_takedown_credits() -> Array[Node]:
	var out: Array[Node] = []
	var now := Engine.get_physics_frames()
	var window := int(ASSIST_WINDOW * Engine.physics_ticks_per_second)
	for id in _recent_attackers:
		if now - int(_recent_attackers[id]) > window:
			continue
		var n := instance_from_id(id) as Node
		if n and is_instance_valid(n):
			out.append(n)
	return out


## Tells each attacker with takedown credit (via on_takedown(victim), if they have it).
func _credit_takedowns() -> void:
	var victim := get_parent()
	for n in get_takedown_credits():
		if n.has_method("on_takedown"):
			n.call("on_takedown", victim)
	_recent_attackers.clear()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	amount *= maxf(healing_mult, 0.0)
	if amount <= 0.0:
		return
	current_health = minf(current_health + amount, get_max_health())
	health_changed.emit(current_health, get_max_health())


# ---- Shields ----

## Adds a shield that absorbs `amount` damage for `duration` seconds. A shield with
## the same non-empty id replaces the old one instead of stacking.
func add_shield(amount: float, duration: float, id: String = "") -> void:
	if is_dead or amount <= 0.0 or duration <= 0.0:
		return
	if id != "":
		for i in range(_shields.size() - 1, -1, -1):
			if _shields[i]["id"] == id:
				_shields.remove_at(i)
	_shields.append({"amount": amount, "time_left": duration, "id": id})
	shield_changed.emit(get_shield())


func get_shield() -> float:
	var total := 0.0
	for sh in _shields:
		total += float(sh["amount"])
	return total


func clear_shields() -> void:
	if _shields.is_empty():
		return
	_shields.clear()
	shield_changed.emit(0.0)


## Takes damage out of shields first. Returns what's left over for health.
func _absorb_with_shields(amount: float) -> float:
	if _shields.is_empty():
		return amount
	while amount > 0.0 and not _shields.is_empty():
		var sh := _shields[0]
		var take := minf(float(sh["amount"]), amount)
		sh["amount"] = float(sh["amount"]) - take
		amount -= take
		if float(sh["amount"]) <= 0.001:
			_shields.remove_at(0)
	shield_changed.emit(get_shield())
	return amount


func _physics_process(delta: float) -> void:
	if _shields.is_empty():
		return
	var changed := false
	for i in range(_shields.size() - 1, -1, -1):
		_shields[i]["time_left"] = float(_shields[i]["time_left"]) - delta
		if float(_shields[i]["time_left"]) <= 0.0:
			_shields.remove_at(i)
			changed = true
	if changed:
		shield_changed.emit(get_shield())


# ---- Mana ----

func use_mana(amount: float) -> bool:
	if amount > current_mana:
		return false
	current_mana -= amount
	mana_changed.emit(current_mana, get_max_mana())
	return true


func restore_mana(amount: float) -> void:
	current_mana = minf(current_mana + amount, get_max_mana())
	mana_changed.emit(current_mana, get_max_mana())


# ---- XP and levels ----

func add_xp(amount: float) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= get_xp_to_level():
		xp -= get_xp_to_level()
		_level_up()
	if level >= MAX_LEVEL:
		xp = 0.0


## Jumps straight to `new_level` (for testing or starting a game later). Can't go down.
func set_level(new_level: int) -> void:
	new_level = clampi(new_level, 1, MAX_LEVEL)
	while level < new_level:
		_level_up()


## Like League: max health and mana go up, and current health / mana go up by the same amount.
func _level_up() -> void:
	var old_hp := get_max_health()
	var old_mp := get_max_mana()
	level += 1
	_apply_max_change(old_hp, old_mp)
	stats_changed.emit()
	leveled_up.emit(level)


func get_xp_to_level() -> float:
	return 100.0 * level


func get_xp_progress() -> float:
	if level >= MAX_LEVEL:
		return 1.0
	return xp / get_xp_to_level()
