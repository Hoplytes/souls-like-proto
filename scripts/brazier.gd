class_name Brazier
extends StaticBody2D
## A bronze brazier on a tripod with a burning fire and a warm light.

var _t := 0.0
var _light: PointLight2D

func _ready() -> void:
	collision_layer = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 8)
	cs.shape = r
	cs.position = Vector2(0, -4)
	add_child(cs)
	_t = randf() * 10.0
	_light = PointLight2D.new()
	var g := GradientTexture2D.new()
	g.width = 256
	g.height = 256
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(1, 1, 1, 1))
	g.gradient.set_color(1, Color(1, 1, 1, 0))
	_light.texture = g
	_light.color = Color(1.0, 0.62, 0.3)
	_light.energy = 0.55
	_light.texture_scale = 0.75
	_light.position = Vector2(0, -26)
	add_child(_light)

func _process(delta: float) -> void:
	_t += delta
	_light.energy = 0.5 + 0.08 * sin(_t * 9.0) + 0.05 * sin(_t * 23.0)
	queue_redraw()

func _draw() -> void:
	var bronze := Color(0.55, 0.36, 0.2)
	var dark := Color(0.25, 0.16, 0.1)
	draw_set_transform(Vector2(2, 0), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 12, Color(0.05, 0.03, 0.08, 0.35))
	draw_set_transform(Vector2.ZERO)
	# Tripod legs.
	draw_line(Vector2(-8, 0), Vector2(-4, -16), dark, 2)
	draw_line(Vector2(8, 0), Vector2(4, -16), dark, 2)
	draw_line(Vector2(0, 1), Vector2(0, -16), dark, 2)
	# Bowl.
	var bowl := PackedVector2Array([Vector2(-11, -22), Vector2(11, -22), Vector2(7, -15), Vector2(-7, -15)])
	draw_colored_polygon(bowl, bronze)
	draw_line(Vector2(-11, -22), Vector2(11, -22), Color(0.8, 0.58, 0.32), 2)
	draw_line(Vector2(-7, -15), Vector2(7, -15), dark, 1)
	# Flames.
	for i in 6:
		var x := -8.0 + i * 3.2
		var h := 9.0 + 6.0 * absf(sin(_t * (6.0 + i) + i * 1.7))
		draw_line(Vector2(x, -23), Vector2(x + sin(_t * 8 + i), -23 - h), Color(1, 0.45 + i * 0.06, 0.12), 2.5)
	draw_line(Vector2(0, -23), Vector2(sin(_t * 7) * 1.5, -30 - 4 * absf(sin(_t * 9))), Color(1, 0.95, 0.6), 2)
