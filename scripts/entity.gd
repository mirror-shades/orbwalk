class_name Entity
extends CharacterBody3D

const ENTITY_LAYER: int = 2
const PROJECTILE_LAYER: int = 3
const AREA_EFFECT_LAYER: int = 4
## Meters a unit can drift from its path before the agent plans a new one.
const REPATH_OFF_PATH := 1.0

@export var definition: EntityDefinition
@export var rotation_speed: float = 10.0

## Stable id for this unit (see EntityData.register_unit). Commands and anything
## that names a unit across machines use this, not the node or its instance id.
var unit_id: int = 0
var stats: StatsComponent = null
var _status: StatusEffects = null

var _attack_target: CharacterBody3D = null
var _attack_cooldown_timer: float = 0.0
var _attack_anim_time: float = 0.0
var _damage_proc_timer: float = 0.0
var _damage_dealt_this_swing: bool = false
## Bonus damage added to the next auto-attack that lands (set by abilities like W).
var _empower_bonus: float = 0.0
## While true, the next auto-attack that lands is a guaranteed crit (Hollow Point).
var _guaranteed_crit: bool = false
## True only while attack_landed is emitted for an ability's hit (not a real auto), so
## effects that belong to the next auto (Hollow Point) can skip it.
var landing_from_ability: bool = false
## True while a volley is being fired (Fan the Hammer): no auto-attacks or other casts,
## and the model keeps facing the way it was aimed, but moving is allowed.
var firing_lock: bool = false

## Emitted when an empowered auto-attack lands.
signal empowered_hit(target: Node, bonus_damage: float)
## Emitted when an auto-attack crits. `target` is the unit the swing was aimed at.
signal attack_crit(target: Node)
## Emitted when an auto-attack hits (melee) or is fired (ranged; damage lands on arrival).
signal attack_landed(target: Node)
## Emitted when an auto-attack lands the killing blow. `empowered` is true when
## that swing carried a bonus from empower_next_attack().
signal attack_killed(target: Node, empowered: bool)
## Emitted when this entity gets kill or assist credit (it damaged `victim` shortly before it died).
signal takedown(victim: Node)

func _enter_tree() -> void:
	unit_id = EntityData.register_unit(self, unit_id)


func _exit_tree() -> void:
	EntityData.unregister_unit(unit_id)


func _ready() -> void:
	_setup_stats()
	_status = get_node_or_null("StatusEffects") as StatusEffects
	if _status == null:
		_status = StatusEffects.new()
		_status.name = "StatusEffects"
		add_child(_status)
	collision_layer = ENTITY_LAYER
	add_to_group("entity")
	var nav := get_node_or_null(^"NavigationAgent3D") as NavigationAgent3D
	if nav:
		nav.path_max_distance = REPATH_OFF_PATH
	_on_entity_ready()

func _on_entity_ready() -> void:
	pass

func _setup_stats() -> void:
	stats = $Stats if has_node("Stats") else StatsComponent.new()
	if not stats.is_inside_tree():
		stats.name = "Stats"
		add_child(stats)
	stats.health_changed.connect(_on_health_changed)
	stats.died.connect(_on_died)
	stats.shield_changed.connect(_on_shield_changed)
	stats.initialize(definition)

func status_effects() -> StatusEffects:
	return _status

## Called by the victim's StatsComponent when this entity gets takedown credit.
func on_takedown(victim: Node) -> void:
	takedown.emit(victim)

## Call at the top of _physics_process. Returns true when fear or a dash is in
## control this frame, so the normal movement and attack logic should be skipped.
func process_crowd_control(delta: float) -> bool:
	if _status == null:
		return false
	if _status.is_movement_locked():
		velocity = Vector3.ZERO
		return true
	if _status.is_stunned():
		velocity = Vector3.ZERO
		_on_stunned(delta)
		return true
	if _status.is_feared():
		if _attack_target:
			clear_attack_target()
		var dir := _status.fear_direction()
		velocity = dir * stats.get_movement_speed()
		move_and_slide()
		_on_feared(dir, delta)
		return true
	return false

