extends Node2D
class_name Game
## The open world: four biomes generated around their landmarks (prairie,
## ruins, snow, caves), the Minotaur's dungeon reached through a portal,
## bonfire checkpoints, enemies per biome and two bosses. Art, music and
## sounds from Flare (CC-BY-SA 3.0).
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

const BIOMES := {
	"prairie": {"name": "Plaine de l'Aube", "tiles": "grass", "music": "overworld_theme",
		"ambience": "environment/bird_twitter_loop", "light": Color(0.8, 0.78, 0.72), "torch": 0.35},
	"ruins": {"name": "Ruines d'Hélos", "tiles": "ruins", "music": "unrest_theme",
		"ambience": "environment/raven_loop", "light": Color(0.62, 0.6, 0.68), "torch": 0.5},
	"snow": {"name": "Crêtes gelées", "tiles": "snow", "music": "magical_theme",
		"ambience": "environment/wind_loop", "light": Color(0.74, 0.8, 0.92), "torch": 0.35},
	"caves": {"name": "Grottes d'ambre", "tiles": "cave", "music": "cave_theme",
		"ambience": "environment/cave_droplets_loop", "light": Color(0.46, 0.42, 0.48), "torch": 0.8},
	"dungeon": {"name": "Labyrinthe d'Astérion", "tiles": "dungeon", "music": "dungeon_theme",
		"ambience": "environment/cave_wind_loop", "light": Color(0.36, 0.34, 0.44), "torch": 0.7},
}
## Places: bonfires (and the teleport menu). Cells are in world coordinates.
const PLACES := {
	"prairie": {"label": "Plaine de l'Aube (départ)", "cell": Vector2(78, 78)},
	"ruins": {"label": "Ruines d'Hélos", "cell": Vector2(22, 60)},
	"snow": {"label": "Crêtes gelées", "cell": Vector2(60, 24)},
	"caves": {"label": "Grottes d'ambre", "cell": Vector2(32, 34)},
	"dungeon": {"label": "Labyrinthe d'Astérion", "cell": HALL_AT + Vector2(18.5, 18.5)},
}
## Boss arenas: centre cell, radius in cells, where the teleport menu drops you.
const ARENAS := {
	"minotaur": {"center": HALL_AT + Vector2(6.5, 6.5), "radius": 4.6, "label": "Boss : Astérion, le Minotaure",
		"entry": HALL_AT + Vector2(11.5, 11.5)},
	"wyvern_water": {"center": Vector2(80, 14), "radius": 5.0, "label": "Boss : Glacevive, la Wyverne",
		"entry": Vector2(73, 21)},
}
const PORTAL_IN := Vector2(16, 18)  # in the caves, to the dungeon
const PORTAL_OUT := HALL_AT + Vector2(20.5, 15.5)  # in the dungeon, back to the caves

## Floors and scenery per biome: [first id, last id] ranges of each tileset.
const FLOORS := {
	"prairie": [[16, 31]], "ruins": [[24, 31], [153, 166]], "snow": [[16, 31]], "caves": [[16, 31]],
}
const FLOOR_PATCHES := {  # second floor, painted where a noise is high
	"prairie": [[32, 47]], "ruins": [[105, 119]], "snow": [[32, 47]], "caves": [[48, 55]],
}
## [first id, last id, collision radius (0 = walk through), weight]
const DECOR := {
	"prairie": [[252, 255, 10, 6], [248, 251, 9, 4], [240, 243, 9, 3], [244, 247, 6, 1], [112, 127, 0, 10],
		[128, 131, 7, 2], [132, 135, 12, 0.4], [136, 137, 9, 1], [140, 143, 8, 0.4]],
	"ruins": [[223, 234, 12, 4], [241, 246, 12, 1.2], [186, 194, 0, 4], [312, 317, 0, 3], [291, 294, 12, 0.5],
		[289, 290, 14, 0.3], [274, 277, 7, 0.4]],
	"snow": [[244, 247, 7, 4], [128, 131, 7, 2], [553, 567, 0, 4], [132, 135, 12, 1], [112, 127, 0, 5],
		[532, 534, 8, 0.25], [136, 137, 8, 1]],
	"caves": [[144, 149, 10, 4], [150, 153, 12, 3], [132, 135, 0, 3], [162, 163, 9, 0.3]],
}
const DENSITY := {"prairie": 0.09, "ruins": 0.07, "snow": 0.06, "caves": 0.09}
const ENEMIES := {
	"prairie": [["goblin", 7], ["goblin_elite", 2]],
	"ruins": [["skeleton", 4], ["skeleton_weak", 3], ["zombie", 2]],
	"snow": [["ice_ant", 7]],
	"caves": [["antlion", 3], ["fire_ant", 4]],
}
const DUNGEON_FLOOR_PLAIN := [16, 17, 18, 19, 22, 23, 26, 29, 30, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47]
const DUNGEON_FLOOR_COBBLE := [32, 33, 34, 35]

