extends Node2D
class_name Game
## The open world: four biomes generated around their landmarks, a village
## and a lake, the Minotaur's dungeon reached through a portal, bonfire
## checkpoints, enemies per biome and two bosses. Scenery and characters from
## SmallScaleInt's fantasy pack (licensed, res://local/fantasy/); bosses,
## music and sounds from Flare (CC-BY-SA 3.0).
## Map cell (i, j) is drawn at ((i - j) * 48, (i + j) * 24): screen up is
## toward cell (0, 0). The T key opens a menu to teleport to every place.

const TW := 96.0
const TH := 48.0
const W := 96  # the open world is W x W cells
const HALL := 22  # the dungeon hall is HALL x HALL cells...
const HALL_AT := Vector2(140, 0)  # ...placed apart from the world

## Remembered across reloads: where the hero comes back after dying, and
## which bosses are already dead.
static var spawn_place := "prairie"
static var defeated := {}

## The biome keys are prairie (south), ruins (west), "snow" (east, now a pine
## forest) and "caves" (north, now the dead lands).
static var fantasy := false  # the pack's art is there
## Camera distance chosen in the pause menu (kept across reloads).
static var zoom_choice := 0
const ZOOM_NAMES := ["éloignée", "moyenne", "proche"]
static var BIOMES := {}
static var PLACES := {}

const FANTASY_BIOMES := {
	"prairie": {"name": "Plaine de l'Aube", "music": "overworld_theme",
		"ambience": "environment/bird_twitter_loop", "light": Color(0.9, 0.88, 0.82), "torch": 0.3},
	"ruins": {"name": "Ruines d'Hélos", "music": "magical_theme",
		"ambience": "environment/wind_loop", "light": Color(0.86, 0.76, 0.62), "torch": 0.4},
	"snow": {"name": "Forêt des Cimes", "music": "forest_theme",
		"ambience": "environment/forest_owl_loop", "light": Color(0.66, 0.74, 0.7), "torch": 0.5},
	"caves": {"name": "Terres mortes", "music": "unrest_theme",
		"ambience": "environment/raven_loop", "light": Color(0.6, 0.52, 0.56), "torch": 0.6},
	"dungeon": {"name": "Labyrinthe d'Astérion", "music": "dungeon_theme",
		"ambience": "environment/cave_wind_loop", "light": Color(0.42, 0.38, 0.46), "torch": 0.7},
}
## Places: bonfires (and the teleport menu). Cells are in world coordinates.
const PLACE_CELLS := {
	"prairie": Vector2(78, 78), "ruins": Vector2(22, 60), "snow": Vector2(60, 24), "caves": Vector2(32, 34),
	"dungeon": HALL_AT + Vector2(18.5, 18.5),
}
## Boss arenas: centre cell, radius in cells, where the teleport menu drops you.
const ARENAS := {
	"minotaur": {"center": HALL_AT + Vector2(6.5, 6.5), "radius": 4.6, "label": "Boss : Astérion, le Minotaure",
		"entry": HALL_AT + Vector2(11.5, 11.5)},
	"wyvern_water": {"center": Vector2(80, 14), "radius": 5.0, "label": "Boss : Glacevive, la Wyverne",
		"entry": Vector2(73, 21)},
}
## The lake (east of the start, in the plain) and the village (south-west).
const LAKE_CENTER := Vector2(86, 63)
const LAKE_RADIUS := Vector2(6.5, 5.0)
const VILLAGE := Rect2(59, 79, 16, 14)  # cells kept for the village
## Houses: first cell, length along j (they are 2 cells wide), look.
const HOUSES := [
	[Vector2(61, 81), 3, "slate"], [Vector2(65, 80), 2, "timber"], [Vector2(61, 86), 2, "tiles"],
	[Vector2(66, 87), 3, "slate"], [Vector2(70, 83), 2, "timber"], [Vector2(70, 88), 2, "grey"],
]
const HOUSE_LOOKS := {  # wall, wall with a window, roof
	"slate": ["Wall D1", "Wall D7", "Roof D"], "tiles": ["Wall D1", "Wall D7", "Roof C"],
	"timber": ["Wall G1", "Wall G7", "Roof C"], "grey": ["Wall F1", "Wall F7", "Roof D"],
}
const WINDMILL := Vector2(58.5, 91.5)
const PORTAL_IN := Vector2(16, 18)  # in the north, to the dungeon
const PORTAL_OUT := HALL_AT + Vector2(20.5, 15.5)  # in the dungeon, back

## The four turns of the pack's tiles ("Tree A1" -> "Tree A1_N", ..._E, _S, _W).
static func _turns(names: Array) -> Array:
	var out := []
	for n in names:
		for t in ["_N", "_E", "_S", "_W"]:
			out.append(n + t)
	return out

static func _series(prefix: String, from: int, to: int, suffix := "") -> Array:
	var out := []
	for k in range(from, to + 1):
		out.append("%s%d%s" % [prefix, k, suffix])
	return out

