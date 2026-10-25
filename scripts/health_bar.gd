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

## Shield on top of health, drawn as a white segment after the green.
@export var shield_amount: float = 0.0:
	set(v):
		shield_amount = maxf(v, 0.0)
		_update_display()

@export var bar_width: float = 2.0
@export var bar_height: float = 0.2
@export var show_segments: bool = true:
	set(v):
		show_segments = v
		if _shader_material:
			_shader_material.set_shader_parameter("segment_count", _get_segment_count())
		_update_display()

@export var fill_color: Color = Color(0.0, 0.7, 0.0, 1.0):
	set(v):
		fill_color = v
		if _shader_material:
			_shader_material.set_shader_parameter("fill_color", fill_color)

static var _shared_shader: Shader

var _bar_mesh: MeshInstance3D
var _shader_material: ShaderMaterial

func _ready() -> void:
	_create_bar()

func _create_bar() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(bar_width, bar_height)

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = _get_shader()
	_shader_material.set_shader_parameter("fill_percent", current_health / max_health if max_health > 0.0 else 0.0)
	_shader_material.set_shader_parameter("segment_count", _get_segment_count())
	_shader_material.set_shader_parameter("fill_color", fill_color)
	_shader_material.set_shader_parameter("bar_size", Vector2(bar_width, bar_height))

	_bar_mesh = MeshInstance3D.new()
	_bar_mesh.name = "BarQuad"
	_bar_mesh.mesh = quad
	_bar_mesh.material_override = _shader_material
	add_child(_bar_mesh)

## Every bar uses its own material (for its own parameters) but they can all share
## one compiled shader.
func _get_shader() -> Shader:
	if _shared_shader == null:
		_shared_shader = Shader.new()
		_shared_shader.code = _shader_code()
	return _shared_shader

func _shader_code() -> String:
	return """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform vec4 fill_color : source_color = vec4(0.0, 0.7, 0.0, 1.0);
uniform vec4 empty_color : source_color = vec4(0.04, 0.04, 0.05, 0.92);
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float fill_percent : hint_range(0.0, 1.0) = 1.0;
uniform float shield_percent : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shield_color : source_color = vec4(0.92, 0.95, 1.0, 1.0);
uniform int segment_count : hint_range(1, 40) = 10;
// Size of the quad in world units, so border and segment lines keep the same
// thickness however wide or tall the bar is.
uniform vec2 bar_size = vec2(2.0, 0.2);
uniform float border_world = 0.035;
uniform float line_world = 0.02;

void fragment() {
	vec2 uv = UV;
	vec2 b = vec2(border_world) / bar_size;

	bool is_border = uv.x < b.x || uv.x > 1.0 - b.x || uv.y < b.y || uv.y > 1.0 - b.y;

	vec2 inner = (uv - b) / (1.0 - 2.0 * b);
	float seg_pos = inner.x * float(segment_count);
	// Distance (world units) to the nearest segment divider.
	float seg_w = bar_size.x * (1.0 - 2.0 * b.x) / float(segment_count);
	float to_edge = abs(fract(seg_pos) - 0.5);
	float dist_to_divider = (0.5 - to_edge) * seg_w;
	bool is_line = dist_to_divider < line_world * 0.5 && inner.x > 0.001 && inner.x < 0.999 && segment_count > 1;

	// Light along the top, darker toward the bottom, so the bar reads as a tube.
	float shade = mix(1.25, 0.72, clamp(inner.y, 0.0, 1.0));

	if (is_border) {
		ALBEDO = border_color.rgb;
		ALPHA = border_color.a;
	} else if (is_line) {
		ALBEDO = line_color.rgb;
		ALPHA = line_color.a;
	} else if (inner.x <= fill_percent) {
		ALBEDO = fill_color.rgb * shade;
		ALPHA = fill_color.a;
	} else if (inner.x <= fill_percent + shield_percent) {
		ALBEDO = shield_color.rgb * shade;
		ALPHA = shield_color.a;
	} else {
		ALBEDO = empty_color.rgb * mix(1.5, 0.8, clamp(inner.y, 0.0, 1.0));
		ALPHA = empty_color.a;
	}
}"""

func _update_display() -> void:
	if _shader_material:
		var fill := current_health / max_health if max_health > 0.0 else 0.0
		_shader_material.set_shader_parameter("fill_percent", fill)
		var sh := shield_amount / max_health if max_health > 0.0 else 0.0
		_shader_material.set_shader_parameter("shield_percent", clampf(sh, 0.0, 1.0 - fill))

func _get_segment_count() -> int:
	if not show_segments:
		return 1
	return maxi(int(max_health / 100.0), 1)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		var cam_basis := camera.global_basis
		global_basis = Basis(cam_basis.x, cam_basis.y, -cam_basis.z)
