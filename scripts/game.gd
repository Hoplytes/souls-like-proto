extends Node2D
class_name Game
## The open world (laid out by WorldMap): four regions, highlands, a river
## and its lake, roads, thick forests, a village with its fields, a ruined
## city, camps; the Minotaur's dungeon reached through a cave, bonfire
## checkpoints, enemies per region and two bosses. Scenery and characters from
## SmallScaleInt's fantasy pack (licensed, res://local/fantasy/); bosses,
## music and sounds from Flare (CC-BY-SA 3.0).
## Map cell (i, j) is drawn at ((i - j) * 48, (i + j) * 24): screen up is
## toward cell (0, 0). The T key opens a menu to teleport to every place.

const TW := 96.0
const TH := 48.0
const W := WorldMap.W  # the open world is W x W cells
const HALL := 22  # the dungeon hall is HALL x HALL cells...
const HALL_AT := Vector2(172, 0)  # ...placed apart from the world

## Remembered across reloads: where the hero comes back after dying, and
## which bosses are already dead.
static var spawn_place := "prairie"
static var defeated := {}

## The biome keys are prairie (south), ruins (west), "snow" (east, now a pine
## forest) and "caves" (north, now the dead lands).
static var fantasy := false  # the pack's art is there
## Camera distance chosen in the pause menu (kept across reloads).
static var zoom_choice := 1
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
	"prairie": WorldMap.PLACES.prairie, "ruins": WorldMap.PLACES.ruins, "snow": WorldMap.PLACES.snow,
	"caves": WorldMap.PLACES.caves, "dungeon": HALL_AT + Vector2(18.5, 18.5),
}
## Boss arenas: centre cell, radius in cells, where the teleport menu drops you.
const ARENAS := {
	"minotaur": {"center": HALL_AT + Vector2(6.5, 6.5), "radius": 4.6, "label": "Boss : Astérion, le Minotaure",
		"entry": HALL_AT + Vector2(11.5, 11.5)},
	"wyvern_water": {"center": WorldMap.WYVERN, "radius": WorldMap.WYVERN_RADIUS, "label": "Boss : Glacevive, la Wyverne",
		"entry": WorldMap.WYVERN + Vector2(-6.0, 6.5)},
}
const HOUSE_LOOKS := {  # wall, wall with a window, roof
	"slate": ["Wall D1", "Wall D7", "Roof D"], "tiles": ["Wall D1", "Wall D7", "Roof C"],
	"timber": ["Wall G1", "Wall G7", "Roof C"], "grey": ["Wall F1", "Wall F7", "Roof D"],
}
const PORTAL_IN := WorldMap.PORTAL  # at the foot of the cave, to the dungeon
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

