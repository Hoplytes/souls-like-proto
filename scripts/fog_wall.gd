class_name FogWall
extends Node2D
## One piece of the white fog closing a boss's arena: a low bank of mist
## from its point to the next one along the ring, with puffs rolling in it.
## The pieces are sorted with the scenery, so the hero is seen in front of
## the fog or through it.

const HEIGHT := 34.0
var next_rel := Vector2.ZERO  # the next point of the ring, from this one
var light: Texture2D
var _t := randf() * 20.0
var _seed := randf() * 10.0

func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree() and Fx.near_camera(global_position):
		queue_redraw()

func _draw() -> void:
	var a := Vector2.ZERO
	var b := next_rel
	var bottom := Color(1.3, 1.35, 1.45, 0.3 + 0.06 * sin(_t * 1.3 + _seed))
	var top := Color(1.25, 1.3, 1.4, 0.0)
	draw_polygon(PackedVector2Array([a, b, b + Vector2(0, -HEIGHT), a + Vector2(0, -HEIGHT)]),
		PackedColorArray([bottom, bottom, top, top]))
	if light == null:
		return
	for k in 6:  # puffs rolling along the bank and rising a little
		var ph := fmod(_t * 0.22 + k / 6.0 + _seed, 1.0)
		var along := fmod(k * 0.29 + _t * 0.06 + _seed, 1.0)
		var p := a.lerp(b, along) + Vector2(sin(_t * 0.7 + k * 1.9) * 4.0, -6.0 - ph * HEIGHT * 0.9)
		var r := 14.0 + 12.0 * ph + 4.0 * sin(k * 2.7 + _seed)
		draw_texture_rect(light, Rect2(p - Vector2(r, r * 0.65), Vector2(r * 2.0, r * 1.3)), false,
			Color(1.35, 1.4, 1.5, 0.5 * sin(ph * PI)))
