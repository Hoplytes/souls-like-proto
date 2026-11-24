class_name LockMarker
extends Node2D
## The lock-on marker: a small glowing diamond on the locked enemy's chest.

var target: Node2D
var _t := 0.0

func _ready() -> void:
	z_index = 50
	visible = false

func _process(delta: float) -> void:
	_t += delta
	visible = is_instance_valid(target)
	if visible:
		var h: float = target.get("body_height") if target.get("body_height") != null else 40.0
		var lift: float = target.sprite.lift if target.get("sprite") is HdSprite else 0.0
		global_position = target.global_position + Vector2(0, -h * 0.55 - lift)
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var r := 4.0 + sin(_t * 6.0) * 0.6
	var pts := PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0), Vector2(0, -r)])
	draw_circle(Vector2.ZERO, r + 4.0, Color(1.0, 0.9, 0.7, 0.12))
	draw_colored_polygon(pts, Color(1.0, 0.95, 0.85, 0.9))
	draw_polyline(pts, Color(0.55, 0.08, 0.05), 1.2)
