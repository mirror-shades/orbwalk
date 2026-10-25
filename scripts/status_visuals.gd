class_name StatusVisuals
extends RefCounted
## Shared look for status thumbnails (HUD row and the strips above health bars).
## The "icons" are placeholders: a colored tile with a short label; a proper icon
## set can replace the label later.

const BUFF_COLOR := Color(1.0, 0.85, 0.45)

const DATA := {
	"stun": {"label": "STN", "color": Color(1.0, 0.9, 0.3)},
	"knockup": {"label": "AIR", "color": Color(0.45, 0.85, 1.0)},
	"fear": {"label": "FER", "color": Color(0.8, 0.45, 1.0)},
	"root": {"label": "ROT", "color": Color(0.8, 0.62, 0.34)},
	"blind": {"label": "BLD", "color": Color(0.9, 0.8, 0.55)},
	"dodge": {"label": "SMK", "color": Color(0.68, 0.68, 0.76)},
	"stealth": {"label": "CLK", "color": Color(0.55, 0.8, 1.0)},
	"slow": {"label": "SLW", "color": Color(0.55, 0.8, 1.0)},
	"poison": {"label": "PSN", "color": Color(0.55, 0.95, 0.3)},
	"channel": {"label": "CST", "color": Color(1.0, 0.7, 0.3)},
	"ms": {"label": "MS", "color": Color(0.6, 1.0, 0.6)},
	"as": {"label": "AS", "color": Color(1.0, 0.7, 0.3)},
	"slow_immune": {"label": "IMM", "color": Color(0.4, 0.9, 0.8)},
}

## Lower sorts first. Badges (stack counters) come after normal effects.
const PRIORITY := {
	"stun": 0, "knockup": 1, "fear": 2, "root": 3, "blind": 4,
	"dodge": 5, "stealth": 5, "slow": 6, "poison": 7, "channel": 8,
	"ms": 10, "as": 11, "slow_immune": 12,
}


static func info(key: String) -> Dictionary:
	if DATA.has(key):
		return DATA[key]
	return {"label": "BUF", "color": BUFF_COLOR}


static func priority(key: String) -> int:
	if PRIORITY.has(key):
		return int(PRIORITY[key])
	if key.begins_with("buff:"):
		return 20
	if key.begins_with("badge:"):
		return 30
	return 50


## The label to draw on a thumbnail. Long labels (stat buff texts) are cut down.
static func label_for(key: String, label: String) -> String:
	if label != "":
		return label.to_upper().left(4)
	return str(info(key)["label"])


static func color_for(key: String, color: Color) -> Color:
	if color.a > 0.0:
		return color
	return info(key)["color"]
