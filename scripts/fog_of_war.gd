class_name FogOfWar
extends Node3D
## Fog of war. Each team sees what's within the sight range (Stat.SIGHT_RANGE) of
## its living units. Enemy units outside that are hidden from the viewer and can't
## be targeted (see can_see()). Towers and the orb are always visible. Neutral
## units (jungle monsters) don't see, but are hidden like enemies.
##
## The fog is drawn by a full-screen overlay that darkens every pixel whose world
## position isn't visible to `viewer_team`, using a small visibility texture.

const UPDATE_INTERVAL := 0.1
## Texture cells per meter.
const RESOLUTION := 1.0
## Soft edge of each vision circle, in meters.
const EDGE := 1.5

static var _active: FogOfWar = null

## Whose view is drawn and which units get hidden.
var viewer_team: int = EntityDefinition.Team.TEAM_1
## World area covered by the fog (x, z).
var area: Rect2
var shown: bool = true

var _timer: float = 0.0
## team -> {instance_id: true} of units that team can see this update.
var _seen: Dictionary = {}
## team -> Array of [Vector2 position, radius].
var _sources: Dictionary = {}
var _image: Image
var _texture: ImageTexture
var _cells: PackedByteArray
var _width: int = 0
var _height: int = 0


## True if `team` can see `node`. Stealth always hides the unit from enemies,
## even when fog is off. Without a fog node everything else is visible.
static func can_see(team: int, node: Node) -> bool:
	if node == null:
		return true
	if _hidden_by_stealth(team, node):
		return false
	if _active == null or not is_instance_valid(_active):
		return true
	return _active.is_visible_to(team, node)


static func _hidden_by_stealth(team: int, node: Node) -> bool:
	var st := EntityData.get_stats_of(node)
	if st == null or st.get_team() == team:
		return false
	var fx := node.get_node_or_null("StatusEffects") as StatusEffects
	return fx != null and fx.is_stealthed()


## `p_shown` = draw the fog and hide unseen units. Without it, vision rules
## (can_see) still apply but the screen shows everything.
func setup(p_area: Rect2, p_viewer_team: int, p_shown: bool) -> void:
	area = p_area
	viewer_team = p_viewer_team
	shown = p_shown


func _ready() -> void:
	_active = self
	# Update vision after units have moved this tick (higher = later).
	process_physics_priority = 100
	_width = maxi(ceili(area.size.x * RESOLUTION), 1)
	_height = maxi(ceili(area.size.y * RESOLUTION), 1)
	_cells.resize(_width * _height)
	_image = Image.create_from_data(_width, _height, false, Image.FORMAT_L8, _cells)
	_texture = ImageTexture.create_from_image(_image)
	if shown:
		_build_overlay()
	_refresh()


func _exit_tree() -> void:
	if _active == self:
		_active = null


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = UPDATE_INTERVAL
	_refresh()


func is_visible_to(team: int, node: Node) -> bool:
	var st := EntityData.get_stats_of(node)
	if st == null or st.get_team() == team:
		return true
	if _hidden_by_stealth(team, node):
		return false
	# Most lookups are for units this team sees.
	if (_seen.get(team, {}) as Dictionary).has(node.get_instance_id()):
		return true
	if team == EntityDefinition.Team.NEUTRAL:
		return true
	var kind := st.get_entity_type()
	if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB:
		return true
	return false


func _refresh() -> void:
	var units: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("entity"):
		if node is Node3D and EntityData.get_stats_of(node):
			units.append(node)
	# Vision sources per team.
	_sources.clear()
	for u in units:
		var st := EntityData.get_stats_of(u)
		var team := st.get_team()
		if st.is_dead or team == EntityDefinition.Team.NEUTRAL:
			continue
		if not _sources.has(team):
			_sources[team] = []
		_sources[team].append([Vector2(u.global_position.x, u.global_position.z), st.get_stat(StatsComponent.Stat.SIGHT_RANGE)])
	# Which units each team sees.
	_seen.clear()
	for team in _sources:
		var seen := {}
		for u in units:
			if _hidden_by_stealth(team, u):
				continue
			var p := Vector2(u.global_position.x, u.global_position.z)
			# Stealthed units (meta "stealth") are only seen up close.
			var stealth := float(u.get_meta("stealth", INF))
			for src in _sources[team]:
				var r := minf(float(src[1]), stealth)
				if p.distance_squared_to(src[0]) <= r * r:
					seen[u.get_instance_id()] = true
					break
		_seen[team] = seen
	if not shown:
		return
	# Hide what the viewer can't see.
	for u in units:
		u.visible = is_visible_to(viewer_team, u)
	_draw_texture()


## Stamps each of the viewer's vision circles into the texture, with a soft edge.
func _draw_texture() -> void:
	_cells.fill(0)
	for src in _sources.get(viewer_team, []):
		var center: Vector2 = (src[0] - area.position) * RESOLUTION
		var r: float = float(src[1]) * RESOLUTION
		var edge := EDGE * RESOLUTION
		var x0 := maxi(floori(center.x - r), 0)
		var x1 := mini(ceili(center.x + r), _width - 1)
		var y0 := maxi(floori(center.y - r), 0)
		var y1 := mini(ceili(center.y + r), _height - 1)
		for y in range(y0, y1 + 1):
			var row := y * _width
			var dy := float(y) + 0.5 - center.y
			for x in range(x0, x1 + 1):
				var dx := float(x) + 0.5 - center.x
				var d := sqrt(dx * dx + dy * dy)
				if d >= r:
					continue
				var v := int(clampf((r - d) / edge, 0.0, 1.0) * 255.0)
				if v > _cells[row + x]:
					_cells[row + x] = v
	_image.set_data(_width, _height, false, Image.FORMAT_L8, _cells)
	_texture.update(_image)


func _build_overlay() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 map_origin;
uniform vec2 map_size;
uniform vec4 fog_color : source_color = vec4(0.02, 0.03, 0.07, 1.0);
uniform float fog_strength = 0.68;

void vertex() {
	// Cover the whole screen.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// World position of what's drawn at this pixel, from the depth buffer.
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec2 uv = (world.xz - map_origin) / map_size;
	float vis = 0.0;
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		vis = texture(fog_tex, uv).r;
	}
	ALBEDO = fog_color.rgb;
	ALPHA = (1.0 - vis) * fog_strength;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	# Draw after every other transparent thing (tree leaves, effects) so they get fogged too.
	mat.render_priority = Material.RENDER_PRIORITY_MAX
	mat.set_shader_parameter("fog_tex", _texture)
	mat.set_shader_parameter("map_origin", area.position)
	mat.set_shader_parameter("map_size", area.size)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mi := MeshInstance3D.new()
	mi.name = "FogOverlay"
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Never culled: the shader places it on screen itself.
	mi.custom_aabb = AABB(Vector3(-100000.0, -100000.0, -100000.0), Vector3(200000.0, 200000.0, 200000.0))
	add_child(mi)
