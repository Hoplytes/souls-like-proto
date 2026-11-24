class_name Bonfire
extends Node2D
## A bonfire: a coiled sword planted in a ring of stones and ashes. Unlit
## until the hero kindles it; then resting there refills health and flasks,
## brings the enemies back, sets where the hero comes back after dying, and
## opens the bonfire's menu (level up, travel). The wood and the flames are
## tiles and effects of the pack added by the game.

var lit := false
var _t := randf() * 10.0

func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree() and Fx.near_camera(global_position):
		queue_redraw()

func _draw() -> void:
	if lit:
		draw_circle(Vector2.ZERO, 26 + sin(_t * 3) * 2, Color(1, 0.55, 0.2, 0.08))
		draw_circle(Vector2.ZERO, 14 + sin(_t * 5) * 1.5, Color(1, 0.6, 0.25, 0.12))
	else:  # embers still glowing in the ashes
		for k in 5:
			var a := 0.4 + 0.3 * sin(_t * 2.0 + k * 1.7)
			draw_circle(Vector2(cos(k * 1.3) * 5.0, sin(k * 1.9) * 2.0 - 1.0), 1.0, Color(1.0, 0.45, 0.15, a))
	# The coiled sword, leaning a little.
	var tip := Vector2(1, -2)
	var hilt := Vector2(-2, -24)
	var blade := PackedVector2Array()
	for k in 9:
		var f := k / 8.0
		var p := tip.lerp(hilt, f)
		blade.append(p + Vector2(sin(f * TAU * 2.0) * 1.2 if f < 0.8 else 0.0, 0))
	draw_polyline(blade, Color(0.15, 0.12, 0.1), 3.0)
	draw_polyline(blade, Color(0.55, 0.5, 0.46) if not lit else Color(0.95, 0.7, 0.45), 1.4)
	draw_line(hilt + Vector2(-4, 1.5), hilt + Vector2(4, -0.5), Color(0.2, 0.15, 0.1), 2.0)
	draw_line(hilt, hilt + Vector2(-0.6, -5), Color(0.3, 0.2, 0.12), 2.0)
