extends Node

@export var entity_definitions: Array[EntityDefinition] = []

var _by_id: Dictionary = {}

# ---- Unit ids ----
# Every Entity gets an integer unit id when it first enters the tree (see entity.gd).
# Commands name units by this id, never by node or instance id, so the id can
# mean the same unit on every machine once ids are handed out by one authority.
# Ids are never reused: an id for a unit that's gone resolves to null instead of
# to some newer unit.

## The unit id the next new entity gets. 0 means "no entity".
var _next_unit_id: int = 1
## id -> the entity node, for entities currently in the tree.
var _entities: Dictionary[int, Node] = {}

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

## Gives `node` a unit id (or re-adds its existing one) and indexes it.
## Called by Entity when it enters the tree. Returns the id.
func register_unit(node: Node, current_id: int) -> int:
	var id := current_id
	if id <= 0:
		id = _next_unit_id
		_next_unit_id += 1
	_entities[id] = node
	return id


## Starts a new match's unit ids at `first` (1 by default), so the same match
## always hands out the same ids; replays rely on this, since commands name
## units by id. Ids still in use are never handed out again, so if units from
## something else are alive this may start higher. Returns the first id.
func restart_unit_ids(first: int = 1) -> int:
	var start := maxi(first, 1)
	for id in _entities:
		if is_instance_valid(_entities[id]):
			start = maxi(start, id + 1)
	_next_unit_id = start
	return start


## Called by Entity when it leaves the tree. The id isn't handed out again.
func unregister_unit(id: int) -> void:
	_entities.erase(id)


## The entity with `id`, or null if there's none (gone, freed, or never existed).
func unit_by_id(id: int) -> Node:
	var node: Node = _entities.get(id)
	if node == null or not is_instance_valid(node):
		return null
	return node


## The unit id of `node`, or 0 if it isn't an entity.
static func id_of(node: Node) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	return int(node.get("unit_id")) if "unit_id" in node else 0


static func is_enemy(team_a: int, team_b: int) -> bool:
	if team_a == EntityDefinition.Team.NEUTRAL or team_b == EntityDefinition.Team.NEUTRAL:
		return true
	return team_a != team_b

static func get_stats_of(node: Node) -> StatsComponent:
	if not node:
		return null
	return node.get_node_or_null(^"Stats") as StatsComponent

func get_living_entities() -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group("entity"):
		if not is_instance_valid(node):
			continue
		var sc := get_stats_of(node)
		if sc and not sc.is_dead:
			result.append(node)
	return result

func get_enemies_of(team: int) -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group("entity"):
		if not is_instance_valid(node):
			continue
		var sc := get_stats_of(node)
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
		var sc := get_stats_of(node)
		if not sc or sc.is_dead:
			continue
		if not is_enemy(team, sc.get_team()):
			continue
		var d := from_pos.distance_squared_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = node
	return nearest