## Per region: floors, floor patches (where a noise is high), road tiles,
## ground overlays (tiles), trees (and rarer ones), bushes (solid), flora
## (walked through), rocks, breakables, and the enemies [type, count].
func _theme_fantasy() -> Dictionary:
	return {
		"tilesets": {"fantasy": "res://local/fantasy/tiles/"},
		"zoom": 2.0 / 3.0,  # the pack's tiles at their real size (128 px wide)
		"prairie": {"floors": _turns(["Ground A2"]), "patches": _turns(["Ground A18"]),
			"road": _turns(["Ground A1", "Ground A1", "Ground A1", "Ground I9"]),
			"overlays": _turns(_series("Ground A", 6, 12) + ["Ground A22", "Ground A23", "Ground A24"] + _series("Flora A", 1, 7)),
			"trees": _turns(["Tree A1", "Tree A2", "Tree A3"]), "rare_trees": _turns(["Tree D1", "Tree D2", "Tree A4"]),
			"bushes": _turns(["Tree B1", "Tree B2", "Tree B3"]), "flora": _turns(_series("Flora B", 1, 6)),
			"rocks": _turns(["Stone A1", "Stone A2", "Stone A3"]),
			"breakables": ["break_grass", "break_grass_small", "break_tree_green"],
			"enemies": [["pack/brigand_a", 5], ["pack/brigand_b", 4], ["pack/brigand_c", 4]]},
		"ruins": {"floors": _turns(["Ground J1"]), "patches": _turns(["Ground I9"]),
			"road": _turns(["Ground A1", "Ground A1", "Ground A1", "Ground I9"]),
			"overlays": _turns(_series("Ground J", 5, 8) + _series("Ground E", 2, 9)),
			"trees": _turns(["Tree C1"]), "rare_trees": _turns(["Tree E1", "Tree E3", "Tree A2"]),
			"bushes": _turns(["Tree B1", "Tree B3"]), "flora": ["Misc E5_S", "Misc E6_S", "Misc E7_S", "Misc E9_S"],
			"rocks": _turns(["Stone A13", "Stone A4", "Stone A5", "Stone A9", "Stone A11"]),
			"breakables": ["break_tree_yellow", "break_stones", "break_jar"],
			"enemies": [["pack/skeleton_a", 5], ["pack/skeleton_c", 4], ["pack/brigand_b", 3]]},
		"snow": {"floors": _turns(["Ground A18"]), "patches": _turns(["Ground A2"]),
			"road": _turns(["Ground A1", "Ground A1", "Ground A1", "Ground I9"]),
			"overlays": _turns(["Ground A19", "Ground A20", "Ground A21", "Ground A10", "Ground A11"]),
			"trees": _turns(["Tree D1", "Tree D2", "Tree D3"]), "rare_trees": _turns(["Tree A4", "Tree E2", "Tree A1"]),
			"bushes": _turns(["Tree B1", "Tree B2"]), "flora": _turns(_series("Flora B", 1, 6)),
			"rocks": _turns(["Stone A1", "Stone A2", "Stone A10", "Stone A16"]),
			"breakables": ["break_rocks", "break_woodpile", "break_grass"],
			"enemies": [["pack/skeleton_a", 4], ["pack/brigand_a", 4], ["pack/skeleton_c", 3]]},
		"caves": {"floors": _turns(["Ground C3"]), "patches": _turns(["Ground B6"]),
			"road": _turns(["Ground B3"]),
			"overlays": _turns(_series("Ground E", 10, 15)),
			"trees": _turns(["Tree E1", "Tree E3"]), "rare_trees": _turns(["Tree E2", "Tree E4", "Tree E5"]),
			"bushes": _turns(["Stone A17", "Stone A18", "Stone A19"]), "flora": _turns(["Stone A21", "Stone A22", "Stone A12"]),
			"rocks": _turns(["Stone A17", "Stone A18", "Stone A19", "Stone A10"]),
			"breakables": ["break_stones", "break_rocks", "break_crate"],
			"enemies": [["pack/skeleton_b", 5], ["pack/skeleton_a", 4]]},
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
var _floor_top: TileMapLayer  # grass over the earth blocks of the lake's banks
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
	"water": Color(0.2, 0.42, 0.55), "roof": Color(0.55, 0.25, 0.18), "planks": Color(0.5, 0.36, 0.2),
	"road": Color(0.55, 0.42, 0.28), "paved": Color(0.62, 0.6, 0.56), "field": Color(0.78, 0.66, 0.3),
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
	map = WorldMap.new()
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
	_floor_top = TileMapLayer.new()
	_floor_top.tile_set = ts
	_floor_top.z_index = -10
	_floor_top.scale = _floor.scale
	_floor_top.position = _floor.position
	add_child(_floor_top)

func _set_floor(i: int, j: int, tileset: String, id: Variant) -> void:
	var src: Array = _sources["%s:%s" % [tileset, str(id)]]
	_floor.set_cell(Vector2i(i, j), src[0], src[1])

func _pick(names: Array) -> String:
	return names[_rng.randi() % names.size()]

# --- the open world --------------------------------------------------------

## The geography (regions, relief, water, roads, forests, places): see WorldMap.
var map: WorldMap

## Region of a world cell.
func biome_at(i: float, j: float) -> String:
	return map.region_at(Vector2i(floori(i), floori(j)))

func level_at(c: Vector2i) -> int:
	return 0 if map.ramps.has(c) else map.level_at(c)

## Scenery is grouped by blocks of CHUNK x CHUNK cells: each block is a
## y-sorted node (sorted together with the characters) hidden while it is
## off screen, with one static body holding its collisions.
const CHUNK := 8
var _chunks := {}  # Vector2i -> Node2D
var _chunk_bodies := {}  # Vector2i -> StaticBody2D
var _tall := {}  # Vector2i -> Array of the block's trees: faded when in front of the hero
var _faded: Array = []
var _occupied := {}  # cells holding a solid prop (no enemy spawns there)
var _field_cells := {}
var _water_cells: Array[Vector2i] = []
var _overlay: TileMapLayer  # grass tufts, pebbles, flowers: tiles, not nodes
var _cull_t := 0.0
var _fade_t := 0.0
static var _shapes := {}  # radius -> shared CircleShape2D

func _chunk_key(cell: Vector2) -> Vector2i:
	return Vector2i(floori(cell.x / CHUNK), floori(cell.y / CHUNK))

func _chunk(cell: Vector2) -> Node2D:
	var k := _chunk_key(cell)
	if not _chunks.has(k):
		var n := Node2D.new()
		n.y_sort_enabled = true
		world.add_child(n)
		_chunks[k] = n
		var b := StaticBody2D.new()
		b.collision_layer = 1
		add_child(b)
		_chunk_bodies[k] = b
		_tall[k] = []
	return _chunks[k]

func _shape(radius: float) -> CircleShape2D:
	var r := snappedf(radius, 0.5)
	if not _shapes.has(r):
		var c := CircleShape2D.new()
		c.radius = r
		_shapes[r] = c
	return _shapes[r]

## A collision circle at a world position, in the block's body.
func _collide(at: Vector2, radius: float) -> void:
	var cs := CollisionShape2D.new()
	cs.shape = _shape(radius)
	cs.position = at
	_chunk(to_cell(at))
	_chunk_bodies[_chunk_key(to_cell(at))].add_child(cs)

## A wall segment between two world points, in the block's body.
func _wall(a: Vector2, b: Vector2) -> void:
	if a.distance_to(b) < 1.0:
		return
	var cs := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = a
	seg.b = b
	cs.shape = seg
	var k := _chunk_key(to_cell((a + b) / 2.0))
	_chunk(to_cell((a + b) / 2.0))
	_chunk_bodies[k].add_child(cs)

## A piece of scenery at a cell position (fractional cell coordinates): the
## pack's tile, a collision at its foot if radius > 0, one level higher on
## the highlands; `tall` ones fade while they hide the hero.
func _prop(name: String, cell: Vector2, radius: float, tall := false) -> Sprite2D:
	var at := cell_of(cell)
	var s := _tile("fantasy", name, at, _chunk(cell))
	if level_at(Vector2i(floori(cell.x), floori(cell.y))) == 1:
		s.offset.y -= LEVEL_HEIGHT * float(_anchors.fantasy.res)
		s.z_index = 1
	if radius > 0.0:
		_collide(at, radius)
		_occupied[Vector2i(floori(cell.x), floori(cell.y))] = true
	if tall:
		_tall[_chunk_key(cell)].append(s)
	return s

## A solid piece of scenery at a world position (dungeon, places).
func _solid(_tileset: String, id: Variant, at: Vector2, radius: float) -> Sprite2D:
	return _prop(str(id), to_cell(at), radius)

func _overlay_at(c: Vector2i, name: String) -> void:
	var src: Array = _sources["fantasy:" + name]
	_overlay.set_cell(c, src[0], src[1])

func _build_world() -> void:
	_overlay = TileMapLayer.new()
	_overlay.tile_set = _floor.tile_set
	_overlay.z_index = -9
	_overlay.scale = _floor.scale
	_overlay.position = _floor.position
	add_child(_overlay)
	var walkable_water := {}  # bridges and the pier: planks over the water
	for c in map.bridges:
		walkable_water[c] = true
	for c in map.pier:
		walkable_water[c] = true
	for r in map.fields:
		for i in range(r.position.x, r.end.x):
			for j in range(r.position.y, r.end.y):
				_field_cells[Vector2i(i, j)] = true
	var water_src: Array = _sources["fantasy:Water"]
	for i in W:
		for j in W:
			var c := Vector2i(i, j)
			var region := map.region_at(c)
			var t: Dictionary = theme[region]
			var col: Color = MAP_COLORS[region]
			if map.is_water(c) or walkable_water.has(c):
				_water.set_cell(c, water_src[0], water_src[1])
				if walkable_water.has(c):
					_set_floor(i, j, "fantasy", _pick(_turns(["Ground F3"])))
					map_image.set_pixel(i, j, MAP_COLORS.planks)
				else:
					_water_cells.append(c)
					map_image.set_pixel(i, j, MAP_COLORS.water)
				continue
			var road := int(map.road[WorldMap.idx(c)])
			var patch := _noise.get_noise_2d(i * 7.0 + 900.0, j * 7.0) > 0.3
			if road == 2:
				_set_floor(i, j, "fantasy", _pick(_turns(["Ground H1", "Ground H4", "Ground H9"])))
				col = MAP_COLORS.paved
			elif road == 1:
				_set_floor(i, j, "fantasy", _pick(t.road))
				col = MAP_COLORS.road
			elif _field_cells.has(c):
				_set_floor(i, j, "fantasy", _pick(_turns(["Ground J1"])))
				col = MAP_COLORS.field
			else:
				_set_floor(i, j, "fantasy", _pick(t.patches if patch else t.floors))
				if patch:
					col = col.darkened(0.1)
			# Banks: an earth block (its side shows over the water) under the grass.
			if road == 0 and _beside_water(c, walkable_water):
				var top: Array = _sources["fantasy:" + _pick(t.floors)]
				_floor_top.set_cell(c, top[0], top[1])
				_set_floor(i, j, "fantasy", _pick(_turns(["Ground A1"])))
			if level_at(c) == 1:
				col = col.lightened(0.16)
			var d := map.forest_at(c)
			if d > 0.62:
				col = col.darkened(0.35)
			elif d > 0.42:
				col = col.darkened(0.18)
			map_image.set_pixel(i, j, col)
			# Ground cover, as tiles; on the roads, grass spilling over their edges.
			if road == 1 and region != "caves":
				var edge := _road_edge(c, region)
				if edge != "":
					_overlay_at(c, edge)
			if road == 0 and level_at(c) == 0 and not map.ramps.has(c):
				if _field_cells.has(c):
					if _rng.randf() < 0.75:
						_overlay_at(c, _pick(_turns(_series("Ground J", 5, 8))))
				elif not map.is_reserved(c) and _rng.randf() < 0.18 + d * 0.25:
					_overlay_at(c, _pick(t.overlays))
			if map.is_free(c) and not _field_cells.has(c):
				_scenery(c, t)
	_soften_dead_lands()
	# The world's limits.
	var top := cell_pos(0, 0)
	var left := cell_pos(0, W)
	var right := cell_pos(W, 0)
	var bottom := cell_pos(W, W)
	for seg in [[top, left], [top, right], [left, bottom], [right, bottom]]:
		_edge(seg[0], seg[1])
	_build_relief()
	_build_lake(walkable_water)
	_build_village()
	_build_fields()
	_build_city()
	_build_camp()
	_build_graveyard()
	# Standing stones around the wyvern's arena.
	for k in 10:
		var c: Vector2 = ARENAS.wyvern_water.center + Vector2.RIGHT.rotated(k * TAU / 10.0) * (ARENAS.wyvern_water.radius + 0.6)
		_prop("Stone A14_S" if k % 2 == 0 else "Stone A15_S", c, 9)

## Grass spilling over a road's edge: a strip along one side, a half-cell
## over two sides meeting at a corner. Sides: 0 = north-east (toward j - 1),
## 1 = south-east (i + 1), 2 = south-west (j + 1), 3 = north-west (i - 1).
const SIDES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const GRASS_EDGES := {  # region -> [strips by side], [halves by first side of the pair (s, s + 1)]
	"prairie": [["Ground A4_N", "Ground A4_E", "Ground A4_S", "Ground A4_W"], ["Ground A3_N", "Ground A3_E", "Ground A3_S", "Ground A3_W"]],
	"ruins": [["Ground J3_N", "Ground J3_E", "Ground J3_S", "Ground J3_W"], ["Ground J2_N", "Ground J2_E", "Ground J2_S", "Ground J2_W"]],
	"snow": [["Ground A20_E", "Ground A20_S", "Ground A20_W", "Ground A20_N"], ["Ground A19_E", "Ground A19_S", "Ground A19_W", "Ground A19_N"]],
}

func _grassy(n: Vector2i) -> bool:
	return WorldMap.inside(n) and map.road[WorldMap.idx(n)] == 0 and not map.is_water(n) \
		and not map.bridges.has(n) and level_at(n) == 0 and not map.ramps.has(n)

func _road_edge(c: Vector2i, region: String) -> String:
	var sides := []
	for k in 4:
		sides.append(_grassy(c + SIDES[k]))
	var set: Array = GRASS_EDGES.get(region, GRASS_EDGES.prairie)
	for k in 4:  # two sides meeting at a corner
		if sides[k] and sides[(k + 1) % 4]:
			return set[1][k]
	for k in 4:
		if sides[k]:
			return set[0][k]
	return ""

## In the dead lands, dark earth meeting the light (roads, stony patches)
## turns half light toward it, instead of a staircase of cells.
const DARK_TO_LIGHT := ["Ground C2_N", "Ground C2_E", "Ground C2_S", "Ground C2_W"]  # light over sides (k, k + 1)

func _light_ground(c: Vector2i) -> bool:
	if not WorldMap.inside(c) or map.region_at(c) != "caves" or map.is_water(c):
		return false
	return map.road[WorldMap.idx(c)] > 0 or _noise.get_noise_2d(c.x * 7.0 + 900.0, c.y * 7.0) > 0.3

func _soften_dead_lands() -> void:
	for i in W:
		for j in W:
			var c := Vector2i(i, j)
			if map.region_at(c) != "caves" or _light_ground(c) or map.is_water(c) or level_at(c) == 1 \
					or _field_cells.has(c):
				continue
			var light := []
			for k in 4:
				light.append(_light_ground(c + SIDES[k]))
			var pick := -1
			for k in 4:
				if light[k] and light[(k + 1) % 4]:
					pick = k
			if pick < 0:
				for k in 4:
					if light[k]:
						pick = k
						break
			if pick >= 0:
				_set_floor(i, j, "fantasy", DARK_TO_LIGHT[pick])

func _beside_water(c: Vector2i, walkable_water: Dictionary) -> bool:
	for n in [c + Vector2i(1, 0), c - Vector2i(1, 0), c + Vector2i(0, 1), c - Vector2i(0, 1)]:
		if map.is_water(n) and not walkable_water.has(n):
			return true
	return false

## Trees, bushes, rocks and breakables of a free cell, by the density of the
## forest there: thick woods (a tree on most cells), open woodland, open land.
func _scenery(c: Vector2i, t: Dictionary) -> void:
	var d := map.forest_at(c)
	var r := _rng.randf()
	var at := Vector2(c) + Vector2(_rng.randf_range(0.25, 0.75), _rng.randf_range(0.25, 0.75))
	var tree := func() -> void:
		_prop(_pick(t.rare_trees if _rng.randf() < 0.12 else t.trees), at, 8.0, true)
	if d > 0.62:
		if r < 0.64:
			tree.call()
		elif r < 0.78:
			_prop(_pick(t.bushes), at, 6.0)
		elif r < 0.88:
			_prop(_pick(t.flora), at, 0.0)
		elif r < 0.9:
			_breakable(_pick(t.breakables), cell_of(at), 7)
	elif d > 0.42:
		if r < 0.36:
			tree.call()
		elif r < 0.5:
			_prop(_pick(t.bushes), at, 6.0)
		elif r < 0.6:
			_prop(_pick(t.flora), at, 0.0)
		elif r < 0.64:
			_prop(_pick(t.rocks), at, 8.0, true)
		elif r < 0.665:
			_breakable(_pick(t.breakables), cell_of(at), 7)
	else:
		if r < 0.035:
			tree.call()
		elif r < 0.075:
			_prop(_pick(t.bushes), at, 6.0)
		elif r < 0.13:
			_prop(_pick(t.flora), at, 0.0)
		elif r < 0.16:
			_prop(_pick(t.rocks), at, 8.0, true)
		elif r < 0.175:
			_breakable(_pick(t.breakables), cell_of(at), 7)

## The lake and the river: water cells block the way; ripples float on them;
## a pier with boats at the landing.
func _build_lake(walkable_water: Dictionary) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)
	for c in _water_cells:
		var poly := CollisionPolygon2D.new()
		poly.polygon = PackedVector2Array([cell_pos(c.x, c.y), cell_pos(c.x + 1, c.y),
			cell_pos(c.x + 1, c.y + 1), cell_pos(c.x, c.y + 1)])
		body.add_child(poly)
		if _rng.randf() < 0.22:
			var fx := _fx(["ripple_a", "ripple_b", "ripple_ring"][_rng.randi() % 3], cell_of(Vector2(c) + Vector2(0.5, 0.5)), _chunk(Vector2(c)))
			fx.modulate = Color(1, 1, 1, 0.5)
			fx.z_index = -9
	# Planks over the water: their sides are open to the water, the rest walkable.
	for c in walkable_water:
		for side in [[Vector2i(0, -1), cell_pos(c.x, c.y), cell_pos(c.x + 1, c.y)],
				[Vector2i(0, 1), cell_pos(c.x, c.y + 1), cell_pos(c.x + 1, c.y + 1)],
				[Vector2i(-1, 0), cell_pos(c.x, c.y), cell_pos(c.x, c.y + 1)],
				[Vector2i(1, 0), cell_pos(c.x + 1, c.y), cell_pos(c.x + 1, c.y + 1)]]:
			var n: Vector2i = c + side[0]
			if map.is_water(n) and not walkable_water.has(n):
				_wall(side[1], side[2])
	if not map.pier.is_empty():
		var end: Vector2i = map.pier[map.pier.size() - 1]
		_tile("fantasy", "Misc B50_S", cell_of(Vector2(end) + Vector2(0.6, 1.6)), _chunk(Vector2(end)))
		_tile("fantasy", "Misc B49_S", cell_of(Vector2(end) + Vector2(-0.5, -1.4)), _chunk(Vector2(end)))
		_prop("Misc A9_S", Vector2(map.pier[0]) + Vector2(0.3, -0.6), 7)
		_breakable("break_crate", cell_of(Vector2(map.pier[0]) + Vector2(0.7, 1.4)), 6)

