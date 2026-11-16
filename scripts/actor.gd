class_name Actor
extends CharacterBody2D
## Shared base for the player, enemies and the boss: health, poise,
## being hit, knockback, flashing and death.

signal damaged(amount: int)
signal died

@export var max_hp := 100
@export var max_poise := 30.0
@export var poise_regen := 12.0
var hp := 100
var poise := 30.0
var dead := false
var invulnerable := false
var knockback := Vector2.ZERO
var sprite: LpcSprite
var hurtbox: Area2D
var body_height := 40.0
var shadow_size := Vector2(12, 5)

func setup_body(layers: Array, hurt_layer: int, radius: float = 7.0) -> void:
	hp = max_hp
	poise = max_poise
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	add_child(cs)
	sprite = LpcSprite.new()
	add_child(sprite)
	sprite.set_layers(layers)
	hurtbox = Area2D.new()
	hurtbox.collision_layer = hurt_layer
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.set_meta("actor", self)
	var hs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = radius + 4
	cap.height = body_height
	hs.shape = cap
	hs.position = Vector2(0, -body_height * 0.45)
	hurtbox.add_child(hs)
	add_child(hurtbox)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, shadow_size.y / shadow_size.x))
	draw_circle(Vector2.ZERO, shadow_size.x, Color(0, 0, 0, 0.35))

func regen_poise(delta: float) -> void:
	poise = minf(max_poise, poise + poise_regen * delta)

var _riposte_until := 0

## Called by a Hitbox. The player overrides it to block and parry.
func receive_hit(h: Hitbox) -> void:
	take_hit(h.damage, h.poise_damage, h.origin())

## Called on the attacker when the player parries it.
func on_parried() -> void:
	open_to_riposte()
	on_stagger()

func open_to_riposte(seconds: float = 1.6) -> void:
	_riposte_until = Time.get_ticks_msec() + int(seconds * 1000)

func take_hit(dmg: int, poise_dmg: float, from: Vector2) -> bool:
	if dead or invulnerable:
		return false
	if Time.get_ticks_msec() < _riposte_until:
		_riposte_until = 0
		dmg *= 2
		poise_dmg *= 2
		Fx.float_text(get_parent(), global_position + Vector2(0, -body_height - 14), "Riposte !", Color(1, 0.85, 0.3))
	hp = maxi(0, hp - dmg)
	poise -= poise_dmg
	damaged.emit(dmg)
	var away := (global_position - from).normalized()
	knockback = away * knockback_strength(dmg)
	flash()
	Fx.hit_spark(get_parent(), global_position + Vector2(0, -body_height * 0.5) - away * 6)
	if hp <= 0:
		die()
	elif poise <= 0:
		poise = max_poise
		on_stagger()
	else:
		on_hurt()
	return true

func knockback_strength(dmg: int) -> float:
	return 60.0 + dmg * 2.0

func flash() -> void:
	sprite.modulate = Color(4, 4, 4)
	var t := create_tween()
	t.tween_property(sprite, "modulate", base_modulate(), 0.15)

func base_modulate() -> Color:
	return Color.WHITE

func apply_knockback(delta: float) -> Vector2:
	var k := knockback
	knockback = knockback.move_toward(Vector2.ZERO, 600 * delta)
	return k

## Overridden by subclasses.
func on_hurt() -> void:
	pass

func on_stagger() -> void:
	pass

func die() -> void:
	dead = true
	velocity = Vector2.ZERO
	sprite.play("hurt", 9.0, false, true)
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	died.emit()
