class_name DemolitionAbility
extends Ability
## W: sends every robot on the board (from Q or R, whatever state it is in) at the
## nearest enemy. Each bursts there, dealing magic damage and adding Bleed, and is
## consumed; a robot with nothing in range bursts where it stands. Refused (for free)
## when there are no robots.


func _cast_problem() -> String:
	var manager := ArtificerRobots.find(caster)
	if manager == null or manager.board_count() == 0:
		return "No robots on the board."
	return ""


func _cast(_target_pos: Vector3) -> void:
	var def := definition as DemolitionDefinition
	var manager := ArtificerRobots.find(caster)
	if manager == null:
		return
	var damage := ranked(def.base_damage, def.damage_per_rank) + def.ap_ratio * ap()
	manager.seek_all(damage, def.radius, def.bleed_stacks, def.seek_speed, def.seek_range)
