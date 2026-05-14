extends Node3D

@onready var charizard = $Charizard
@onready var gnome = $Gnome

# Configuration
@export var detection_range: float = 5.0
@export var check_interval: float = 0.5  # How often to check distance in seconds

# Navigation mesh bake settings
@export var nav_agent_radius: float = 0.5
@export var nav_agent_height: float = 2.0
@export var nav_agent_max_climb: float = 0.3
@export var nav_agent_max_slope: float = 45.0
@export var nav_cell_size: float = 0.3
@export var nav_edge_max_length: float = 12.0

var time_since_last_check: float = 0.0

func _ready() -> void:
	if not charizard:
		push_error("Charizard node not found!")
	else:
		print("Charizard node found!")
	if not gnome:
		push_error("Gnome node not found!")
	else:
		print("Gnome node found!")

	_setup_navigation()

func _setup_navigation() -> void:
	if has_node("NavigationRegion3D"):
		return

	var nav_region := NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	add_child(nav_region)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = nav_agent_radius
	nav_mesh.agent_height = nav_agent_height
	nav_mesh.agent_max_climb = nav_agent_max_climb
	nav_mesh.agent_max_slope = nav_agent_max_slope
	nav_mesh.cell_size = nav_cell_size
	nav_mesh.edge_max_length = nav_edge_max_length

	# Manual rectangular navmesh: walls bound the area at approx x:[-50,150] z:[-50,150]
	nav_mesh.vertices = PackedVector3Array([
		Vector3(-45, 0, -45),
		Vector3(145, 0, -45),
		Vector3(145, 0, 145),
		Vector3(-45, 0, 145),
	])
	nav_mesh.add_polygon(PackedInt32Array([0, 1, 2]))
	nav_mesh.add_polygon(PackedInt32Array([0, 2, 3]))

	nav_region.navigation_mesh = nav_mesh
	print("Navigation mesh created (", nav_mesh.vertices.size(), " vertices, ", nav_mesh.get_polygon_count(), " polygons)")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Only update timer if both nodes exist
	if not (charizard and gnome):
		print("One or both nodes are missing!")
		return
		
	time_since_last_check += delta
	if time_since_last_check >= check_interval:
		time_since_last_check = 0.0
		print("Checking positions:")
		print("Charizard position: ", charizard.global_position)
		print("Gnome position: ", gnome.global_position)
		
		# Create 2D positions by ignoring Y (height)
		var char_pos = Vector2(charizard.global_position.x, charizard.global_position.z)
		var gnome_pos = Vector2(gnome.global_position.x, gnome.global_position.z)
		var distance = char_pos.distance_to(gnome_pos)
		
		print("Current distance: ", distance)
		
		if distance < detection_range:
			push_warning("Charizard and Gnome are close to each other! Distance: " + str(distance))
