extends Node

@export var entity_definitions: Array[EntityDefinition] = []

var _by_id: Dictionary = {}

func _ready() -> void:
	_rebuild_index()

func _rebuild_index() -> void:
	_by_id.clear()
	for def in entity_definitions:
		if def and not def.entity_id.is_empty():
			_by_id[def.entity_id] = def

func get_definition(id: String) -> EntityDefinition:
	return _by_id.get(id)

func register(definition: EntityDefinition) -> void:
	if definition and not definition.entity_id.is_empty():
		_by_id[definition.entity_id] = definition
		if definition not in entity_definitions:
			entity_definitions.append(definition)

static func is_enemy(team_a: int, team_b: int) -> bool:
	if team_a == EntityDefinition.Team.NEUTRAL or team_b == EntityDefinition.Team.NEUTRAL:
		return true
	return team_a != team_b

func get_living_entities() -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group("entity"):
		if not is_instance_valid(node):
			continue
		var sc: StatsComponent = node.get_node_or_null("Stats")
		if sc and not sc.is_dead:
			result.append(node)
	return result

func get_enemies_of(team: int) -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group("entity"):
		if not is_instance_valid(node):
			continue
		var sc: StatsComponent = node.get_node_or_null("Stats")
		if not sc or sc.is_dead:
			continue
		if is_enemy(team, sc.get_team()):
			result.append(node)
	return result

func get_nearest_enemy(from_pos: Vector3, team: int) -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for node in get_tree().get_nodes_in_group("entity"):
		if not is_instance_valid(node):
			continue
		var sc: StatsComponent = node.get_node_or_null("Stats")
		if not sc or sc.is_dead:
			continue
		if not is_enemy(team, sc.get_team()):
			continue
		var d := from_pos.distance_squared_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = node
	return nearest
