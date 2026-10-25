class_name WitchsTitheAbility
extends Ability
## Passive: every enemy one of her spells hits heals her a little. Her abilities
## call on_spell_hit() on each hit and keep their own "already hit" sets, so an
## enemy counts once per cast (each W missile is its own hit). E deals no damage
## and never calls it.

const COLOR := Color(0.55, 1.0, 0.6)


## The Witch's Tithe passive on `entity`, or null if it doesn't have one.
static func of(entity: Node) -> WitchsTitheAbility:
	if entity == null or not is_instance_valid(entity):
		return null
	var c := entity.get_node_or_null("Abilities") as AbilityCaster
	return c.passive as WitchsTitheAbility if c else null


## Shortcut for abilities: heal `caster` for one spell hit on `target`.
static func spell_hit(p_caster: Node, target: Node3D) -> void:
	var p := of(p_caster)
	if p:
		p.on_spell_hit(target)


func on_spell_hit(target: Node3D) -> void:
	if caster.stats.is_dead or not is_instance_valid(target):
		return
	var st := target.get_node_or_null("Stats") as StatsComponent
	if st == null or not EntityData.is_enemy(caster.stats.get_team(), st.get_team()):
		return
	var amount := (definition as WitchsTitheDefinition).heal_per_hit
	caster.stats.heal(amount)
	AbilityUtil.pop_text(get_tree().current_scene, caster.global_position + Vector3(0.0, 3.0, 0.0), "+%d" % roundi(amount), COLOR, 28)
