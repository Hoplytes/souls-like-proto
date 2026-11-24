class_name HeroConfig
## The hero chosen in the creator, saved in user://hero.json. Both models are
## licensed art of SmallScaleInt kept in the private assets repo (res://local/):
## the fighter with the round shield of the fantasy pack, and the HD knight.

static var data := {"v": 3, "model": "pack_hero"}

const DESCRIPTIONS := {
	"pack_hero": "Épée et bouclier rond. Combo de trois coups différents, deux coups lourds qui alternent, pas chassés et course arrière quand il verrouille un ennemi.",
	"hd_knight": "Chevalier en armure, dessiné plus finement. Combo de trois coups (le dernier tournoyant), une vraie roulade et un blocage en deux temps.",
}

## The models whose art is there.
static func options(key: String) -> Array:
	if key != "model":
		return []
	var models := []
	if HdSprite.pack_available():
		models.append("pack_hero")
	if HdSprite.available():
		models.append("hd_knight")
	return models

static func label(key: String, value) -> String:
	if key == "model":
		match value:
			"pack_hero": return "Combattant au bouclier rond"
			"hd_knight": return "Chevalier HD"
	return str(value)

static func save() -> void:
	var f := FileAccess.open("user://hero.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

static func load_saved() -> void:
	if FileAccess.file_exists("user://hero.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("user://hero.json"))
		if d is Dictionary and d.has("model"):
			data.model = d.model
	if not options("model").has(data.model) and not options("model").is_empty():
		data.model = options("model")[0]
