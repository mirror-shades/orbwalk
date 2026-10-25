class_name GritAbility
extends Ability
## Passive: his spells grind Grit into enemies. Each stack slows; E spends every
## stack for bonus damage and a stun. Stacks all drop together when the timer runs out.
## No stack display yet (status visuals are a separate backlog item).

const SLOW_ID := "sleepwalker_grit"

## Target instance id -> {target, stacks, time_left}.
var _targets: Dictionary = {}
## Re-applies the slow a few times a second instead of every frame.
var _slow_timer: float = 0.0


## The Grit passive on `entity`, or null if it doesn't have one.
static func of(entity: Node) -> GritAbility:
	if entity == null or not is_instance_valid(entity):
		return null
	var c := entity.get_node_or_null("Abilities") as AbilityCaster
	return c.passive as GritAbility if c else null


func is_active() -> bool:
	return not _targets.is_empty()


## Adds Grit to an enemy unit. Champions, mercenaries and monsters only.
func add(target: Node3D, count: int = 1) -> void:
	if caster == null or not is_instance_valid(caster) or not is_instance_valid(target) or count <= 0:
		return
	var st := target.get_node_or_null("Stats") as StatsComponent
	if st == null or st.is_dead or st.invulnerable:
		return
	var kind := st.get_entity_type()
	if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB:
		return
	if not EntityData.is_enemy(caster.stats.get_team(), st.get_team()):
		return
	var def := definition as GritDefinition
	var id := target.get_instance_id()
	var e: Dictionary = _targets.get(id, {})
	if e.is_empty():
		e = {"target": target, "stacks": 0, "time_left": 0.0}
		_targets[id] = e
	e["stacks"] = mini(int(e["stacks"]) + count, def.max_stacks)
	e["time_left"] = def.stack_duration
	_apply_slow(e)


## How many Grit stacks `target` has right now (0 if none).
func stacks_of(target: Node) -> int:
	if target == null or not is_instance_valid(target):
		return 0
	var e: Dictionary = _targets.get(target.get_instance_id(), {})
	return int(e["stacks"]) if not e.is_empty() else 0


## Every stacked enemy within `radius` of `center` (unit size counts).
func stacked_in_radius(center: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for id in _targets.keys():
		var e: Dictionary = _targets[id]
		var target := e["target"] as Node3D
		if not is_instance_valid(target):
			continue
		var st := target.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead:
			continue
		if AbilityUtil.flat_distance(target.global_position, center) <= radius + AbilityUtil.unit_radius(target):
			out.append(target)
	return out


## Removes all of `target`'s stacks (E spends them) and ends the slow early.
func consume(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var id := target.get_instance_id()
	if not _targets.has(id):
		return
	_targets.erase(id)
	var fx := target.get_node_or_null("StatusEffects") as StatusEffects
	if fx:
		fx.remove_effect(SLOW_ID)
		fx.clear_badge("grit")


func _apply_slow(e: Dictionary) -> void:
	var target := e["target"] as Node3D
	if not is_instance_valid(target):
		return
	var fx := target.get_node_or_null("StatusEffects") as StatusEffects
	if fx == null:
		return
	var def := definition as GritDefinition
	fx.apply_slow(def.slow_per_stack * float(e["stacks"]), def.slow_refresh, SLOW_ID)
	fx.set_badge("grit", "GRT", Color(0.86, 0.7, 0.42), int(e["stacks"]), float(e["time_left"]), def.stack_duration)


func _tick(delta: float) -> void:
	_slow_timer -= delta
	var refresh_slow := _slow_timer <= 0.0
	if refresh_slow:
		_slow_timer = 0.15
	for id in _targets.keys():
		var e: Dictionary = _targets[id]
		var target := e["target"] as Node3D
		var st: StatsComponent = null
		if is_instance_valid(target):
			st = target.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead:
			_targets.erase(id)
			continue
		e["time_left"] = float(e["time_left"]) - delta
		if float(e["time_left"]) <= 0.0:
			_targets.erase(id)
			var fx := target.get_node_or_null("StatusEffects") as StatusEffects
			if fx:
				fx.remove_effect(SLOW_ID)
				fx.clear_badge("grit")
			continue
		if refresh_slow:
			_apply_slow(e)
