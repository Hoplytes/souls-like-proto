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
	# (the wood and the flames are Flare tiles added by the game)
