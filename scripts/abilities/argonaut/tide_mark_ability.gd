class_name TideMarkAbility
extends Ability
## Passive: his auto-attacks, Q hits and E hits add Tide stacks to enemy champions.
## At 3 stacks the target is Marked. The mark is used up by the next hit from an
## allied champion, or by his own E (his autos and Q never use it up). Using it up
## deals bonus magic damage to the target and sends out a healing bubble that
## bounces between up to two allied champions near the target (him included).
## After a mark is used up or runs out, that target can't be stacked for a while.

const COLOR := Color(0.35, 0.8, 1.0)

## Instance id of the target -> {target, stacks, stack_left, marked_left, cd_left, label, listener}
var _marks: Dictionary = {}


## The Tide Mark passive on `entity`, or null if it doesn't have one.
static func of(entity: Node) -> TideMarkAbility:
	var c := entity.get_node_or_null("Abilities") as AbilityCaster
	return c.passive as TideMarkAbility if c else null


func _ready() -> void:
	caster.attack_landed.connect(_on_attack_landed)


func is_active() -> bool:
	for id in _marks:
		if float(_marks[id]["marked_left"]) > 0.0:
			return true
	return false


## True if `target` is Marked right now. Used by the bot.
func is_marked(target: Node) -> bool:
	var e: Dictionary = _marks.get(target.get_instance_id(), {})
	return not e.is_empty() and float(e["marked_left"]) > 0.0


## Adds one Tide stack to an enemy champion. The 3rd stack marks them.
func add_stack(target: Node3D) -> void:
	if not _is_enemy_champion(target):
		return
	var def := definition as TideMarkDefinition
	var e := _entry(target)
	if float(e["cd_left"]) > 0.0 or float(e["marked_left"]) > 0.0:
		return
	e["stacks"] = int(e["stacks"]) + 1
	e["stack_left"] = def.stack_duration
	if int(e["stacks"]) >= def.stacks_to_mark:
		_mark(e)
	_update_label(e)
	_update_badge(e)


## His E hit an enemy champion: use up their mark if they have one, otherwise add a stack.
## An E that adds the 3rd stack only marks them.
func on_ropes_end_hit(target: Node3D) -> void:
	if is_marked(target):
		_consume(target.get_instance_id())
	else:
		add_stack(target)


func _on_attack_landed(target: Node) -> void:
	if target is Node3D:
		add_stack(target as Node3D)


func _mark(e: Dictionary) -> void:
	var def := definition as TideMarkDefinition
	e["stacks"] = 0
	e["stack_left"] = 0.0
	e["marked_left"] = def.mark_duration
	var target := e["target"] as Node3D
	var st := target.get_node_or_null("Stats") as StatsComponent
	var listener := _on_marked_damaged.bind(target.get_instance_id())
	e["listener"] = listener
	st.damaged.connect(listener)
	AbilityUtil.pop_text(get_tree().current_scene, target.global_position + Vector3(0.0, 3.0, 0.0), "Marked!", COLOR, 34)
	_update_badge(e)


## A marked target took damage. An allied champion's hit (not his own) uses up the mark.
func _on_marked_damaged(_amount: float, source: Node, target_id: int) -> void:
	if source == null or not is_instance_valid(source) or source == caster:
		return
	var st := source.get_node_or_null("Stats") as StatsComponent
	if st == null or st.get_entity_type() != EntityDefinition.EntityType.CHAMPION:
		return
	if st.get_team() != caster.stats.get_team():
		return
	# Deferred so the hit that triggered it finishes first.
	_consume.call_deferred(target_id)


func _consume(target_id: int) -> void:
	var e: Dictionary = _marks.get(target_id, {})
	if e.is_empty() or float(e["marked_left"]) <= 0.0:
		return
	var def := definition as TideMarkDefinition
	_unmark(e)
	var target := e["target"] as Node3D
	if not is_instance_valid(target):
		return
	var st := target.get_node_or_null("Stats") as StatsComponent
	if st == null or st.is_dead:
		return
	var pos := target.global_position
	var dmg := def.payoff_base + def.payoff_hp_ratio * caster.stats.get_max_health()
	st.take_magic_damage(dmg, caster)
	var scene := get_tree().current_scene
	AbilityUtil.ring_flash(scene, pos, 1.6, Color(COLOR, 0.9))
	AbilityUtil.pop_text(scene, pos + Vector3(0.0, 2.6, 0.0), "Tide! -%d" % roundi(dmg), COLOR, 40)
	TideBubble.launch(scene, caster.stats.get_team(), pos, def.bubble_heal, def.bubble_bounces, def.bubble_range, def.bubble_speed)


