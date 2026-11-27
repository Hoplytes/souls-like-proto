class_name Thrown
extends Node2D
## A fire bomb thrown by the hero: it flies in an arc to where it was aimed,
## explodes in flames (enemies and breakable scenery around are hurt), and
## leaves the ground burning for a moment, hurting whoever stays in it.

const FLIGHT := 0.5
const RADIUS := 34.0
const DAMAGE := 42
const BURN_TIME := 3.0
const BURN_DAMAGE := 7

var source: Node2D
var from := Vector2.ZERO
var to := Vector2.ZERO
var _t := 0.0
var _landed := false
var _burn_t := 0.0
var _tick := 0.0

static func throw(parent: Node, src: Node2D, at: Vector2, target: Vector2) -> Thrown:
	var b := Thrown.new()
	b.source = src
	b.from = at
	b.to = target
	b.position = at
	parent.add_child(b)
	return b

func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed:
		var k := minf(1.0, _t / FLIGHT)
		position = from.lerp(to, k)
		if k >= 1.0:
			_explode()
		queue_redraw()
		return
	_burn_t += delta
	_tick -= delta
	if _tick <= 0.0 and _burn_t < BURN_TIME:
		_tick = 0.5
		Hitbox.spawn(get_parent(), source, global_position, 0, "circle", Vector2(RADIUS * 0.8, 0), BURN_DAMAGE, 4, 16, 0.08)
	if _burn_t >= BURN_TIME + 0.6:
		queue_free()

func _draw() -> void:
	if _landed:
		return
	var k := minf(1.0, _t / FLIGHT)
	var up := -18.0 - 46.0 * sin(k * PI)  # its height over its shadow
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 3.5, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(0, up), 3.5, Color(0.18, 0.16, 0.15))
	draw_circle(Vector2(1.5, up - 3.5), 1.8, Color(1.0, 0.65, 0.2, 0.6 + 0.4 * sin(_t * 40.0)))

func _explode() -> void:
	_landed = true
	z_index = -1
	Hitbox.spawn(get_parent(), source, global_position + Vector2(0, -10), 0, "circle", Vector2(RADIUS, 0), DAMAGE, 30, 16, 0.12)
	Fx.ring(get_parent(), global_position, 4, RADIUS * 1.2, Color(1.0, 0.6, 0.2), 0.35, 3)
	Fx.shake(3)
	Sfx.flare(self, "powers/fireball", global_position, -2.0)
	Sfx.flare(self, "powers/burn", global_position, -6.0)
	if not ResourceLoader.exists("res://local/fantasy/fx/burning_ground.png"):
		return
	var ground := Sprite2D.new()  # a patch of burning ground
	ground.texture = Fx.still("burning_ground")
	ground.scale = Vector2(1.0, 0.75) * (RADIUS * 2.3 / ground.texture.get_width())
	ground.modulate = Color(1, 1, 1, 0.85)
	add_child(ground)
	var t := ground.create_tween()
	t.tween_interval(BURN_TIME - 0.6)
	t.tween_property(ground, "modulate:a", 0.0, 1.0)
	for k in 3:  # and flames on it
		var flame := Fx.pack("fx_burn", Vector2.RIGHT.rotated(k * TAU / 3.0 + 0.4) * Vector2(14, 7), self, false, 0.45)
		flame.z_index = 1
		var ft := flame.create_tween()
		ft.tween_interval(BURN_TIME - 0.4)
		ft.tween_property(flame, "modulate:a", 0.0, 0.6)
