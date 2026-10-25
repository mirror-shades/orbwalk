class_name SimRng
extends RefCounted
## The one source of randomness for game logic (crits, minion jitter, spawn
## order...). ProtoGame seeds it from the match seed, so the same seed and the
## same commands play out the same match. That's what makes replays work.
##
## Game logic must use these instead of the global randf() / randi() /
## Array.shuffle(). Purely visual randomness (UI timers, effects) can keep using
## the global ones.
##
## Bots get their own stream (bot_rng). Their dice rolls then never shift the
## game's stream, so a replay can feed in recorded bot commands without
## running the bots' decisions.

static var _rng := RandomNumberGenerator.new()
static var _bot_rng := RandomNumberGenerator.new()


## Restarts both streams from `seed`.
static func reseed(p_seed: int) -> void:
	_rng.seed = hash([p_seed, "sim"])
	_bot_rng.seed = hash([p_seed, "bots"])


static func randf() -> float:
	return _rng.randf()


static func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


static func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Fisher-Yates shuffle of `arr` in place, using the game stream (or `rng`).
static func shuffle(arr: Array, rng: RandomNumberGenerator = null) -> void:
	var r := rng if rng != null else _rng
	for i in range(arr.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## The bots' stream. Only bot decision code may use it.
static func bot_rng() -> RandomNumberGenerator:
	return _bot_rng


## A fresh generator for one bot, seeded from the bot stream.
static func new_bot_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = _bot_rng.randi()
	return r