var world: Node2D
var player: Player
var boss: Boss  # the boss being fought (for the HUD)
var hud
var music: Music
var cam: Camera2D
var _floor: TileMapLayer
var _sources := {}  # "tileset:id" -> TileSet source id
var _anchors := {}  # tileset -> {id: anchor}
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
	"prairie": Color(0.36, 0.46, 0.2), "ruins": Color(0.45, 0.43, 0.38), "snow": Color(0.84, 0.87, 0.92),
	"caves": Color(0.36, 0.27, 0.19), "dungeon": Color(0.25, 0.23, 0.26),
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
	for t in ["grass", "ruins", "snow", "cave", "dungeon"]:
		_anchors[t] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/flare/tiles/%s/anchors.json" % t))
	world_rect = Rect2(-W * TW / 2.0 - 40, -300, W * TW + 80, W * TH + 340)
	start_pos = cell_of(PLACES.prairie.cell) + Vector2(0, 30)
	arena_center = cell_of(ARENAS.minotaur.center)
	arena_radius = ARENAS.minotaur.radius * TW / sqrt(2.0)

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
		var wood := _tile("grass", 102, Vector2(0, 2), b)
		wood.show_behind_parent = true
		var fire := _tile("dungeon", 167, Vector2(0, -2), b)  # the brazier's flames
		fire.scale *= 0.8
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
	_ambience.volume_db = -10.0
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
		if a.begins_with("--autotest="):
			var t: Node = load("res://tools/autotest.gd").new()
			t.main = self
			t.out = a.trim_prefix("--autotest=")
			add_child(t)

# --- tiles -----------------------------------------------------------------

