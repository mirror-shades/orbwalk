class_name BountyAbility
extends Ability

const MODIFIER_ID := "wakeman_bounty"
const BADGE_ID := "bounty"
const BADGE_COLOR := Color(1.0, 0.78, 0.25)

var stacks: int = 0
var _badge_timer: float = 0.0


func _ready() -> void:
	caster.takedown.connect(_on_takedown)
	_apply()
	_sync_badge()


static func of(entity: Node) -> BountyAbility:
	if entity == null or not is_instance_valid(entity):
		return null
	var c := entity.get_node_or_null("Abilities") as AbilityCaster
	return c.passive as BountyAbility if c else null


func add_stacks(amount: int) -> void:
	if amount <= 0:
		return
	stacks += amount
	_apply()
	_sync_badge()


func tumble_kill_stacks() -> int:
	return (definition as BountyDefinition).tumble_kill_stacks


func _on_takedown(victim: Node) -> void:
	var victim_stats := EntityData.get_stats_of(victim)
	if victim_stats == null or victim_stats.get_entity_type() != EntityDefinition.EntityType.CHAMPION:
		return
	var def := definition as BountyDefinition
	if victim_stats.killer == caster:
		add_stacks(def.kill_stacks)
	else:
		add_stacks(def.assist_stacks)


func _apply() -> void:
	if caster == null or caster.stats == null:
		return
	var def := definition as BountyDefinition
	if stacks <= 0:
		caster.stats.remove_modifier(MODIFIER_ID)
		return
	caster.stats.set_modifier(MODIFIER_ID, {
		StatsComponent.Stat.ATTACK_DAMAGE: def.attack_damage_per_stack * float(stacks),
	})


func _sync_badge() -> void:
	var fx := caster.status_effects() if caster else null
	if fx == null:
		return
	if stacks <= 0:
		fx.clear_badge(BADGE_ID)
		return
	fx.set_badge(BADGE_ID, "BTY", BADGE_COLOR, stacks, 1.0, 1.0)


func _tick(delta: float) -> void:
	if stacks <= 0:
		return
	_badge_timer -= delta
	if _badge_timer > 0.0:
		return
	_badge_timer = 0.5
	_sync_badge()
