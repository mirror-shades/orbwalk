class_name StatsComponent
extends Node

signal health_changed(current: float, max_hp: float)
signal mana_changed(current: float, max_mp: float)
signal died()
signal leveled_up(new_level: int)
signal damaged(amount: float, source: Node)

var definition: EntityDefinition
var level: int = 1
var xp: float = 0.0
var current_health: float = 0.0
var current_mana: float = 0.0
var is_dead: bool = false

var bonus_attack_damage: float = 0.0
var bonus_ability_power: float = 0.0
var bonus_armor: float = 0.0
var bonus_magic_resist: float = 0.0
var bonus_attack_speed: float = 0.0
var bonus_movement_speed: float = 0.0

func initialize(def: EntityDefinition = null, start_level: int = 1) -> void:
	definition = def
	level = start_level
	current_health = get_max_health()
	current_mana = get_max_mana()
	is_dead = false

func get_max_health() -> float:
	return _base_or_default("stats_max_health", "growth_health", 500.0)

func get_health_regen() -> float:
	return _base_or_default("stats_health_regen", "growth_health_regen", 5.0)

func get_max_mana() -> float:
	return _base_or_default("stats_max_mana", "growth_mana", 300.0)

func get_mana_regen() -> float:
	return _base_or_default("stats_mana_regen", "growth_mana_regen", 7.0)

func get_attack_damage() -> float:
	return _base_or_default("stats_attack_damage", "growth_attack_damage", 60.0) + bonus_attack_damage

func get_ability_power() -> float:
	return _base_or_default("stats_ability_power", null, 0.0) + bonus_ability_power

func get_armor() -> float:
	return _base_or_default("stats_armor", "growth_armor", 25.0) + bonus_armor

func get_magic_resist() -> float:
	return _base_or_default("stats_magic_resist", "growth_magic_resist", 30.0) + bonus_magic_resist

func get_attack_speed() -> float:
	return _base_or_default("stats_attack_speed", "growth_attack_speed", 0.625) + bonus_attack_speed

func get_attack_range() -> float:
	return definition.stats_attack_range if definition else 1.5

func get_movement_speed() -> float:
	return _base_or_default("stats_movement_speed", null, 5.0) + bonus_movement_speed

func _base_or_default(base_prop: String, growth_prop, default_val: float) -> float:
	if not definition:
		return default_val
	var base: float = definition.get(base_prop)
	if growth_prop:
		var growth: float = definition.get(growth_prop)
		return definition.get_stat_at_level(base, growth, level)
	return base

func take_damage(amount: float, source: Node = null) -> void:
	if is_dead:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, get_max_health())
	damaged.emit(amount, source)
	if current_health <= 0.0:
		is_dead = true
		died.emit()

func take_physical_damage(raw_damage: float, source: Node = null) -> void:
	take_damage(raw_damage * (100.0 / (100.0 + get_armor())), source)

func take_magic_damage(raw_damage: float, source: Node = null) -> void:
	take_damage(raw_damage * (100.0 / (100.0 + get_magic_resist())), source)

func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = minf(current_health + amount, get_max_health())
	health_changed.emit(current_health, get_max_health())

func use_mana(amount: float) -> bool:
	if amount > current_mana:
		return false
	current_mana -= amount
	mana_changed.emit(current_mana, get_max_mana())
	return true

func restore_mana(amount: float) -> void:
	current_mana = minf(current_mana + amount, get_max_mana())
	mana_changed.emit(current_mana, get_max_mana())

func add_xp(amount: float) -> void:
	xp += amount
	var xp_needed := get_xp_to_level()
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		var health_gain := definition.growth_health if definition else 85.0
		var mana_gain := definition.growth_mana if definition else 40.0
		current_health = minf(current_health + health_gain, get_max_health())
		current_mana = minf(current_mana + mana_gain, get_max_mana())
		xp_needed = get_xp_to_level()
		leveled_up.emit(level)

func get_xp_to_level() -> float:
	return 100.0 * level

func get_xp_progress() -> float:
	return xp / get_xp_to_level()