## Per biome: tileset, floors, floor patches (where a noise is high), ground
## overlays (flat, walked over), scenery [names, collision radius (0 = walk
## through), weight], scenery density, and the enemies [type, count].
func _theme_fantasy() -> Dictionary:
	return {
		"tilesets": {"fantasy": "res://local/fantasy/tiles/"},
		"zoom": 2.0 / 3.0,  # the pack's tiles at their real size (128 px wide)
		"prairie": {"set": "fantasy", "floors": _turns(["Ground A2"]), "patches": _turns(["Ground A18"]),
			"overlays": _turns(_series("Ground A", 6, 12) + ["Ground A22", "Ground A23", "Ground A24"])
				+ _turns(_series("Flora A", 1, 7)), "density": 0.075,
			"decor": [[_turns(["Tree A1", "Tree A2", "Tree A3"]), 9, 6], [_turns(["Tree B1", "Tree B2", "Tree B3"]), 7, 2],
				[_turns(["Tree D1", "Tree D2"]), 8, 1], [_turns(["Stone A1", "Stone A2", "Stone A3"]), 8, 1.2],
				[_turns(_series("Flora B", 1, 6)), 0, 3], [["Misc A3_S", "Misc A4_S", "Misc B3_S", "Misc E2_S",
				"Misc E3_S", "Misc E4_S", "Misc B6_S"], 10, 0.5]],
			"enemies": [["pack/brigand_a", 4], ["pack/brigand_b", 3], ["pack/brigand_c", 3]]},
		"ruins": {"set": "fantasy", "floors": _turns(["Ground J1"]), "patches": _turns(["Ground H1", "Ground H4", "Ground H9"]),
			"overlays": _turns(_series("Ground J", 5, 8) + _series("Ground E", 2, 9)), "density": 0.07,
			"decor": [[_turns(["Tree C1"]), 9, 5], [_turns(["Tree E1", "Tree E3"]), 7, 1.5],
				[_turns(["Stone A13", "Stone A14", "Stone A15", "Stone A4", "Stone A5"]), 8, 1.5],
				[_turns(["Wall A6", "Wall A19", "Wall A20"]), 9, 1.5], [_turns(["Wall A8", "Wall A9", "Wall A17"]), 9, 1],
				[["Misc C1_S", "Misc C5_S", "Misc C6_S", "Misc C7_S"], 9, 0.6],
				[["Misc E5_S", "Misc E6_S", "Misc E7_S", "Misc E9_S"], 0, 1.5]],
			"enemies": [["pack/skeleton_a", 4], ["pack/skeleton_c", 3], ["pack/brigand_b", 2]]},
		"snow": {"set": "fantasy", "floors": _turns(["Ground A18"]), "patches": _turns(["Ground A2"]),
			"overlays": _turns(["Ground A20", "Ground A21", "Ground A10", "Ground A11"]), "density": 0.1,
			"decor": [[_turns(["Tree D1", "Tree D2", "Tree D3"]), 9, 8], [_turns(["Stone A1", "Stone A2", "Stone A10"]), 9, 2],
				[_turns(["Tree A4"]), 5, 0.6], [_turns(["Stone A16"]), 7, 0.25], [_turns(_series("Flora B", 1, 6)), 0, 2]],
			"enemies": [["pack/skeleton_a", 3], ["pack/brigand_a", 3], ["pack/skeleton_c", 2]]},
		"caves": {"set": "fantasy", "floors": _turns(["Ground C3", "Ground I9"]), "patches": _turns(["Ground B1", "Ground B4"]),
			"overlays": _turns(_series("Ground E", 10, 15)), "density": 0.08,
			"decor": [[_turns(["Tree E1", "Tree E3"]), 7, 5], [_turns(["Tree E2", "Tree E4", "Tree E5"]), 8, 2],
				[_turns(["Stone A17", "Stone A18", "Stone A19"]), 9, 2], [_turns(["Stone A21", "Stone A22"]), 7, 0.6],
				[_turns(["Stone A8"]), 12, 0.15], [["Misc C12_S", "Misc C13_S"], 8, 0.3]],
			"enemies": [["pack/skeleton_b", 4], ["pack/skeleton_a", 3]]},
		"dungeon": {"set": "fantasy", "floors": _turns(["Ground D1"]), "arena": _turns(["Ground H10", "Ground H11"]),
			"bones": [], "enemies": [["pack/skeleton_c", 3], ["pack/skeleton_b", 2]]},
	}

var world: Node2D
var player: Player
var boss: Boss  # the boss being fought (for the HUD)
var hud
var music: Music
var cam: Camera2D
var _floor: TileMapLayer
var _water: TileMapLayer
var _sources := {}  # "tileset:id" -> TileSet source id
var _anchors := {}  # tileset -> its tiles.json (atlas rects and anchors)
var _pages := {}  # tileset -> atlas textures
var theme: Dictionary
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _bonfires := {}  # place -> Bonfire
var _bosses := {}  # model -> Boss
var _sealed := {}  # model -> barrier node
var _enemies: Array = []
var _blocked := {}  # cells kept free of scenery
var _biome := ""
var _ambience: AudioStreamPlayer
var _modulate: CanvasModulate
var _torch: PointLight2D
var _ended := false
var _active_t := 0.0
var _menu: GameMenu
var _map_screen: CanvasLayer
var _menu_guard := 0  # physics frame until which Esc/Tab cannot reopen a menu
## The map (one pixel per cell, coloured by biome; scenery darker), for the map screen.
var map_image := Image.create(W, W, false, Image.FORMAT_RGBA8)
var hall_image := Image.create(HALL, HALL, false, Image.FORMAT_RGBA8)
const MAP_COLORS := {
	"water": Color(0.2, 0.42, 0.55), "roof": Color(0.55, 0.25, 0.18),
	"prairie": Color(0.38, 0.5, 0.2), "ruins": Color(0.62, 0.52, 0.24), "snow": Color(0.18, 0.32, 0.2),
	"caves": Color(0.3, 0.22, 0.16), "dungeon": Color(0.3, 0.29, 0.3),
}

# The old single-level names, used by the test scripts.
var start_pos := Vector2.ZERO
var arena_center := Vector2.ZERO
var arena_radius := 0.0
var world_rect := Rect2()

static func cell_pos(i: float, j: float) -> Vector2:
	return Vector2((i - j) * TW / 2.0, (i + j) * TH / 2.0)

static func to_cell(p: Vector2) -> Vector2:
	return Vector2((p.y / (TH / 2.0) + p.x / (TW / 2.0)) / 2.0, (p.y / (TH / 2.0) - p.x / (TW / 2.0)) / 2.0)

static func cell_of(v: Vector2) -> Vector2:
	return cell_pos(v.x, v.y)

