class_name WranglerPounceAbility
extends Ability
## Passive: when she auto-attacks an enemy champion, the pug leaps onto them and
## bites, slowing them. Each champion has its own cooldown. The pug only pounces
## while it's following her: if it's busy the bite is skipped and nothing goes on
## cooldown.

const SLOW_ID := "wrangler_pounce_slow"

var _pet: WranglerPet
## Instance id of each champion -> seconds until the pug can pounce on them again.
var _cooldowns: Dictionary = {}


## The pounce passive on `entity`, or null.
static func of(entity: Node) -> WranglerPounceAbility:
	var c := entity.get_node_or_null("Abilities") as AbilityCaster
	return c.passive as WranglerPounceAbility if c else null


## The pug that belongs to `entity`, or null.
static func pet_of(entity: Node) -> WranglerPet:
	var p := of(entity)
	return p.pet() if p else null


func pet() -> WranglerPet:
	return _pet


func _ready() -> void:
	caster.attack_landed.connect(_on_attack_landed)
	_pet = WranglerPet.new()
	_pet.owner_entity = caster
	caster.add_child(_pet)


func _on_attack_landed(target: Node) -> void:
	if _pet == null or caster.stats.is_dead or not _pet.is_following():
		return
	if not (target is Node3D) or not _is_enemy_champion(target):
		return
	var id := target.get_instance_id()
	if float(_cooldowns.get(id, 0.0)) > 0.0:
		return
	var def := definition as PounceDefinition
	if ProtoUtil.flat_distance(_pet.global_position, (target as Node3D).global_position) > def.leap_range:
		return
	_cooldowns[id] = def.target_cooldown
	_pet.leap_to_target(target as Node3D, def.leap_speed, _bite.bind(target))


func _bite(target: Node) -> void:
	if target == null or not is_instance_valid(target) or caster.stats.is_dead:
		_pet.follow()
		return
	var st := target.get_node_or_null("Stats") as StatsComponent
	if st == null or st.is_dead or not EntityData.is_enemy(caster.stats.get_team(), st.get_team()):
		_pet.follow()
		return
	var def := definition as PounceDefinition
	var dmg := def.base_damage + def.damage_per_level * float(caster.stats.level) + def.ad_ratio * ad()
	st.take_physical_damage(dmg, caster)
	if not st.is_dead:
		var fx := target.get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			fx.apply_slow(def.slow, def.slow_duration, SLOW_ID)
	_pet.bite()
	AbilityUtil.ring_flash(get_tree().current_scene, (target as Node3D).global_position, 1.1, Color(0.95, 0.75, 0.35, 0.8))
	_pet.follow()


func _tick(delta: float) -> void:
	if _cooldowns.is_empty():
		return
	for id in _cooldowns.keys():
		var left := float(_cooldowns[id]) - delta
		if left <= 0.0:
			_cooldowns.erase(id)
		else:
			_cooldowns[id] = left


func _is_enemy_champion(target: Node) -> bool:
	var st := target.get_node_or_null("Stats") as StatsComponent
	if st == null or st.is_dead:
		return false
	if st.get_entity_type() != EntityDefinition.EntityType.CHAMPION:
		return false
	return EntityData.is_enemy(caster.stats.get_team(), st.get_team())
