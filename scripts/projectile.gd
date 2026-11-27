class_name Projectile
extends Hitbox
## A missile: a magic bolt (the pack's effect) or a knife, thrown by an
## enemy at the hero (it can be blocked, and a parry deflects it) or by the
## hero at the enemies. It flies straight at chest height and breaks on
## walls, trees and rocks.

const HEIGHT := 18.0  # flies at chest height
var velocity := Vector2.ZERO
var kind := "bolt"
var _life := 2.4
var _spin := 0.0
var _gone := false

static func launch(parent: Node, src: Node2D, pos: Vector2, dir: Vector2, speed: float, dmg: int,
		poise: int, what: String, targets: int = 8) -> Projectile:
	var p := Projectile.new()
	p.source = src
	p.damage = dmg
	p.poise_damage = poise
	p.ranged = true
	p.kind = what
	p.collision_layer = 0
	p.collision_mask = targets | 1  # the hurtboxes aimed at (8 the hero's, 16 the enemies'), and the world
	p.monitorable = false
	var body := CollisionShape2D.new()  # the hero's body, at chest height
	var c := CircleShape2D.new()
	c.radius = 5.0
	body.shape = c
	body.position = Vector2(0, -HEIGHT)
	p.add_child(body)
	var feet := CollisionShape2D.new()  # trunks and rocks, on the ground
	var c2 := CircleShape2D.new()
	c2.radius = 2.5
	feet.shape = c2
	p.add_child(feet)
	p.position = pos
	p.velocity = dir.normalized() * speed
	parent.add_child(p)
	p.area_entered.connect(p._on_area)
	p.body_entered.connect(p._on_body)
	if what == "bolt":
		var fx := Fx.pack("fx_bolt", Vector2(0, -HEIGHT), p, false, 0.55)
		fx.rotation = dir.angle()
		fx.modulate = Color(1.2, 1.1, 1.3)
	return p

func _physics_process(delta: float) -> void:
	if _gone:
		return
	position += velocity * delta
	_spin += delta * 22.0
	_life -= delta
	if _life <= 0.0:
		_burst()
	queue_redraw()

func _draw() -> void:
	if kind != "knife" or _gone:
		return
	draw_set_transform(Vector2(0, -HEIGHT), _spin)
	draw_line(Vector2(-5, 0), Vector2(1, 0), Color(0.35, 0.22, 0.12), 2.0)
	draw_line(Vector2(1, 0), Vector2(8, 0), Color(0.85, 0.88, 0.92), 1.6)
	draw_line(Vector2(1, -2), Vector2(1, 2), Color(0.5, 0.45, 0.4), 1.2)

func _on_area(a: Area2D) -> void:
	if _gone:
		return
	var target = a.get_meta("actor", null)
	if target == null or target == source or (collision_mask & 8 and not target is Player):
		return
	target.receive_hit(self)
	_burst()

func _on_body(b: Node) -> void:
	if not _gone and b is StaticBody2D:
		Sfx.play(self, "hit_bone", global_position, -10.0)
		_burst()

func _burst() -> void:
	_gone = true
	set_deferred("monitoring", false)
	if kind == "bolt":
		Fx.ring(get_parent(), global_position + Vector2(0, -HEIGHT), 2, 14, Color(0.8, 0.5, 1.0), 0.25, 2)
	else:
		Fx.hit_spark(get_parent(), global_position + Vector2(0, -HEIGHT))
	queue_free()
