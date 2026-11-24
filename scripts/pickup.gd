class_name Pickup
extends Node2D
## Something lying on the ground to use with [E]: an item (a pale glow with
## motes rising from it, as in the Souls), the bloodstain where the hero
## last died, holding the souls he dropped (a green glow on a dark pool), or
## a message left on the ground (orange runes) by those who passed before.

var stain := false
var message := false
## Height of the ground under it (highlands).
var lift := 0.0
var _t := randf() * 10.0

func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	var base := Vector2(0, -lift)
	if message:
		_draw_runes(base)
		return
	var col := Color(0.45, 1.0, 0.55) if stain else Color(1.0, 0.95, 0.8)
	var pulse := 0.75 + 0.25 * sin(_t * 3.0)
	if stain:
		draw_set_transform(base, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 11.0, Color(0.25, 0.02, 0.02, 0.75))
		draw_circle(Vector2(5, 3), 6.0, Color(0.3, 0.03, 0.03, 0.7))
		draw_circle(Vector2.ZERO, 16.0 * pulse, Color(col, 0.12))
		draw_set_transform(Vector2.ZERO)
	var glow := 1.0 if stain else 1.35
	for k in 5:  # the glow
		draw_circle(base + Vector2(0, -6), (18.0 - k * 3.4) * pulse * glow, Color(col, 0.06 + k * 0.05))
	draw_circle(base + Vector2(0, -6), 2.6, Color(1, 1, 1, 0.95))
	for k in 8:  # motes rising
		var ph := fmod(_t * 0.5 + k / 8.0, 1.0)
		var p := base + Vector2(sin(k * 2.3 + _t * 1.7) * 7.0, -4.0 - ph * 34.0)
		draw_circle(p, 1.4, Color(col, sin(ph * PI) * 0.9))

func _draw_runes(base: Vector2) -> void:
	var a := 0.55 + 0.25 * sin(_t * 2.0)
	var col := Color(1.0, 0.55, 0.15, a)
	draw_set_transform(base, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.5, 0.1, 0.1 * a))
	draw_arc(Vector2.ZERO, 12.0, 0, TAU, 32, col, 1.2)
	for k in 5:  # scrawled signs
		var ang := k * TAU / 5.0 + 0.4
		var p := Vector2.RIGHT.rotated(ang) * 7.0
		draw_line(p + Vector2(-2.5, -1.5), p + Vector2(2.5, 1.5), col, 1.2)
		draw_line(p + Vector2(0, -2.5), p + Vector2(0.5, 2.5), col, 1.2)
	draw_set_transform(Vector2.ZERO)
