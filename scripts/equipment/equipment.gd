class_name Equipment
extends Node
## A champion's pre-match build: one item per slot (see ItemCatalog).
## Stat bonuses go into the champion's StatsComponent as the "equipment" modifier
## and are refreshed on level up (for per-level items). The game asks this node for
## gold income and last-hit rewards; every other item passive runs here.
##
## Add it as a child of an Entity (after its AbilityCaster, if it has one), then call equip().

const MODIFIER_ID := "equipment"
const RAGE_MODIFIER_ID := "equipment_rage"

var owner_entity: Entity
## Slot -> item id.
var loadout: Dictionary = {}

var _since_damaged: float = 0.0
var _last_stand_cd: float = 0.0
var _ward_timer: float = 0.0
var _spellblade_ready: float = 0.0
var _spellblade_cd: float = 0.0
var _hit_count: int = 0
var _rage_bonus: float = 0.0


func _ready() -> void:
	owner_entity = get_parent() as Entity
	if owner_entity == null or owner_entity.stats == null:
		push_error("Equipment must be a child of an Entity.")
		return
	var st := owner_entity.stats
	st.leveled_up.connect(func(_l: int) -> void: _apply_stats())
	st.damaged.connect(func(_a: float, _s: Node) -> void: _since_damaged = 0.0)
	st.hit_taken.connect(_on_hit_taken)
	st.health_changed.connect(_on_health_changed)
	owner_entity.attack_landed.connect(_on_attack_landed)
	owner_entity.takedown.connect(_on_takedown)
	var caster := owner_entity.get_node_or_null("Abilities") as AbilityCaster
	if caster:
		caster.ability_cast.connect(_on_ability_cast)
	_apply_stats()


func equip(new_loadout: Dictionary) -> void:
	loadout = new_loadout.duplicate()
	_ward_timer = 0.0
	if is_inside_tree():
		_apply_stats()


func items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in ItemCatalog.SLOT_ORDER:
		var item := ItemCatalog.get_item(str(loadout.get(slot, "")))
		if not item.is_empty():
			out.append(item)
	return out


## Sum of one numeric item field across the build.
func total(field: String) -> float:
	var sum := 0.0
	for item in items():
		sum += float(item.get(field, 0.0))
	return sum


func last_hit_gold() -> int:
	return roundi(total("gold_per_last_hit"))


## Called by the game when this champion last-hits a mercenary.
func on_last_hit() -> void:
	var mana := total("mana_per_last_hit")
	if mana > 0.0 and not owner_entity.stats.is_dead:
		owner_entity.stats.restore_mana(mana)


func _apply_stats() -> void:
	if owner_entity == null or owner_entity.stats == null:
		return
	var st := owner_entity.stats
	var bonuses := {}
	for item in items():
		var flat: Dictionary = item.get("stats", {})
		for stat in flat:
			bonuses[stat] = float(bonuses.get(stat, 0.0)) + float(flat[stat])
		var per_level: Dictionary = item.get("per_level", {})
		for stat in per_level:
			bonuses[stat] = float(bonuses.get(stat, 0.0)) + float(per_level[stat]) * st.level
	st.set_modifier(MODIFIER_ID, bonuses)
	_update_rage()


func _physics_process(delta: float) -> void:
	if owner_entity == null or owner_entity.stats == null:
		return
	var st := owner_entity.stats
	_since_damaged += delta
	_last_stand_cd = maxf(_last_stand_cd - delta, 0.0)
	_spellblade_cd = maxf(_spellblade_cd - delta, 0.0)
	_spellblade_ready = maxf(_spellblade_ready - delta, 0.0)
	if st.is_dead:
		_ward_timer = 0.0
		return
	# Troll Hide: regenerate out of combat.
	var idle := total("idle_regen")
	if idle > 0.0 and _since_damaged >= ItemCatalog.IDLE_DELAY and st.current_health < st.get_max_health():
		st.heal(st.get_max_health() * idle * delta)
	# Wards: a shield that refills on a timer.
	_ward_timer -= delta
	if _ward_timer <= 0.0:
		_ward_timer = ItemCatalog.WARD_REFRESH
		for slot in ItemCatalog.SLOT_ORDER:
			var id := str(loadout.get(slot, ""))
			var item := ItemCatalog.get_item(id)
			if item.has("ward"):
				var amount := float(item["ward"]) + float(item.get("ward_per_level", 0.0)) * st.level
				st.add_shield(amount, ItemCatalog.WARD_REFRESH + 0.1, "ward_" + id)