## Ends the mark (used up or run out) and starts the per-target cooldown.
func _unmark(e: Dictionary) -> void:
	var def := definition as TideMarkDefinition
	e["marked_left"] = 0.0
	e["cd_left"] = def.target_cooldown
	var target := e["target"] as Node3D
	var listener: Callable = e.get("listener", Callable())
	if is_instance_valid(target) and listener.is_valid():
		var st := target.get_node_or_null("Stats") as StatsComponent
		if st and st.damaged.is_connected(listener):
			st.damaged.disconnect(listener)
	e["listener"] = Callable()
	_update_label(e)
	_update_badge(e)


func _tick(delta: float) -> void:
	for id in _marks.keys():
		var e: Dictionary = _marks[id]
		var target := e["target"] as Node3D
		var st: StatsComponent = null
		if is_instance_valid(target):
			st = target.get_node_or_null("Stats") as StatsComponent
		if st == null or st.is_dead or caster.stats.is_dead:
			_remove(id)
			continue
		var changed := false
		if float(e["marked_left"]) > 0.0:
			e["marked_left"] = float(e["marked_left"]) - delta
			if float(e["marked_left"]) <= 0.0:
				_unmark(e)
		if int(e["stacks"]) > 0:
			e["stack_left"] = float(e["stack_left"]) - delta
			if float(e["stack_left"]) <= 0.0:
				e["stacks"] = 0
				changed = true
		if float(e["cd_left"]) > 0.0:
			e["cd_left"] = maxf(float(e["cd_left"]) - delta, 0.0)
		if int(e["stacks"]) == 0 and float(e["marked_left"]) <= 0.0 and float(e["cd_left"]) <= 0.0:
			_remove(id)
			continue
		if changed:
			_update_label(e)
		_update_badge(e)


func _entry(target: Node3D) -> Dictionary:
	var id := target.get_instance_id()
	if not _marks.has(id):
		_marks[id] = {
			"target": target, "stacks": 0, "stack_left": 0.0,
			"marked_left": 0.0, "cd_left": 0.0, "label": null, "listener": Callable(),
		}
	return _marks[id]


func _remove(id: int) -> void:
	var e: Dictionary = _marks[id]
	if float(e["marked_left"]) > 0.0:
		_unmark(e)
	var label := e["label"] as Node3D
	if label and is_instance_valid(label):
		label.queue_free()
	_marks.erase(id)


## Small markers over the target: one dot per Tide stack, and a ring while marked.
func _update_label(e: Dictionary) -> void:
	var target := e["target"] as Node3D
	if not is_instance_valid(target):
		return
	var def := definition as TideMarkDefinition
	var holder := e["label"] as Node3D
	if holder == null or not is_instance_valid(holder):
		holder = _make_markers(def.stacks_to_mark)
		var hb := target.get_node_or_null("HealthBar") as Node3D
		holder.position = Vector3(0.0, (hb.position.y if hb else 2.5) + 0.6, 0.0)
		target.add_child(holder)
		e["label"] = holder
	var marked := float(e["marked_left"]) > 0.0
	var stacks := int(e["stacks"])
	for i in def.stacks_to_mark:
		(holder.get_child(i) as Node3D).visible = not marked and i < stacks
	(holder.get_child(def.stacks_to_mark) as Node3D).visible = marked


## `count` dots in a row plus a ring (the last child), all hidden.
func _make_markers(count: int) -> Node3D:
	var holder := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.11
	dot_mesh.height = 0.22
	for i in count:
		var dot := MeshInstance3D.new()
		dot.mesh = dot_mesh
		dot.material_override = mat
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.position.x = (float(i) - float(count - 1) * 0.5) * 0.32
		dot.visible = false
		holder.add_child(dot)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.55
	torus.rings = 32
	torus.ring_segments = 6
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	holder.add_child(ring)
	return holder


## Mirror the Tide stacks/mark onto the target's status strip (and the player HUD
## when it's the player's own target).
func _update_badge(e: Dictionary) -> void:
	var target := e["target"] as Node3D
	if not is_instance_valid(target):
		return
	var fx := target.get_node_or_null("StatusEffects") as StatusEffects
	if fx == null:
		return
	var def := definition as TideMarkDefinition
	if float(e["marked_left"]) > 0.0:
		fx.set_badge("tide", "MRK", COLOR, 1, float(e["marked_left"]), def.mark_duration)
	elif int(e["stacks"]) > 0:
		fx.set_badge("tide", "TID", COLOR, int(e["stacks"]), float(e["stack_left"]), def.stack_duration)
	else:
		fx.clear_badge("tide")


func _is_enemy_champion(target: Node) -> bool:
	if target == null or not is_instance_valid(target) or not (target is Node3D):
		return false
	var st := target.get_node_or_null("Stats") as StatsComponent
	if st == null or st.is_dead:
		return false
	if st.get_entity_type() != EntityDefinition.EntityType.CHAMPION:
		return false
	return EntityData.is_enemy(caster.stats.get_team(), st.get_team())


func _exit_tree() -> void:
	for id in _marks.keys():
		_remove(id)
