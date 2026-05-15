extends Node3D

@onready var charizard = $Charizard
@onready var gnome = $Gnome

@export var nav_agent_radius: float = 0.5
@export var nav_agent_height: float = 2.0
@export var nav_agent_max_climb: float = 0.3
@export var nav_agent_max_slope: float = 45.0
@export var nav_cell_size: float = 0.3
@export var nav_edge_max_length: float = 12.0

func _ready() -> void:
	if not charizard:
		push_error("Charizard node not found!")
	if not gnome:
		push_error("Gnome node not found!")

	_create_navigation()

func _create_navigation() -> void:
	for child in get_children():
		if child is NavigationRegion3D:
			child.queue_free()

	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	add_child(region)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = nav_agent_radius
	nav_mesh.agent_height = nav_agent_height
	nav_mesh.agent_max_climb = nav_agent_max_climb
	nav_mesh.agent_max_slope = nav_agent_max_slope
	nav_mesh.cell_size = nav_cell_size
	nav_mesh.edge_max_length = nav_edge_max_length

	var geo := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, geo, self)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, geo)

	var count := nav_mesh.get_polygon_count()
	print("Navmesh baked: ", count, " polygons")

	if count == 0:
		push_warning("Baking produced 0 polygons — falling back to rectangle")
		var fallback := NavigationMesh.new()
		fallback.agent_radius = nav_agent_radius
		fallback.agent_height = nav_agent_height
		fallback.agent_max_climb = nav_agent_max_climb
		fallback.agent_max_slope = nav_agent_max_slope
		fallback.cell_size = nav_cell_size
		fallback.edge_max_length = nav_edge_max_length
		fallback.vertices = PackedVector3Array([
			Vector3(-45, 0, -45),
			Vector3(145, 0, -45),
			Vector3(145, 0, 145),
			Vector3(-45, 0, 145),
		])
		fallback.add_polygon(PackedInt32Array([0, 1, 2]))
		fallback.add_polygon(PackedInt32Array([0, 2, 3]))
		region.navigation_mesh = fallback
	else:
		region.navigation_mesh = nav_mesh

	print("Nav region map RID: ", region.get_navigation_map())
