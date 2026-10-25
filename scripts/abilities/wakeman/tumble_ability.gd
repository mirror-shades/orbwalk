class_name TumbleAbility
extends Ability

const GLOW_COLOR := Color(1.0, 0.82, 0.35)
const KILL_WINDOW := 3.0

var _charge_left: float = 0.0
var _kill_window: float = 0.0
var _glow: MeshInstance3D


func _ready() -> void:
	caster.attack_landed.connect(_on_attack_landed)
	caster.attack_killed.connect(_on_attack_killed)
	caster.stats.died.connect(_on_died)


func is_active() -> bool:
	return _charge_left > 0.0


func start_cooldown() -> void:
	pass


func _start_charge_cooldown() -> void:
	super.start_cooldown()


func _cast_problem() -> String:
	if _charge_left > 0.0:
		return "Your next shot is already charged."
	var fx := caster.status_effects()
	if fx == null:
		return "Can't dash."
	if fx.is_movement_locked():
		return "Already dashing."
	if fx.is_rooted():
		return "Rooted."
	return ""


func _cast(target_pos: Vector3) -> void:
	var def := definition as TumbleDefinition
	var from := caster.global_position
	var dir := target_pos - from
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = _facing()
	dir = dir.normalized()
	var dest := DashAbility.clip_to_navmesh(caster, from, from + dir * def.distance)
	caster.status_effects().start_forced_move(dest, def.dash_speed)
	caster.empower_next_attack(ranked(def.ad_bonus, def.ad_bonus_per_rank) * ad())
	caster.reset_attack_timer()
	_charge_left = def.charge_duration
	_set_glow(true)


func _tick(delta: float) -> void:
	if _kill_window > 0.0:
		_kill_window = maxf(_kill_window - delta, 0.0)
	if _charge_left <= 0.0:
		return
	_charge_left -= delta
	if _charge_left <= 0.0 or caster.stats.is_dead:
		_expire()


func _on_attack_landed(_target: Node) -> void:
	if _charge_left <= 0.0:
		return
	_charge_left = 0.0
	_kill_window = KILL_WINDOW
	_set_glow(false)
	_start_charge_cooldown()


func _on_attack_killed(target: Node, empowered: bool) -> void:
	if not empowered or _kill_window <= 0.0:
		return
	var st := EntityData.get_stats_of(target)
	if st == null:
		return
	var kind := st.get_entity_type()
	if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB:
		return
	var bounty := BountyAbility.of(caster)
	if bounty:
		bounty.add_stacks(bounty.tumble_kill_stacks())
	_kill_window = 0.0


func _expire() -> void:
	_charge_left = 0.0
	caster.clear_empowered_attack()
	_set_glow(false)
	_start_charge_cooldown()


func _on_died() -> void:
	if _charge_left <= 0.0:
		return
	_charge_left = 0.0
	caster.clear_empowered_attack()
	_set_glow(false)
	_start_charge_cooldown()


func _facing() -> Vector3:
	var models := caster.get_node_or_null("Models") as Node3D
	if models:
		var f := -models.global_basis.z
		f.y = 0.0
		if f.length_squared() > 0.0001:
			return f
	return Vector3.RIGHT


func _set_glow(on: bool) -> void:
	if _glow == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.9
		torus.outer_radius = 1.1
		torus.rings = 48
		torus.ring_segments = 6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = GLOW_COLOR
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow = MeshInstance3D.new()
		_glow.mesh = torus
		_glow.material_override = mat
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.scale = Vector3(1.0, 0.15, 1.0)
		_glow.position.y = 0.08
		caster.add_child(_glow)
	_glow.visible = on