func _ready() -> void:
	setup_inputs()
	_rng.seed = 11
	_noise.seed = 4
	_noise.frequency = 0.02
	fantasy = ResourceLoader.exists("res://local/fantasy/tiles/atlas_0.png")
	if not fantasy:
		_missing_art()
		return
	theme = _theme_fantasy()
	BIOMES = FANTASY_BIOMES
	PLACES = {}
	for place in PLACE_CELLS:
		PLACES[place] = {"label": BIOMES[place].name + (" (départ)" if place == "prairie" else ""),
			"cell": PLACE_CELLS[place]}
	for t in theme.tilesets:
		var dir: String = theme.tilesets[t]
		_anchors[t] = JSON.parse_string(FileAccess.get_file_as_string(dir + "tiles.json"))
		var pages := []
		for k in 4:
			var path := dir + "atlas_%d.png" % k
			if not ResourceLoader.exists(path):
				break
			pages.append(load(path))
		_pages[t] = pages
	world_rect = Rect2(-W * TW / 2.0 - 40, -300, W * TW + 80, W * TH + 340)
	start_pos = cell_of(PLACES.prairie.cell) + Vector2(0, 30)
	arena_center = cell_of(ARENAS.minotaur.center)
	arena_radius = ARENAS.minotaur.radius * TW / sqrt(2.0)

	_preload()
	_build_floor_layer()
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	_build_world()
	_build_dungeon()
	for place in PLACES:
		var b := Bonfire.new()
		b.position = cell_of(PLACES[place].cell)
		world.add_child(b)
		var wood := _tile("fantasy", "FirePlace", Vector2.ZERO, b)
		wood.show_behind_parent = true
		_fx("flame", Vector2(0, -4), b).scale *= 1.4
		var glow := PointLight2D.new()
		glow.texture = _light_texture()
		glow.color = Color(1.0, 0.65, 0.3)
		glow.energy = 0.9
		glow.texture_scale = 1.2
		glow.position = Vector2(0, -12)
		b.add_child(glow)
		_bonfires[place] = b
	_make_portal(PORTAL_IN, PORTAL_OUT + Vector2(-1.5, 0), "Labyrinthe d'Astérion")
	_make_portal(PORTAL_OUT, PORTAL_IN + Vector2(1.5, 1.5), "Grottes d'ambre")

	player = Player.new()
	player.position = cell_of(PLACES[spawn_place].cell) + Vector2(0, 56)
	world.add_child(player)
	cam = Camera2D.new()
	cam.position = Vector2(0, -20)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.zoom = Vector2.ONE * _zoom()
	player.add_child(cam)
	Fx.camera = cam
	player.died.connect(_on_player_died)

	_spawn_enemies()
	_spawn_bosses()

	_modulate = CanvasModulate.new()
	add_child(_modulate)
	_torch = PointLight2D.new()
	_torch.texture = _light_texture()
	_torch.color = Color(1.0, 0.85, 0.7)
	_torch.texture_scale = 1.6
	_torch.position = Vector2(0, -20)
	player.add_child(_torch)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -8.0
	add_child(_ambience)
	music = Music.new()
	add_child(music)
	_build_hud()
	_update_area()
	_update_biome(true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--showcase="):
			var sc: Node = load("res://tools/showcase.gd").new()
			sc.main = self
			sc.out = a.trim_prefix("--showcase=")
			add_child(sc)
		if a.begins_with("--profile="):
			var pr: Node = load("res://tools/profile.gd").new()
			pr.main = self
			pr.out = a.trim_prefix("--profile=")
			add_child(pr)
		if a.begins_with("--autotest="):
			var t: Node = load("res://tools/autotest.gd").new()
			t.main = self
			t.out = a.trim_prefix("--autotest=")
			add_child(t)

## Everything that would otherwise load in the middle of the game (enemy
## and boss animations, music, ambiences) is loaded now, at the start.
static var _ambience_cache := {}

func _preload() -> void:
	var models := {}
	for b in ["prairie", "ruins", "snow", "caves", "dungeon"]:
		for e in theme[b].enemies:
			models[e[0]] = true
	for m in ARENAS:
		models[m] = true
	for m in models:
		HdSprite.preload_flare(m)
	for b in BIOMES:
		Music.stream_of(BIOMES[b].music)
		_ambience_stream(BIOMES[b].ambience)
	for t in Music.TRACKS:
		Music.stream_of(t)

func _ambience_stream(name: String) -> AudioStreamOggVorbis:
	if not _ambience_cache.has(name):
		var amb: AudioStreamOggVorbis = load("res://assets/flare_audio/soundfx/%s.ogg" % name).duplicate()
		amb.loop = true
		_ambience_cache[name] = amb
	return _ambience_cache[name]

## Without the pack's art (private assets repo not checked out in local/),
## there is nothing to draw the world with: say so.
func _missing_art() -> void:
	var l := Label.new()
	l.text = "Graphismes absents : le dossier local/ (dépôt privé souls-like-assets) n'est pas là."
	l.position = Vector2(40, 160)
	add_child(l)

# --- tiles -----------------------------------------------------------------

func _tile(tileset: String, id: Variant, at: Vector2, parent: Node, z: int = 0) -> Sprite2D:
	# All the tiles of a tileset share one atlas: the renderer can batch them.
	var s := Sprite2D.new()
	var a: Array = _anchors[tileset].tiles[str(id)]  # [page, x, y, w, h, ax, ay]
	s.texture = _pages[tileset][int(a[0])]
	s.region_enabled = true
	s.region_rect = Rect2(a[1], a[2], a[3], a[4])
	s.centered = false
	s.offset = -Vector2(a[5], a[6])
	s.scale = Vector2.ONE / float(_anchors[tileset].get("res", 1))
	s.position = at
	s.z_index = z
	parent.add_child(s)
	return s

## A solid piece of scenery: a tile plus a small collision at its base.
func _solid(tileset: String, id: Variant, at: Vector2, radius: float) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.position = at
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	b.add_child(cs)
	world.add_child(b)
	_tile(tileset, id, Vector2.ZERO, b)
	return b

## Floors go into one isometric TileMapLayer (cheap to draw, even huge).
func _build_floor_layer() -> void:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	var res := float(_anchors.values()[0].res)  # tiles are stored at res x their size
	ts.tile_size = Vector2i(int(TW * res), int(TH * res))
	# One atlas source per tileset: the floor tiles on a grid (floors.png).
	for tileset in _anchors:
		var meta: Dictionary = _anchors[tileset]
		var src := TileSetAtlasSource.new()
		src.texture = load(theme.tilesets[tileset] + "floors.png")
		src.texture_region_size = Vector2i(int(meta.floor_cell[0]), int(meta.floor_cell[1]))
		var sid := ts.add_source(src)
		var cols := int(meta.floor_cols)
		for id in meta.floors:
			var k := int(meta.floors[id])
			var at := Vector2i(k % cols, k / cols)
			src.create_tile(at)
			_sources["%s:%s" % [tileset, id]] = [sid, at]
	_floor = TileMapLayer.new()
	_floor.tile_set = ts
	_floor.z_index = -10
	_floor.scale = Vector2.ONE / res
	add_child(_floor)
	_floor.position = cell_pos(0.5, 0.5) - _floor.map_to_local(Vector2i.ZERO) / res
	# Water lies under the ground layer: the earth blocks around it show their
	# sides over it, like banks.
	_water = TileMapLayer.new()
	_water.tile_set = ts
	_water.z_index = -11
	_water.scale = _floor.scale
	_water.position = _floor.position
	add_child(_water)

func _set_floor(i: int, j: int, tileset: String, id: Variant) -> void:
	var src: Array = _sources["%s:%s" % [tileset, str(id)]]
	_floor.set_cell(Vector2i(i, j), src[0], src[1])

func _pick(names: Array) -> String:
	return names[_rng.randi() % names.size()]

# --- the open world --------------------------------------------------------

## Which biome a world cell belongs to: prairie to the south (bottom of
## the screen), snow to the east, ruins to the west, caves to the north;
## borders wander with a noise.
func biome_at(i: float, j: float) -> String:
	var u := i - j + _noise.get_noise_2d(i * 3.0, j * 3.0) * 14.0
	var v := i + j - W + _noise.get_noise_2d(j * 3.0 + 400.0, i * 3.0) * 14.0
	if v > 18.0:
		return "prairie"
	if u > 20.0:
		return "snow"
	if u < -20.0:
		return "ruins"
	return "caves"

func _keep_clear(c: Vector2, radius: float) -> void:
	for di in range(-int(radius) - 1, int(radius) + 2):
		for dj in range(-int(radius) - 1, int(radius) + 2):
			if Vector2(di, dj).length() <= radius:
				_blocked[Vector2i(int(c.x) + di, int(c.y) + dj)] = true

func is_water(i: float, j: float) -> bool:
	var d := Vector2(i + 0.5, j + 0.5) - LAKE_CENTER
	var k := (d.x / LAKE_RADIUS.x) ** 2 + (d.y / LAKE_RADIUS.y) ** 2
	return k + _noise.get_noise_2d(i * 9.0 + 300.0, j * 9.0) * 0.5 < 1.0

func _near_water(i: int, j: int) -> bool:
	for di in [-1, 0, 1]:
		for dj in [-1, 0, 1]:
			if is_water(i + di, j + dj):
				return true
	return false

func _build_world() -> void:
	for p in PLACES.values():
		_keep_clear(p.cell, 3.5)
	for i in range(int(VILLAGE.position.x), int(VILLAGE.end.x)):
		for j in range(int(VILLAGE.position.y), int(VILLAGE.end.y)):
			_blocked[Vector2i(i, j)] = true
	_keep_clear(WINDMILL, 2.0)
	for model in ARENAS:
		_keep_clear(ARENAS[model].center, ARENAS[model].radius + 1.5)
	_keep_clear(PORTAL_IN, 2.5)
	for i in W:
		for j in W:
			var b := biome_at(i + 0.5, j + 0.5)
			var bt: Dictionary = theme[b]
			var tileset: String = bt.set
			var c := Vector2i(i, j)
			if is_water(i, j):
				_water.set_cell(c, _sources["fantasy:Water"][0], _sources["fantasy:Water"][1])
				map_image.set_pixel(i, j, MAP_COLORS.water)
				_blocked[c] = true
				_water_cells.append(c)
				continue
			var patch := _noise.get_noise_2d(i * 7.0 + 900.0, j * 7.0) > 0.3
			if _near_water(i, j):
				_set_floor(i, j, tileset, _pick(_turns(["Ground A1"])))  # earth banks
				_blocked[c] = true
			else:
				_set_floor(i, j, tileset, _pick(bt.patches if patch else bt.floors))
			var col: Color = MAP_COLORS[b]
			map_image.set_pixel(i, j, col.darkened(0.12) if patch else col)
			var edge := i < 3 or j < 3 or i >= W - 3 or j >= W - 3
			if _blocked.has(c):
				continue
			if not bt.overlays.is_empty() and _rng.randf() < 0.22:  # grass tufts, pebbles...
				_tile(tileset, _pick(bt.overlays), cell_of(Vector2(i + 0.5, j + 0.5)), _floor_decor())
			var dense := _noise.get_noise_2d(i * 5.0 + 50.0, j * 5.0 - 70.0) > 0.25  # woods, rock fields
			var chance: float = bt.density * (2.5 if dense else 1.0)
			if edge:
				chance = 0.75
			if _rng.randf() < chance:
				_decor(b, tileset, Vector2(i + _rng.randf_range(0.2, 0.8), j + _rng.randf_range(0.2, 0.8)), edge)
	# The world's limits.
	var top := cell_pos(0, 0)
	var left := cell_pos(0, W)
	var right := cell_pos(W, 0)
	var bottom := cell_pos(W, W)
	for seg in [[top, left], [top, right], [left, bottom], [right, bottom]]:
		_edge(seg[0], seg[1])
	_build_lake()
	_build_village()
	# Standing stones around the wyvern's arena.
	for k in 10:
		var c: Vector2 = ARENAS.wyvern_water.center + Vector2.RIGHT.rotated(k * TAU / 10.0) * (ARENAS.wyvern_water.radius + 0.6)
		_solid("fantasy", "Stone A14_S" if k % 2 == 0 else "Stone A15_S", cell_of(c), 9)

var _water_cells: Array[Vector2i] = []

## The lake: water cells block the way; ripples and foam float on them.
func _build_lake() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)
	for c in _water_cells:
		var poly := CollisionPolygon2D.new()
		poly.polygon = PackedVector2Array([cell_pos(c.x, c.y), cell_pos(c.x + 1, c.y),
			cell_pos(c.x + 1, c.y + 1), cell_pos(c.x, c.y + 1)])
		body.add_child(poly)
		if _rng.randf() < 0.3:
			var fx := _fx(["ripple_a", "ripple_b", "ripple_ring"][_rng.randi() % 3], cell_of(Vector2(c) + Vector2(0.5, 0.5)), _floor_decor())
			fx.modulate = Color(1, 1, 1, 0.55)

