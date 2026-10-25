class_name SandWaveAbility
extends Ability
## Q: a sand wave rolls its full range in a straight line. Every enemy it passes
## takes magic damage, is rooted and gains a Grit stack, once each. Towers and the
## orb don't block it; the lane edge does.

func _cast(target_pos: Vector3) -> void:
	var def := definition as SandWaveDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	if dir.length() < 0.1:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	dir = dir.normalized()
	var to := from + dir * def.travel_distance
	var dest := AbilityUtil.clip_spell_to_lane(caster, from, to)

	var wave := SandWave.new()
	wave.team = caster.stats.get_team()
	wave.source = caster
	wave.dest = Vector3(dest.x, 0.0, dest.z)
	wave.speed = def.travel_speed
	wave.width = def.width
	wave.damage = ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
	wave.root_duration = ranked(def.root_duration, def.root_per_rank)
	get_tree().current_scene.add_child(wave)
	wave.launch(from)
