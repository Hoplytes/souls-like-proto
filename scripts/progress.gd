class_name Progress
## The player's progress, kept across deaths and sessions (user://save.json;
## in the browser, the site's local storage): souls carried, level and the
## three stats bought with souls at the bonfires, bonfires lit, the last one
## rested at, bosses beaten, items taken, flask count, and the bloodstain
## where the souls were dropped at the last death.

const PATH := "user://save.json"
const FLASKS_MAX := 7

static var data := {}
## Off during the automatic tests, which must not touch the player's save.
static var saving := true

static func fresh() -> Dictionary:
	return {
		"v": 1, "souls": 0, "level": 1, "vigor": 1, "endurance": 1, "strength": 1,
		"flasks": 3, "lit": ["prairie"], "spawn": "prairie", "defeated": {}, "taken": {},
		"stain": {},  # {"x", "y": world position, "souls"}
		"deaths": 0, "kills": 0,
	}

static func new_game() -> void:
	data = fresh()
	save()

static func exists() -> bool:
	return FileAccess.file_exists(PATH)

static func load_game() -> void:
	data = fresh()
	if not exists():
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Dictionary:
		for k in d:
			if data.has(k):
				data[k] = d[k]
	for k in ["souls", "level", "vigor", "endurance", "strength", "flasks", "deaths", "kills"]:
		data[k] = int(data[k])

static func ensure_loaded() -> void:
	if data.is_empty():
		load_game()

static func save() -> void:
	if not saving:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

# --- stats -------------------------------------------------------------------

const STATS := {
	"vigor": ["Vigueur", "Santé"], "endurance": ["Endurance", "Endurance"], "strength": ["Force", "Dégâts"],
}

static func max_hp() -> int:
	return 110 + (int(data.vigor) - 1) * 14

static func max_stamina() -> float:
	return 95.0 + (int(data.endurance) - 1) * 9.0

static func damage_mult() -> float:
	return 1.0 + (int(data.strength) - 1) * 0.07

## Souls needed to go from the current level to the next one.
static func level_cost() -> int:
	return int(round((60.0 + 30.0 * pow(float(data.level), 1.55)) / 10.0)) * 10

static func level_up(stat: String) -> bool:
	var cost := level_cost()
	if int(data.souls) < cost:
		return false
	data.souls = int(data.souls) - cost
	data[stat] = int(data[stat]) + 1
	data.level = int(data.level) + 1
	save()
	return true

static func add_souls(n: int) -> void:
	data.souls = int(data.souls) + n

## Base damage multiplier of the hero's attacks, shown in the level-up menu.
static func damage_text(strength: int) -> String:
	return "×%.2f" % (1.0 + (strength - 1) * 0.07)
