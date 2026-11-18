class_name Player
extends Actor
## The player, a Spartan hoplite: movement, roll with invincibility frames, stamina,
## light/heavy attacks with combos, shield block and parry, healing flasks
## and weapon swap.

signal stats_changed

enum State { FREE, ROLL, ATTACK, HEAL, BLOCK, STAGGER, DEAD }

const SPEED := 95.0
const ROLL_TIME := 0.48
const ROLL_IFRAMES := Vector2(0.03, 0.36)
const ROLL_COST := 22.0
const STAMINA_REGEN := 55.0
const STAMINA_DELAY := 0.5
const BUFFER_TIME := 0.3
const HEAL_TIME := 0.9
const HEAL_AMOUNT := 45
const PARRY_WINDOW := 0.18  # seconds after raising the shield
const BLOCK_ARC := deg_to_rad(75.0)  # half-angle of the shield's cover
const BLOCK_SPEED := 0.45

var max_stamina := 100.0
var stamina := 100.0
var flasks := 3
var max_flasks := 3
var weapon := "spear"
var state := State.FREE
var facing := Vector2.DOWN
var _stamina_wait := 0.0
var _t := 0.0
var _buffer := ""
var _buffer_t := 0.0
var _roll_dir := Vector2.ZERO
var _ghost_t := 0.0
var _landed := false
var _atk: Dictionary
var _atk_kind := ""
var _atk_phase := 0
var _combo := 0
var _healed := false
var _hit_iframes := 0.0
var _stagger_time := 0.35
var _shield: Sprite2D  # the shield raised in front of the body while blocking
var _guard_flash := 0.0
var _guard_jolt := 0.0
var _step_t := 0.0

func _ready() -> void:
	max_hp = 120
	max_poise = 1.0  # any hit staggers, except during heavy attacks
	collision_layer = 2
	collision_mask = 1 | 4
	setup_body(_layers_for(weapon), 8)
	sprite.pivot = 22.0  # rotate around the body's centre, for the roll
	sprite.play("idle", 2.0)
	_shield = Sprite2D.new()
	_shield.visible = false
	add_child(_shield)

func _layers_for(w: String) -> Array:
	var l: Array = Weapons.DATA[w].layers
	return ["res://assets/sprites/spartan_back.png", "res://assets/sprites/aspis_bg.png", l[0],
		"res://assets/sprites/spartan.png", "res://assets/sprites/aspis_fg.png", l[1]]

const ASPIS_LAYERS := [1, 4]  # indices of the shield layers in _layers_for()

func _physics_process(delta: float) -> void:
	queue_redraw()
	if state == State.DEAD:
		velocity = apply_knockback(delta)
		move_and_slide()
		return
	_hit_iframes = maxf(0.0, _hit_iframes - delta)
	_read_buffer(delta)
	_regen(delta)
	_t += delta
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	match state:
		State.FREE: _free(input)
		State.ROLL: _roll(delta)
		State.ATTACK: _attack(delta)
		State.HEAL: _heal(input)
		State.BLOCK: _block(input)
		State.STAGGER:
			velocity = Vector2.ZERO
			if _t >= _stagger_time:
				_to_free()
	velocity += apply_knockback(delta)
	move_and_slide()
	_guard_flash = maxf(0.0, _guard_flash - delta)
	_guard_jolt = maxf(0.0, _guard_jolt - delta)
	_update_shield()
	invulnerable = (state == State.ROLL and _t > ROLL_IFRAMES.x and _t < ROLL_IFRAMES.y) or _hit_iframes > 0.0
	stats_changed.emit()

func _read_buffer(delta: float) -> void:
	for a in ["roll", "attack_light", "attack_heavy", "heal", "switch_weapon", "block"]:
		if Input.is_action_just_pressed(a):
			_buffer = a
			_buffer_t = BUFFER_TIME
	_buffer_t -= delta
	if _buffer_t <= 0.0:
		_buffer = ""

func _take_buffer(allowed: Array) -> String:
	if _buffer in allowed:
		var b := _buffer
		_buffer = ""
		return b
	return ""

