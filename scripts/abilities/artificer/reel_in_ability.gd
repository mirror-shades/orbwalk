class_name ReelInAbility
extends Ability
## E: every robot fires a ray at him (robots stay where they are), he gains a shield,
## and enemies close to him are shoved back and slowed so a dive can't land.
## Works with an empty board too: then it is just the base shield and the shove.

const SHIELD_ID := "artificer_reel_shield"
const SLOW_ID := "artificer_reel_slow"


func _cast(_target_pos: Vector3) -> void:
	var def := definition as ReelInDefinition
	var manager := ArtificerRobots.get_or_create(caster)
	var rays := 0
	if manager:
		var ray_damage := ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
		rays = manager.fire_rays(ray_damage, def.ray_width)
	var extra := mini(maxi(rays - 1, 0), def.shield_cap_contributions)
	var shield := ranked(def.shield_base, def.shield_per_rank) + float(extra) * ranked(def.shield_per_robot, def.shield_per_robot_per_rank)
	caster.stats.add_shield(shield, def.shield_duration, SHIELD_ID)
	_shove(def)


## Pushes every nearby enemy straight away from the caster and slows it.
func _shove(def: ReelInDefinition) -> void:
	var tree := get_tree()
	var from := caster.global_position
	var slow := ranked(def.push_slow, def.push_slow_per_rank)
	for body in AbilityUtil.enemies_in_radius(tree, caster.stats.get_team(), from, def.push_radius):
		var fx := body.get_node_or_null("StatusEffects") as StatusEffects
		if fx == null:
			continue
		fx.apply_slow(slow, def.push_slow_duration, SLOW_ID)
		var away := Vector3(body.global_position.x - from.x, 0.0, body.global_position.z - from.z)
		if away.length_squared() < 0.0001:
			away = Vector3.RIGHT
		var dest := body.global_position + away.normalized() * def.push_distance
		dest = DashAbility.clip_to_navmesh(body, body.global_position, dest)
		fx.start_forced_move(dest, def.push_speed)
	AbilityUtil.ring_flash(tree.current_scene, from, def.push_radius, Color(0.55, 0.8, 1.0, 0.8))
