class_name SpawnerPool
## The 12 signature spawners and their upgrades, for the roll menu.
## Spawners send minions; of the upgrades, only the "doubles" ones do anything yet.
## Design: docs/signature_spawners.md, docs/spawner_system.md.

const SLOTS := 5
const MAX_UPGRADES := 3
const CARDS_PER_ROLL := 3

## id -> {name, unit, champion, ability, upgrades: [[id, name, text], ...]}
const SPAWNERS := {
	"wharf": {
		"name": "Wharf", "unit": "Dockhand", "champion": "argonaut",
		"ability": "Every 6s, ropes the farthest enemy in range, pulls it in, and taunts it.",
		"upgrades": [
			["double_rope", "Double Rope", "Haul throws two ropes at two different targets."],
			["long_rope", "Long Rope", "Haul's range +50%."],
			["anchor", "Anchor", "The hauled target is stunned for a moment when it lands."],
			["ropes_end", "Rope's End", "Every 3rd attack lashes in a half circle in front of it."],
			["whale_spout", "Whale Spout", "On death, knocks up enemies nearby."],
			["crew", "Crew", "Doubles the Dockhands it sends each wave."],
		],
	},
	"workshop": {
		"name": "Workshop", "unit": "Clockwork Soldier", "champion": "artificer",
		"ability": "On death, bursts for damage and a slow.",
		"upgrades": [
			["bigger_bang", "Bigger Bang", "Burst radius +50%."],
			["bleed_charge", "Bleed Charge", "The burst also applies Bleed."],
			["shove", "Shove", "The burst also knocks enemies back."],
			["production_line", "Production Line", "Doubles the Clockwork Soldiers it sends each wave."],
			["windup_delay", "Wind-up Delay", "On death, winds up for 1s, then bursts for double damage. Enemies can hit it during the wind-up to stop the burst."],
			["self_destruct", "Self-Destruct", "Below 25% HP, rushes the nearest enemy group and bursts early."],
		],
	},
	"witchs_hut": {
		"name": "Witch's Hut", "unit": "Coven Witch", "champion": "broom_rider",
		"ability": "Every 5s, throws 3 weak sparks at the closest enemies.",
		"upgrades": [
			["bigger_swarm", "Bigger Swarm", "5 sparks instead of 3."],
			["quick_swarm", "Quick Swarm", "Sparks every 3s instead of 5s."],
			["hex_bolt", "Hex Bolt", "Every 3rd auto hits harder and slows."],
			["spark_shield", "Spark Shield", "Gains a small shield each time it throws sparks."],
			["witchs_tithe", "Witch's Tithe", "Heals a little for each spark that hits."],
			["coven", "Coven", "Doubles the Coven Witches it sends each wave."],
		],
	},
	"thieves_den": {
		"name": "Thieves' Den", "unit": "Cutpurse", "champion": "cats_paw",
		"ability": "On first contact, throws a knife through the wave, then ropes in behind their frontline.",
		"upgrades": [
			["low_cut", "Low Cut", "Attacks deal bonus damage to enemies below 35% HP."],
			["reel_in", "Reel In", "Fears enemies around where it lands for a moment."],
			["empower", "Empower", "Every 4th attack splashes onto enemies near the target."],
			["dash_reset", "Dash Reset", "After a kill, dashes to the next closest enemy and gains attack speed briefly."],
			["slowing_blade", "Slowing Blade", "The knife slows everything it passes through."],
			["gang", "Gang", "Doubles the Cutpurses it sends each wave."],
		],
	},
	"drill_yard": {
		"name": "Drill Yard", "unit": "Corporal", "champion": "drill_sergeant",
		"ability": "Every 3rd attack is a wide cleave that heals it for part of the damage.",
		"upgrades": [
			["quick_cleave", "Quick Cleave", "Cleave every 2nd attack instead of every 3rd."],
			["fall_in", "Fall In", "Takes less damage for each allied minion nearby."],
			["war_banner", "War Banner", "Carries a banner. Allies near it attack faster and are tougher; it's dropped where it dies."],
			["forward_march", "Forward, March!", "Every 10s, nearby allies surge forward briefly: faster and unslowable."],
			["field_medic", "Field Medic", "Cleave's healing also goes to allies near it."],
			["squad", "Squad", "Doubles the Corporals it sends each wave."],
		],
	},
	"shooting_gallery": {
		"name": "Shooting Gallery", "unit": "Deputy", "champion": "gunslinger",
		"ability": "Every auto fires two smaller shots.",
		"upgrades": [
			["fan_the_hammer", "Fan the Hammer", "Every 6s, fires a spread of bullets down a line."],
			["hollow_point", "Hollow Point", "Every 5th shot is a guaranteed crit that bleeds."],
			["big_iron", "Big Iron", "Every 10s, a wind-up slug hits everything in a line, and the recoil knocks it back."],
			["triple_tap", "Triple Tap", "Fires three shots per auto instead of two."],
			["ricochet", "Ricochet", "Shots that kill bounce to the nearest enemy."],
			["posse", "Posse", "Doubles the Deputies it sends each wave."],
		],
	},
	"dojo": {
		"name": "Dojo", "unit": "Initiate", "champion": "hired_blade",
		"ability": "Attacks alternate between 1 Bleed stack and a slow.",
		"upgrades": [
			["twin_cut", "Twin Cut", "Bleed attacks add 2 stacks instead of 1."],
			["hamstring", "Hamstring", "Slow attacks slow harder and for longer."],
			["kata", "Kata", "Each attack makes it a little faster, stacking."],
			["grapple", "Grapple", "On first contact, grapples to the farthest enemy in range."],
			["flurry", "Flurry", "Every 4th attack strikes twice, applying both Bleed and slow."],
			["dojo", "Dojo", "Doubles the Initiates it sends each wave."],
		],
	},
	"apothecary": {
		"name": "Apothecary", "unit": "Peddler", "champion": "potion_seller",
		"ability": "Long-range attacks lob potions that splash a small area.",
		"upgrades": [
			["glue", "Glue", "Every 3rd potion is bigger and slows."],
			["poison", "Poison", "Every 3rd potion poisons everything it hits."],
			["spilled_stock", "Spilled Stock", "On death, leaves a poison circle."],
			["demolition_brew", "Demolition Brew", "Potions deal bonus damage to towers."],
			["satisfied_customer", "Satisfied Customer", "Heals a little each time a potion hits a champion."],
			["caravan", "Caravan", "Doubles the Peddlers it sends each wave."],
		],
	},
	"dune_spire": {
		"name": "Dune Spire", "unit": "Sandcaller", "champion": "sleepwalker",
		"ability": "At half health, sprays a blinding sand cloud.",
		"upgrades": [
			["second_wind", "Second Wind", "Also sprays sand at 25% health."],
			["dust_devil", "Dust Devil", "The sand cloud also slows."],
			["sandstorm", "Sandstorm", "The sand cloud is bigger and drifts toward the enemy."],
			["opening_spray", "Opening Spray", "Also sprays sand on first contact."],
			["last_gasp", "Last Gasp", "On death, sprays one final sand cloud."],
			["caravan_of_dunes", "Caravan of Dunes", "Doubles the Sandcallers it sends each wave."],
		],
	},
	"union_hall": {
		"name": "Union Hall", "unit": "Riveter", "champion": "unioneer",
		"ability": "Wind-up attack speed. Every 5th auto drops a 1 HP turret that fires 3 shots.",
		"upgrades": [
			["heavy_duty", "Heavy Duty", "Turrets fire 5 shots instead of 3."],
			["quick_build", "Quick Build", "A turret every 4th auto instead of every 5th."],
			["chain_lightning", "Chain Lightning", "A turret's last shot chains to 2 more enemies."],
			["reinforced", "Reinforced", "Turrets survive one hit before breaking."],
			["overload", "Overload", "At max Wind-up, its attacks briefly stun."],
			["local_chapter", "Local Chapter", "Doubles the Riveters it sends each wave."],
		],
	},
	"hunters_lodge": {
		"name": "Hunter's Lodge", "unit": "Tracker", "champion": "wakeman",
		"ability": "At half health, rolls back; its next attack deals bonus damage.",
		"upgrades": [
			["second_roll", "Second Roll", "Also rolls at 25% health."],
			["charged_kill", "Charged Kill", "If the charged shot kills, it gets another tumble."],
			["hunters_reach", "Hunter's Reach", "+attack range."],
			["flashbang", "Flashbang", "The roll leaves a grenade that slows and blinds enemies nearby."],
			["opening_shot", "Opening Shot", "Its first attack of each fight is charged."],
			["hunting_party", "Hunting Party", "Doubles the Trackers it sends each wave."],
		],
	},
	"kennel": {
		"name": "Kennel", "unit": "Kennelmaster", "champion": "wrangler",
		"ability": "On first contact, charges in and stuns the first enemy it hits.",
		"upgrades": [
			["bark", "Bark", "Every 5s, barks and slows nearby enemies."],
			["sic_em", "Sic 'Em", "Every 8s, latches onto its target, dealing damage over time."],
			["heel_again", "Heel Again", "Charges again every 10s, not just on first contact."],
			["longer_stun", "Longer Stun", "Heel's stun lasts longer."],
			["pack", "Pack", "The charge hits every enemy in its path, not just the first."],
			["kennel", "Kennel", "Doubles the Kennelmasters it sends each wave."],
		],
	},
}


## Upgrades that double how many minions a spawner sends each wave (ProtoGame.wave_size).
## The only upgrades that change gameplay so far.
const EXTRA_UNIT_UPGRADES := ["crew", "production_line", "coven", "gang", "squad", "posse", "dojo", "caravan", "caravan_of_dunes", "local_chapter", "hunting_party", "kennel"]


## The signature spawner of a champion, or "" if it has none.
static func signature_of(champion_id: String) -> String:
	for id in SPAWNERS:
		if SPAWNERS[id]["champion"] == champion_id:
			return id
	return ""


## [name, text] of one upgrade.
static func upgrade_info(spawner_id: String, upgrade_id: String) -> Array:
	for u in SPAWNERS[spawner_id]["upgrades"]:
		if u[0] == upgrade_id:
			return [u[1], u[2]]
	return [upgrade_id, ""]
