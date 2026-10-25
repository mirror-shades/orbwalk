class_name HexSwarmAbility
extends Ability
## W: shield herself and fire homing missiles at enemies within range, one each:
## enemy champions first, then the closest. Missiles hit mercenaries and monsters harder. With fewer enemies than missiles, the spares also go to the closest.
## Each missile that lands heals her (Witch's Tithe).

const SHIELD_ID := "br_hex_shield"
const COLOR := Color(0.75, 0.4, 1.0)

var _shield_left: float = 0.0


func is_active() -> bool:
	return _shield_left > 0.0 and caster.stats.get_shield() > 0.0


func _tick(delta: float) -> void:
	_shield_left = maxf(_shield_left - delta, 0.0)


func _cast(_target_pos: Vector3) -> void:
	var def := definition as HexSwarmDefinition
	caster.stats.add_shield(ranked(def.shield, def.shield_per_rank) + def.shield_ap_ratio * ap(), def.shield_duration, SHIELD_ID)
	_shield_left = def.shield_duration
	AbilityUtil.ring_flash(get_tree().current_scene, caster.global_position, 1.4, Color(COLOR, 0.8))

	var targets := targets_in_range()
	if targets.is_empty():
		return
	var dmg := ranked(def.missile_damage, def.missile_damage_per_rank) + def.missile_ap_ratio * ap()
	for i in def.missile_count:
		var t: Node3D = targets[i] if i < targets.size() else targets[0]
		var shot := HomingShot.fire(caster, t, dmg if _is_champion(t) else dmg * def.non_champion_mult, def.missile_speed, COLOR)
		shot.magic = true
		shot.cause = "hex_swarm:missile"
		shot.landed.connect(_on_missile_landed)
		# Fan the missiles out a little so three on one target read as three.
		var side := float(i - (def.missile_count - 1) * 0.5)
		shot.global_position += caster.global_basis.x * side * 0.35


## Enemies within missile range: champions first, then closest first. Used by the bot too.
func targets_in_range() -> Array[Node3D]:
	var def := definition as HexSwarmDefinition
	var found := AbilityUtil.enemies_in_radius(get_tree(), caster.stats.get_team(), caster.global_position, def.missile_range)
	var from := caster.global_position
	# Enemy champions first, then the closest.
	found.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var ca := _is_champion(a)
		if ca != _is_champion(b):
			return ca
		return AbilityUtil.flat_distance(a.global_position, from) < AbilityUtil.flat_distance(b.global_position, from))
	return found


func _on_missile_landed(target: Node3D) -> void:
	WitchsTitheAbility.spell_hit(caster, target)


static func _is_champion(body: Node3D) -> bool:
	var st := body.get_node_or_null("Stats") as StatsComponent
	return st != null and st.get_entity_type() == EntityDefinition.EntityType.CHAMPION