## The village: stone and timber houses around a paved square with a well,
## stalls, carts and hay; a windmill on its edge.
func _build_village() -> void:
	var square := Vector2(66, 85)
	for i in range(-3, 4):
		for j in range(-2, 3):
			if Vector2(i, j).length() < 3.2:
				_set_floor(int(square.x) + i, int(square.y) + j, "fantasy", _pick(_turns(["Ground H1", "Ground H4", "Ground H9"])))
	for h in HOUSES:
		_house(int(h[0].x), int(h[0].y), h[1], h[2])
	_solid("fantasy", "Misc B42_S", cell_of(square + Vector2(0.5, 0.5)), 14)  # the well
	for p in [["Misc B17_S", Vector2(68.5, 82.5), 14], ["Misc B18_S", Vector2(64, 84), 14], ["Misc B14_S", Vector2(69, 86.5), 12],
			["Misc A4_S", Vector2(64.6, 82.6), 9], ["Misc B3_S", Vector2(68.4, 91.3), 9], ["Misc E3_S", Vector2(60.5, 90.5), 10],
			["Misc E2_S", Vector2(63.5, 91.5), 9], ["Misc B6_S", Vector2(73.5, 81), 12], ["Misc B44_S", Vector2(64.2, 87.8), 4],
			["Misc B45_S", Vector2(67.8, 82.2), 4], ["Misc A9_S", Vector2(72.5, 86.5), 8], ["Misc B11_S", Vector2(59.8, 84.5), 12]]:
		_solid("fantasy", p[0], cell_of(p[1]), p[2])
	var mill := StaticBody2D.new()
	mill.position = cell_of(WINDMILL)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26
	cs.shape = circle
	mill.add_child(cs)
	world.add_child(mill)
	_fx("windmill", Vector2.ZERO, mill).speed_scale = 0.6

