class_name Prop
extends StaticBody2D
## Procedurally drawn scenery: pillars, broken walls, dead trees, graves,
## rocks. Origin is the base, so props y-sort with the characters.

var kind := "pillar"
var size := Vector2(16, 40)
var seed_v := 0

static func make(parent: Node, k: String, pos: Vector2, s: Vector2 = Vector2.ZERO, solid: bool = true) -> Prop:
	var p := Prop.new()
	p.kind = k
	p.position = pos
	p.seed_v = int(pos.x * 13 + pos.y * 7)
	if s != Vector2.ZERO:
		p.size = s
	elif k == "tree":
		p.size = Vector2(10, 46)
	elif k == "grave":
		p.size = Vector2(12, 14)
	elif k == "rock":
		p.size = Vector2(18, 10)
	p.collision_layer = 1 if solid else 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(p.size.x, minf(10.0, p.size.y))
	cs.shape = r
	cs.position = Vector2(0, -r.size.y / 2)
	p.add_child(cs)
	parent.add_child(p)
	return p

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var w := size.x
	var h := size.y
	match kind:
		"pillar":
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.35))
			draw_circle(Vector2(2, 0), w * 0.75, Color(0, 0, 0, 0.35))
			draw_set_transform(Vector2.ZERO)
			draw_rect(Rect2(-w / 2, -h, w, h), Color(0.42, 0.41, 0.44))
			draw_rect(Rect2(-w / 2, -h, w * 0.3, h), Color(0.52, 0.51, 0.54))
			draw_rect(Rect2(w / 2 - w * 0.25, -h, w * 0.25, h), Color(0.3, 0.29, 0.33))
			draw_rect(Rect2(-w / 2 - 2, -h - 4, w + 4, 5), Color(0.48, 0.47, 0.5))
			draw_rect(Rect2(-w / 2 - 2, -5, w + 4, 5), Color(0.33, 0.32, 0.36))
			for i in 3:
				var y := -rng.randf_range(8, h - 8)
				draw_line(Vector2(-w / 2 + rng.randf_range(0, w), y), Vector2(-w / 2 + rng.randf_range(0, w), y + 5), Color(0.2, 0.2, 0.22), 1)
		"wall":
			draw_rect(Rect2(-w / 2, -h, w, h), Color(0.25, 0.24, 0.27))
			draw_rect(Rect2(-w / 2, -h, w, 6), Color(0.38, 0.37, 0.4))
			var bh := 8.0
			var row := 0
			var y := -h + 6
			while y < -1:
				var off := 0.0 if row % 2 == 0 else 8.0
				var x := -w / 2 + off
				while x < w / 2:
					draw_line(Vector2(x, y), Vector2(x, minf(y + bh, 0)), Color(0.17, 0.16, 0.19), 1)
					x += 16
				draw_line(Vector2(-w / 2, y), Vector2(w / 2, y), Color(0.17, 0.16, 0.19), 1)
				y += bh
				row += 1
		"tree":
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.35))
			draw_circle(Vector2(0, 0), 14, Color(0, 0, 0, 0.3))
			draw_set_transform(Vector2.ZERO)
			draw_rect(Rect2(-3, -h, 6, h), Color(0.22, 0.17, 0.14))
			for i in 5:
				var by := -h + rng.randf_range(4, h * 0.6)
				var dir := -1.0 if i % 2 == 0 else 1.0
				var end := Vector2(dir * rng.randf_range(10, 18), by - rng.randf_range(6, 14))
				draw_line(Vector2(0, by), end, Color(0.22, 0.17, 0.14), 2)
				draw_line(end, end + Vector2(dir * 5, -4), Color(0.22, 0.17, 0.14), 1)
		"grave":
			draw_rect(Rect2(-w / 2, -h, w, h), Color(0.36, 0.36, 0.4))
			draw_circle(Vector2(0, -h), w / 2, Color(0.36, 0.36, 0.4))
			draw_line(Vector2(0, -h - 3), Vector2(0, -h + 6), Color(0.22, 0.22, 0.26), 1)
			draw_line(Vector2(-3, -h), Vector2(3, -h), Color(0.22, 0.22, 0.26), 1)
		"rock":
			var pts := PackedVector2Array()
			for i in 8:
				var a := PI + i * PI / 7.0
				pts.append(Vector2(cos(a) * w / 2 * rng.randf_range(0.8, 1.0), sin(a) * h * rng.randf_range(0.7, 1.0)))
			draw_colored_polygon(pts, Color(0.33, 0.33, 0.35))
			draw_line(pts[2], pts[4], Color(0.45, 0.45, 0.48), 1)
