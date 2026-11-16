class_name Fx
extends Node2D
## Small procedural effects (sparks, rings, slash arcs) plus game-feel
## helpers: screen shake and hit-stop.

static var camera: Camera2D
static var _shake := 0.0

var kind := ""
var color := Color.WHITE
var life := 0.2
var age := 0.0
var r0 := 0.0
var r1 := 10.0
var angle := 0.0
var arc := PI
var width := 2.0
var seed_dirs: Array[Vector2] = []

static func _make(parent: Node, pos: Vector2, k: String, col: Color, duration: float) -> Fx:
	var f := Fx.new()
	f.kind = k
	f.color = col
	f.life = duration
	f.position = pos
	f.z_index = 50
	parent.add_child(f)
	return f

static func hit_spark(parent: Node, pos: Vector2) -> void:
	var f := _make(parent, pos, "spark", Color(1, 0.95, 0.7), 0.16)
	for i in 7:
		f.seed_dirs.append(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(8, 16))

static func ring(parent: Node, pos: Vector2, from_r: float, to_r: float, col: Color, duration: float, w: float = 2.0) -> Fx:
	var f := _make(parent, pos, "ring", col, duration)
	f.r0 = from_r
	f.r1 = to_r
	f.width = w
	f.z_index = -1  # on the ground, under the characters
	return f

static func slash_arc(parent: Node, pos: Vector2, facing: float, radius: float, col: Color, duration: float = 0.14) -> void:
	var f := _make(parent, pos, "arc", col, duration)
	f.angle = facing
	f.r1 = radius
	f.arc = PI * 0.9

## A danger zone that fills up until the attack lands (the "telegraph").
static func zone(parent: Node, pos: Vector2, rot: float, shape: String, size: Vector2, duration: float,
		col: Color = Color(1, 0.15, 0.1)) -> Fx:
	var f := _make(parent, pos, "zone_" + shape, col, duration)
	f.rotation = rot
	f.r1 = size.x
	f.r0 = size.y
	f.z_index = -1  # on the ground, under the characters
	return f

## Little dust puffs kicked up at the start and end of a roll.
static func dust(parent: Node, pos: Vector2, push: Vector2) -> void:
	var f := _make(parent, pos, "dust", Color(0.65, 0.6, 0.5, 0.7), 0.35)
	f.z_index = -1
	for i in 5:
		f.seed_dirs.append(push * randf_range(4, 12) + Vector2(randf_range(-7, 7), randf_range(-3, 2)))

static func float_text(parent: Node, pos: Vector2, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.position = pos + Vector2(-20, -10)
	l.z_index = 60
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", l.position.y - 18, 0.6)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.3)
	t.tween_callback(l.queue_free)

static func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

static func update_shake(delta: float) -> void:
	if camera == null:
		return
	_shake = move_toward(_shake, 0.0, 30.0 * delta)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake

static func hitstop(tree: SceneTree, duration: float) -> void:
	Engine.time_scale = 0.05
	tree.create_timer(duration, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := age / life
	var c := color
	if kind.begins_with("zone_"):
		var fill := Color(c, 0.12 + 0.25 * t)
		var edge := Color(c, 0.75)
		if kind == "zone_circle":
			draw_circle(Vector2.ZERO, r1 * t, fill)
			draw_arc(Vector2.ZERO, r1, 0, TAU, 40, edge, 1.5)
		else:  # rect starting at the origin and pointing along +x
			draw_rect(Rect2(0, -r0 / 2, r1 * t, r0), fill)
			draw_rect(Rect2(0, -r0 / 2, r1, r0), edge, false, 1.5)
		return
	c.a *= 1.0 - t
	match kind:
		"spark":
			for d in seed_dirs:
				draw_line(d * t * 0.6, d * (0.4 + t), c, 1.5)
		"dust":
			for d in seed_dirs:
				draw_circle(d * (0.4 + t), 2.5 * (1.0 - t) + 1.0, c)
		"ring":
			draw_arc(Vector2.ZERO, lerpf(r0, r1, t), 0, TAU, 40, c, width)
		"arc":
			var a0 := angle - arc / 2
			draw_arc(Vector2.ZERO, r1, a0, a0 + arc * minf(1.0, t * 2.5), 16, c, 3.0)
			draw_arc(Vector2.ZERO, r1 - 4, a0, a0 + arc * minf(1.0, t * 2.5), 16, Color(c, c.a * 0.5), 2.0)
