class_name AbilityCaster
extends Node
## Gives an entity the four abilities (Q, W, E, R) listed in its EntityDefinition
## (ability_1 .. ability_4). Handles mana, cooldowns, mana regen and ability ranks.
## It reads no input: casts and rank-ups arrive as PlayerCommands through
## ProtoGame.execute_command() (from PlayerController or a bot).
##
## Ranks work like League: one skill point per champion level. Slots 1-3 have 5
## ranks, and rank N needs champion level 2N-1 (1, 3, 5, 7, 9). Slot 4 has 3 ranks
## at levels 6, 11 and 16. Unlearned abilities can't be cast.
##
## Add it as a child of a champion, after the champion is in the scene tree.

signal ability_cast(slot: int)
signal cast_failed(slot: int, reason: String)
signal ability_ranked_up(slot: int, new_rank: int)

const SLOT_KEYS := ["Q", "W", "E", "R"]
const ACTIONS := ["ability_1", "ability_2", "ability_3", "ability_4"]
const LEVEL_ACTIONS := ["ability_level_1", "ability_level_2", "ability_level_3", "ability_level_4"]
const ULT_SLOT := 3
## Champion level needed for each rank (index 0 = rank 1).
const BASIC_RANK_LEVELS: Array[int] = [1, 3, 5, 7, 9]
const ULT_RANK_LEVELS: Array[int] = [6, 11, 16]

var caster: Entity
var abilities: Array[Ability] = [null, null, null, null]
## The champion's passive (EntityDefinition.passive), or null. It has no key.
var passive: Ability


func _ready() -> void:
	caster = get_parent() as Entity
	if caster == null:
		push_error("AbilityCaster must be a child of an Entity.")
		return
	var def := caster.definition
	if def:
		var defs: Array[AbilityDefinition] = [def.ability_1, def.ability_2, def.ability_3, def.ability_4]
		for i in 4:
			if defs[i] == null:
				continue
			var a := defs[i].create_ability() as Ability
			if a == null:
				continue
			a.name = SLOT_KEYS[i]
			a.setup(defs[i], caster)
			add_child(a)
			abilities[i] = a
		if def.passive:
			passive = def.passive.create_ability() as Ability
			if passive:
				passive.name = "Passive"
				passive.rank = 1
				passive.setup(def.passive, caster)
				add_child(passive)


# ---- Ranks ----

func get_rank(slot: int) -> int:
	var a := get_ability(slot)
	return a.rank if a else 0


func max_rank(slot: int) -> int:
	return rank_levels(slot).size()


## Champion level needed for each rank of the ability in `slot`.
func rank_levels(slot: int) -> Array[int]:
	return ULT_RANK_LEVELS if slot == ULT_SLOT else BASIC_RANK_LEVELS


## Unspent skill points: one per champion level, minus ranks already bought.
func skill_points() -> int:
	var spent := 0
	for a in abilities:
		if a:
			spent += a.rank
	return maxi(caster.stats.level - spent, 0)


## Returns "" if a point can go into `slot` right now, otherwise why not.
func rank_up_problem(slot: int) -> String:
	var a := get_ability(slot)
	if a == null:
		return "%s doesn't exist." % SLOT_KEYS[slot]
	if skill_points() <= 0:
		return "No skill points."
	if a.rank >= max_rank(slot):
		return "%s is already max rank." % a.display_name()
	var need: int = rank_levels(slot)[a.rank]
	if caster.stats.level < need:
		return "%s rank %d needs level %d." % [a.display_name(), a.rank + 1, need]
	return ""


func can_rank_up(slot: int) -> bool:
	return rank_up_problem(slot) == ""


## Spends a skill point on `slot`. Returns "" on success, otherwise why it can't
## (and emits cast_failed with the reason).
func rank_up(slot: int) -> String:
	var problem := rank_up_problem(slot)
	if problem != "":
		cast_failed.emit(slot, problem)
		return problem
	var a := get_ability(slot)
	a.rank += 1
	ability_ranked_up.emit(slot, a.rank)
	return ""


## The slot a bot should spend its next skill point on, or -1 if none can be
## spent: R when possible, then one rank in each basic ability, then the
## definition's skill_priority order.
func next_auto_rank_slot() -> int:
	if skill_points() <= 0:
		return -1
	if can_rank_up(ULT_SLOT):
		return ULT_SLOT
	var order := caster.definition.skill_priority
	for slot in order:
		if get_rank(slot) == 0 and can_rank_up(slot):
			return slot
	for slot in order:
		if can_rank_up(slot):
			return slot
	for slot in 3:
		if can_rank_up(slot):
			return slot
	return -1


func get_ability(slot: int) -> Ability:
	if slot < 0 or slot >= abilities.size():
		return null
	return abilities[slot]


## Updates the aim of a charged cast while it's being held (no mana or cooldown).
## Abilities without aim support ignore it.
func aim(slot: int, target_pos: Vector3) -> void:
	var a := get_ability(slot)
	if a and a.has_method("set_aim"):
		a.call("set_aim", target_pos)


## Casts the ability in `slot` at `target_pos`. Returns "" on success, otherwise
## why it can't (and emits cast_failed).
func try_cast(slot: int, target_pos: Vector3) -> String:
	var a := get_ability(slot)
	var problem := ""
	if a == null:
		problem = "%s isn't built yet." % SLOT_KEYS[slot]
	elif not a.is_learned():
		problem = "%s isn't learned yet (%s to level it)." % [a.display_name(), Controls.binding_text(LEVEL_ACTIONS[slot])]
	elif caster.stats.is_dead:
		problem = "You can't cast while dead."
	elif caster.status_effects() and caster.status_effects().is_feared():
		problem = "You can't cast while feared."
	elif caster.status_effects() and caster.status_effects().is_stunned():
		problem = "You can't cast while stunned."
	elif caster.firing_lock and not a.wants_recast():
		problem = "You're mid-volley."
	elif caster.status_effects() and caster.status_effects().is_channeling() and not a.wants_recast():
		problem = "You're charging the storm."
	elif a.wants_recast():
		if caster.has_method("break_stealth"):
			caster.call("break_stealth")
		a.recast(target_pos)
		ability_cast.emit(slot)
		return ""
	else:
		problem = a.cast_problem(target_pos)
	if problem != "":
		cast_failed.emit(slot, problem)
		return problem
	if caster.has_method("break_stealth"):
		caster.call("break_stealth")
	caster.stats.use_mana(a.mana_cost())
	a.start_cooldown()
	a.cast(target_pos)
	ability_cast.emit(slot)
	return ""


func _physics_process(delta: float) -> void:
	if caster == null or caster.stats == null or caster.stats.is_dead:
		return
	var st := caster.stats
	if st.current_mana < st.get_max_mana():
		st.restore_mana(st.get_mana_regen() * delta)