func _regen(delta: float) -> void:
	if state in [State.ROLL, State.ATTACK]:
		return
	_stamina_wait -= delta
	if _stamina_wait <= 0.0:
		var k := 0.5 if state == State.HEAL else (0.3 if state == State.BLOCK else 1.0)
		stamina = minf(max_stamina, stamina + STAMINA_REGEN * delta * k)

func _spend(cost: float) -> bool:
	if stamina <= 0.0:
		return false
	stamina = maxf(0.0, stamina - cost)
	_stamina_wait = STAMINA_DELAY
	return true

func _to_free() -> void:
	state = State.FREE
	_t = 0.0
	_reset_sprite()

# --- free movement -------------------------------------------------------

func _free(input: Vector2) -> void:
	if input != Vector2.ZERO:
		facing = input.normalized()
	var action := _take_buffer(["roll", "attack_light", "attack_heavy", "heal", "switch_weapon", "block"])
	if _start_action(action, input):
		return
	if Input.is_action_pressed("block"):
		_start_block()
		return
	velocity = input * SPEED
	sprite.set_dir(LpcSprite.dir_from_vector(facing))
	if input != Vector2.ZERO:
		sprite.play("walk", 11.0)
		_step_t -= get_physics_process_delta_time()
		if _step_t <= 0.0:
			_step_t = 0.3
			Sfx.play(self, "step", null, -8.0, 0.1)
	else:
		sprite.play("idle", 2.0)

func _start_action(action: String, input: Vector2) -> bool:
	match action:
		"roll":
			if _spend(ROLL_COST):
				_start_roll(input)
				return true
		"attack_light", "attack_heavy":
			var kind := "light" if action == "attack_light" else "heavy"
			if stamina > 0.0:
				_combo = 0
				_start_attack(kind, input)
				return true
		"block":
			_start_block()
			return true
		"heal":
			if flasks > 0:
				state = State.HEAL
				_t = 0.0
				_healed = false
				sprite.play("idle", 2.0)
				return true
		"switch_weapon":
			weapon = "spear" if weapon == "sword" else "sword"
			sprite.set_layers(_layers_for(weapon))
			Fx.float_text(get_parent(), global_position + Vector2(0, -50), Weapons.DATA[weapon].name, Color(0.9, 0.85, 0.6))
	return false

# --- roll ----------------------------------------------------------------

func _start_roll(input: Vector2) -> void:
	state = State.ROLL
	_t = 0.0
	_ghost_t = 0.08
	_landed = false
	_roll_dir = input.normalized() if input != Vector2.ZERO else facing
	facing = _roll_dir
	sprite.set_dir(LpcSprite.dir_from_vector(_roll_dir))
	sprite.play("jump", 0.0, false, true)
	sprite.set_frame(1)
	Sfx.play(self, "roll", null, -4.0)
	Fx.dust(get_parent(), global_position, -_roll_dir)

## The roll: crouch, a full tumble while tucked, then a crouched landing.
## Sideways it spins; up or down it squashes like a forward roll.
func _roll(delta: float) -> void:
	var k := _t / ROLL_TIME
	velocity = _roll_dir * lerpf(300.0, 90.0, k * k)  # ~110 px
	var tumble := clampf((k - 0.12) / 0.68, 0.0, 1.0)  # 0..1 during the tucked part
	var sideways := absf(_roll_dir.x) > absf(_roll_dir.y)
	if k < 0.12:
		sprite.set_frame(1)
		sprite.scale = Vector2(1.1, 0.85)
	elif k < 0.8:
		sprite.set_frame(3 if fmod(tumble * 4.0, 2.0) < 1.0 else 2)
		sprite.position.y = -sprite.pivot + 9.0  # tucked frames are drawn mid-air: bring them to the ground
		if sideways:
			sprite.rotation = signf(_roll_dir.x) * tumble * TAU
			sprite.scale = Vector2(0.9, 0.9)
		else:
			var c := cos(tumble * TAU * 2.0)  # two quick flips read as a forward roll
			sprite.scale = Vector2(1.05, 0.5 + 0.45 * absf(c))
			sprite.position.x = sin(tumble * TAU) * 2.0
	else:
		_reset_sprite()
		sprite.set_frame(1 if k < 0.92 else 0)
		sprite.scale = Vector2(1.08, 0.9) if k < 0.92 else Vector2.ONE
		if not _landed:
			_landed = true
			Fx.dust(get_parent(), global_position, _roll_dir * 0.5)
	if k < 0.8:
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_spawn_ghost()
			_ghost_t = 0.07
	if _t >= ROLL_TIME:
		_to_free()