func _tile(tileset: String, id: int, at: Vector2, parent: Node, z: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/flare/tiles/%s/%d.png" % [tileset, id])
	s.centered = false
	var a: Array = _anchors[tileset][str(id)]
	s.offset = -Vector2(a[0], a[1])
	s.scale = Vector2.ONE / float(_anchors[tileset].get("res", 1))
	s.position = at
	s.z_index = z
	parent.add_child(s)
	return s

## A solid piece of scenery: a tile plus a small collision at its base.
func _solid(tileset: String, id: int, at: Vector2, radius: float) -> StaticBody2D:
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
	var res := float(_anchors.grass.get("res", 1))  # tiles are stored at res x their size
	ts.tile_size = Vector2i(int(TW * res), int(TH * res))
	var floors := {"grass": [[16, 47]], "ruins": [[24, 31], [105, 119], [153, 166]], "snow": [[16, 47], [344, 363]],
		"cave": [[16, 31], [48, 55]], "dungeon": [[16, 19], [22, 23], [26, 26], [29, 47], [60, 63]]}
	for tileset in floors:
		for r in floors[tileset]:
			for id in range(r[0], r[1] + 1):
				if not _anchors[tileset].has(str(id)) or str(id) == "res":
					continue
				var tex: Texture2D = load("res://assets/flare/tiles/%s/%d.png" % [tileset, id])
				var src := TileSetAtlasSource.new()
				src.texture = tex
				src.texture_region_size = Vector2i(tex.get_size())
				src.create_tile(Vector2i.ZERO)
				_sources["%s:%d" % [tileset, id]] = ts.add_source(src)
	_floor = TileMapLayer.new()
	_floor.tile_set = ts
	_floor.z_index = -10
	_floor.scale = Vector2.ONE / res
	add_child(_floor)
	_floor.position = cell_pos(0.5, 0.5) - _floor.map_to_local(Vector2i.ZERO) / res

func _set_floor(i: int, j: int, tileset: String, id: int) -> void:
	_floor.set_cell(Vector2i(i, j), _sources["%s:%d" % [tileset, id]], Vector2i.ZERO)

func _pick(ranges: Array) -> int:
	var r: Array = ranges[_rng.randi() % ranges.size()]
	return _rng.randi_range(r[0], r[1])

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

func _build_world() -> void:
	for p in PLACES.values():
		_keep_clear(p.cell, 3.5)
	for model in ARENAS:
		_keep_clear(ARENAS[model].center, ARENAS[model].radius + 1.5)
	_keep_clear(PORTAL_IN, 2.5)
	for i in W:
		for j in W:
			var b := biome_at(i + 0.5, j + 0.5)
			var tileset: String = BIOMES[b].tiles
			var patch := _noise.get_noise_2d(i * 7.0 + 900.0, j * 7.0) > 0.3
			_set_floor(i, j, tileset, _pick(FLOOR_PATCHES[b] if patch else FLOORS[b]))
			var col: Color = MAP_COLORS[b]
			map_image.set_pixel(i, j, col.darkened(0.12) if patch else col)
			var c := Vector2i(i, j)
			var edge := i < 3 or j < 3 or i >= W - 3 or j >= W - 3
			if _blocked.has(c):
				continue
			var dense := _noise.get_noise_2d(i * 5.0 + 50.0, j * 5.0 - 70.0) > 0.25  # woods, rock fields
			var chance: float = DENSITY[b] * (2.5 if dense else 1.0)
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
	# A summoning circle marks the wyvern's arena and the dungeon portal.
	_tile("snow", 264, cell_of(ARENAS.wyvern_water.center), _floor_decor(), 1)
	_tile("cave", 265, cell_of(PORTAL_IN), _floor_decor(), 1)

var _floor_decor_node: Node2D

func _floor_decor() -> Node2D:
	if _floor_decor_node == null:
		_floor_decor_node = Node2D.new()
		_floor_decor_node.z_index = -9
		add_child(_floor_decor_node)
	return _floor_decor_node

func _decor(b: String, tileset: String, c: Vector2, solid_only: bool) -> void:
	var table: Array = DECOR[b]
	var total := 0.0
	for e in table:
		if not solid_only or e[2] > 0:
			total += e[3]
	var roll := _rng.randf() * total
	for e in table:
		if solid_only and e[2] == 0:
			continue
		roll -= e[3]
		if roll <= 0.0:
			var id := _rng.randi_range(e[0], e[1])
			if e[2] > 0:
				_solid(tileset, id, cell_of(c), e[2])
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
	var arena_c: Vector2 = ARENAS.minotaur.center - HALL_AT
	for i in HALL:
		for j in HALL:
			var cobble := Vector2(i + 0.5, j + 0.5).distance_to(arena_c) < ARENAS.minotaur.radius + 0.6
			var ids: Array = DUNGEON_FLOOR_COBBLE if cobble else DUNGEON_FLOOR_PLAIN
			_set_floor(int(HALL_AT.x) + i, int(HALL_AT.y) + j, "dungeon", ids[_rng.randi() % ids.size()])
			hall_image.set_pixel(i, j, MAP_COLORS.dungeon.lightened(0.15) if cobble else MAP_COLORS.dungeon)
	_tile("dungeon", 265, _hall(arena_c.x, arena_c.y), _floor_decor(), 1)
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		var c := arena_c + Vector2.RIGHT.rotated(a) * 2.6
		_tile("dungeon", 60 + k, _hall(c.x, c.y), _floor_decor(), 1)
	var top := _hall(0, 0)
	var left := _hall(0, HALL)
	var right := _hall(HALL, 0)
	var bottom := _hall(HALL, HALL)
	for seg in [[top, left], [top, right], [left, bottom], [right, bottom]]:
		_edge(seg[0], seg[1])
	# Back walls: the upper-left edge shows its right face, the upper-right
	# edge its left face (the Flare tiles come in left/right pairs).
	for k in range(-1, HALL):
		if k == -1:
			_tile("dungeon", 66, _hall(-0.5, -0.5), world)
			continue
		_tile("dungeon", [65, 69, 103, 97, 99, 65, 107, 69][posmod(k, 8)], _hall(-0.5, k + 0.5), world)
		_tile("dungeon", [64, 68, 102, 96, 98, 64, 106, 68][posmod(k + 3, 8)], _hall(k + 0.5, -0.5), world)
	for k in 10:
		var a := k * TAU / 10.0
		var c := arena_c + Vector2.RIGHT.rotated(a) * (ARENAS.minotaur.radius + 0.9)
		if absf(wrapf(a - PI / 4.0, -PI, PI)) < 0.5 or c.x < 0.6 or c.y < 0.6:
			continue
		_solid("dungeon", 111, _hall(c.x, c.y), 12)
	for spot in [[128, Vector2(1.2, 14)], [129, Vector2(14, 1.2)], [130, Vector2(1.2, 18)], [131, Vector2(18, 1.2)]]:
		_solid("dungeon", spot[0], _hall(spot[1].x, spot[1].y), 16)
	for spot in [[194, Vector2(15, 15)], [199, Vector2(9.5, 16.5)], [200, Vector2(17, 9)]]:
		_solid("dungeon", spot[0], _hall(spot[1].x, spot[1].y), 22)
	for c in [Vector2(17, 20), Vector2(20, 17), Vector2(14, 9), Vector2(3, 10), Vector2(10, 3)]:
		_brazier(_hall(c.x, c.y))
	for k in 26:
		var c := Vector2(_rng.randf_range(1, HALL - 1), _rng.randf_range(1, HALL - 1))
		if c.distance_to(Vector2(18.5, 18.5)) < 2.5:
			continue
		_tile("dungeon", 176 + _rng.randi() % 8, _hall(c.x, c.y), world).z_index = -5

func _brazier(at: Vector2) -> void:
	var b := _solid("dungeon", 151, at, 10)
	var fire := _tile("dungeon", 167, Vector2(0, -14), b)
	fire.z_index = 1
	var light := PointLight2D.new()
	light.texture = _light_texture()
	light.color = Color(1.0, 0.6, 0.3)
	light.energy = 0.9
	light.texture_scale = 1.4
	light.position = Vector2(0, -20)
	b.add_child(light)

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
	for b in ENEMIES:
		for entry in ENEMIES[b]:
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
	for spot in [[Vector2(14, 16), "skeleton"], [Vector2(16, 12.5), "skeleton"], [Vector2(11, 14), "zombie"],
			[Vector2(13, 10.5), "skeleton"], [Vector2(10, 11), "zombie"]]:
		_add_enemy(spot[1], HALL_AT + spot[0])

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
	var amb: AudioStreamOggVorbis = load("res://assets/flare_audio/soundfx/%s.ogg" % info.ambience).duplicate()
	amb.loop = true
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
