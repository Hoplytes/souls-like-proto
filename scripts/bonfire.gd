class_name Bonfire
extends Node2D
## Checkpoint: resting refills health and flasks and brings enemies back.

var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 26 + sin(_t * 3) * 2, Color(1, 0.55, 0.2, 0.08))
	draw_circle(Vector2.ZERO, 14 + sin(_t * 5) * 1.5, Color(1, 0.6, 0.25, 0.12))
	draw_line(Vector2(-8, 0), Vector2(8, -3), Color(0.3, 0.2, 0.15), 3)
	draw_line(Vector2(-8, -3), Vector2(8, 0), Color(0.26, 0.17, 0.12), 3)
	draw_line(Vector2(0, 2), Vector2(2, -22), Color(0.55, 0.55, 0.6), 2)  # the planted sword
	draw_line(Vector2(-3, -15), Vector2(6, -16), Color(0.55, 0.55, 0.6), 2)
	for i in 5:
		var x := -6.0 + i * 3.0
		var hgt := 8.0 + 5.0 * absf(sin(_t * (6.0 + i) + i))
		draw_line(Vector2(x, -1), Vector2(x + sin(_t * 9 + i), -hgt), Color(1, 0.5 + i * 0.07, 0.15), 2)
	draw_line(Vector2(0, -1), Vector2(sin(_t * 7), -6 - 3 * absf(sin(_t * 8))), Color(1, 0.95, 0.6), 2)