## The village: the square paved around its well, houses along the
## streets, stalls and carts, things to break.
func _build_village() -> void:
	var v := WorldMap.VILLAGE
	for i in range(-4, 5):
		for j in range(-4, 5):
			if Vector2(i, j).length() < 3.6:
				_set_floor(int(v.x) + i, int(v.y) + j, "fantasy", _pick(_turns(["Ground H1", "Ground H4", "Ground H9"])))
	for h in map.houses + map.farm_houses:
		_house(h[0].x, h[0].y, h[1], h[2])
	_prop("Misc B42_S", v + Vector2(1.0, 1.0), 14)  # the well, where the streets cross
	var things := [["Misc B17_S", 14], ["Misc B18_S", 14], ["Misc B14_S", 12], ["Misc B6_S", 12], ["Misc B11_S", 12],
		["Misc A4_S", 9], ["Misc A9_S", 8], ["Misc B44_S", 4], ["Misc B45_S", 4], ["Misc B7_S", 8], ["Misc B26_S", 8]]
	var spots := [Vector2(-2.4, -2.2), Vector2(3.6, -2.0), Vector2(-2.2, 3.4), Vector2(3.4, 3.6), Vector2(-3.2, 0.6),
		Vector2(0.4, -3.4), Vector2(4.2, 0.4), Vector2(0.5, 4.3), Vector2(-1.2, -3.6), Vector2(2.6, 4.4), Vector2(-3.6, 2.4)]
	for k in things.size():
		var cell: Vector2 = v + spots[k]
		if map.road[WorldMap.idx(Vector2i(cell))] == 0:
			_prop(things[k][0], cell, things[k][1])
	var breakables := ["break_barrel_a", "break_barrel_b", "break_barrel_c", "break_jar", "break_crate", "break_woodpile", "break_straw"]
	for h in map.houses:
		var c: Vector2i = h[0]
		var spot := Vector2(c.x - 0.6, c.y + _rng.randf_range(0.3, h[1] - 0.3))  # behind the house
		if map.is_free(Vector2i(spot)) or map.is_reserved(Vector2i(spot)):
			if not _occupied.has(Vector2i(spot)) and map.road[WorldMap.idx(Vector2i(spot))] == 0:
				_breakable(_pick(breakables), cell_of(spot), 6)