## A house 2 cells wide and `length` deep: walls on the edges of its cells,
## a door and windows on the front, a pitched roof raised on the walls with a
## hipped end. Drawn as one piece (the parts in a fixed order), sorted with
## the characters by its centre.
func _house(i0: int, j0: int, length: int, look: String) -> void:
	var parts: Array = HOUSE_LOOKS[look]
	var i1 := i0 + 1
	var j1 := j0 + length - 1
	var house := StaticBody2D.new()
	house.collision_layer = 1
	house.position = cell_pos(i0 + 1, j0 + length / 2.0)
	world.add_child(house)
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([cell_pos(i0, j0) - house.position, cell_pos(i1 + 1, j0) - house.position,
		cell_pos(i1 + 1, j1 + 1) - house.position, cell_pos(i0, j1 + 1) - house.position])
	house.add_child(poly)
	var raise := 128.0 / float(_anchors.fantasy.res)  # the walls' height
	var at := func(i: int, j: int, up: float = 0.0) -> Vector2:
		return cell_pos(i + 0.5, j + 0.5) - house.position + Vector2(0, -up)
	for j in range(j0, j1 + 1):  # back walls
		_tile("fantasy", parts[0] + "_W", at.call(i0, j), house)
	for i in range(i0, i1 + 1):
		_tile("fantasy", parts[0] + "_N", at.call(i, j0), house)
	for i in range(i0, i1 + 1):  # front walls
		_tile("fantasy", parts[1] + "_S" if i == i0 else parts[0] + "_S", at.call(i, j1), house)
	for j in range(j0, j1 + 1):
		_tile("fantasy", (parts[1] if j == j1 else parts[0]) + "_E", at.call(i1, j), house)
	_tile("fantasy", "Door A1_E", at.call(i1, j0 + (length - 1) / 2), house)
	for j in range(j0, j1 + 1):  # the roof
		_tile("fantasy", parts[2] + "1_W", at.call(i0, j, raise), house)
		_tile("fantasy", parts[2] + "1_E", at.call(i1, j, raise), house)
	for i in range(i0, i1 + 1):
		_tile("fantasy", parts[2] + "6_E", at.call(i, j1, raise), house)
	for i in range(i0, i1 + 1):
		for j in range(j0, j1 + 1):
			map_image.set_pixel(i, j, MAP_COLORS.roof)

var _floor_decor_node: Node2D

func _floor_decor() -> Node2D:
	if _floor_decor_node == null:
		_floor_decor_node = Node2D.new()
		_floor_decor_node.z_index = -9
		add_child(_floor_decor_node)
	return _floor_decor_node

func _decor(b: String, tileset: String, c: Vector2, solid_only: bool) -> void:
	var table: Array = theme[b].decor
	var total := 0.0
	for e in table:
		if not solid_only or e[1] > 0:
			total += e[2]
	var roll := _rng.randf() * total
	for e in table:
		if solid_only and e[1] == 0:
			continue
		roll -= e[2]
		if roll <= 0.0:
			var id := _pick(e[0])
			if e[1] > 0:
				_solid(tileset, id, cell_of(c), e[1])
				var px := Vector2i(clampi(int(c.x), 0, W - 1), clampi(int(c.y), 0, W - 1))
				map_image.set_pixelv(px, map_image.get_pixelv(px).darkened(0.45))
			else:
				_tile(tileset, id, cell_of(c), world)
			return

