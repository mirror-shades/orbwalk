class_name DustDevilAbility
extends Ability
## W: summon a whirlwind at a spot for 3s. Every second it damages enemies inside
## and adds a Grit stack.

func _cast(target_pos: Vector3) -> void:
	var def := definition as DustDevilDefinition
	var center := AbilityUtil.clamp_to_range(caster.global_position, target_pos, def.cast_range)
	var zone := DustDevil.new()
	zone.team = caster.stats.get_team()
	zone.source = caster
	zone.radius = def.radius
	zone.duration = def.duration
	zone.tick_interval = def.tick_interval
	zone.damage = ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
	get_tree().current_scene.add_child(zone)
	zone.global_position = Vector3(center.x, 0.0, center.z)