## Fields of wheat inside wooden fences (a gate on their south-west side),
## haystacks, a scarecrow; the windmill by the first one.
func _build_fields() -> void:
	for n in map.fields.size():
		var r: Rect2i = map.fields[n]
		var gate := r.position.x + r.size.x / 2
		for i in range(r.position.x, r.end.x):
			for j in range(r.position.y, r.end.y):
				var c := Vector2(i + 0.5, j + 0.5)
				var node := _chunk(c)
				if j == r.position.y:
					_tile("fantasy", "Wall B7_N", cell_of(c), node)
					_wall(cell_pos(i, j), cell_pos(i + 1, j))
				if i == r.position.x:
					_tile("fantasy", "Wall B7_W", cell_of(c), node)
					_wall(cell_pos(i, j), cell_pos(i, j + 1))
				if i == r.end.x - 1:
					_tile("fantasy", "Wall B7_E", cell_of(c), node)
					_wall(cell_pos(i + 1, j), cell_pos(i + 1, j + 1))
				if j == r.end.y - 1 and i != gate:
					_tile("fantasy", "Wall B7_S", cell_of(c), node)
					_wall(cell_pos(i, j + 1), cell_pos(i + 1, j + 1))
		_prop("Misc E3_S" if n % 2 == 0 else "Misc E2_S", Vector2(r.position) + Vector2(1.5, 1.5), 10)
		_breakable("break_straw", cell_of(Vector2(r.end) - Vector2(1.5, 1.6)), 7)
		if r.size.x >= 6:
			_prop("Misc B57_S", Vector2(r.get_center()), 5)
		if n == 0:
			var mill := Vector2(r.end.x + 1.5, r.position.y + 1.0)
			if map.is_free(Vector2i(mill)):
				var node := Node2D.new()
				node.position = cell_of(mill)
				_chunk(mill).add_child(node)
				_collide(cell_of(mill), 26)
				_fx("windmill", Vector2.ZERO, node).speed_scale = 0.6