## Called every frame while feared, after the entity has moved. Override for visuals.
func _on_feared(_dir: Vector3, _delta: float) -> void:
	pass

## Called every frame while stunned. Override for visuals.
func _on_stunned(_delta: float) -> void:
	pass

## Called every frame during a dash or pull. Override for visuals.
func _on_forced_move(_dir: Vector3, _delta: float) -> void:
	pass

## Called when a dash or pull starts.
func _on_forced_move_started() -> void:
	pass

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

func navigate_toward(target: Vector3, speed: float, stop_dist: float = 0.5) -> Vector3:
	var n := get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if n:
		var map_rid := n.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(map_rid) > 0:
			target = NavigationServer3D.map_get_closest_point(map_rid, target)
		# Setting target_position always asks for a new path, even for the same
		# target, so only set it when the target moves. Being pushed off the path
		# (knockback, dash, pull, fear) repaths via REPATH_OFF_PATH.
		if n.target_position != target:
			n.target_position = target
		if n.is_navigation_finished():
			return Vector3.ZERO
		var nav_path := n.get_current_navigation_path()
		if nav_path.size() < 2:
			return Vector3.ZERO
		var next := n.get_next_path_position()
		var dir := next - global_position
		dir.y = 0.0
		if dir.length_squared() > 0.0001:
			return dir.normalized() * speed
		return Vector3.ZERO
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() <= stop_dist:
		return Vector3.ZERO
	return dir.normalized() * speed

# ---- Attack system ----

func set_attack_target(target: CharacterBody3D) -> void:
	_attack_target = target


## The unit this entity is currently chasing and attacking, or null.
func get_attack_target() -> CharacterBody3D:
	return _attack_target


## Ends any stealth effect early (an attack or ability breaks a cloak).
func break_stealth() -> void:
	var fx := status_effects()
	if fx:
		fx.remove_stealth()


func is_attack_target_valid() -> bool:
	if not _attack_target or not is_instance_valid(_attack_target):
		return false
	var ts := EntityData.get_stats_of(_attack_target)
	# A target that walks into the fog is dropped.
	return ts != null and not ts.is_dead and FogOfWar.can_see(stats.get_team(), _attack_target)

func clear_attack_target() -> void:
	if not _damage_dealt_this_swing:
		_attack_cooldown_timer = 0.0
	_attack_target = null
	_attack_anim_time = 0.0
	_damage_proc_timer = 0.0
	_damage_dealt_this_swing = false

func can_attack() -> bool:
	return _attack_cooldown_timer <= 0.0 and not firing_lock

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
	var target_stats := EntityData.get_stats_of(_attack_target)
	if target_stats:
		# Blind (attacker) or dodge (defender): the swing is dodged - no damage,
		# no on-hit riders, and one-shot empower windows are not spent. Structures
		# bypass the miss check.
		var kind := target_stats.get_entity_type()
		var structure := kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB
		if attack_misses_target(_attack_target) and not structure:
			AbilityUtil.pop_text(get_parent(), _attack_target.global_position + Vector3(0.0, 2.4, 0.0), "Miss", Color(0.85, 0.85, 0.85), 30)
			return
		var bonus := _empower_bonus
		_empower_bonus = 0.0
		# Crits multiply the attack's base damage, not on-hit bonuses (like League).
		# A guaranteed crit (Hollow Point) is spent only when the swing lands.
		var crit := stats.get_crit_damage() if _guaranteed_crit else stats.roll_crit()
		if _guaranteed_crit:
			_guaranteed_crit = false
		var dmg := stats.get_attack_damage() * crit + bonus
		dmg = _scaled_auto_damage(dmg, target_stats)
		if crit > 1.0:
			AbilityUtil.pop_text(get_parent(), _attack_target.global_position + Vector3(0.0, 2.4, 0.0), "%d!" % roundi(dmg), Color(1.0, 0.35, 0.2), 48)
			attack_crit.emit(_attack_target)
		if definition and definition.attack_projectile_speed > 0.0:
			# Ranged: the damage lands when the projectile arrives.
			var shot := HomingShot.fire(self, _attack_target, dmg, definition.attack_projectile_speed, definition.attack_projectile_color)
			shot.landed.connect(_on_ranged_attack_landed.bind(bonus > 0.0))
		else:
			target_stats.take_physical_damage(dmg, self, true)
			if target_stats.is_dead:
				attack_killed.emit(_attack_target, bonus > 0.0)
		attack_landed.emit(_attack_target)
		if bonus > 0.0:
			empowered_hit.emit(_attack_target, bonus)