func _reset_sprite() -> void:
	sprite.scale = Vector2.ONE
	sprite.rotation = 0.0
	sprite.position = Vector2(0, -sprite.pivot)

func _spawn_ghost() -> void:
	var g := sprite.duplicate()
	g.set_process(false)
	g.modulate = Color(0.35, 0.45, 0.85, 0.35)
	g.global_position = sprite.global_position
	g.z_index = -1
	get_parent().add_child(g)
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, 0.22)
	t.tween_callback(g.queue_free)

# --- attacks -------------------------------------------------------------

func _soft_lock(input: Vector2) -> Vector2:
	if input != Vector2.ZERO:
		return input.normalized()
	var best: Node2D = null
	var best_d := 80.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return (best.global_position - global_position).normalized() if best else facing

func _start_attack(kind: String, input: Vector2) -> void:
	var w: Dictionary = Weapons.DATA[weapon]
	_atk = w[kind]
	_atk_kind = kind
	_spend(_atk.stamina)
	facing = _soft_lock(input)
	sprite.set_dir(LpcSprite.dir_from_vector(facing))
	sprite.play(w.anim, 0.0, false, true)
	state = State.ATTACK
	_atk_phase = 0
	_t = 0.0

func _attack(_delta: float) -> void:
	var w: Dictionary = Weapons.DATA[weapon]
	var f0: int = w.frames[0]
	var f1: int = w.frames[1]
	var n := sprite.frame_count()
	var wu: float = _atk.windup
	var ac: float = _atk.active
	var rc: float = _atk.recovery
	velocity = Vector2.ZERO
	if _t < wu:
		sprite.set_frame(int(_t / wu * f0))
		if _atk_kind == "heavy":
			sprite.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.6, 1.4, 0.9), _t / wu)
	elif _t < wu + ac:
		if _atk_phase == 0:
			_atk_phase = 1
			sprite.modulate = Color.WHITE
			_spawn_hitbox()
		sprite.set_frame(f0 + int((_t - wu) / ac * (f1 - f0)))
		velocity = facing * (_atk.step / ac)
	elif _t < wu + ac + rc:
		_atk_phase = 2
		var k := (_t - wu - ac) / rc
		sprite.set_frame(mini(n - 1, f1 + int(k * (n - f1))))
		# Chain a combo, or roll out of the second half of the recovery.
		if k > 0.25 and _buffer in ["attack_light", "attack_heavy"] and _combo < 2 and stamina > 0.0:
			var kind := "light" if _take_buffer(["attack_light", "attack_heavy"]) == "attack_light" else "heavy"
			_combo += 1
			_start_attack(kind, Input.get_vector("move_left", "move_right", "move_up", "move_down"))
		elif k > 0.5 and _buffer == "block":
			_buffer = ""
			_start_block()
		elif k > 0.5 and _buffer == "roll" and _spend(ROLL_COST):
			_buffer = ""
			_start_roll(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	else:
		_to_free()

func _spawn_hitbox() -> void:
	var center := global_position + Vector2(0, -18)
	var pos := center + facing * float(_atk.reach)
	var swing := "swing_heavy" if _atk_kind == "heavy" else ("thrust" if weapon == "spear" else "swing_light")
	Sfx.play(self, swing, null, -3.0)
	if _atk_kind == "heavy":
		Sfx.play(self, "player_effort", null, -4.0)
	Hitbox.spawn(get_parent(), self, pos, facing.angle(), _atk.shape, _atk.size,
		_atk.damage, _atk.poise, 16, _atk.active + 0.02)
	if _atk.shape == "circle":
		Fx.slash_arc(get_parent(), center, facing.angle(), _atk.size.x + _atk.reach * 0.6,
			Color(1, 1, 1, 0.9) if _atk_kind == "light" else Color(1, 0.85, 0.5))
	else:
		Fx.ring(get_parent(), pos + facing * _atk.size.x * 0.4, 2, 10, Color(1, 1, 1, 0.8), 0.12)

# --- shield: block and parry ---------------------------------------------

func _start_block() -> void:
	state = State.BLOCK
	_t = 0.0
	facing = _soft_lock(Vector2.ZERO) if _nearest_enemy(150.0) else facing
	_block_pose()

## Hoplite guard: spear drawn back behind the shield, or sword raised.
func _block_pose() -> void:
	sprite.set_dir(LpcSprite.dir_from_vector(facing))
	if weapon == "spear":
		sprite.play("thrust", 0.0, false, true)
		sprite.set_frame(0)
	else:
		sprite.play("slash", 0.0, false, true)
		sprite.set_frame(0)

func _block(input: Vector2) -> void:
	velocity = input * SPEED * BLOCK_SPEED
	# Keep the shield toward the closest enemy, so you can circle around it.
	var e := _nearest_enemy(150.0)
	if e:
		facing = (e.global_position - global_position).normalized()
	elif input != Vector2.ZERO:
		facing = input.normalized()
	_block_pose()
	var action := _take_buffer(["roll", "attack_light", "attack_heavy"])
	if action == "roll" and _spend(ROLL_COST):
		_start_roll(input)
	elif action != "":
		_combo = 0
		_start_attack("light" if action == "attack_light" else "heavy", input)
	elif not Input.is_action_pressed("block") and _t > 0.1:
		_to_free()

func _nearest_enemy(radius: float) -> Node2D:
	var best: Node2D = null
	var best_d := radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func is_parrying() -> bool:
	return state == State.BLOCK and _t < PARRY_WINDOW

func _covers(from: Vector2) -> bool:
	var to_attacker := (from - global_position).normalized()
	return absf(facing.angle_to(to_attacker)) <= BLOCK_ARC

func receive_hit(h: Hitbox) -> void:
	if dead or invulnerable:
		return
	var from := h.origin()
	if state != State.BLOCK or h.unblockable or not _covers(from):
		take_hit(h.damage, h.poise_damage, from)
		return
	var spark := global_position + Vector2(0, -20) + facing * 12
	if is_parrying():
		# Perfect parry: no cost, the attacker is thrown off balance.
		stamina = minf(max_stamina, stamina + 10.0)
		_guard_flash = 0.3
		Sfx.play(self, "parry", null, 0.0, 0.03)
		Fx.ring(get_parent(), spark, 2, 26, Color(1, 0.9, 0.4), 0.25, 3)
		Fx.hit_spark(get_parent(), spark)
		Fx.float_text(get_parent(), global_position + Vector2(0, -56), "Parade !", Color(1, 0.9, 0.4))
		Fx.hitstop(get_tree(), 0.12)
		Fx.shake(3)
		if is_instance_valid(h.source) and h.source.has_method("on_parried"):
			h.source.on_parried()
		return
	var cost := h.damage * 1.3 + h.poise_damage * 0.3
	_stamina_wait = STAMINA_DELAY
	knockback = (global_position - from).normalized() * (40.0 + h.damage * 2.0)
	Fx.hit_spark(get_parent(), spark)
	_guard_jolt = 0.1
	if stamina >= cost:
		stamina -= cost
		Fx.shake(2)
		Sfx.play(self, "block", null, -2.0)
		return
	Sfx.play(self, "guard_break")
	# Guard broken: the shield is knocked aside and half the blow gets through.
	stamina = 0.0
	Fx.float_text(get_parent(), global_position + Vector2(0, -56), "Garde brisée", Color(1, 0.5, 0.3))
	take_hit(int(h.damage * 0.5), 99.0, from)
	_stagger_time = 0.9

## Shows the shield held up in front of the body, facing the threat:
## round face toward the camera, edge-on to the sides, inner face from behind.
## It snaps up in a few frames, flashes gold during the parry window and
## jolts when a blow lands on it.
func _update_shield() -> void:
	var blocking := state == State.BLOCK
	for i in ASPIS_LAYERS:
		sprite.set_layer_visible(i, not blocking)
	_shield.visible = blocking
	if not blocking:
		return
	var d := LpcSprite.dir_from_vector(facing)
	var target := Vector2.ZERO
	match d:
		LpcSprite.Dir.DOWN:
			_shield.texture = preload("res://assets/sprites/shield_front.png")
			target = Vector2(-2, -27)
			_shield.flip_h = false
			_shield.z_index = 1
		LpcSprite.Dir.UP:
			_shield.texture = preload("res://assets/sprites/shield_back.png")
			target = Vector2(-10, -26)  # peeks out beside the body
			_shield.flip_h = false
			_shield.z_index = -1
		_:
			_shield.texture = preload("res://assets/sprites/shield_side.png")
			var side := -1.0 if d == LpcSprite.Dir.LEFT else 1.0
			target = Vector2(10 * side, -24)
			_shield.flip_h = side > 0
			_shield.z_index = 1
	var raise := clampf(_t / 0.07, 0.0, 1.0)
	_shield.position = Vector2(0, -12).lerp(target, raise) - facing * 3.0 * (_guard_jolt / 0.1)
	_shield.scale = Vector2.ONE * lerpf(0.75, 1.0, raise)
	if _guard_flash > 0.0:
		_shield.modulate = Color(2.2, 1.9, 1.0)
	elif is_parrying():
		_shield.modulate = Color(1.35, 1.25, 0.95)
	else:
		_shield.modulate = Color.WHITE

# --- healing -------------------------------------------------------------

func _heal(input: Vector2) -> void:
	velocity = input * SPEED * 0.35
	if input != Vector2.ZERO:
		facing = input.normalized()
		sprite.set_dir(LpcSprite.dir_from_vector(facing))
	sprite.modulate = Color(1, 1, 1).lerp(Color(0.8, 1.5, 0.8), sin(_t / HEAL_TIME * PI))
	if not _healed and _t >= HEAL_TIME * 0.55:
		_healed = true
		flasks -= 1
		hp = mini(max_hp, hp + HEAL_AMOUNT)
		Sfx.play(self, "heal", null, -4.0, 0.0)
		Fx.ring(get_parent(), global_position, 4, 22, Color(0.5, 1, 0.5), 0.4)
		Fx.float_text(get_parent(), global_position + Vector2(0, -50), "+%d" % HEAL_AMOUNT, Color(0.5, 1, 0.5))
	if _t >= HEAL_TIME:
		sprite.modulate = Color.WHITE
		_to_free()

# --- being hit -----------------------------------------------------------

func take_hit(dmg: int, poise_dmg: float, from: Vector2) -> bool:
	var armored := state == State.ATTACK and _atk_kind == "heavy" and _atk_phase >= 1
	if armored:
		poise_dmg = 0.0
		poise = max_poise
	var hit := super.take_hit(dmg, poise_dmg, from)
	if hit:
		Sfx.play(self, "player_hurt", null, -2.0)
		_hit_iframes = 0.45
		Fx.shake(4.0 + dmg * 0.1)
		Fx.hitstop(get_tree(), 0.07)
	return hit

func on_stagger() -> void:
	state = State.STAGGER
	_t = 0.0
	_stagger_time = 0.35
	sprite.modulate = Color.WHITE
	_reset_sprite()
	sprite.play("idle", 0.0)

func die() -> void:
	state = State.DEAD
	Sfx.play(self, "player_death", null, 0.0, 0.0)
	sprite.modulate = Color.WHITE
	_reset_sprite()
	super.die()

func rest() -> void:
	hp = max_hp
	flasks = max_flasks
	stamina = max_stamina
