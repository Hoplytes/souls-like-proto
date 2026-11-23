class_name Boss
extends Actor
## Asterion, the Minotaur. Three telegraphed attacks: a wide war-axe
## cleave (the THRUST states), a leap slam and a charge. Phase 2 (below half
## health) is faster and adds follow-ups.

signal phase_changed(phase: int)

enum State { DORMANT, CHASE, THRUST_WINDUP, THRUST, LEAP_WINDUP, LEAP_AIR, CHARGE_WINDUP, CHARGE, RECOVER, STAGGER, DEAD }

const SCALE := 1.6
const SPEED := 48.0
const BOSS_NAME := "Astérion, le Minotaure"
const CLEAVE_REACH := 40.0
const CLEAVE_RADIUS := 46.0

var player: Player
## A Flare enemy to draw instead of the LPC Minotaur (isometric prototype).
var flare_name := ""
var state := State.DORMANT
var phase := 1
var facing := Vector2.DOWN
var _t := 0.0
var _leap_from := Vector2.ZERO
var _leap_to := Vector2.ZERO
var _follow_up := false
var _recover_time := 0.9
var _last_attack := ""

func _ready() -> void:
	max_hp = 450
	max_poise = 110.0
	poise_regen = 8.0
	body_height = 64.0
	shadow_size = Vector2(20, 7)
	collision_layer = 4
	collision_mask = 1 | 2
	add_to_group("enemies")
	hit_sound = "hit_heavy"
	setup_body(["res://assets/sprites/minotaur_back.png", "res://assets/sprites/waraxe_bg.png",
		"res://assets/sprites/minotaur.png", "res://assets/sprites/waraxe_fg.png"], 16, 11.0, 192)
	if flare_name != "":
		shadow_size = Vector2.ZERO
	else:
		sprite.scale = Vector2.ONE * SCALE
	sprite.modulate = base_modulate()
	sprite.play("idle", 1.5)

func activate() -> void:
	if state == State.DORMANT:
		_go(State.CHASE)
		Sfx.play(self, "boss_roar", global_position, 2.0, 0.0)

func base_modulate() -> Color:
	return Color(1.0, 0.9, 0.9) if phase == 1 else Color(1.3, 0.7, 0.7)

func _speed_mult() -> float:
	return 1.0 if phase == 1 else 0.72  # shorter windups in phase 2

func make_sprite():
	return HdSprite.flare(flare_name) if flare_name != "" else LpcSprite.new()

func _physics_process(delta: float) -> void:
	queue_redraw()
	if flare_name != "":
		sprite.facing8 = facing
	if dead or state == State.DORMANT:
		velocity = apply_knockback(delta)
		move_and_slide()
		return
	regen_poise(delta)
	_t += delta
	var to_p := player.global_position - global_position
	var dist := to_p.length()
	var m := _speed_mult()
	match state:
		State.CHASE:
			if player.dead:
				_walk(Vector2.ZERO)
			elif _t > 0.35 * m:
				_choose_attack(to_p, dist)
			else:
				_walk(to_p.normalized() * SPEED)
		State.THRUST_WINDUP:
			velocity = Vector2.ZERO
			sprite.set_frame(int(clampf(_t / (0.65 * m), 0, 0.99) * 3))
			if _t >= 0.65 * m:
				_go(State.THRUST)
				var c := global_position + Vector2(0, -26)
				Hitbox.spawn(get_parent(), self, c + facing * CLEAVE_REACH, 0, "circle", Vector2(CLEAVE_RADIUS, 0), 26, 45, 8, 0.18)
				Fx.slash_arc(get_parent(), c, facing.angle(), CLEAVE_REACH + 26, Color(1, 0.6, 0.35), 0.2)
				Sfx.play(self, "swing_heavy", global_position, 2.0)
				Sfx.play(self, "boss_effort", global_position, 0.0)
				Fx.shake(3)
		State.THRUST:
			velocity = facing * 220.0 * (1.0 - _t / 0.25)
			sprite.set_frame(3 + int(_t / 0.25 * 2.99))
			if _t >= 0.25:
				if _follow_up:
					_follow_up = false
					_start_thrust()
				else:
					_recover()
		State.LEAP_WINDUP:
			velocity = Vector2.ZERO
			sprite.set_frame(0)
			sprite.position.y = 3.0 * sin(_t * 40.0)  # trembling crouch
			if _t >= 0.5 * m:
				_go(State.LEAP_AIR)
				sprite.position.y = 0
				collision_mask = 1
				Sfx.play(self, "boss_leap", global_position)
				Sfx.play(self, "boss_effort", global_position, 0.0)
				var radius := 52.0 if phase == 1 else 64.0
				Fx.zone(get_parent(), _leap_to, 0, "circle", Vector2(radius, 0), 0.65)
		State.LEAP_AIR:
			var k := _t / 0.65
			global_position = _leap_from.lerp(_leap_to, k)
			sprite.position.y = -70.0 * sin(k * PI)
			sprite.set_frame(1 if k < 0.5 else (2 if k < 0.85 else 4))
			velocity = Vector2.ZERO
			if k >= 1.0:
				sprite.position.y = 0
				collision_mask = 1 | 2
				var radius := 52.0 if phase == 1 else 64.0
				Hitbox.spawn(get_parent(), self, global_position, 0, "circle", Vector2(radius, 0), 30, 60, 8, 0.12, true)
				Fx.ring(get_parent(), global_position, 6, radius, Color(1, 0.8, 0.5), 0.3, 3)
				Sfx.play(self, "boss_slam", global_position, 3.0)
				Fx.shake(8)
				if phase == 2:
					_shockwave(radius)
				_recover()
		State.CHARGE_WINDUP:
			velocity = Vector2.ZERO
			sprite.play("walk", 4.0)
			sprite.modulate = base_modulate().lerp(Color(2, 0.5, 0.4), _t / (0.75 * m))
			if _t >= 0.75 * m:
				_go(State.CHARGE)
				sprite.modulate = base_modulate()
				sprite.play("walk", 20.0)
				Sfx.play(self, "boss_charge", global_position, 2.0)
				Hitbox.spawn(self, self, Vector2(0, -26), 0, "circle", Vector2(26, 0), 22, 50, 8, 0.8)
		State.CHARGE:
			velocity = facing * 270.0
			if _t > 0.08 and get_slide_collision_count() > 0 and get_slide_collision(0).get_collider() is StaticBody2D:
				Fx.shake(10)
				Sfx.play(self, "guard_break", global_position, 2.0)
				Fx.float_text(get_parent(), global_position + Vector2(0, -90), "Étourdi !", Color(1, 0.8, 0.3))
				on_stagger()
			elif _t >= 0.8:
				_recover()
		State.RECOVER:
			velocity = Vector2.ZERO
			sprite.play("idle", 1.5)
			if _t >= _recover_time * m:
				_go(State.CHASE)
		State.STAGGER:
			velocity = Vector2.ZERO
			if _t >= 1.6:
				_go(State.CHASE)
	velocity += apply_knockback(delta)
	move_and_slide()