## An ability hit that counts as an attack hitting `target`: on-hit item effects run.
## It doesn't count as a crit proc and attack-reset or "next auto" effects ignore it.
func emit_ability_hit(target: Node) -> void:
	landing_from_ability = true
	attack_landed.emit(target)
	landing_from_ability = false


func _on_ranged_attack_landed(target: Node3D, empowered: bool) -> void:
	var target_stats := EntityData.get_stats_of(target)
	if target_stats and target_stats.is_dead:
		attack_killed.emit(target, empowered)


## True when this entity's auto-attack is dodged by its own blind.
func auto_attack_is_missed() -> bool:
	var fx := status_effects()
	return fx != null and fx.is_blinded()


## True when an auto-attack from this entity misses `target`: the attacker is
## blinded, or the defender is dodging (Smoke Bomb). Structures bypass this check
## at the call sites, so tower and orb shots always land.
func attack_misses_target(target: Node) -> bool:
	if auto_attack_is_missed():
		return true
	if target == null or not is_instance_valid(target):
		return false
	var fx := target.get_node_or_null("StatusEffects") as StatusEffects
	return fx != null and fx.is_dodging()


## Lets the champion's passive scale the damage of an auto-attack (Cat's Paw's Low Cut).
func _scaled_auto_damage(dmg: float, target_stats: StatsComponent) -> float:
	var c := get_node_or_null("Abilities") as AbilityCaster
	if c and c.passive and c.passive.has_method("scale_auto_damage"):
		return c.passive.scale_auto_damage(dmg, target_stats)
	return dmg

## The next auto-attack that lands deals `bonus` extra physical damage.
func empower_next_attack(bonus: float) -> void:
	_empower_bonus = bonus

func has_empowered_attack() -> bool:
	return _empower_bonus > 0.0

func clear_empowered_attack() -> void:
	_empower_bonus = 0.0

## The next auto-attack that lands is a guaranteed crit. Stays armed through a
## miss (Blind / Dodge), since the swing never lands.
func guarantee_next_crit() -> void:
	_guaranteed_crit = true

func has_guaranteed_crit() -> bool:
	return _guaranteed_crit

func clear_guaranteed_crit() -> void:
	_guaranteed_crit = false

## Lets the next auto-attack start right away (an "attack reset").
func reset_attack_timer() -> void:
	_attack_cooldown_timer = 0.0

func is_attack_anim_active() -> bool:
	return _attack_anim_time > 0.0

# ---- Callbacks ----

func _on_health_changed(current: float, max_hp: float) -> void:
	var hb := get_node_or_null("HealthBar")
	if hb:
		hb.max_health = max_hp
		hb.current_health = current

func _on_shield_changed(total: float) -> void:
	var hb := get_node_or_null("HealthBar")
	if hb:
		hb.set("shield_amount", total)

func _on_died() -> void:
	clear_attack_target()
	clear_empowered_attack()
	clear_guaranteed_crit()
	var cs := get_node_or_null("CollisionShape3D")
	if cs:
		cs.set_deferred("disabled", true)
	var n := get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if n:
		n.set_deferred("avoidance_enabled", false)
	_on_entity_died()

func _on_entity_died() -> void:
	pass
