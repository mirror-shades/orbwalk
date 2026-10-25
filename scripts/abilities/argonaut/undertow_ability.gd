class_name UndertowAbility
extends Ability
## W: his next auto-attack within the window starts right away, deals bonus damage,
## and drags the target under: a slow that starts light and grows heavier over its
## duration, so running gets harder the longer it lasts (and R lands at its peak).
## Works on champions, mercenaries and monsters.

const SLOW_ID := "wf_undertow"
const COLOR := Color(0.25, 0.55, 0.85)

var _time_left: float = 0.0
## Targets being slowed: {target: Node3D, age: float}
var _ramps: Array[Dictionary] = []
var _glow: MeshInstance3D


func _ready() -> void:
	caster.attack_landed.connect(_on_attack)


func is_active() -> bool:
	return _time_left > 0.0


func _cast(_target_pos: Vector3) -> void:
	_time_left = (definition as UndertowDefinition).window
	caster.reset_attack_timer()
	_set_glow(true)


func _on_attack(target: Node) -> void:
	if _time_left <= 0.0 or not (target is Node3D):
		return
	var st := target.get_node_or_null("Stats") as StatsComponent
	if st == null or st.is_dead:
		return
	var kind := st.get_entity_type()
	if kind == EntityDefinition.EntityType.TOWER or kind == EntityDefinition.EntityType.ORB:
		return
	_time_left = 0.0
	_set_glow(false)
	var def := definition as UndertowDefinition
	st.take_physical_damage(ranked(def.bonus_damage, def.bonus_damage_per_rank) + def.ad_ratio * ad(), caster)
	if st.is_dead:
		return
	for r in _ramps:
		if r["target"] == target:
			r["age"] = 0.0
			return
	_ramps.append({"target": target, "age": 0.0})
	AbilityUtil.ring_flash(get_tree().current_scene, (target as Node3D).global_position, 1.2, Color(COLOR, 0.8))


## How strong the slow is `age` seconds after the hit.
func slow_at(age: float) -> float:
	var def := definition as UndertowDefinition
	var k := clampf(age / maxf(def.slow_duration, 0.01), 0.0, 1.0)
	return lerpf(def.slow_start, ranked(def.slow_max, def.slow_max_per_rank), k)


func _tick(delta: float) -> void:
	if _time_left > 0.0:
		_time_left -= delta
		if _time_left <= 0.0 or caster.stats.is_dead:
			_time_left = 0.0
			_set_glow(false)
	if _ramps.is_empty():
		return
	var def := definition as UndertowDefinition
	for i in range(_ramps.size() - 1, -1, -1):
		var r := _ramps[i]
		var t = r["target"]
		r["age"] = float(r["age"]) + delta
		if not is_instance_valid(t) or float(r["age"]) >= def.slow_duration:
			_ramps.remove_at(i)
			continue
		var fx := (t as Node).get_node_or_null("StatusEffects") as StatusEffects
		if fx:
			# Re-applied every frame with the current strength; same id, so it replaces itself.
			fx.apply_slow(slow_at(float(r["age"])), minf(0.2, def.slow_duration - float(r["age"])), SLOW_ID)


## A blue ring under him while the charged auto is waiting.
func _set_glow(on: bool) -> void:
	if _glow == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.95
		torus.outer_radius = 1.15
		torus.rings = 48
		torus.ring_segments = 6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLOR
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow = MeshInstance3D.new()
		_glow.mesh = torus
		_glow.material_override = mat
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.scale = Vector3(1.0, 0.15, 1.0)
		_glow.position.y = 0.08
		caster.add_child(_glow)
	_glow.visible = on