## The ruined city of Hélos: a plaza with its statue and colonnade, paved
## streets, and the broken walls of its houses.
func _build_city() -> void:
	var city := WorldMap.CITY
	_prop("Misc C1_S", city, 14)
	for k in 8:
		var a := k * TAU / 8.0
		if k % 4 == 1:
			continue  # fallen ones
		_prop("Wall A19_S" if k % 2 == 0 else "Wall A6_S", city + Vector2.RIGHT.rotated(a) * 3.4, 9, true)
	for k in 3:
		_prop(["Wall A8_S", "Wall A9_S", "Wall A17_S"][k], city + Vector2.RIGHT.rotated(k * 2.1 + 0.4) * 2.6, 8)
	var walls := ["Wall A1_", "Wall A4_", "Wall A5_", "Wall A7_", "Wall A1_"]
	for r in map.ruins_rooms:
		for i in range(r.position.x, r.end.x):
			for j in range(r.position.y, r.end.y):
				_set_floor(i, j, "fantasy", _pick(_turns(["Ground H1", "Ground H9"])))
				var c := Vector2(i + 0.5, j + 0.5)
				var node := _chunk(c)
				for side in [["N", j == r.position.y, cell_pos(i, j), cell_pos(i + 1, j)],
						["W", i == r.position.x, cell_pos(i, j), cell_pos(i, j + 1)],
						["E", i == r.end.x - 1, cell_pos(i + 1, j), cell_pos(i + 1, j + 1)],
						["S", j == r.end.y - 1, cell_pos(i, j + 1), cell_pos(i + 1, j + 1)]]:
					if side[1] and _rng.randf() < 0.68:
						var s := _tile("fantasy", _pick(walls) + side[0], cell_of(c), node)
						if side[0] in ["E", "S"]:
							_tall[_chunk_key(c)].append(s)
						_wall(side[2], side[3])
		var inner := Vector2(r.position) + Vector2(1.0, 1.0) + Vector2(_rng.randf() * (r.size.x - 2), _rng.randf() * (r.size.y - 2))
		_prop(["Wall A8_S", "Wall A9_S", "Wall A17_S"][_rng.randi() % 3], inner, 8)
		if _rng.randf() < 0.5:
			_breakable(["break_jar", "break_stones"][_rng.randi() % 2], cell_of(Vector2(r.end) - Vector2(1.4, 1.4)), 6)
		if _rng.randf() < 0.3:
			_prop("Tree C1_S", Vector2(r.position) + Vector2(r.size) * 0.5 + Vector2(0.3, -0.4), 8, true)

