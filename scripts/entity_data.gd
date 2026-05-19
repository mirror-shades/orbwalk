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
