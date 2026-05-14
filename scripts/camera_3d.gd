extends Camera3D

@export var target_path: NodePath
@export var follow_speed: float = 5.0

var target: Node3D
var initial_offset: Vector3

func _ready() -> void:
	if target_path.is_empty():
		push_warning("No target path set!")
		return
		
	target = get_node(target_path)
	if not target:
		push_warning("Camera target not found at path: " + str(target_path))
		return
		
	# Store the initial offset between camera and target
	initial_offset = global_position - target.global_position

func _process(delta: float) -> void:
	if not target:
		return
		
	var target_pos = target.global_position
	
	# Calculate desired position using the initial offset
	var desired_pos = target_pos + initial_offset
	
	# Smoothly interpolate to the target position
	global_position = global_position.lerp(desired_pos, follow_speed * delta)
