class_name HeroConfig
## The hero's look and gear, chosen in the character creator and kept in
## user://hero.json. Pieces are Flare avatar art (assets/flare/avatar/).

const BODIES := ["male", "female", "female_dark"]
const HEADS := {"male": ["head_short", "head_bald"], "female": ["head_long"], "female_dark": ["head_long"]}
const HELMS := ["", "leather_hood", "chain_coif", "plate_helm", "mage_hood", "mage_hood_alt1", "mage_hood_alt2"]
const CHESTS := ["default_chest", "cloth_shirt", "leather_chest", "chain_cuirass", "plate_cuirass", "mage_vest", "mage_vest_alt1", "mage_vest_alt2"]
const HANDS := ["default_hands", "cloth_gloves", "leather_gloves", "chain_gloves", "plate_gauntlets", "mage_sleeves", "mage_sleeves_alt1", "mage_sleeves_alt2"]
const LEGS := ["default_legs", "cloth_pants", "leather_pants", "chain_greaves", "plate_greaves", "mage_skirt", "mage_skirt_alt1", "mage_skirt_alt2"]
const FEET := ["default_feet", "cloth_sandals", "leather_boots", "chain_boots", "plate_boots", "mage_boots", "mage_boots_alt1", "mage_boots_alt2"]
const SHIELDS := ["", "buckler", "iron_buckler", "shield", "kite_shield"]
## Armour tints: a colour multiplied over the armour pieces (not the skin).
const TINTS := [
	["Naturel", Color(1, 1, 1)], ["Bronze", Color(1.0, 0.78, 0.5)], ["Noirci", Color(0.55, 0.55, 0.6)],
	["Sang", Color(1.0, 0.55, 0.5)], ["Or", Color(1.15, 1.0, 0.55)], ["Givre", Color(0.75, 0.9, 1.15)],
]
const NAMES := {
	"male": "Homme", "female": "Femme", "female_dark": "Femme, peau mate",
	"head_short": "Cheveux courts", "head_bald": "Crâne rasé", "head_long": "Cheveux longs",
	"": "Aucun", "leather_hood": "Capuche de cuir", "chain_coif": "Camail de mailles", "plate_helm": "Heaume",
	"mage_hood": "Capuche de mage (brune)", "mage_hood_alt1": "Capuche de mage (noire)", "mage_hood_alt2": "Capuche de mage (pourpre)",
	"default_chest": "Torse nu", "cloth_shirt": "Chemise", "leather_chest": "Plastron de cuir",
	"chain_cuirass": "Cotte de mailles", "plate_cuirass": "Cuirasse", "mage_vest": "Robe de mage (brune)",
	"mage_vest_alt1": "Robe de mage (noire)", "mage_vest_alt2": "Robe de mage (pourpre)",
	"default_hands": "Mains nues", "cloth_gloves": "Gants de tissu", "leather_gloves": "Gants de cuir",
	"chain_gloves": "Gants de mailles", "plate_gauntlets": "Gantelets", "mage_sleeves": "Manches de mage (brune)",
	"mage_sleeves_alt1": "Manches de mage (noire)", "mage_sleeves_alt2": "Manches de mage (pourpre)",
	"default_legs": "Jambes nues", "cloth_pants": "Pantalon de tissu", "leather_pants": "Pantalon de cuir",
	"chain_greaves": "Jambières de mailles", "plate_greaves": "Grèves", "mage_skirt": "Jupe de mage (brune)",
	"mage_skirt_alt1": "Jupe de mage (noire)", "mage_skirt_alt2": "Jupe de mage (pourpre)",
	"default_feet": "Pieds nus", "cloth_sandals": "Sandales", "leather_boots": "Bottes de cuir",
	"chain_boots": "Bottes de mailles", "plate_boots": "Solerets", "mage_boots": "Bottes de mage (brune)",
	"mage_boots_alt1": "Bottes de mage (noire)", "mage_boots_alt2": "Bottes de mage (pourpre)",
	"buckler": "Rondache", "iron_buckler": "Rondache de fer", "shield": "Écu", "kite_shield": "Bouclier en amande",
}

static var data := {
	"v": 2, "model": "pack_hero", "body": "male", "head": "head_short", "helm": "", "chest": "chain_cuirass",
	"hands": "leather_gloves", "legs": "leather_pants", "feet": "leather_boots",
	"weapon": "longsword", "shield": "shield", "tint": 0,
}

## The list of choices for each line of the creator.
static func options(key: String) -> Array:
	match key:
		"model":
			var models := []
			if HdSprite.pack_available():
				models.append("pack_hero")
			if HdSprite.available():
				models.append("hd_knight")
			return models + ["flare"]
		"body": return BODIES
		"head": return HEADS[data.body]
		"helm": return HELMS
		"chest": return CHESTS
		"hands": return HANDS
		"legs": return LEGS
		"feet": return FEET
		"weapon": return Weapons.DATA.keys()
		"shield": return SHIELDS
		"tint": return range(TINTS.size())
	return []

static func label(key: String, value) -> String:
	match key:
		"model":
			match value:
				"pack_hero": return "Combattant au bouclier rond"
				"hd_knight": return "Chevalier HD"
			return "Personnalisé (Flare)"
		"weapon": return Weapons.DATA[value].name
		"tint": return TINTS[value][0]
		"shield":
			if value != "" and Weapons.two_handed(data.weapon):
				return NAMES[value] + " (inutilisable à deux mains)"
	return NAMES.get(value, str(value))

## Folder of one piece's sheets; the dark-skin body only redraws the pieces
## that show skin and borrows the others from "female".
static func piece_folder(body: String, piece: String) -> String:
	var path := "avatar/%s/%s" % [body, piece]
	if not ResourceLoader.exists("res://assets/flare/%s/stance.png" % path) and body == "female_dark":
		path = "avatar/female/" + piece
	return path

static func save() -> void:
	var f := FileAccess.open("user://hero.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

static func load_saved() -> void:
	if not FileAccess.file_exists("user://hero.json"):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string("user://hero.json"))
	if d is Dictionary:
		for k in d:
			if data.has(k):
				data[k] = d[k]
		if int(d.get("v", 1)) < 2:  # saved before the fantasy pack: its hero becomes the default
			data.model = "pack_hero"
			data.v = 2
	data.tint = int(data.tint)
	for k in ["body", "head", "helm", "chest", "hands", "legs", "feet", "weapon", "shield"]:
		if not options(k).has(data[k]):
			data[k] = options(k)[0]
	if not options("model").has(data.model):
		data.model = options("model")[0]
