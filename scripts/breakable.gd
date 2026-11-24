class_name Breakable
extends StaticBody2D
## A piece of scenery the hero can smash (barrels, jars, hay, small trees,
## rock piles...): the pack's "explosion" animations start with the intact
## object and end on its debris. It takes several blows (more for wood, more
## still for stone; a heavy attack counts double): each one shakes it and
## sends chips flying. The debris stays, and the way is free.

const SOUNDS := {"wood": "hit_bone", "stone": "rocks", "soft": "roll"}
## Health per material: a light sword blow does 18, a heavy one 36.
const HEALTH := {"soft": 30, "wood": 50, "stone": 70}

var sprite: AnimatedSprite2D
var material_kind := "wood"
var radius := 8.0
var broken := false
var hp := 50
## Plays a one-shot effect (chips of wood or stone) at a position; set by the game.
var chips: Callable
var _hurtbox: Area2D

func _ready() -> void:
	collision_layer = 1
	hp = HEALTH.get(material_kind, 50)
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
	hp -= h.damage if h != null else hp
	Sfx.play(self, SOUNDS.get(material_kind, "hit_bone"), global_position, -2.0 if hp <= 0 else -6.0)
	Fx.hit_spark(get_parent(), global_position + Vector2(0, -radius))
	if hp > 0:
		# Still standing: it shakes and chips fly off.
		var t := create_tween()
		var base := sprite.position
		for k in 4:
			t.tween_property(sprite, "position", base + Vector2(2.5 if k % 2 == 0 else -2.5, 0), 0.03)
		t.tween_property(sprite, "position", base, 0.03)
		if chips.is_valid() and material_kind != "soft":
			chips.call("hit_stone" if material_kind == "stone" else "hit_wood", global_position)
		return
	broken = true
	sprite.play()
	collision_layer = 0
	_hurtbox.queue_free()
	z_index = -1 if material_kind == "soft" else 0
	Fx.shake(1.5)
