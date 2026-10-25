class_name HaulInAbility
extends Ability
## Q: throw a weighted rope in a straight line. The first enemy champion or
## mercenary it touches takes damage and is dragged to just in front of him.
## The rope passes over towers and the orb. A hit adds a Tide stack (passive).

var _rope: HaulRope


func is_active() -> bool:
	return _rope != null and is_instance_valid(_rope) and not _rope.is_queued_for_deletion()


func _cast(target_pos: Vector3) -> void:
	var def := definition as HaulInDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	if dir.length() < 0.1:
		var models := caster.get_node_or_null("Models") as Node3D
		dir = -models.global_basis.z if models else Vector3.RIGHT
		dir.y = 0.0
	dir = dir.normalized()

	var rope := HaulRope.new()
	rope.thrower = caster
	rope.team = caster.stats.get_team()
	rope.damage = ranked(def.base_damage, def.damage_per_rank) + def.ad_ratio * ad()
	rope.width = def.width
	rope.max_range = def.cast_range
	rope.speed = def.rope_speed
	rope.pull_speed = def.pull_speed
	rope.dir = dir
	rope.hooked.connect(_on_hooked)
	caster.get_parent().add_child(rope)
	rope.global_position = from + Vector3(0.0, 1.0, 0.0)
	_rope = rope


func _on_hooked(target: Node3D) -> void:
	var tide := TideMarkAbility.of(caster)
	if tide:
		tide.add_stack(target)
