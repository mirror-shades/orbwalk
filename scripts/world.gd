extends Node3D

@onready var charizard = $Charizard
@onready var gnome = $Gnome

@export var nav_agent_radius: float = 0.3
@export var nav_agent_height: float = 2.0
@export var nav_agent_max_climb: float = 0.1
@export var nav_agent_max_slope: float = 45.0
@export var nav_cell_size: float = 0.1
@export var nav_edge_max_length: float = 12.0
@export var nav_obstacle_padding: float = 0.35

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
	_add_obstacle_geometry(geo, self)
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

func _add_obstacle_geometry(geo: NavigationMeshSourceGeometryData3D, node: Node) -> void:
	var counts := _collect_geometry(geo, node)
	print("Collected ", counts.x, " meshes, ", counts.y, " collision shapes for navmesh baking")

func _collect_geometry(geo: NavigationMeshSourceGeometryData3D, node: Node) -> Vector2:
	var mesh_count := 0
	var shape_count := 0
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh:
			var aabb: AABB = child.mesh.get_aabb()
			if aabb.size.x > 50.0 and aabb.size.z > 50.0:
				geo.add_mesh(child.mesh, child.global_transform)
				mesh_count += 1
		if child is CollisionShape3D and child.shape:
			var body := child.get_parent()
			if body is CollisionObject3D:
				var shape: Shape3D = child.shape
				var is_large_ground := false
				if shape is BoxShape3D:
					var size: Vector3 = shape.size
					if size.x > 10.0 and size.z > 10.0:
						is_large_ground = true
				if not is_large_ground:
					_add_projected_obstruction(geo, child)
					shape_count += 1
		var child_counts := _collect_geometry(geo, child)
		mesh_count += child_counts.x
		shape_count += child_counts.y
	return Vector2(mesh_count, shape_count)

func _add_projected_obstruction(geo: NavigationMeshSourceGeometryData3D, cs: CollisionShape3D) -> void:
	var shape: Shape3D = cs.shape
	var gp := cs.global_position
	var gb := cs.global_transform.basis
	var vertices := PackedVector3Array()

	if shape is BoxShape3D:
		var x_axis := gb * Vector3.RIGHT
		var z_axis := gb * Vector3.BACK
		var x_scale := x_axis.length()
		var z_scale := z_axis.length()
		var hx: float = shape.size.x / 2.0
		var hz: float = shape.size.z / 2.0
		if x_scale > 0.0:
			hx += nav_obstacle_padding / x_scale
		if z_scale > 0.0:
			hz += nav_obstacle_padding / z_scale
		for corner in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
			var r := gb * Vector3(corner.x, 0, corner.y)
			vertices.append(Vector3(r.x + gp.x, 0, r.z + gp.z))
	elif shape is CylinderShape3D:
		for i in 16:
			var angle := i * 2.0 * PI / 16.0
			var v := Vector2(cos(angle) * shape.radius, sin(angle) * shape.radius)
			var r := gb * Vector3(v.x, 0, v.y)
			var padding_dir := Vector3(r.x, 0, r.z)
			if padding_dir.length() > 0.0:
				padding_dir = padding_dir.normalized() * nav_obstacle_padding
				r.x += padding_dir.x
				r.z += padding_dir.z
			vertices.append(Vector3(r.x + gp.x, 0, r.z + gp.z))

	if vertices.size() > 2:
		geo.add_projected_obstruction(vertices, 0.0, nav_agent_height, true)
