class_name SkeletonEnemy
extends Actor
## Basic enemy: wanders, chases the player, telegraphs a sword slash,
## then leaves a recovery window to punish.

enum State { IDLE, CHASE, WINDUP, ATTACK, RECOVER, STAGGER, DEAD }

const SPEED := 52.0
const AGGRO := 150.0
const RANGE := 34.0
const WINDUP := 0.5
const RECOVER := 0.7

var player: Player
var state := State.IDLE
var home := Vector2.ZERO
var facing := Vector2.DOWN
var _t := 0.0
var _cooldown := 0.0
var _wander := Vector2.ZERO

func _ready() -> void:
	max_hp = 70
	max_poise = 30.0
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	add_to_group("enemies")
	setup_body(["res://assets/sprites/sword_bg.png", "res://assets/sprites/skeleton.png", "res://assets/sprites/sword_fg.png"], 16)
	home = global_position
	sprite.play("idle", 2.0)

func _physics_process(delta: float) -> void:
	queue_redraw()
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
			elif dist < RANGE and _cooldown <= 0.0:
				facing = to_p.normalized()
				_go(State.WINDUP)
				sprite.set_dir(LpcSprite.dir_from_vector(facing))
				sprite.play("slash", 0.0, false, true)
			else:
				_move(to_p.normalized() * SPEED)
		State.WINDUP:
			velocity = Vector2.ZERO
			var k := _t / WINDUP
			sprite.set_frame(int(k * 3.0))
			sprite.modulate = Color.WHITE.lerp(Color(2.0, 0.6, 0.6), k)
			if _t >= WINDUP:
				_go(State.ATTACK)
				sprite.modulate = Color.WHITE
				var c := global_position + Vector2(0, -18)
				Hitbox.spawn(get_parent(), self, c + facing * 20, 0, "circle", Vector2(26, 0), 18, 1, 8, 0.12)
				Fx.slash_arc(get_parent(), c, facing.angle(), 34, Color(1, 0.5, 0.4))
		State.ATTACK:
			velocity = facing * 90.0
			sprite.set_frame(3 + int(_t / 0.12 * 2))
			if _t >= 0.12:
				_go(State.RECOVER)
		State.RECOVER:
			velocity = Vector2.ZERO
			sprite.set_frame(5)
			if _t >= RECOVER:
				_cooldown = randf_range(0.3, 1.0)
				_go(State.CHASE)
		State.STAGGER:
			velocity = Vector2.ZERO
			if _t >= 0.6:
				_go(State.CHASE)
	velocity += apply_knockback(delta)
	move_and_slide()

func _go(s: State) -> void:
	state = s
	_t = 0.0

func _move(v: Vector2) -> void:
	velocity = v
	if v.length() > 1.0:
		facing = v.normalized()
		sprite.set_dir(LpcSprite.dir_from_vector(facing))
		sprite.play("walk", 9.0)
	else:
		sprite.play("idle", 2.0)

func on_stagger() -> void:
	_go(State.STAGGER)
	sprite.modulate = Color.WHITE
	sprite.play("idle", 0.0)
	Fx.float_text(get_parent(), global_position + Vector2(0, -50), "Brisé !", Color(1, 0.8, 0.3))

func on_hurt() -> void:
	if state == State.IDLE:
		_go(State.CHASE)

func die() -> void:
	state = State.DEAD
	sprite.modulate = Color.WHITE
	super.die()
	var t := create_tween()
	t.tween_interval(1.5)
	t.tween_property(self, "modulate:a", 0.0, 1.0)
	t.tween_callback(queue_free)
