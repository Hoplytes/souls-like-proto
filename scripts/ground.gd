extends Node2D
## Draws the ground: moss and dirt outside, a paved arena for the boss and a
## dirt path between them. All textures are generated at start-up.

var world_rect := Rect2()
var arena_center := Vector2.ZERO
var arena_radius := 200.0
var path_points := PackedVector2Array()
var _grass: ImageTexture
var _stone: ImageTexture
var _decals: Array = []

func _ready() -> void:
	z_index = -10
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_grass = _make_grass()
	_stone = _make_stone()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 260:
		_decals.append([Vector2(rng.randf_range(world_rect.position.x, world_rect.end.x),
			rng.randf_range(world_rect.position.y, world_rect.end.y)), rng.randi() % 3])

func _make_grass() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for y in 64:
		for x in 64:
			var n := rng.randf()
			var c := Color(0.16, 0.2, 0.15)
			if n > 0.9:
				c = Color(0.21, 0.26, 0.18)
			elif n < 0.08:
				c = Color(0.12, 0.15, 0.12)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _make_stone() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for y in 32:
		for x in 32:
			var c := Color(0.3, 0.29, 0.31).darkened(rng.randf() * 0.12)
			if y % 16 == 0 or (x + (8 if (y / 16) % 2 == 1 else 0)) % 16 == 0:
				c = Color(0.18, 0.17, 0.2)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _draw() -> void:
	draw_texture_rect(_grass, world_rect, true)
	for i in range(path_points.size() - 1):
		draw_line(path_points[i], path_points[i + 1], Color(0.24, 0.2, 0.15), 46)
		draw_circle(path_points[i], 23, Color(0.24, 0.2, 0.15))
	for d in _decals:
		match d[1]:
			0: draw_line(d[0], d[0] + Vector2(1, -4), Color(0.26, 0.32, 0.2), 1)
			1: draw_rect(Rect2(d[0], Vector2(2, 1)), Color(0.35, 0.33, 0.3))
			2: draw_circle(d[0], 1.5, Color(0.45, 0.2, 0.2))
	# Paved boss arena: a stone texture clipped to a circle.
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 48:
		var p := arena_center + Vector2.RIGHT.rotated(i * TAU / 48) * arena_radius
		pts.append(p)
		uvs.append(p / 32.0)
	draw_colored_polygon(pts, Color.WHITE, uvs, _stone)
	draw_arc(arena_center, arena_radius, 0, TAU, 48, Color(0.15, 0.14, 0.17), 4)