func _on_attack_landed(target: Node) -> void:
	var ts := EntityData.get_stats_of(target)
	if ts == null or ts.is_dead:
		return
	var st := owner_entity.stats
	# Witch's Fang: magic damage on every hit.
	var on_hit := total("on_hit_magic")
	if on_hit > 0.0:
		ts.take_magic_damage(on_hit + total("on_hit_magic_per_level") * st.level, owner_entity)
	# Rhythm Gloves: every Nth hit.
	for item in items():
		if not item.has("nth_hit"):
			continue
		_hit_count += 1
		if _hit_count >= int(item["nth_hit"]):
			_hit_count = 0
			var dmg := float(item.get("nth_hit_magic", 0.0)) + float(item.get("nth_hit_magic_per_level", 0.0)) * st.level
			if not ts.is_dead:
				ts.take_magic_damage(dmg, owner_entity)
				_pop("%d" % roundi(dmg), (target as Node3D).global_position if target is Node3D else owner_entity.global_position, Color(0.75, 0.5, 1.0))
	# Spellthread Gloves: the auto after an ability cast.
	if _spellblade_ready > 0.0 and not ts.is_dead:
		_spellblade_ready = 0.0
		_spellblade_cd = ItemCatalog.SPELLBLADE_COOLDOWN
		ts.take_physical_damage(total("spellblade") * st.get_base_attack_damage(), owner_entity)


func _on_ability_cast(_slot: int) -> void:
	if total("spellblade") > 0.0 and _spellblade_cd <= 0.0:
		_spellblade_ready = ItemCatalog.SPELLBLADE_WINDOW


## Spiked Cuirass: auto-attacks taken are partly dealt back. Not against towers or the orb.
func _on_hit_taken(dealt: float, _type: int, source: Node, from_attack: bool) -> void:
	var thorns := total("thorns")
	if thorns <= 0.0 or not from_attack or source == null or not is_instance_valid(source):
		return
	var ss := EntityData.get_stats_of(source)
	if ss == null or ss.is_dead:
		return
	var kind := ss.get_entity_type()
	if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB:
		return
	ss.take_magic_damage(dealt * thorns, owner_entity)


func _on_health_changed(current: float, max_hp: float) -> void:
	var st := owner_entity.stats
	# Last Stand Plate.
	var last_stand := total("last_stand")
	if last_stand > 0.0 and not st.is_dead and _last_stand_cd <= 0.0 and current > 0.0 and current < max_hp * ItemCatalog.LAST_STAND_THRESHOLD:
		_last_stand_cd = ItemCatalog.LAST_STAND_COOLDOWN
		st.add_shield(max_hp * last_stand, ItemCatalog.LAST_STAND_DURATION, "last_stand")
		_pop("Last Stand!", owner_entity.global_position, Color(1.0, 0.85, 0.4))
	_update_rage()


## Bloodrage Vest: bonus attack speed scaled by missing health.
func _update_rage() -> void:
	var st := owner_entity.stats
	var rage := total("rage_attack_speed")
	var bonus := 0.0
	if rage > 0.0 and not st.is_dead:
		bonus = rage * (1.0 - clampf(st.current_health / maxf(st.get_max_health(), 1.0), 0.0, 1.0))
	if absf(bonus - _rage_bonus) < 0.005:
		return
	_rage_bonus = bonus
	st.set_modifier(RAGE_MODIFIER_ID, {StatsComponent.Stat.ATTACK_SPEED: bonus} if bonus > 0.0 else {})


func _on_takedown(victim: Node) -> void:
	var vs := EntityData.get_stats_of(victim)
	if vs == null or vs.get_entity_type() != EntityDefinition.EntityType.CHAMPION:
		return
	var st := owner_entity.stats
	var frac := total("takedown_heal")
	if frac > 0.0:
		st.heal(st.get_max_health() * frac)
		st.restore_mana(st.get_max_mana() * frac)
		_pop("+%d%%" % roundi(frac * 100.0), owner_entity.global_position, Color(0.5, 1.0, 0.6))
	var haste := total("takedown_haste")
	if haste > 0.0 and owner_entity.status_effects():
		owner_entity.status_effects().apply_move_speed(haste, ItemCatalog.TAKEDOWN_HASTE_DURATION, "equipment_takedown_haste")


func _pop(text: String, at: Vector3, color: Color) -> void:
	if owner_entity.get_parent():
		AbilityUtil.pop_text(owner_entity.get_parent(), at + Vector3(0.0, 3.0, 0.0), text, color, 34)
