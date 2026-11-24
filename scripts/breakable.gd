class_name Breakable
extends StaticBody2D
## A piece of scenery the hero can smash (barrels, jars, hay, small trees,
## rock piles...): the pack's "explosion" animations start with the intact
## object and end on its debris. One hit breaks it; the debris stays, and the
## way is free.

const SOUNDS := {"wood": "hit_bone", "stone": "rocks", "soft": "roll"}

var sprite: AnimatedSprite2D
var material_kind := "wood"
var radius := 8.0
var broken := false
var _hurtbox: Area2D

func _ready() -> void:
	collision_layer = 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	add_child(cs)
	# Struck like an enemy: a hurtbox on the enemies' hurtbox layer.
	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = 16
	_hurtbox.collision_mask = 0
	_hurtbox.set_meta("actor", self)
	var hs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = radius + 4.0
	hs.shape = hc
	hs.position = Vector2(0, -radius)
	_hurtbox.add_child(hs)
	add_child(_hurtbox)
	sprite.stop()
	sprite.frame = 0

func receive_hit(h: Hitbox) -> void:
	if broken:
		return
	broken = true
	sprite.play()
	Sfx.play(self, SOUNDS.get(material_kind, "hit_bone"), global_position, -2.0)
	Fx.hit_spark(get_parent(), global_position + Vector2(0, -radius))
	collision_layer = 0
	_hurtbox.queue_free()
	z_index = -1 if material_kind == "soft" else 0
	if h != null:
		Fx.shake(1.5)