func _edge(a: Vector2, b: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = a
	seg.b = b
	cs.shape = seg
	body.add_child(cs)
	add_child(body)

# --- the Minotaur's dungeon --------------------------------------------------

func _hall(i: float, j: float) -> Vector2:
	return cell_of(HALL_AT + Vector2(i, j))

func _build_dungeon() -> void:
	var d: Dictionary = theme.dungeon
	var set: String = d.set
	var arena_c: Vector2 = ARENAS.minotaur.center - HALL_AT
	for i in HALL:
		for j in HALL:
			var cobble := Vector2(i + 0.5, j + 0.5).distance_to(arena_c) < ARENAS.minotaur.radius + 0.6
			_set_floor(int(HALL_AT.x) + i, int(HALL_AT.y) + j, set, _pick(d.arena if cobble else d.floors))
			hall_image.set_pixel(i, j, MAP_COLORS.dungeon.lightened(0.15) if cobble else MAP_COLORS.dungeon)
	var top := _hall(0, 0)
	var left := _hall(0, HALL)
	var right := _hall(HALL, 0)
	var bottom := _hall(HALL, HALL)
	for seg in [[top, left], [top, right], [left, bottom], [right, bottom]]:
		_edge(seg[0], seg[1])
	var pillar := "Wall A19_S"
	var statues := ["Misc C5_S", "Misc C6_S", "Misc C1_S", "Stone A14_S"]
	var tombs := ["Misc C9_S", "Misc C9_S", "Misc C9_S"]
	# Back walls: heavy stone blocks along the two far edges.
	for k in range(-1, HALL):
		_tile(set, "Wall A16_S", _hall(-0.5, k + 0.5), world)
		if k >= 0:
			_tile(set, "Wall A16_S", _hall(k + 0.5, -0.5), world)
	for k in 10:
		var a := k * TAU / 10.0
		var c := arena_c + Vector2.RIGHT.rotated(a) * (ARENAS.minotaur.radius + 0.9)
		if absf(wrapf(a - PI / 4.0, -PI, PI)) < 0.5 or c.x < 0.6 or c.y < 0.6:
			continue
		_solid(set, pillar, _hall(c.x, c.y), 12)
	var spots := [Vector2(1.2, 14), Vector2(14, 1.2), Vector2(1.2, 18), Vector2(18, 1.2)]
	for k in 4:
		_solid(set, statues[k], _hall(spots[k].x, spots[k].y), 16)
	var tomb_spots := [Vector2(15, 15), Vector2(9.5, 16.5), Vector2(17, 9)]
	for k in 3:
		_solid(set, tombs[k], _hall(tomb_spots[k].x, tomb_spots[k].y), 14)
	for c in [Vector2(17, 20), Vector2(20, 17), Vector2(14, 9), Vector2(3, 10), Vector2(10, 3)]:
		_brazier(_hall(c.x, c.y))
	if not d.bones.is_empty():
		for k in 26:
			var c := Vector2(_rng.randf_range(1, HALL - 1), _rng.randf_range(1, HALL - 1))
			if c.distance_to(Vector2(18.5, 18.5)) < 2.5:
				continue
			_tile(set, _pick(d.bones), _hall(c.x, c.y), world).z_index = -5

func _brazier(at: Vector2) -> void:
	var b := _solid("fantasy", "Misc C8_S", at, 10)
	_fx("flame", Vector2(0, -22), b).z_index = 1
	var light := PointLight2D.new()
	light.texture = _light_texture()
	light.color = Color(1.0, 0.6, 0.3)
	light.energy = 0.9
	light.texture_scale = 1.4
	light.position = Vector2(0, -20)
	b.add_child(light)

## An animated prop of the pack (fire, torch, portal), looping.
var _fx_meta := {}
var _fx_frames := {}

func _fx(name: String, at: Vector2, parent: Node) -> AnimatedSprite2D:
	if _fx_meta.is_empty():
		_fx_meta = JSON.parse_string(FileAccess.get_file_as_string("res://local/fantasy/fx/fx.json"))
	var m: Dictionary = _fx_meta[name]
	if not _fx_frames.has(name):
		var strip: Texture2D = load("res://local/fantasy/fx/%s.png" % name)
		var sf := SpriteFrames.new()
		sf.set_animation_speed("default", 14.0)
		for k in int(m.frames):
			var at_tex := AtlasTexture.new()
			at_tex.atlas = strip
			at_tex.region = Rect2(k * m.w, 0, m.w, m.h)
			sf.add_frame("default", at_tex)
		_fx_frames[name] = sf
	var s := AnimatedSprite2D.new()
	s.sprite_frames = _fx_frames[name]
	s.centered = false
	s.offset = -Vector2(m.ax, m.ay)
	s.scale = Vector2.ONE / float(_anchors.fantasy.res)
	s.position = at
	s.play()
	s.frame = randi() % int(m.frames)
	parent.add_child(s)
	return s

func _light_texture() -> GradientTexture2D:
	var g := GradientTexture2D.new()
	g.width = 256
	g.height = 256
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(1, 1, 1, 1))
	g.gradient.set_color(1, Color(1, 1, 1, 0))
	return g

# --- portals ---------------------------------------------------------------

func _make_portal(at: Vector2, to: Vector2, label: String) -> void:
	var a := Area2D.new()
	a.position = cell_of(at)
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 16
	cs.shape = c
	a.add_child(cs)
	add_child(a)
	var ring := _tile("fantasy", "Misc C14_S", Vector2.ZERO, world)
	ring.position = a.position + Vector2(0, -2)
	_fx("portal", a.position + Vector2(0, -1), world)
	var glow := PointLight2D.new()
	glow.texture = _light_texture()
	glow.color = Color(0.5, 0.6, 1.0)
	glow.energy = 0.8
	glow.texture_scale = 0.8
	a.add_child(glow)
	a.body_entered.connect(func(body):
		if body == player and not player.dead:
			Sfx.flare(self, "environment/teleporter", null, -4.0)
			teleport_to_cell(to, label))

## Moves the hero, with a flash. Used by portals and the teleport menu.
func teleport_to_cell(c: Vector2, label: String = "") -> void:
	player._set_lock(null)
	player.global_position = cell_of(c) + Vector2(0, 56)
	player.velocity = Vector2.ZERO
	cam.reset_smoothing()
	Fx.ring(world, player.global_position, 4, 40, Color(0.6, 0.7, 1.0), 0.5)
	_update_area()
	_update_biome(true)
	if label != "":
		hud.flash_message(label, Color(0.85, 0.9, 1.0))
		get_tree().create_timer(2.0).timeout.connect(func(): if not _ended: hud.message = "")

func in_dungeon(p: Vector2 = Vector2.INF) -> bool:
	var c := to_cell(player.global_position if p == Vector2.INF else p)
	return c.x >= HALL_AT.x - 2

## The camera stays inside the area the hero is in.
func _update_area() -> void:
	var r: Rect2
	if in_dungeon():
		r = Rect2(_hall(0, HALL).x - 40, _hall(0, 0).y - 260, HALL * TW + 80, HALL * TH + 300)
	else:
		r = world_rect
	cam.limit_left = int(r.position.x)
	cam.limit_top = int(r.position.y)
	cam.limit_right = int(r.end.x)
	cam.limit_bottom = int(r.end.y)

# --- enemies and bosses ------------------------------------------------------

func _spawn_enemies() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for b in ["prairie", "ruins", "snow", "caves"]:
		for entry in theme[b].enemies:
			var placed := 0
			var tries := 0
			while placed < entry[1] and tries < 500:
				tries += 1
				var c := Vector2(rng.randf_range(6, W - 6), rng.randf_range(6, W - 6))
				if biome_at(c.x, c.y) != b or _blocked.has(Vector2i(c)):
					continue
				if c.distance_to(PLACES[b].cell) < 7.0:
					continue
				_add_enemy(entry[0], c)
				placed += 1
	var guards := []
	for e in theme.dungeon.enemies:
		for k in e[1]:
			guards.append(e[0])
	var spots := [Vector2(14, 16), Vector2(16, 12.5), Vector2(11, 14), Vector2(13, 10.5), Vector2(10, 11)]
	for k in mini(guards.size(), spots.size()):
		_add_enemy(guards[k], HALL_AT + spots[k])

func _add_enemy(model: String, c: Vector2) -> void:
	var s := SkeletonEnemy.new()
	s.flare_name = model
	s.position = cell_of(c)
	s.player = player
	world.add_child(s)
	_enemies.append(s)

func _spawn_bosses() -> void:
	for model in ARENAS:
		if defeated.has(model):
			continue
		var b := Boss.new()
		b.flare_name = model
		b.position = cell_of(ARENAS[model].center) + Vector2(0, -20)
		b.player = player
		world.add_child(b)
		b.died.connect(_on_boss_died.bind(model))
		b.phase_changed.connect(func(_p): music.play("boss_phase2", 2.5))
		_bosses[model] = b
	boss = _bosses.get("minotaur")

