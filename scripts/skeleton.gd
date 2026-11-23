class_name SkeletonEnemy
extends Actor
## Basic melee enemy (Flare skeleton or zombie): wanders, chases the player,
## telegraphs its attack, then leaves a recovery window to punish.
## kind "spear" thrusts from further away; "sword" swings wide.

enum State { IDLE, CHASE, WINDUP, ATTACK, RECOVER, STAGGER, DEAD }

const WINDUP := 0.5
const RECOVER := 0.7
## Per enemy type: health, damage, speed, sight, and the Flare sound prefix.
const TYPES := {
	"skeleton": {"hp": 70, "damage": 18, "speed": 52.0, "aggro": 150.0, "sound": "skeleton"},
	"skeleton_weak": {"hp": 45, "damage": 13, "speed": 58.0, "aggro": 150.0, "sound": "skeleton"},
	"zombie": {"hp": 90, "damage": 20, "speed": 40.0, "aggro": 130.0, "sound": "zombie"},
	"goblin": {"hp": 50, "damage": 14, "speed": 66.0, "aggro": 170.0, "sound": "goblin"},
	"goblin_elite": {"hp": 85, "damage": 20, "speed": 62.0, "aggro": 170.0, "sound": "goblin"},
	"antlion": {"hp": 110, "damage": 24, "speed": 48.0, "aggro": 140.0, "sound": "antlion"},
	"ice_ant": {"hp": 60, "damage": 16, "speed": 64.0, "aggro": 160.0, "sound": "antlion"},
	"fire_ant": {"hp": 65, "damage": 18, "speed": 64.0, "aggro": 160.0, "sound": "antlion"},
}

var SPEED := 52.0
var AGGRO := 150.0
var _damage := 18

var player: Player
var kind := "sword"
## A Flare enemy to draw instead of the LPC hoplite (isometric prototype).
var flare_name := "skeleton"
var state := State.IDLE
var home := Vector2.ZERO
var facing := Vector2.DOWN
var _t := 0.0
var _cooldown := 0.0
var _wander := Vector2.ZERO
var _stagger_time := 0.6

func _ready() -> void:
	var t: Dictionary = TYPES.get(flare_name, TYPES.skeleton)
	max_hp = t.hp
	_damage = t.damage
	SPEED = t.speed
	AGGRO = t.aggro
	max_poise = 30.0
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	add_to_group("enemies")
	hit_sound = "hit_bone"
	setup_body([], 16)
	home = global_position
	shadow_size = Vector2.ZERO  # Flare sprites draw their own shadow
	sprite.play("idle", 2.0)

func make_sprite():
	return HdSprite.flare(flare_name)

func _physics_process(delta: float) -> void:
	queue_redraw()
	sprite.facing8 = facing
	if dead:
		velocity = apply_knockback(delta)
		move_and_slide()
		return
	regen_poise(delta)
	_t += delta
	_cooldown -= delta
	var to_p := player.global_position - global_position if is_instance_valid(player) else Vector2.ZERO
	var dist := to_p.length()
	var player_ok := is_instance_valid(player) and not player.dead
	match state:
		State.IDLE:
			if player_ok and dist < AGGRO:
				_go(State.CHASE)
			else:
				if _t > 1.5:
					_t = 0.0
					_wander = Vector2.RIGHT.rotated(randf() * TAU) * (0.0 if randf() < 0.4 else 22.0)
					if global_position.distance_to(home) > 60:
						_wander = (home - global_position).normalized() * 22.0
				_move(_wander)
		State.CHASE:
			if not player_ok or dist > AGGRO * 1.8:
				_go(State.IDLE)
			elif dist < _range() and _cooldown <= 0.0:
				facing = to_p.normalized()
				_go(State.WINDUP)
				sprite.play(_anim(), 0.0, false, true)
			else:
				_move(to_p.normalized() * SPEED)
		State.WINDUP:
			velocity = Vector2.ZERO
			var k := _t / WINDUP
			sprite.set_frame(int(k * (4.0 if kind == "spear" else 3.0)))
			sprite.modulate = Color.WHITE.lerp(Color(2.0, 0.6, 0.6), k)
			if _t >= WINDUP:
				_go(State.ATTACK)
				sprite.modulate = Color.WHITE
				var c := global_position + Vector2(0, -18)
				if kind == "spear":
					Hitbox.spawn(get_parent(), self, c + facing * 36, facing.angle(), "rect", Vector2(56, 14), _damage, 1, 8, 0.12)
				else:
					Hitbox.spawn(get_parent(), self, c + facing * 20, 0, "circle", Vector2(26, 0), _damage, 1, 8, 0.12)
					Fx.slash_arc(get_parent(), c, facing.angle(), 34, Color(1, 0.5, 0.4))
				Sfx.play(self, "skeleton_swing", global_position)
		State.ATTACK:
			velocity = facing * 90.0
			if kind == "spear":
				sprite.set_frame(4 + int(_t / 0.12 * 2))
			else:
				sprite.set_frame(3 + int(_t / 0.12 * 2))
			if _t >= 0.12:
				_go(State.RECOVER)
		State.RECOVER:
			velocity = Vector2.ZERO
			sprite.set_frame(7 if kind == "spear" else 5)
			if _t >= RECOVER:
				_cooldown = randf_range(0.3, 1.0)
				_go(State.CHASE)
		State.STAGGER:
			velocity = Vector2.ZERO
			if _t >= _stagger_time:
				_go(State.CHASE)
	velocity += apply_knockback(delta)
	move_and_slide()

func _range() -> float:
	return 52.0 if kind == "spear" else 34.0

func _anim() -> String:
	return "thrust" if kind == "spear" else "slash"

func _go(s: State) -> void:
	state = s
	_t = 0.0

func _move(v: Vector2) -> void:
	velocity = v
	if v.length() > 1.0:
		facing = v.normalized()
		sprite.play("walk", 9.0)
	else:
		sprite.play("idle", 2.0)

func on_parried() -> void:
	open_to_riposte()
	_go(State.STAGGER)
	sprite.modulate = Color.WHITE
	sprite.play("idle", 0.0)
	_stagger_time = 1.4

func on_stagger() -> void:
	_go(State.STAGGER)
	_stagger_time = 0.6
	sprite.modulate = Color.WHITE
	sprite.play("idle", 0.0)
	Fx.float_text(get_parent(), global_position + Vector2(0, -50), "Brisé !", Color(1, 0.8, 0.3))

func take_hit(dmg: int, poise_dmg: float, from: Vector2) -> bool:
	var hit := super.take_hit(dmg, poise_dmg, from)
	if hit and not dead and randf() < 0.6:
		Sfx.flare(self, "enemies/%s_hit" % TYPES.get(flare_name, TYPES.skeleton).sound, global_position, -8.0)
	return hit

func on_hurt() -> void:
	if state == State.IDLE:
		_go(State.CHASE)

func die() -> void:
	state = State.DEAD
	Sfx.flare(self, "enemies/%s_die" % TYPES.get(flare_name, TYPES.skeleton).sound, global_position, -6.0)
	sprite.modulate = Color.WHITE
	super.die()
	var t := create_tween()
	t.tween_interval(1.5)
	t.tween_property(self, "modulate:a", 0.0, 1.0)
	t.tween_callback(queue_free)