## The brigands' camp: tents around a fire, barricades, loot.
func _build_camp() -> void:
	var c := WorldMap.CAMP
	_campfire(c)
	for p in [["Misc B43_S", Vector2(-2.6, -1.4), 18], ["Misc B46_S", Vector2(1.6, -2.8), 16], ["Misc B41_S", Vector2(-2.4, 2.2), 12],
			["Misc B12_S", Vector2(2.8, 1.8), 12], ["Misc B44_S", Vector2(0.3, -1.8), 4], ["Misc B29_S", Vector2(3.6, -1.0), 10]]:
		_prop(p[0], c + p[1], p[2])
	for k in 7:
		var a := k * TAU / 7.0 + 0.3
		if k == 2:
			continue  # the way in
		_prop("Wall B5_" + ["N", "E", "S", "W"][k % 4], c + Vector2.RIGHT.rotated(a) * 4.3, 8)
	for p in [Vector2(-1.2, 3.0), Vector2(0.8, 3.1), Vector2(-3.4, 0.4)]:
		_breakable(["break_crate", "break_barrel_a", "break_woodpile"][randi() % 3], cell_of(c + p), 6)

## A graveyard in the dead lands: rows of headstones, a gallows, cages.
func _build_graveyard() -> void:
	var g := WorldMap.GRAVEYARD
	for i in range(-3, 4, 2):
		for j in range(-2, 3, 2):
			_prop(["Stone A4_S", "Stone A5_S", "Stone A13_S", "Stone A15_S"][_rng.randi() % 4], g + Vector2(i, j) + Vector2(0.5, 0.5), 5)
	_prop("Misc B29_S", g + Vector2(-3.6, -3.0), 10)
	_prop("Misc C12_S", g + Vector2(3.6, -2.8), 8)
	_prop("Misc C9_S", g + Vector2(3.4, 2.8), 9)
	_prop("Tree E1_S", g + Vector2(-3.8, 3.4), 7, true)

func _campfire(c: Vector2) -> void:
	var node := Node2D.new()
	node.position = cell_of(c)
	_chunk(c).add_child(node)
	_tile("fantasy", "FirePlace", Vector2.ZERO, node)
	_fx("flame", Vector2(0, -4), node).scale *= 1.3
	var glow := PointLight2D.new()
	glow.texture = _light_texture()
	glow.color = Color(1.0, 0.6, 0.3)
	glow.energy = 0.8
	glow.texture_scale = 1.1
	glow.position = Vector2(0, -12)
	node.add_child(glow)
	_collide(cell_of(c), 10)

## A house 2 cells wide and `length` deep: walls on the edges of its cells
## with a doorway on the front, a wooden floor and a few things inside, a
## pitched roof raised on the walls with a hipped end. The back walls are
## sorted by the house's back corner (the hero inside is always in front of
## them); the front walls and the roof form one piece that fades away while
## the hero is inside.
func _house(i0: int, j0: int, length: int, look: String) -> void:
	var parts: Array = HOUSE_LOOKS[look]
	var i1 := i0 + 1
	var j1 := j0 + length - 1
	var door_j := j0 + (length - 1) / 2
	var chunk := _chunk(Vector2(i0 + 1, j0 + length / 2.0))
	var back := Node2D.new()
	back.position = cell_pos(i0, j0)
	chunk.add_child(back)
	var front := Node2D.new()
	front.position = cell_pos(i0 + 1, j0 + length / 2.0)
	chunk.add_child(front)
	var raise := 128.0 / float(_anchors.fantasy.res)  # the walls' height
	var at := func(node: Node2D, i: int, j: int, up: float = 0.0) -> Vector2:
		return cell_pos(i + 0.5, j + 0.5) - node.position + Vector2(0, -up)
	for j in range(j0, j1 + 1):  # back walls
		_tile("fantasy", parts[0] + "_W", at.call(back, i0, j), back)
	for i in range(i0, i1 + 1):
		_tile("fantasy", parts[0] + "_N", at.call(back, i, j0), back)
	for i in range(i0, i1 + 1):  # front walls, a doorway on the front-right side
		_tile("fantasy", parts[1] + "_S" if i == i0 else parts[0] + "_S", at.call(front, i, j1), front)
	for j in range(j0, j1 + 1):
		if j != door_j:
			_tile("fantasy", (parts[1] if j == j1 else parts[0]) + "_E", at.call(front, i1, j), front)
	for j in range(j0, j1 + 1):  # the roof
		_tile("fantasy", parts[2] + "1_W", at.call(front, i0, j, raise), front)
		_tile("fantasy", parts[2] + "1_E", at.call(front, i1, j, raise), front)
	for i in range(i0, i1 + 1):
		_tile("fantasy", parts[2] + "6_E", at.call(front, i, j1, raise), front)
	# Walls as segments, open at the door.
	for sg in [[cell_pos(i0, j0), cell_pos(i1 + 1, j0)], [cell_pos(i0, j0), cell_pos(i0, j1 + 1)],
			[cell_pos(i0, j1 + 1), cell_pos(i1 + 1, j1 + 1)], [cell_pos(i1 + 1, j0), cell_pos(i1 + 1, door_j)],
			[cell_pos(i1 + 1, door_j + 1), cell_pos(i1 + 1, j1 + 1)]]:
		_wall(sg[0], sg[1])
	# Inside: planks, a table, something to break, a chest in the long ones.
	for i in range(i0, i1 + 1):
		for j in range(j0, j1 + 1):
			_set_floor(i, j, "fantasy", _pick(_turns(["Ground F1"])))
			_overlay.erase_cell(Vector2i(i, j))
			map_image.set_pixel(i, j, MAP_COLORS.roof)
	_prop("Misc B27_S", Vector2(i0 + 0.5, j0 + 0.5), 8)
	_breakable(["break_barrel_a", "break_jar", "break_crate"][(i0 + j0) % 3], cell_pos(i0 + 0.4, j1 + 0.6), 6)
	if length > 2:
		_prop("Chest A1_S", Vector2(i1 + 0.3, j0 + 0.4), 6)
	# Fade the front away while the hero is inside.
	var inside := Area2D.new()
	inside.collision_layer = 0
	inside.collision_mask = 2
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([cell_pos(i0, j0), cell_pos(i1 + 1, j0), cell_pos(i1 + 1, j1 + 1), cell_pos(i0, j1 + 1)])
	inside.add_child(poly)
	add_child(inside)
	inside.body_entered.connect(func(body):
		if body == player:
			create_tween().tween_property(front, "modulate:a", 0.12, 0.25))
	inside.body_exited.connect(func(body):
		if body == player:
			create_tween().tween_property(front, "modulate:a", 1.0, 0.25))