func arena_entry() -> Vector2:
	return cell_of(ARENAS.minotaur.entry)

func _arena_dist(p: Vector2, model: String) -> float:
	return to_cell(p).distance_to(ARENAS[model].center)

# --- game flow ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	Fx.update_shake(delta)
	if _ended:
		return
	# Only the enemies near the hero think (big map).
	_active_t -= delta
	if _active_t <= 0.0:
		_active_t = 0.4
		for e in _enemies + _bosses.values():
			if is_instance_valid(e):
				var near: bool = e.global_position.distance_to(player.global_position) < 800.0
				e.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
		_update_area()
		_update_biome(false)
	var near_fire := ""
	for place in _bonfires:
		if player.global_position.distance_to(_bonfires[place].global_position) < 40:
			near_fire = place
	var fighting := not _sealed.is_empty()
	hud.hint = "[E] Se reposer au feu" if near_fire != "" and not fighting and not player.dead else ""
	if near_fire != "" and not fighting and Input.is_action_just_pressed("interact"):
		_rest(near_fire)
	for model in _bosses:
		var b: Boss = _bosses[model]
		if is_instance_valid(b) and not b.dead and not _sealed.has(model) \
				and _arena_dist(player.global_position, model) < ARENAS[model].radius - 0.8:
			_close_arena(model)
	if Input.is_action_just_pressed("teleport") and not player.dead:
		open_teleport_menu()
	if Engine.get_physics_frames() <= _menu_guard:
		pass
	elif Input.is_action_just_pressed("pause") and not player.dead:
		open_pause_menu()
	elif Input.is_action_just_pressed("map") and not player.dead:
		open_map()
	if Input.is_action_just_pressed("help"):
		hud.show_help = not hud.show_help
	if Input.is_action_just_pressed("sound_set"):
		Fx.float_text(world, player.global_position + Vector2(0, -60), Sfx.toggle_set(self), Color(0.8, 0.9, 1))
	if Input.is_action_just_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))

func _rest(place: String) -> void:
	spawn_place = place
	player.rest()
	_spawn_enemies()
	Sfx.play(self, "bonfire", null, -2.0, 0.0)
	Fx.ring(world, _bonfires[place].global_position, 4, 60, Color(1, 0.7, 0.3), 0.6)
	hud.flash_message("Feu allumé", Color(1, 0.75, 0.35), "Santé et fioles restaurées. Les ennemis sont revenus.")
	get_tree().create_timer(2.0).timeout.connect(func(): if not _ended: hud.message = "")

## Music, ambience and light follow the biome the hero is in.
func _update_biome(force: bool) -> void:
	var b := "dungeon" if in_dungeon() else biome_at(to_cell(player.global_position).x, to_cell(player.global_position).y)
	if b == _biome and not force:
		return
	var changed := b != _biome
	_biome = b
	var info: Dictionary = BIOMES[b]
	if _sealed.is_empty():
		music.play(info.music, 2.0, -12.0)
	var amb := _ambience_stream(info.ambience)
	if _ambience.stream != amb:
		_ambience.stream = amb
		_ambience.play()
	var t := create_tween().set_parallel(true)
	t.tween_property(_modulate, "color", info.light, 1.5 if not force else 0.01)
	t.tween_property(_torch, "energy", info.torch, 1.5 if not force else 0.01)
	if changed and not force and hud.message == "":
		hud.flash_message(info.name, Color(0.9, 0.85, 0.7))
		get_tree().create_timer(2.0).timeout.connect(func(): if not _ended and hud.message == info.name: hud.message = "")

## A ring of blue light closes a boss arena.
func _close_arena(model: String) -> void:
	var a: Dictionary = ARENAS[model]
	boss = _bosses[model]
	var ring := StaticBody2D.new()
	ring.collision_layer = 1
	var pts := PackedVector2Array()
	for k in 49:
		var c: Vector2 = a.center + Vector2.RIGHT.rotated(k * TAU / 48.0) * (a.radius + 0.3)
		pts.append(cell_of(c))
	for k in 48:
		var cs := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = pts[k]
		seg.b = pts[k + 1]
		cs.shape = seg
		ring.add_child(cs)
	var line := Node2D.new()
	line.z_index = -4
	line.draw.connect(func():
		line.draw_polyline(pts, Color(0.4, 0.6, 1.0, 0.85), 3.0)
		line.draw_polyline(pts, Color(0.6, 0.8, 1.0, 0.35), 9.0))
	ring.add_child(line)
	add_child(ring)
	_sealed[model] = ring
	Fx.shake(5)
	Sfx.play(self, "parry", null, -2.0, 0.0)
	boss.activate()
	music.play("boss_phase1", 1.0)
	hud.boss = boss
	hud.show_boss = true
	hud.flash_message(boss.boss_name, Color(0.9, 0.8, 0.6))
	get_tree().create_timer(2.0).timeout.connect(func(): if not _ended: hud.message = "")

func _on_boss_died(model: String) -> void:
	defeated[model] = true
	Fx.hitstop(get_tree(), 0.25)
	hud.show_boss = false
	music.stop(2.5)
	get_tree().create_timer(1.2).timeout.connect(func(): Sfx.play(self, "victory", null, -2.0, 0.0))
	hud.flash_message("ENNEMI ABATTU", Color(0.95, 0.8, 0.35), _bosses[model].boss_name)
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(_sealed.get(model)):
			_sealed[model].queue_free()
		_sealed.erase(model)
		if not _ended:
			hud.message = ""
		_biome = ""
		_update_biome(true))

func _on_player_died() -> void:
	_ended = true
	hud.flash_message("VOUS ÊTES MORT", Color(0.75, 0.08, 0.06))
	music.stop(1.0)
	Sfx.play(self, "you_died", null, -2.0, 0.0)
	get_tree().create_timer(3.5).timeout.connect(get_tree().reload_current_scene)

# --- HUD and teleport menu -----------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var vignette := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.05, 1.05)
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.02, 0.0, 0.05, 0.0))
	grad.gradient.set_color(1, Color(0.02, 0.0, 0.05, 0.75))
	grad.gradient.add_point(0.55, Color(0.02, 0.0, 0.05, 0.0))
	vignette.texture = grad
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vignette)
	hud = Control.new()
	hud.set_script(load("res://scripts/hud.gd"))
	layer.add_child(hud)
	hud.player = player
	hud.boss = boss
	get_tree().create_timer(12.0).timeout.connect(func(): hud.show_help = false)

