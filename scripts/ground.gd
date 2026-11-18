extends Node2D
## The ground, built from LPC Revised tiles: cobbled dirt everywhere, golden
## autumn grass on top with proper edges (picked from each cell's
## neighbours), and the paved boss arena.

const CELL := 32
const DIRT := [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)]
const GRASS := [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]

var world_rect := Rect2()
var arena_center := Vector2.ZERO
var arena_radius := 200.0
var path_points := PackedVector2Array()
var clearings: Array = []  # [center, radius] patches of bare dirt
var _grass := {}
var _cols := 0
var _rows := 0
var _slabs: Texture2D

func _ready() -> void:
	z_index = -10
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_slabs = load("res://assets/env/arena_marble.png")
	_cols = int(ceil(world_rect.size.x / CELL))
	_rows = int(ceil(world_rect.size.y / CELL))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL, CELL)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/env/terrain_autumn.png")
	src.texture_region_size = Vector2i(CELL, CELL)
	for c in 6:
		for r in 8:
			src.create_tile(Vector2i(c, r))
	ts.add_source(src, 0)
	var base := TileMapLayer.new()
	base.tile_set = ts
	add_child(base)
	var arena := Node2D.new()  # drawn between the dirt and the grass
	arena.draw.connect(_draw_arena.bind(arena))
	arena.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(arena)
	var grass := TileMapLayer.new()
	grass.tile_set = ts
	add_child(grass)

	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	_build_mask()
	for x in _cols:
		for y in _rows:
			base.set_cell(Vector2i(x, y), 0, DIRT[rng.randi() % DIRT.size()])
			if _is_grass(x, y):
				grass.set_cell(Vector2i(x, y), 0, _grass_tile(x, y, rng))

func _cell_center(x: int, y: int) -> Vector2:
	return world_rect.position + Vector2(x + 0.5, y + 0.5) * CELL

func _build_mask() -> void:
	for x in _cols:
		for y in _rows:
			_grass[Vector2i(x, y)] = not _is_bare(_cell_center(x, y))
	# Remove one-cell-thin strips: the tiles cannot draw them.
	var changed := true
	while changed:
		changed = false
		for x in _cols:
			for y in _rows:
				if _is_grass(x, y) and ((not _is_grass(x, y - 1) and not _is_grass(x, y + 1)) or
						(not _is_grass(x - 1, y) and not _is_grass(x + 1, y))):
					_grass[Vector2i(x, y)] = false
					changed = true

func _is_bare(p: Vector2) -> bool:
	if p.distance_to(arena_center) < arena_radius + 20:
		return true
	for c in clearings:
		if p.distance_to(c[0]) < c[1]:
			return true
	for i in range(path_points.size() - 1):
		if Geometry2D.get_closest_point_to_segment(p, path_points[i], path_points[i + 1]).distance_to(p) < 34:
			return true
	return false

func _is_grass(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= _cols or y >= _rows:
		return true
	return _grass[Vector2i(x, y)]

## Edge and corner tiles come from the 3x3 "grass island" block (0..2, 0..2)
## and inner corners from the 2x2 "grass with a hole" block (0..1, 6..7).
func _grass_tile(x: int, y: int, rng: RandomNumberGenerator) -> Vector2i:
	var n := _is_grass(x, y - 1)
	var s := _is_grass(x, y + 1)
	var w := _is_grass(x - 1, y)
	var e := _is_grass(x + 1, y)
	var col := 1
	var row := 1
	if not w:
		col = 0
	elif not e:
		col = 2
	if not n:
		row = 0
	elif not s:
		row = 2
	if col != 1 or row != 1:
		return Vector2i(col, row)
	if not _is_grass(x + 1, y + 1):
		return Vector2i(0, 6)
	if not _is_grass(x - 1, y + 1):
		return Vector2i(1, 6)
	if not _is_grass(x + 1, y - 1):
		return Vector2i(0, 7)
	if not _is_grass(x - 1, y - 1):
		return Vector2i(1, 7)
	return GRASS[rng.randi() % GRASS.size()]

func _draw_arena(node: Node2D) -> void:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 64:
		var p := arena_center + Vector2.RIGHT.rotated(i * TAU / 64) * arena_radius
		pts.append(p)
		uvs.append(p / 64.0)
	node.draw_colored_polygon(pts, Color.WHITE, uvs, _slabs)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Cracks, stains and moss: the temple has been abandoned for centuries.
	for i in 40:
		var p := arena_center + Vector2.RIGHT.rotated(rng.randf() * TAU) * sqrt(rng.randf()) * (arena_radius - 24)
		var crack := PackedVector2Array([p])
		for j in rng.randi_range(2, 5):
			crack.append(crack[-1] + Vector2(rng.randf_range(-9, 9), rng.randf_range(-6, 6)))
		node.draw_polyline(crack, Color(0.35, 0.3, 0.27, 0.7), 1.0)
	for i in 26:
		var a := rng.randf() * TAU
		var p := arena_center + Vector2.RIGHT.rotated(a) * rng.randf_range(arena_radius - 40, arena_radius - 20)
		node.draw_circle(p, rng.randf_range(4, 10), Color(0.32, 0.38, 0.22, 0.45))
	# Central altar circle.
	node.draw_arc(arena_center, 44, 0, TAU, 48, Color(0.5, 0.42, 0.36), 6)
	node.draw_arc(arena_center, 36, 0, TAU, 48, Color(0.66, 0.58, 0.5), 2)
	_draw_meander(node, arena_center, 44, Color(0.36, 0.28, 0.24), 0.5)
	# Greek key (meander) frieze along the rim.
	node.draw_arc(arena_center, arena_radius - 11, 0, TAU, 96, Color(0.3, 0.25, 0.22), 16)
	_draw_meander(node, arena_center, arena_radius - 11, Color(0.86, 0.8, 0.68), 1.0)

## One ring of the Greek key pattern: a square spiral repeated along a circle.
func _draw_meander(node: Node2D, center: Vector2, radius: float, col: Color, scale: float) -> void:
	var unit := 12.0 * scale
	var count := int(TAU * radius / unit)
	var glyph := [Vector2(0, 5), Vector2(0, -5), Vector2(9, -5), Vector2(9, 2), Vector2(4, 2), Vector2(4, -1), Vector2(6, -1)]
	for i in count:
		var a := i * TAU / count
		var n := Vector2.RIGHT.rotated(a)  # outward
		var t := n.orthogonal()
		var base := center + n * radius
		var pts := PackedVector2Array()
		for g in glyph:
			pts.append(base + t * (g.x - 6.0) * scale - n * g.y * scale)
		node.draw_polyline(pts, col, maxf(1.0, 1.5 * scale))
		node.draw_line(base + t * -6.0 * scale - n * 5.0 * scale, base + t * 6.0 * scale - n * 5.0 * scale, col, maxf(1.0, 1.5 * scale))
