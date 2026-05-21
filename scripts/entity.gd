extends CharacterBody3D

const ENTITY_LAYER: int = 2

@export var definition: EntityDefinition
@export var rotation_speed: float = 10.0

var stats: StatsComponent = null

var _attack_target: CharacterBody3D = null
var _attack_cooldown_timer: float = 0.0
var _attack_anim_time: float = 0.0
var _damage_proc_timer: float = 0.0
var _damage_dealt_this_swing: bool = false

func _ready() -> void:
	_setup_stats()
	collision_layer = ENTITY_LAYER
	add_to_group("entity")
	_on_entity_ready()

func _on_entity_ready() -> void:
	pass

func _setup_stats() -> void:
	stats = $Stats if has_node("Stats") else StatsComponent.new()
	if not stats.is_inside_tree():
		stats.name = "Stats"
		add_child(stats)
	stats.initialize(definition)
	stats.health_changed.connect(_on_health_changed)
	stats.died.connect(_on_died)
	var hb := get_node_or_null("HealthBar")
	if hb:
		hb.max_health = stats.get_max_health()
		hb.current_health = stats.current_health

func get_nav() -> NavigationAgent3D:
	return get_node_or_null("NavigationAgent3D")

func _horizontal_direction_to(target_pos: Vector3) -> Vector3:
	var dir := target_pos - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return dir.normalized()

func face_position(target_pos: Vector3, pivot: Node3D, delta: float) -> void:
	var dir := _horizontal_direction_to(target_pos)
	if dir != Vector3.ZERO:
		pivot.rotation.y = lerp_angle(
			pivot.rotation.y,
			atan2(-dir.x, -dir.z),
			minf(rotation_speed * delta, 1.0)
		)

# ---- Attack system ----

func set_attack_target(target: CharacterBody3D) -> void:
	_attack_target = target

func is_attack_target_valid() -> bool:
	if not _attack_target or not is_instance_valid(_attack_target):
		return false
	var ts: StatsComponent = _attack_target.get_node_or_null("Stats")
	return ts != null and not ts.is_dead

func clear_attack_target() -> void:
	if not _damage_dealt_this_swing:
		_attack_cooldown_timer = 0.0
	_attack_target = null
	_attack_anim_time = 0.0
	_damage_proc_timer = 0.0
	_damage_dealt_this_swing = false

func can_attack() -> bool:
	return _attack_cooldown_timer <= 0.0

func start_attack_cooldown() -> void:
	_attack_cooldown_timer = 1.0 / stats.get_attack_speed()

func begin_attack_anim(anim_length: float, swing_ratio: float = 0.5) -> void:
	_attack_anim_time = anim_length
	_damage_proc_timer = anim_length * swing_ratio
	_damage_dealt_this_swing = false

func process_attack(delta: float) -> bool:
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	if _attack_anim_time <= 0.0:
		return false
	_attack_anim_time = maxf(_attack_anim_time - delta, 0.0)
	_damage_proc_timer = maxf(_damage_proc_timer - delta, 0.0)
	if _damage_proc_timer <= 0.0 and not _damage_dealt_this_swing:
		_damage_dealt_this_swing = true
		return true
	return false

func deal_attack_damage() -> void:
	var target_stats: StatsComponent = null
	if _attack_target:
		target_stats = _attack_target.get_node_or_null("Stats")
	if target_stats:
		target_stats.take_physical_damage(stats.get_attack_damage(), self)

func is_attack_anim_active() -> bool:
	return _attack_anim_time > 0.0

# ---- Callbacks ----

func _input(event: InputEvent) -> void:
	_on_input(event)

func _on_input(_event: InputEvent) -> void:
	pass

func _on_health_changed(current: float, _max_hp: float) -> void:
	var hb := get_node_or_null("HealthBar")
	if hb:
		hb.current_health = current

func _on_died() -> void:
	clear_attack_target()
	var cs := get_node_or_null("CollisionShape3D")
	if cs:
		cs.set_deferred("disabled", true)
	var nav := get_node_or_null("NavigationAgent3D")
	if nav:
		nav.set_deferred("avoidance_enabled", false)
	_on_entity_died()

func _on_entity_died() -> void:
	pass
