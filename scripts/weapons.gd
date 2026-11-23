class_name Weapons
## Weapons of the modular hero. Each belongs to a family that sets its
## moveset; times are in seconds. Two-handed weapons hit harder and slower
## and leave no hand for a shield. Timings follow the Souls: the hero's
## attacks arm about as slowly as the enemies' (~0.3-0.5 s for a light
## attack, critpoints.net), so swinging into an enemy's windup is a risk;
## once started, an attack is committed.

const FAMILIES := {
	"dagger": {
		"light": {"windup": 0.24, "active": 0.08, "recovery": 0.19, "damage": 11, "poise": 5, "stamina": 9,
			"shape": "circle", "size": Vector2(22, 0), "reach": 14, "step": 30},
		"heavy": {"windup": 0.45, "active": 0.10, "recovery": 0.35, "damage": 24, "poise": 12, "stamina": 20,
			"shape": "rect", "size": Vector2(40, 12), "reach": 26, "step": 120},
	},
	"sword": {
		"light": {"windup": 0.30, "active": 0.10, "recovery": 0.27, "damage": 18, "poise": 12, "stamina": 15,
			"shape": "circle", "size": Vector2(28, 0), "reach": 18, "step": 35},
		"heavy": {"windup": 0.58, "active": 0.12, "recovery": 0.46, "damage": 36, "poise": 30, "stamina": 28,
			"shape": "circle", "size": Vector2(34, 0), "reach": 20, "step": 70},
	},
	"axe": {
		"light": {"windup": 0.34, "active": 0.10, "recovery": 0.32, "damage": 22, "poise": 18, "stamina": 18,
			"shape": "circle", "size": Vector2(28, 0), "reach": 18, "step": 30},
		"heavy": {"windup": 0.66, "active": 0.12, "recovery": 0.51, "damage": 44, "poise": 40, "stamina": 32,
			"shape": "circle", "size": Vector2(34, 0), "reach": 20, "step": 60},
	},
	"blunt": {
		"light": {"windup": 0.36, "active": 0.10, "recovery": 0.32, "damage": 18, "poise": 26, "stamina": 18,
			"shape": "circle", "size": Vector2(26, 0), "reach": 16, "step": 25},
		"heavy": {"windup": 0.70, "active": 0.12, "recovery": 0.54, "damage": 40, "poise": 55, "stamina": 34,
			"shape": "circle", "size": Vector2(36, 0), "reach": 18, "step": 40},
	},
	"great": {
		"light": {"windup": 0.44, "active": 0.12, "recovery": 0.41, "damage": 30, "poise": 30, "stamina": 24,
			"shape": "circle", "size": Vector2(36, 0), "reach": 22, "step": 30},
		"heavy": {"windup": 0.85, "active": 0.14, "recovery": 0.61, "damage": 60, "poise": 70, "stamina": 42,
			"shape": "circle", "size": Vector2(44, 0), "reach": 24, "step": 60},
	},
}

const DATA := {
	"dagger": {"name": "Dague", "family": "dagger"},
	"shortsword": {"name": "Épée courte", "family": "sword"},
	"longsword": {"name": "Épée longue", "family": "sword"},
	"greatsword": {"name": "Espadon", "family": "great", "two_handed": true},
	"zweihander": {"name": "Zweihänder", "family": "great", "two_handed": true},
	"hand_axe": {"name": "Hachette", "family": "axe"},
	"battle_axe": {"name": "Hache de bataille", "family": "great", "two_handed": true},
	"infantry_axe": {"name": "Hache d'infanterie", "family": "axe"},
	"club": {"name": "Gourdin", "family": "blunt"},
	"reinforced_club": {"name": "Gourdin clouté", "family": "blunt"},
	"mace": {"name": "Masse", "family": "blunt"},
	"smith_hammer": {"name": "Marteau de forge", "family": "blunt"},
	"war_hammer": {"name": "Marteau de guerre", "family": "great", "two_handed": true},
	"maul": {"name": "Maillet", "family": "great", "two_handed": true},
}

static func moves(weapon: String) -> Dictionary:
	return FAMILIES[DATA[weapon].family]

static func two_handed(weapon: String) -> bool:
	return DATA[weapon].get("two_handed", false)
