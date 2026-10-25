class_name ProtoAIBuilder
extends RefCounted
## A bot's spawner picks. Whenever its seat has a banked roll it opens it, waits
## a moment like a person would, and picks a card through a PICK_ROLL command.
## Preference: a new spawner while a slot is open, then an extra-minion upgrade,
## then any upgrade, with a little randomness so bots don't all build the same.

var game: ProtoGame
var seat: int
var rng := RandomNumberGenerator.new()
## Seconds before the next pick. Bots don't pick the instant they level up.
var _wait: float = -1.0


func _init(p_game: ProtoGame, p_seat: int) -> void:
	game = p_game
	seat = p_seat
	rng = SimRng.new_bot_rng()


## Called every tick by ProtoGame.
func step() -> void:
	var rolls: SpawnerRolls = game.spawner_rolls.get(seat)
	if rolls == null or rolls.banked <= 0:
		_wait = -1.0
		return
	if _wait < 0.0:
		_wait = rng.randf_range(1.0, 3.0)
	_wait -= 1.0 / float(Engine.physics_ticks_per_second)
	if _wait > 0.0:
		return
	var cards := rolls.open_roll()
	if cards.is_empty():
		return
	game.execute_command(seat, PlayerCommand.pick_roll(_choose(cards)))
	# The pick lands next tick; wait before looking at the next roll.
	_wait = rng.randf_range(1.0, 3.0)


func _choose(cards: Array[Dictionary]) -> int:
	var best := 0
	var best_score := -INF
	for i in cards.size():
		var c := cards[i]
		var score := rng.randf_range(0.0, 0.5)
		if c["kind"] == "spawner":
			score += 3.0
		elif c["upgrade"] in SpawnerPool.EXTRA_UNIT_UPGRADES:
			score += 2.0
		else:
			score += 1.0
		if score > best_score:
			best_score = score
			best = i
	return best