func _choose_attack(to_p: Vector2, dist: float) -> void:
	facing = to_p.normalized()
	sprite.set_dir(LpcSprite.dir_from_vector(facing))
	var options: Array[String] = []
	if dist < 80:
		options = ["thrust", "thrust", "leap"]
	elif dist < 170:
		options = ["leap", "charge", "thrust"]
	else:
		options = ["charge", "leap"]
	if options.size() > 1 and _last_attack in options:
		options.erase(_last_attack)  # avoid the same attack three times in a row
	var pick: String = options.pick_random()
	_last_attack = pick
	match pick:
		"thrust":
			_follow_up = phase == 2
			_start_thrust()
		"leap":
			_go(State.LEAP_WINDUP)
			sprite.play("slash", 0.0, false, true)
			_leap_from = global_position
			_leap_to = global_position + to_p.limit_length(170.0)
		"charge":
			_go(State.CHARGE_WINDUP)
			Fx.zone(get_parent(), global_position + Vector2(0, -10), facing.angle(), "rect", Vector2(210, 40), 0.75 * _speed_mult())

func _start_thrust() -> void:
	facing = (player.global_position - global_position).normalized()
	sprite.set_dir(LpcSprite.dir_from_vector(facing))
	_go(State.THRUST_WINDUP)
	sprite.play("slash", 0.0, false, true)
	Fx.zone(get_parent(), global_position + facing * CLEAVE_REACH, 0, "circle", Vector2(CLEAVE_RADIUS, 0), 0.65 * _speed_mult())

func _shockwave(radius: float) -> void:
	var t := get_tree().create_timer(0.3, false)
	t.timeout.connect(func():
		if dead:
			return
		Fx.ring(get_parent(), global_position, radius, radius * 1.9, Color(1, 0.4, 0.3), 0.35, 4)
		Hitbox.spawn(get_parent(), self, global_position, 0, "circle", Vector2(radius * 1.8, 0), 18, 20, 8, 0.1, true))

func _recover() -> void:
	_go(State.RECOVER)
	_recover_time = randf_range(0.8, 1.2)

func _walk(v: Vector2) -> void:
	velocity = v
	if v.length() > 1.0:
		facing = v.normalized()
		sprite.set_dir(LpcSprite.dir_from_vector(facing))
		sprite.play("walk", 7.0)
	else:
		sprite.play("idle", 1.5)

func _go(s: State) -> void:
	state = s
	_t = 0.0

func take_hit(dmg: int, poise_dmg: float, from: Vector2) -> bool:
	var hit := super.take_hit(dmg, poise_dmg, from)
	if hit and not dead and randf() < 0.35:
		Sfx.play(self, "boss_hurt", global_position, -2.0)
	if hit and phase == 1 and hp <= max_hp / 2 and not dead:
		phase = 2
		sprite.modulate = base_modulate()
		Fx.ring(get_parent(), global_position, 10, 120, Color(1, 0.2, 0.2), 0.6, 4)
		Fx.float_text(get_parent(), global_position + Vector2(0, -100), "Astérion entre en rage !", Color(1, 0.3, 0.3))
		Fx.shake(8)
		Sfx.play(self, "boss_rage", global_position, 3.0, 0.0)
		phase_changed.emit(2)
	return hit

## A parried boss loses a chunk of poise and its combo; when the poise
## breaks it is staggered and open to a riposte.
func on_parried() -> void:
	poise -= 45.0
	_follow_up = false
	if poise <= 0.0:
		poise = max_poise
		open_to_riposte()
		on_stagger()
	else:
		_go(State.RECOVER)
		_recover_time = 0.9
		sprite.position.y = 0
		sprite.modulate = base_modulate()

func knockback_strength(_dmg: int) -> float:
	return 25.0 if state != State.STAGGER else 60.0

func on_stagger() -> void:
	_go(State.STAGGER)
	sprite.position.y = 0
	collision_mask = 1 | 2
	sprite.modulate = base_modulate()
	sprite.play("idle", 0.0)

func die() -> void:
	state = State.DEAD
	Sfx.play(self, "boss_death", global_position, 3.0, 0.0)
	sprite.position.y = 0
	sprite.modulate = Color.WHITE
	super.die()
