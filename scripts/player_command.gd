class_name PlayerCommand
extends RefCounted
## Everything a player can tell the simulation to do. The local player's
## PlayerController, the roll menu and the bots (ai_champion.gd, ai_builder.gd) build
## commands here and hand them to ProtoGame.execute_command(), which checks them
## and applies them. Nothing else should change game state on a player's behalf.
##
## A command is a Dictionary of built-in types, so it can be sent over the
## network as-is later.

enum Type {
	MOVE,     ## {pos: Vector3}
	ATTACK,   ## {target: int}
	STOP,     ## {}
	CAST,     ## {slot: int, pos: Vector3}
	AIM,      ## {slot: int, pos: Vector3} - live aim for a charged cast
	RANK_UP,  ## {slot: int}
	PICK_ROLL,  ## {index: int} - take card `index` of the seat's open spawner roll
}


static func move(pos: Vector3) -> Dictionary:
	return {"type": Type.MOVE, "pos": Vector3(pos.x, 0.0, pos.z)}


static func attack(target: Node) -> Dictionary:
	return {"type": Type.ATTACK, "target": target_id(target)}


static func stop() -> Dictionary:
	return {"type": Type.STOP}


static func cast(slot: int, pos: Vector3) -> Dictionary:
	return {"type": Type.CAST, "slot": slot, "pos": pos}


## Live aim for a charged cast: no cost, no cooldown, just a direction update.
static func aim(slot: int, pos: Vector3) -> Dictionary:
	return {"type": Type.AIM, "slot": slot, "pos": pos}


static func rank_up(slot: int) -> Dictionary:
	return {"type": Type.RANK_UP, "slot": slot}


static func pick_roll(index: int) -> Dictionary:
	return {"type": Type.PICK_ROLL, "index": index}


## How a command names an entity: its stable unit id (Entity.unit_id, 0 = none).
static func target_id(node: Node) -> int:
	return EntityData.id_of(node)


## The entity a command's target id points at, or null if it's gone.
static func resolve_target(id: int) -> Node:
	return EntityData.unit_by_id(id)
