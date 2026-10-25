class_name SpawnerRolls
extends RefCounted
## One player's spawner board and banked rolls (docs/spawner_system.md).
## Every level-up banks a roll. Opening a roll shows up to 3 random cards: a new
## spawner (only while a slot is open) or an upgrade for a spawner you own.
## Picks arrive as PICK_ROLL commands (ProtoGame._apply_command), which place the
## spawner buildings and read this board when sending waves.

signal changed()

## Slot order: [{"id": spawner id, "upgrades": [upgrade ids]}, ...]
var slots: Array[Dictionary] = []
var banked: int = 0
## The open roll's cards. Kept until one is picked, so closing and reopening
## the menu can't fish for a better roll.
var offer: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()


## Seeded separately from SimRng so opening rolls never shifts the match's randomness.
func setup(champion_id: String, seed_value: int) -> void:
	_rng.seed = seed_value
	var sig := SpawnerPool.signature_of(champion_id)
	if sig != "":
		slots.append({"id": sig, "upgrades": []})


func bank_roll() -> void:
	banked += 1
	changed.emit()


func has_open_roll() -> bool:
	return not offer.is_empty()


## The cards of the open roll, drawing a new one if needed. Empty when there's
## nothing to roll (no banked rolls, or the board is already full).
func open_roll() -> Array[Dictionary]:
	if offer.is_empty() and banked > 0:
		offer = _draw()
		if offer.is_empty():
			# Nothing left to offer: the board is maxed, so banked rolls are useless.
			banked = 0
		changed.emit()
	return offer


## Applies card `index` of the open roll and uses up the roll.
func pick(index: int) -> void:
	if index < 0 or index >= offer.size():
		return
	var card := offer[index]
	if card["kind"] == "spawner":
		slots.append({"id": card["spawner"], "upgrades": []})
	else:
		for s in slots:
			if s["id"] == card["spawner"]:
				(s["upgrades"] as Array).append(card["upgrade"])
	offer.clear()
	banked -= 1
	changed.emit()


## Clears the board and puts these spawners in it, in slot order. Used by
## replays and the balance runner. Each entry is {"id", "upgrades"}.
func set_board(board: Array) -> void:
	slots.clear()
	for s: Dictionary in board:
		var ups: Array[String] = []
		ups.assign(s.get("upgrades", []))
		slots.append({"id": str(s["id"]), "upgrades": ups})
	offer.clear()
	changed.emit()


func upgrades_of(slot: int) -> Array:
	return slots[slot]["upgrades"]


func owns(spawner_id: String) -> bool:
	for s in slots:
		if s["id"] == spawner_id:
			return true
	return false


## Every card that could show up right now, then up to CARDS_PER_ROLL of them at random.
func _draw() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if slots.size() < SpawnerPool.SLOTS:
		for id in SpawnerPool.SPAWNERS:
			if not owns(id):
				options.append({"kind": "spawner", "spawner": id})
	for s in slots:
		var taken: Array = s["upgrades"]
		if taken.size() >= SpawnerPool.MAX_UPGRADES:
			continue
		for u in SpawnerPool.SPAWNERS[s["id"]]["upgrades"]:
			if not taken.has(u[0]):
				options.append({"kind": "upgrade", "spawner": s["id"], "upgrade": u[0]})
	var out: Array[Dictionary] = []
	while out.size() < SpawnerPool.CARDS_PER_ROLL and not options.is_empty():
		out.append(options.pop_at(_rng.randi_range(0, options.size() - 1)))
	return out
