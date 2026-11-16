class_name Weapons
## Weapon definitions. Adding a weapon = adding an entry here (plus its LPC
## sheets). Times are in seconds; "frames" splits the attack animation into
## windup / active / recovery frames.

const DATA := {
	"sword": {
		"name": "Épée courte",
		"anim": "slash",
		"frames": [3, 5],  # frames 0-2 windup, 3-4 active, 5 recovery
		"layers": ["res://assets/sprites/sword_bg.png", "res://assets/sprites/sword_fg.png"],
		"light": {"windup": 0.13, "active": 0.10, "recovery": 0.22, "damage": 20, "poise": 14,
			"stamina": 16, "shape": "circle", "size": Vector2(30, 0), "reach": 20, "step": 40},
		"heavy": {"windup": 0.40, "active": 0.12, "recovery": 0.38, "damage": 40, "poise": 35,
			"stamina": 30, "shape": "circle", "size": Vector2(38, 0), "reach": 22, "step": 80},
	},
	"spear": {
		"name": "Lance",
		"anim": "thrust",
		"frames": [4, 6],  # frames 0-3 windup, 4-5 active, 6-7 recovery
		"layers": ["res://assets/sprites/spear_bg.png", "res://assets/sprites/spear_fg.png"],
		"light": {"windup": 0.15, "active": 0.10, "recovery": 0.20, "damage": 16, "poise": 9,
			"stamina": 13, "shape": "rect", "size": Vector2(62, 16), "reach": 40, "step": 20},
		"heavy": {"windup": 0.34, "active": 0.20, "recovery": 0.36, "damage": 32, "poise": 26,
			"stamina": 28, "shape": "rect", "size": Vector2(70, 18), "reach": 44, "step": 170},
	},
}
