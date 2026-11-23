class_name MapView
extends Control
## The map screen (Tab / Select): the open world seen from above in the same
## isometric diamond as the game, with the bonfires, bosses, the dungeon
## portal and the hero. The Minotaur's dungeon is shown in an inset.

signal closed

var game: Game
var _tex: ImageTexture
var _hall_tex: ImageTexture
var _t := 0.0

const SCALE := 2.8  # map pixels per cell (half-width of a cell's diamond)
const HALL_SCALE := 3.2

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_tex = ImageTexture.create_from_image(game.map_image)
	_hall_tex = ImageTexture.create_from_image(game.hall_image)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _origin() -> Vector2:
	return Vector2(size.x * 0.5 - 40, 36)

func _hall_origin() -> Vector2:
	return Vector2(size.x - 80, size.y - 30 - Game.HALL * HALL_SCALE)

## Map position of a world cell (or, for the dungeon, of a cell in the inset).
func _at(c: Vector2) -> Vector2:
	if c.x >= Game.HALL_AT.x - 2:
		var h := c - Game.HALL_AT
		return _hall_origin() + Vector2((h.x - h.y) * HALL_SCALE, (h.x + h.y) * HALL_SCALE / 2.0)
	return _origin() + Vector2((c.x - c.y) * SCALE, (c.x + c.y) * SCALE / 2.0)

func _draw_diamond_texture(tex: Texture2D, origin: Vector2, s: float) -> void:
	draw_set_transform_matrix(Transform2D(Vector2(s, s / 2.0), Vector2(-s, s / 2.0), origin))
	draw_texture(tex, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _diamond(origin: Vector2, n: int, s: float) -> PackedVector2Array:
	return PackedVector2Array([origin, origin + Vector2(n * s, n * s / 2.0), origin + Vector2(0, n * s),
		origin + Vector2(-n * s, n * s / 2.0), origin])

func _text(pos: Vector2, s: String, size_px: int, col: Color, center := true) -> void:
	var f := get_theme_default_font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var p := pos - Vector2(w / 2.0 if center else 0.0, 0)
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 3, Color(0, 0, 0, 0.8))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.04, 0.88))
	_text(Vector2(size.x / 2.0, 20), "Carte", 14, Color(0.92, 0.78, 0.55))
	# The world and its frame.
	_draw_diamond_texture(_tex, _origin(), SCALE)
	draw_polyline(_diamond(_origin(), Game.W, SCALE), Color(0.62, 0.45, 0.25), 1.0)
	# The dungeon inset.
	_draw_diamond_texture(_hall_tex, _hall_origin(), HALL_SCALE)
	draw_polyline(_diamond(_hall_origin(), Game.HALL, HALL_SCALE), Color(0.62, 0.45, 0.25), 1.0)
	_text(_hall_origin() + Vector2(0, Game.HALL * HALL_SCALE + 12), "Labyrinthe d'Astérion", 8, Color(0.8, 0.75, 0.7))
	# The portal and its link to the inset.
	var a := _at(Game.PORTAL_IN)
	var b := _at(Game.PORTAL_OUT)
	draw_dashed_line(a, b, Color(0.5, 0.6, 1.0, 0.5), 1.0, 4.0)
	for p in [a, b]:
		draw_arc(p, 3.5, 0, TAU, 16, Color(0.55, 0.7, 1.0), 1.5)
	# Bonfires, named after their region.
	for place in Game.PLACES:
		var p := _at(Game.PLACES[place].cell)
		var flick := 2.4 + sin(_t * 6.0 + p.x) * 0.4
		draw_circle(p, flick + 1.2, Color(0, 0, 0, 0.6))
		draw_circle(p, flick, Color(1.0, 0.62, 0.22))
		var label: String = Game.BIOMES[place].name
		if place != "dungeon":
			_text(p + Vector2(0, -7), label, 8, Color(1.0, 0.92, 0.8))
	# Bosses: red while alive, grey once defeated.
	for model in Game.ARENAS:
		var p := _at(Game.ARENAS[model].center)
		var dead: bool = Game.defeated.has(model)
		var col := Color(0.55, 0.55, 0.55) if dead else Color(0.9, 0.18, 0.15)
		draw_line(p + Vector2(-3.5, -3.5), p + Vector2(3.5, 3.5), col, 2.0)
		draw_line(p + Vector2(-3.5, 3.5), p + Vector2(3.5, -3.5), col, 2.0)
		if model == "wyvern_water":
			_text(p + Vector2(0, -8), "Glacevive" + (" (vaincue)" if dead else ""), 7, col.lightened(0.3))
		else:
			_text(p + Vector2(0, -8), "Astérion" + (" (vaincu)" if dead else ""), 7, col.lightened(0.3))
	# The hero: an arrow pointing where he faces, blinking softly.
	var hp := _at(Game.to_cell(game.player.global_position))
	var f: Vector2 = game.player.facing.normalized()
	var side := f.orthogonal()
	var pts := PackedVector2Array([hp + f * 6.0, hp - f * 3.5 + side * 3.5, hp - f * 1.5, hp - f * 3.5 - side * 3.5])
	var glow := 0.6 + 0.4 * absf(sin(_t * 4.0))
	draw_circle(hp, 7.0, Color(1, 1, 1, 0.15 * glow))
	draw_colored_polygon(pts, Color(1, 1, 1, 0.7 + 0.3 * glow))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.8), 1.0)
	# Legend.
	var y := size.y - 16
	var lx := 18.0
	draw_circle(Vector2(lx, y - 3), 2.6, Color(1.0, 0.62, 0.22))
	_text(Vector2(lx + 7, y), "feu de camp", 8, Color(0.8, 0.78, 0.74), false)
	lx += 72
	draw_line(Vector2(lx - 3, y - 6), Vector2(lx + 3, y), Color(0.9, 0.18, 0.15), 2.0)
	draw_line(Vector2(lx - 3, y), Vector2(lx + 3, y - 6), Color(0.9, 0.18, 0.15), 2.0)
	_text(Vector2(lx + 7, y), "boss", 8, Color(0.8, 0.78, 0.74), false)
	lx += 42
	draw_arc(Vector2(lx, y - 3), 3.5, 0, TAU, 16, Color(0.55, 0.7, 1.0), 1.5)
	_text(Vector2(lx + 7, y), "portail", 8, Color(0.8, 0.78, 0.74), false)
	lx += 52
	draw_colored_polygon(PackedVector2Array([Vector2(lx, y - 7), Vector2(lx + 3.5, y), Vector2(lx - 3.5, y)]), Color.WHITE)
	_text(Vector2(lx + 7, y), "vous", 8, Color(0.8, 0.78, 0.74), false)
	_text(Vector2(size.x / 2.0, size.y - 4), "Tab, Échap ou B pour fermer", 7, Color(0.65, 0.62, 0.58))

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("map") or e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel") \
			or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_B):
		get_viewport().set_input_as_handled()
		closed.emit()
