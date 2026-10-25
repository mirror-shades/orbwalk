class_name PotionMixAbility
extends Ability
## W (glue) and E (poison): load an ingredient into the next Q. Only one can be
## loaded at a time; while one is loaded, the other key is locked. R never uses
## them. A colored orb over his head shows enemies which one is loaded.

var _loaded_left: float = 0.0
## A small orb over his head in the mix's color while the next Q is mixed.
var _label: MeshInstance3D


## The ingredient loaded on `entity` right now, or null.
static func loaded_on(entity: Node) -> PotionMixAbility:
	var c := entity.get_node_or_null("Abilities") as AbilityCaster
	if c == null:
		return null
	for a in c.abilities:
		var mix := a as PotionMixAbility
		if mix and mix.is_loaded():
			return mix
	return null


func is_loaded() -> bool:
	return _loaded_left > 0.0


func is_active() -> bool:
	return is_loaded()


func _cast_problem() -> String:
	var other := PotionMixAbility.loaded_on(caster)
	if other and other != self:
		return "%s is already loaded." % other.display_name()
	return ""


func _cast(_target_pos: Vector3) -> void:
	_loaded_left = (definition as PotionMixDefinition).window
	_show_label(true)


## Uses up the ingredient and returns what it does to the potion, with damage worked
## out now (his rank and AP at the time of the throw).
func consume() -> Dictionary:
	var def := definition as PotionMixDefinition
	_loaded_left = 0.0
	_show_label(false)
	return {
		"kind": def.kind,
		"color": def.color,
		"radius": def.radius,
		"flight_time": def.flight_time,
		"bonus_damage": ranked(def.bonus_damage, def.bonus_damage_per_rank) + def.bonus_ap_ratio * ap(),
		"slow": def.slow,
		"slow_duration": def.slow_duration,
		"poison_damage": ranked(def.poison_damage, def.poison_damage_per_rank) + def.poison_ap_ratio * ap() if def.poison_damage > 0.0 else 0.0,
		"poison_duration": def.poison_duration,
	}


func _tick(delta: float) -> void:
	if _loaded_left <= 0.0:
		return
	_loaded_left -= delta
	if _loaded_left <= 0.0 or caster.stats.is_dead:
		_loaded_left = 0.0
		_show_label(false)


func _show_label(on: bool) -> void:
	if _label == null or not is_instance_valid(_label):
		var def := definition as PotionMixDefinition
		var orb := SphereMesh.new()
		orb.radius = 0.2
		orb.height = 0.4
		var mat := StandardMaterial3D.new()
		mat.albedo_color = def.color
		mat.emission_enabled = true
		mat.emission = def.color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		_label = MeshInstance3D.new()
		_label.mesh = orb
		_label.material_override = mat
		_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hb := caster.get_node_or_null("HealthBar") as Node3D
		_label.position = Vector3(0.0, (hb.position.y if hb else 2.5) + 0.6, 0.0)
		caster.add_child(_label)
	_label.visible = on


func _exit_tree() -> void:
	if _label and is_instance_valid(_label):
		_label.queue_free()
