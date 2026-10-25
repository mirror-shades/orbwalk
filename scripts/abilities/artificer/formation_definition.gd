class_name FormationDefinition
extends AbilityDefinition
## The Artificer's passive. The numbers are read by ArtificerRobots when a robot pulses.

## Other robots within this distance of a pulsing robot feed its damage.
@export var radius: float = 6.0
## Bonus pulse damage per nearby robot.
@export var bonus_per_robot: float = 0.2
## Cap on the bonus (two nearby robots).
@export var max_bonus: float = 0.4


func create_ability() -> Node:
	return load("res://scripts/abilities/artificer/formation_ability.gd").new()
