extends Node3D

@export var max_health: float = 1000.0:
	set(v):
		max_health = v
		if _shader_material:
			_shader_material.set_shader_parameter("segment_count", _get_segment_count())
		_update_display()

@export var current_health: float = 1000.0:
	set(v):
		current_health = clampf(v, 0.0, max_health)
		_update_display()

@export var bar_width: float = 2.0
@export var bar_height: float = 0.2
@export var show_segments: bool = true:
	set(v):
		show_segments = v
		if _shader_material:
			_shader_material.set_shader_parameter("segment_count", _get_segment_count())
		_update_display()

var _bar_mesh: MeshInstance3D
var _shader_material: ShaderMaterial

func _ready() -> void:
	_create_bar()

func _create_bar() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(bar_width, bar_height)

	var shader := Shader.new()
	shader.code = _shader_code()

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("fill_percent", current_health / max_health if max_health > 0.0 else 0.0)
	_shader_material.set_shader_parameter("segment_count", _get_segment_count())

	_bar_mesh = MeshInstance3D.new()
	_bar_mesh.name = "BarQuad"
	_bar_mesh.mesh = quad
	_bar_mesh.material_override = _shader_material
	add_child(_bar_mesh)

func _shader_code() -> String:
	return """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform vec4 fill_color : source_color = vec4(0.0, 0.7, 0.0, 1.0);
uniform vec4 empty_color : source_color = vec4(0.06, 0.06, 0.06, 0.9);
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float fill_percent : hint_range(0.0, 1.0) = 1.0;
uniform int segment_count : hint_range(1, 20) = 10;
uniform float border_thickness : hint_range(0.0, 0.1) = 0.015;

void fragment() {
	vec2 uv = UV;

	bool is_border = uv.x < border_thickness || uv.x > 1.0 - border_thickness ||
		uv.y < border_thickness || uv.y > 1.0 - border_thickness;

	float bar_x = (uv.x - border_thickness) / (1.0 - 2.0 * border_thickness);
	float seg_pos = bar_x * float(segment_count);
	float seg_dist = abs(fract(seg_pos) - 0.5);
	float line_half = 0.04;
	bool is_line = seg_dist > 0.5 - line_half && bar_x > 0.001 && bar_x < 0.999;

	if (is_border) {
		ALBEDO = border_color.rgb;
		ALPHA = border_color.a;
	} else if (is_line) {
		ALBEDO = line_color.rgb;
		ALPHA = line_color.a;
	} else if (bar_x <= fill_percent) {
		ALBEDO = fill_color.rgb;
		ALPHA = fill_color.a;
	} else {
		ALBEDO = empty_color.rgb;
		ALPHA = empty_color.a;
	}
}"""

func _update_display() -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("fill_percent", current_health / max_health if max_health > 0.0 else 0.0)

func _get_segment_count() -> int:
	if not show_segments:
		return 1
	return maxi(int(max_health / 100.0), 1)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		var cam_basis := camera.global_basis
		global_basis = Basis(cam_basis.x, cam_basis.y, -cam_basis.z)