## A breakable piece of scenery (see Breakable) at a world position.
func _breakable(name: String, at: Vector2, radius: float = 8.0) -> Breakable:
	var b := Breakable.new()
	b.position = at
	b.radius = radius
	b.material_kind = "stone" if name in ["break_jar", "break_stones", "break_rocks"] \
		else ("soft" if name in ["break_grass", "break_grass_small", "break_straw", "break_tree_green", "break_tree_yellow"] else "wood")
	b.sprite = _fx(name, Vector2.ZERO, b)
	b.chips = func(fx_name: String, where: Vector2) -> void:
		var fx := _fx(fx_name, where, world)
		fx.frame = 0
		fx.sprite_frames.set_animation_loop("default", false)
		fx.animation_finished.connect(fx.queue_free)
	var cell := to_cell(at)
	if level_at(Vector2i(floori(cell.x), floori(cell.y))) == 1:
		b.sprite.position.y -= LEVEL_HEIGHT
		b.z_index = 1
	_chunk(cell).add_child(b)
	return b

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

## Blocks off screen are hidden (not drawn, not sorted).
func _cull_chunks() -> void:
	var view := get_viewport_rect().size / cam.zoom
	var center := cam.get_screen_center_position()
	# Tall things (trees, raised ones) reach up to ~230 units above their base.
	var r := Rect2(center - view / 2.0 - Vector2(70, 40), view + Vector2(140, 300))
	for k in _chunks:
		var bb := Rect2(cell_pos(k.x * CHUNK, k.y * CHUNK), Vector2.ZERO)
		bb = bb.expand(cell_pos((k.x + 1) * CHUNK, k.y * CHUNK)).expand(cell_pos(k.x * CHUNK, (k.y + 1) * CHUNK))
		bb = bb.expand(cell_pos((k.x + 1) * CHUNK, (k.y + 1) * CHUNK))
		_chunks[k].visible = r.intersects(bb)

func show_all_chunks() -> void:
	for k in _chunks:
		_chunks[k].visible = true

## Trees (and tall ruins) standing in front of the hero or of a nearby
## enemy turn see-through, and the hidden character is drawn over them.
var _occluded := {}  # actor -> true

func _fade_occluders() -> void:
	var now := []
	_occluded.clear()
	var actors := [player]
	for e in _enemies:
		if is_instance_valid(e) and not e.dead and e.process_mode != Node.PROCESS_MODE_DISABLED \
				and e.global_position.distance_to(player.global_position) < 420.0:
			actors.append(e)
	for a in actors:
		var p: Vector2 = a.global_position
		var k0 := _chunk_key(to_cell(p))
		var base_z := 1 if a.sprite.lift > LEVEL_HEIGHT * 0.5 else 0
		for di in [-1, 0, 1]:
			for dj in [-1, 0, 1]:
				for s in _tall.get(k0 + Vector2i(di, dj), []):
					var d: Vector2 = s.global_position - p
					if d.y > 2.0 and d.y < 125.0 and absf(d.x) < 56.0 and s.z_index == base_z:
						_occluded[a] = true
						if a == player and not s in now:
							now.append(s)
	for s in _faded:
		if is_instance_valid(s) and not s in now:
			s.modulate.a = 1.0
	for s in now:
		s.modulate.a = 0.45
	_faded = now

# --- relief: plateaus, cliffs, ramps -------------------------------------------

## The highlands are one level up (a cliff of the pack: 128 px, 96 units).
const LEVEL_HEIGHT := 96.0

## Height of the ground at a world position (0 below, up on the highlands,
## in between on ramps).
func height_at(p: Vector2) -> float:
	var f := to_cell(p)
	var c := Vector2i(floori(f.x), floori(f.y))
	if map.ramps.has(c):
		return LEVEL_HEIGHT * clampf(1.0 - (f.x - c.x), 0.0, 1.0)
	return LEVEL_HEIGHT * level_at(c)

## Highland cells: their top one level up, cliffs on their south-east and
## south-west sides (the cave of the dungeon in one of them), rims behind;
## cliffs block the way except down the ramps.
func _build_relief() -> void:
	for i in W:
		for j in W:
			var c := Vector2i(i, j)
			if level_at(c) == 1:
				_highland_cell(c)
			elif map.ramps.has(c):
				var node := Node2D.new()
				node.position = cell_pos(c.x + 0.5, c.y + 0.5)
				_chunk(Vector2(c)).add_child(node)
				_tile("fantasy", "Ground G16_E", Vector2.ZERO, node)
				# Its sides are walls; its back (the highland) and front (the ground) are open.
				_wall(cell_pos(c.x, c.y), cell_pos(c.x + 1, c.y))
				_wall(cell_pos(c.x, c.y + 1), cell_pos(c.x + 1, c.y + 1))
				map_image.set_pixel(c.x, c.y, MAP_COLORS.road)

