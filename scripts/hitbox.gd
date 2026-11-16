class_name Hitbox
extends Area2D
## A short-lived damage zone. Hits each hurtbox at most once.

var damage := 10
var poise_damage := 10
var source: Node2D
var _hit := {}

static func spawn(parent: Node, src: Node2D, pos: Vector2, rot: float, shape_kind: String,
		size: Vector2, dmg: int, poise: int, target_layer: int, life: float) -> Hitbox:
	var h := Hitbox.new()
	h.source = src
	h.damage = dmg
	h.poise_damage = poise
	h.collision_layer = 0
	h.collision_mask = target_layer
	h.monitorable = false
	var cs := CollisionShape2D.new()
	if shape_kind == "circle":
		var c := CircleShape2D.new()
		c.radius = size.x
		cs.shape = c
	else:
		var r := RectangleShape2D.new()
		r.size = size
		cs.shape = r
	h.add_child(cs)
	h.position = pos
	h.rotation = rot
	parent.add_child(h)
	h.area_entered.connect(h._on_area)
	h.get_tree().create_timer(life, false).timeout.connect(h.queue_free)
	return h

func _on_area(a: Area2D) -> void:
	var target = a.get_meta("actor", null)
	if target == null or target == source or _hit.has(target):
		return
	_hit[target] = true
	target.take_hit(damage, poise_damage, source.global_position if is_instance_valid(source) else global_position)