## Every place you can jump to: bonfires, then the boss arenas.
func teleport_places() -> Array:
	var out := []
	for place in PLACES:
		out.append([PLACES[place].label, PLACES[place].cell])
	out.append(["Village", Vector2(67, 91.5)])
	out.append(["Lac", Vector2(82, 70)])
	for model in ARENAS:
		out.append([ARENAS[model].label + (" (vaincu)" if defeated.has(model) else ""), ARENAS[model].entry])
	return out

func _open_menu(title: String, items: Array, footer: String = "") -> void:
	if _menu:
		_menu.queue_free()
	get_tree().paused = true
	_menu = GameMenu.open(self, title, items, footer)
	_menu.closed.connect(func():
		_menu = null
		_menu_guard = Engine.get_physics_frames() + 2
		get_tree().paused = false)

func _close_menu() -> void:
	if _menu:
		_menu.close()

## The camera zoom: far = the theme's (the pack's tiles at their real size).
func _zoom() -> float:
	return [float(theme.zoom), 1.0, 1.3][zoom_choice]

## Esc / Start: the pause menu.
func open_pause_menu() -> void:
	var muted := AudioServer.is_bus_mute(0)
	_open_menu("Pause", [
		["Reprendre", _close_menu],
		["Carte", open_map],
		["Téléportation…", open_teleport_menu],
		["Aide à l'écran : " + ("affichée" if hud.show_help else "masquée"), func():
			hud.show_help = not hud.show_help
			open_pause_menu()],
		["Son : " + ("coupé" if muted else "activé"), func():
			AudioServer.set_bus_mute(0, not muted)
			open_pause_menu()],
		["Caméra : " + ZOOM_NAMES[zoom_choice], func():
			zoom_choice = (zoom_choice + 1) % ZOOM_NAMES.size()
			cam.zoom = Vector2.ONE * _zoom()
			open_pause_menu()],
		["Bruitages : " + Sfx.sounds_label(), func():
			Sfx.toggle_set(self)
			open_pause_menu()],
		["", null],
		["Créateur de personnage", func():
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/creator.tscn")],
		["Recommencer au dernier feu", func():
			get_tree().paused = false
			get_tree().reload_current_scene()],
	] + ([] if OS.has_feature("web") else [["Quitter le jeu", func(): get_tree().quit()]]),
		"Échap ou B pour reprendre")

## Tab / Select, or from the pause menu: the map of the world.
func open_map() -> void:
	_close_menu()
	if _map_screen:
		return
	get_tree().paused = true
	_map_screen = CanvasLayer.new()
	_map_screen.layer = 10
	_map_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_map_screen)
	var view := MapView.new()
	view.game = self
	_map_screen.add_child(view)
	view.closed.connect(func():
		_map_screen.queue_free()
		_map_screen = null
		_menu_guard = Engine.get_physics_frames() + 2
		get_tree().paused = false)

## T, or from the pause menu: jump to any bonfire or boss.
func open_teleport_menu() -> void:
	if not _sealed.is_empty():
		_close_menu()
		hud.flash_message("Impossible pendant un combat de boss", Color(1, 0.6, 0.5))
		get_tree().create_timer(1.5).timeout.connect(func(): if not _ended: hud.message = "")
		return
	var items := []
	for p in teleport_places():
		items.append([p[0], _teleport_pick.bind(p)])
	_open_menu("Téléportation (test)", items, "Chiffre, clic ou A pour partir · Échap ou B pour fermer")

func _teleport_pick(p: Array) -> void:
	_close_menu()
	teleport_to_cell(p[1], p[0])

# --- controls ------------------------------------------------------------

static func setup_inputs() -> void:
	var map := {
		"move_up": [[KEY_W], [KEY_UP], ["axis", JOY_AXIS_LEFT_Y, -1.0], ["btn", JOY_BUTTON_DPAD_UP]],
		"move_down": [[KEY_S], [KEY_DOWN], ["axis", JOY_AXIS_LEFT_Y, 1.0], ["btn", JOY_BUTTON_DPAD_DOWN]],
		"move_left": [[KEY_A], [KEY_LEFT], ["axis", JOY_AXIS_LEFT_X, -1.0], ["btn", JOY_BUTTON_DPAD_LEFT]],
		"move_right": [[KEY_D], [KEY_RIGHT], ["axis", JOY_AXIS_LEFT_X, 1.0], ["btn", JOY_BUTTON_DPAD_RIGHT]],
		"roll": [[KEY_SPACE], ["btn", JOY_BUTTON_B]],
		"block": [[KEY_L], [KEY_SHIFT], ["btn", JOY_BUTTON_LEFT_SHOULDER]],
		"attack_light": [[KEY_J], ["mouse", MOUSE_BUTTON_LEFT], ["btn", JOY_BUTTON_X], ["btn", JOY_BUTTON_RIGHT_SHOULDER]],
		"attack_heavy": [[KEY_K], ["mouse", MOUSE_BUTTON_RIGHT], ["btn", JOY_BUTTON_Y], ["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
		"heal": [[KEY_R], ["axis", JOY_AXIS_TRIGGER_LEFT, 1.0]],
		"interact": [[KEY_E], ["btn", JOY_BUTTON_A]],
		"help": [[KEY_H]],
		"pause": [[KEY_ESCAPE], [KEY_P], ["btn", JOY_BUTTON_START]],
		"mute": [[KEY_M]],
		"sound_set": [[KEY_N]],
		"teleport": [[KEY_T]],
		"lock": [[KEY_I], ["mouse", MOUSE_BUTTON_MIDDLE], ["btn", JOY_BUTTON_RIGHT_STICK]],
		"lock_left": [[KEY_U], ["mouse", MOUSE_BUTTON_WHEEL_UP]],
		"lock_right": [[KEY_O], ["mouse", MOUSE_BUTTON_WHEEL_DOWN]],
		"map": [[KEY_TAB], ["btn", JOY_BUTTON_BACK]],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.3)
		for e in map[action]:
			var ev: InputEvent
			if e[0] is String and e[0] == "axis":
				ev = InputEventJoypadMotion.new()
				ev.axis = e[1]
				ev.axis_value = e[2]
			elif e[0] is String and e[0] == "btn":
				ev = InputEventJoypadButton.new()
				ev.button_index = e[1]
			elif e[0] is String and e[0] == "mouse":
				ev = InputEventMouseButton.new()
				ev.button_index = e[1]
			else:
				ev = InputEventKey.new()
				ev.physical_keycode = e[0]  # physical: ZQSD on AZERTY = WASD on QWERTY
			InputMap.action_add_event(action, ev)