func _highland_cell(c: Vector2i) -> void:
	var t: Dictionary = theme[map.region_at(c)]
	var node := Node2D.new()
	node.position = cell_pos(c.x + 0.5, c.y + 0.5)
	_chunk(Vector2(c)).add_child(node)
	_tile("fantasy", _pick(t.floors), Vector2(0, -LEVEL_HEIGHT), node)
	var e_low := level_at(c + Vector2i(1, 0)) == 0 and not map.ramps.has(c + Vector2i(1, 0))
	var s_low := level_at(c + Vector2i(0, 1)) == 0
	var n_low := level_at(c + Vector2i(0, -1)) == 0
	var w_low := level_at(c + Vector2i(-1, 0)) == 0
	if c == WorldMap.CAVE_FACE:
		_tile("fantasy", "Ground G22_E", Vector2.ZERO, node)  # the cave's mouth
		if s_low:
			_tile("fantasy", "Ground G12_S", Vector2.ZERO, node)
	elif e_low and s_low:
		_tile("fantasy", "Ground G13_S", Vector2.ZERO, node)
	else:
		if e_low:
			_tile("fantasy", "Ground G12_E", Vector2.ZERO, node)
		if s_low:
			_tile("fantasy", "Ground G12_S", Vector2.ZERO, node)
	if n_low:
		_tile("fantasy", "Ground G12_N", Vector2.ZERO, node)
	if w_low:
		_tile("fantasy", "Ground G12_W", Vector2.ZERO, node)
	if level_at(c + Vector2i(1, 0)) == 0 and not map.ramps.has(c + Vector2i(1, 0)):
		_wall(cell_pos(c.x + 1, c.y), cell_pos(c.x + 1, c.y + 1))
	if s_low:
		_wall(cell_pos(c.x, c.y + 1), cell_pos(c.x + 1, c.y + 1))
	if n_low and not map.ramps.has(c + Vector2i(0, -1)):
		_wall(cell_pos(c.x, c.y), cell_pos(c.x + 1, c.y))
	if w_low and not map.ramps.has(c + Vector2i(-1, 0)):
		_wall(cell_pos(c.x, c.y), cell_pos(c.x, c.y + 1))

## Characters stand on the ground under them; up there, they are drawn over
## the highland's cells.
func _update_heights() -> void:
	for a in [player] + _enemies:
		if is_instance_valid(a) and a.sprite and a.process_mode != Node.PROCESS_MODE_DISABLED:
			var h := height_at(a.global_position)
			if absf(a.sprite.lift - h) > 0.01:
				a.sprite.lift = h
			a.z_index = (1 if h > LEVEL_HEIGHT * 0.5 else 0) + (2 if _occluded.has(a) else 0)

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
	_solid("fantasy", "Misc C8_S", at, 10)
	var b := Node2D.new()
	b.position = at + Vector2(0, 1)
	_chunk(to_cell(at)).add_child(b)
	_fx("flame", Vector2(0, -23), b).z_index = 1
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
		sf.set_animation_loop("default", not (name.begins_with("break_") or name.begins_with("hit_")))
		for k in int(m.frames):
			var at_tex := AtlasTexture.new()
			at_tex.atlas = strip
			var cols := int(m.get("cols", m.frames))
			at_tex.region = Rect2((k % cols) * m.w, (k / cols) * m.h, m.w, m.h)
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
	if at == PORTAL_IN:  # the portal glows in the cave's mouth
		var mouth := Node2D.new()
		mouth.position = cell_pos(WorldMap.CAVE_FACE.x + 1.02, WorldMap.CAVE_FACE.y + 0.5)
		_chunk(at).add_child(mouth)
		_fx("portal", Vector2(0, -4), mouth).scale *= 0.8
	else:
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
	# Wanderers in each region, away from the bonfires and the village.
	for b in ["prairie", "ruins", "snow", "caves"]:
		for entry in theme[b].enemies:
			var placed := 0
			var tries := 0
			while placed < entry[1] and tries < 1500:
				tries += 1
				var c := Vector2i(rng.randi_range(5, W - 6), rng.randi_range(5, W - 6))
				if map.region_at(c) != b or not map.is_free(c) or _occupied.has(c) or _field_cells.has(c):
					continue
				if Vector2(c).distance_to(PLACES[b].cell) < 9.0 or Vector2(c).distance_to(WorldMap.VILLAGE) < 15.0:
					continue
				_add_enemy(entry[0], Vector2(c) + Vector2(0.5, 0.5))
				placed += 1
	# Groups: the brigands' camp, the graveyard, the ruined city's plaza.
	for k in 4:
		var a := k * TAU / 4.0 + 0.5
		_add_enemy(["pack/brigand_a", "pack/brigand_b", "pack/brigand_c", "pack/brigand_b"][k], WorldMap.CAMP + Vector2.RIGHT.rotated(a) * 2.0)
		_add_enemy(["pack/skeleton_b", "pack/skeleton_a", "pack/skeleton_b", "pack/skeleton_c"][k], WorldMap.GRAVEYARD + Vector2.RIGHT.rotated(a) * 2.3)
		_add_enemy(["pack/skeleton_a", "pack/skeleton_c", "pack/skeleton_a", "pack/skeleton_c"][k], WorldMap.CITY + Vector2.RIGHT.rotated(a) * 5.4)
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
	_cull_t -= delta
	if _cull_t <= 0.0:
		_cull_t = 0.15
		_cull_chunks()
	_fade_t -= delta
	if _fade_t <= 0.0:
		_fade_t = 0.08
		_fade_occluders()
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
	_update_heights()
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
	out.append(["Village", WorldMap.VILLAGE + Vector2(0.5, 5.0)])
	out.append(["Lac (ponton)", Vector2(WorldMap.LANDING) + Vector2(-1.5, -0.6)])
	out.append(["Ville en ruine", WorldMap.CITY + Vector2(0.5, 5.5)])
	out.append(["Camp des brigands", WorldMap.CAMP + Vector2(0.6, 1.4)])
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
