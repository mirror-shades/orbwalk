class_name HairTriggerAbility
extends Ability
## Passive: an auto-attack crit grants a short burst of move speed that decays
## linearly. Refreshes on a new crit but not more often than the internal cooldown.

const EFFECT_ID := "gunslinger_hair_trigger"
## Long enough that the effect survives between fixed ticks, short enough that a
## missed refresh ends it.
const REFRESH_WINDOW := 0.1

var _cooldown_left: float = 0.0
var _time_left: float = 0.0


func _ready() -> void:
	caster.attack_crit.connect(_on_attack_crit)


func _on_attack_crit(_target: Node) -> void:
	var def := definition as HairTriggerDefinition
	if _cooldown_left > 0.0:
		return
	_cooldown_left = def.internal_cooldown
	_time_left = def.duration


func _tick(delta: float) -> void:
	var def := definition as HairTriggerDefinition
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _time_left <= 0.0:
		return

	var fx := caster.status_effects()
	if fx == null or caster.stats.is_dead:
		_time_left = 0.0
		return

	_time_left = maxf(_time_left - delta, 0.0)
	if _time_left <= 0.0:
		fx.remove_effect(EFFECT_ID)
		return

	var fraction := _time_left / maxf(def.duration, 0.01)
	fx.apply_move_speed(def.move_speed_bonus * fraction, REFRESH_WINDOW, EFFECT_ID)
