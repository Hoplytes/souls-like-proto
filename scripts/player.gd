class_name Player
extends Actor
## The player: movement, roll with invincibility frames, stamina, light and
## heavy attacks with combos (moveset set by the weapon), block and parry,
## healing flasks. Drawn as the modular hero of the character creator
## fighter with the round shield of the fantasy pack, or as the HD knight.

signal stats_changed

enum State { FREE, ROLL, ATTACK, HEAL, BLOCK, STAGGER, DEAD }

const SPEED := 95.0
## Souls-like feel: walking answers at once (almost no inertia); the weight
## comes from committing to actions (attacks, rolls) that cannot be
## cancelled early, and from the equipment load (heavier armour, heavier roll).
const ACCEL := 1500.0  # px/s² (full speed in ~0.06 s)
const DECEL := 1300.0
const TURN_SPEED := 22.0  # rad/s: a quick pivot, not an instant flip
## Walk cycle speed (frames played per second, before conversion to the sheet).
const WALK_ANIM := 9.5
## Attacks follow the stick during the first part of the windup only.
const ATTACK_TRACKING := 0.4
const ROLL_TIME := 0.56
const ROLL_IFRAMES := Vector2(0.0, 0.43)  # from the first frame, 433 ms (Dark Souls 3 medium roll)
## Rolls by equipment load (Dark Souls' fast / medium / fat roll): distance
## factor and recovery (end of the roll where nothing can be done), in s.
const ROLLS := {
	"light": {"distance": 1.08, "recovery": 0.10, "iframes": 1.1},
	"medium": {"distance": 1.0, "recovery": 0.16, "iframes": 1.0},
	"heavy": {"distance": 0.82, "recovery": 0.30, "iframes": 0.8},
}
const ROLL_COST := 22.0
const STAMINA_REGEN := 45.0
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
var weapon := "longsword"
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
var _guard_flash := 0.0
var _step_t := 0.0
## True when the HD knight (licensed art in res://local/) is the chosen model.
var hd := false
## True for the hero of the fantasy pack (licensed): also an "hd" model, with
## three different swings, strafing steps and a backward run.
var pack := false
var _roll_class := "medium"
var _heavy_k := 0
## Lock-on (Souls): the hero keeps facing the locked enemy and strafes around it.
const LOCK_RANGE := 230.0  # px to pick a target
const LOCK_BREAK := 320.0  # px at which the lock is lost
var lock_target: Node2D
var _lock_marker: LockMarker
var _stick_flicked := false

func make_sprite():
	if pack:
		return HdSprite.flare("pack/hero")
	var k := HdSprite.new()
	k.set_res(128.0 / 96.0)  # same artist as the pack: drawn at the scale of its characters
	return k

func _ready() -> void:
	pack = HeroConfig.data.model == "pack_hero" and HdSprite.pack_available()
	hd = true  # both models have their own roll, block and heal animations
	weapon = "longsword"
	if hd:
		shadow_size = Vector2.ZERO  # its sheets include a shadow
	max_hp = 120
	max_poise = 1.0  # any hit staggers, except during heavy attacks
	collision_layer = 2
	collision_mask = 1 | 4
	setup_body([], 8, 7.0, 160)
	_roll_class = "light" if pack else "medium"  # the armoured knight rolls heavier
	_lock_marker = LockMarker.new()
	add_child(_lock_marker)
	_lock_marker.top_level = true
	sprite.pivot = 22.0  # rotate around the body's centre, for the roll
	sprite.play("idle", 2.0)

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
	_update_lock(delta)
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
	sprite.facing8 = facing
	var iframes_end: float = ROLL_IFRAMES.x + (ROLL_IFRAMES.y - ROLL_IFRAMES.x) * ROLLS[_roll_class].iframes
	invulnerable = (state == State.ROLL and _t > ROLL_IFRAMES.x and _t < iframes_end) or _hit_iframes > 0.0
	stats_changed.emit()

func _read_buffer(delta: float) -> void:
	for a in ["roll", "attack_light", "attack_heavy", "heal", "block"]:
		if Input.is_action_just_pressed(a):
			_buffer = a
			_buffer_t = BUFFER_TIME
	# An input given during an attack or a roll waits for its end (Souls' buffer).
	if state not in [State.ATTACK, State.ROLL]:
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
	sprite.modulate = Color.WHITE

# --- free movement -------------------------------------------------------

func _free(input: Vector2) -> void:
	var delta := get_physics_process_delta_time()
	if lock_target:
		_turn_toward(_to_target(), delta)
	elif input != Vector2.ZERO:
		_turn_toward(input.normalized(), delta)
	var action := _take_buffer(["roll", "attack_light", "attack_heavy", "heal", "block"])
	if _start_action(action, input):
		return
	if Input.is_action_pressed("block"):
		_start_block()
		return
	# Momentum: speed builds up along the way the hero faces.
	if input != Vector2.ZERO:
		# Locked: strafe where the stick points; free: walk where the hero faces.
		var dir := input.normalized() if lock_target else facing
		var target := dir * SPEED * minf(1.0, input.length())
		velocity = velocity.move_toward(target, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, DECEL * delta)
	var pace := velocity.length() / SPEED
	if pace > 0.1:
		sprite.play(_move_anim(), WALK_ANIM * clampf(pace, 0.5, 1.0))
		_step_t -= delta * pace
		if _step_t <= 0.0:
			_step_t = 4.5 / WALK_ANIM  # two steps per walk cycle
			Sfx.flare(self, "steps/step_%s%d" % [_step_kind(), randi_range(1, 4)], null, -10.0, 0.08)
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
	return false

## Walking, or, locked on an enemy with a model that has them, strafing
## steps and a backward run.
func _move_anim() -> String:
	if lock_target == null or not (sprite is HdSprite) or not sprite.has_anim("strafe_left"):
		return "walk"
	var v := velocity.normalized()
	var ahead := facing.dot(v)
	if ahead > 0.6:
		return "walk"
	if ahead < -0.6:
		return "back"
	return "strafe_right" if facing.cross(v) > 0.0 else "strafe_left"

## Turns the hero at a limited speed (no instant about-turn).
func _turn_toward(dir: Vector2, delta: float) -> void:
	var a := facing.angle()
	var b := dir.angle()
	facing = Vector2.from_angle(rotate_toward(a, b, TURN_SPEED * delta))

# --- roll ----------------------------------------------------------------

func _start_roll(input: Vector2) -> void:
	state = State.ROLL
	_t = 0.0
	_ghost_t = 0.08
	_landed = false
	_roll_dir = input.normalized() if input != Vector2.ZERO else facing
	facing = _roll_dir
	if hd:
		sprite.play("jump", 0.0, false, true)
	else:
		sprite.play("stagger", 0.0, false, true)  # the tucked pose of the tumble
		sprite.set_progress(0.6)
	Sfx.play(self, "roll", null, -4.0)
	Fx.dust(get_parent(), global_position, -_roll_dir)

## The roll. The HD knight has a real animation; the modular hero dashes
## low: a crouch, two quick squashes while tucked, then a landing.
func _roll(delta: float) -> void:
	var k := minf(1.0, _t / ROLL_TIME)
	var r: Dictionary = ROLLS[_roll_class]
	if _t > ROLL_TIME:  # committed: a short recovery, slowing to a stop
		velocity = _roll_dir * lerpf(60.0, 0.0, (_t - ROLL_TIME) / r.recovery) * r.distance
		if _t >= ROLL_TIME + r.recovery:
			_to_free()
		return
	velocity = _roll_dir * lerpf(255.0, 80.0, k * k) * r.distance  # ~110 px
	if hd:  # the HD hero has a real roll animation
		sprite.set_progress(k)
		if k > 0.8 and not _landed:
			_landed = true
			Fx.dust(get_parent(), global_position, _roll_dir * 0.5)
		return
	var tumble := clampf((k - 0.12) / 0.68, 0.0, 1.0)  # 0..1 during the tucked part
	if k < 0.12:
		sprite.scale = Vector2(1.1, 0.85)
	elif k < 0.8:
		sprite.position.y = -sprite.pivot + 4.0
		var c := cos(tumble * TAU * 2.0)  # two quick squashes read as a dashing tumble
		sprite.scale = Vector2(1.05, 0.5 + 0.45 * absf(c))
		sprite.position.x = sin(tumble * TAU) * 2.0
	else:
		_reset_sprite()
		if k >= 0.92:
			sprite.play("idle", 2.0)
		sprite.scale = Vector2(1.08, 0.9) if k < 0.92 else Vector2.ONE
		if not _landed:
			_landed = true
			Fx.dust(get_parent(), global_position, _roll_dir * 0.5)
	if k < 0.8:
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_spawn_ghost()
			_ghost_t = 0.07

func _reset_sprite() -> void:
	sprite.scale = Vector2.ONE
	sprite.rotation = 0.0
	sprite.position = Vector2(0, -sprite.pivot - sprite.lift)

func _spawn_ghost() -> void:
	var g: Node2D = sprite.duplicate()
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
	if lock_target:
		return _to_target()
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
	_atk = Weapons.moves(weapon)[kind].duplicate()
	if _combo > 0:  # follow-ups of a combo come out quicker than the opener
		_atk.windup *= 0.7
	_atk_kind = kind
	_spend(_atk.stamina)
	facing = _soft_lock(input)
	# Light: three different swings in a combo; heavy: two swings in turn.
	var anim: String = ["slash", "slash2", "slash3"][clampi(_combo, 0, 2)]
	if kind == "heavy":
		anim = ["slash_heavy", "slash_heavy2"][_heavy_k % 2]
		_heavy_k += 1
	if not sprite.has_anim(anim):
		anim = "slash_heavy" if kind == "heavy" else "slash"
	sprite.play(anim, 0.0, false, true)
	state = State.ATTACK
	_atk_phase = 0
	_t = 0.0

func _attack(_delta: float) -> void:
	var wu: float = _atk.windup
	var ac: float = _atk.active
	var rc: float = _atk.recovery
	velocity = Vector2.ZERO
	sprite.set_progress(_t / (wu + ac + rc))
	# Early in the windup the swing can still be aimed; then it is locked.
	var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _t < wu * ATTACK_TRACKING and lock_target:
		_turn_toward(_to_target(), _delta)
	elif _t < wu * ATTACK_TRACKING and stick != Vector2.ZERO:
		_turn_toward(stick.normalized(), _delta)
	if _t < wu:
		# Immediate feedback (Bloodborne): the windup starts at once with a
		# small step forward, even if the hit itself comes later.
		if _t < wu * 0.5:
			velocity = facing * 28.0
		if _atk_kind == "heavy":
			sprite.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.6, 1.4, 0.9), _t / wu)
	elif _t < wu + ac:
		if _atk_phase == 0:
			_atk_phase = 1
			sprite.modulate = Color.WHITE
			_spawn_hitbox()
		velocity = facing * (_atk.step / ac)
	elif _t < wu + ac + rc:
		_atk_phase = 2
		var k := (_t - wu - ac) / rc
		# Chain a combo, or roll out of the second half of the recovery.
		if k > 0.45 and _buffer in ["attack_light", "attack_heavy"] and _combo < 2 and stamina > 0.0:
			var kind := "light" if _take_buffer(["attack_light", "attack_heavy"]) == "attack_light" else "heavy"
			_combo += 1
			_start_attack(kind, Input.get_vector("move_left", "move_right", "move_up", "move_down"))
		elif k > 0.7 and _buffer == "block":
			_buffer = ""
			_start_block()
		elif k > 0.7 and _buffer == "roll" and _spend(ROLL_COST):
			_buffer = ""
			_start_roll(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	else:
		_to_free()

func _spawn_hitbox() -> void:
	var center := global_position + Vector2(0, -18)
	var pos := center + facing * float(_atk.reach)
	var swing := "swing_heavy" if _atk_kind == "heavy" or Weapons.two_handed(weapon) else "swing_light"
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

## Footsteps: leather for the fighter, metal for the armoured knight.
func _step_kind() -> String:
	return "leather" if pack else "metal"

func _start_block() -> void:
	state = State.BLOCK
	_t = 0.0
	facing = _soft_lock(Vector2.ZERO) if _nearest_enemy(150.0) else facing
	_block_pose()

## Raise the shield (or the weapon, two-handed), then hold the guard.
func _block_pose() -> void:
	if hd:
		if _t < 0.25:
			sprite.play("block_start", 0.0, false)
			sprite.set_progress(_t / 0.25)
		else:
			sprite.play("block", 12.0 * 8.0 / 15.0)
		return
	sprite.play("block", 0.0, false)
	sprite.set_progress(minf(0.99, _t / 0.08))
	if _guard_flash > 0.0:
		sprite.modulate = Color(1.8, 1.6, 1.0)
	elif is_parrying():
		sprite.modulate = Color(1.25, 1.2, 1.0)
	else:
		sprite.modulate = Color.WHITE

func _block(input: Vector2) -> void:
	velocity = input * SPEED * BLOCK_SPEED
	# Keep the shield toward the closest enemy, so you can circle around it.
	var e: Node2D = lock_target if lock_target else _nearest_enemy(150.0)
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

# --- lock-on ---------------------------------------------------------------

func _to_target() -> Vector2:
	var d := lock_target.global_position - global_position
	return d.normalized() if d.length() > 1.0 else facing

func _lockable(e: Node) -> bool:
	return is_instance_valid(e) and not e.dead and e.is_inside_tree() and e.visible \
		and global_position.distance_to(e.global_position) < LOCK_RANGE

## The enemy to lock: the closest, favouring the ones in front of the hero
## (or, to switch, the next one on the given side of the current target).
func _pick_target(side: int = 0) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	var ref := _to_target() if lock_target else facing
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _lockable(e) or e == lock_target:
			continue
		var to: Vector2 = e.global_position - global_position
		var score := to.length() * (1.6 - 0.6 * ref.dot(to.normalized()))
		if side != 0:
			var turn := ref.angle_to(to)  # > 0: clockwise on screen = to the right
			if signf(turn) != side:
				continue
			score = absf(turn) * 100.0 + to.length() * 0.2
		if score < best_score:
			best_score = score
			best = e
	return best

func toggle_lock() -> void:
	if lock_target:
		_set_lock(null)
	else:
		var t := _pick_target()
		if t:
			_set_lock(t)
		else:
			# Like the Souls: no enemy around, the camera simply recentres.
			Fx.camera.position = Vector2(0, -20)

func _set_lock(t: Node2D) -> void:
	lock_target = t
	_lock_marker.target = t
	if t:
		Sfx.play(self, "block", null, -18.0, 0.0)

func _update_lock(delta: float) -> void:
	if Input.is_action_just_pressed("lock"):
		toggle_lock()
	var side := 0
	if Input.is_action_just_pressed("lock_right"):
		side = 1
	elif Input.is_action_just_pressed("lock_left"):
		side = -1
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(rx) > 0.7 and not _stick_flicked:
		_stick_flicked = true
		side = int(signf(rx))
	elif absf(rx) < 0.3:
		_stick_flicked = false
	if side != 0 and lock_target:
		var t := _pick_target(side)
		if t:
			_set_lock(t)
	if lock_target and (not is_instance_valid(lock_target) or lock_target.dead
			or global_position.distance_to(lock_target.global_position) > LOCK_BREAK):
		# The target died or got away: lock the next enemy around, if any.
		var was := lock_target
		lock_target = null
		var next := _pick_target() if is_instance_valid(was) and was.dead else null
		_set_lock(next)
	# The camera leans toward the locked enemy to keep both in view.
	if Fx.camera and Fx.camera.get_parent() == self:
		var want := Vector2(0, -20)
		if lock_target:
			want += (lock_target.global_position - global_position) * 0.35
		Fx.camera.position = Fx.camera.position.lerp(want, 1.0 - exp(-6.0 * delta))

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

# --- healing -------------------------------------------------------------

func _heal(input: Vector2) -> void:
	velocity = input * SPEED * 0.35
	if input != Vector2.ZERO:
		facing = input.normalized()
	if hd:
		sprite.play("heal", 0.0, false)
		sprite.set_progress(_t / HEAL_TIME)
	else:
		sprite.play("idle", 2.0)
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
	sprite.play("stagger", 15.0 / 0.35 * 6.0 / 15.0, false, true)

func die() -> void:
	_set_lock(null)
	state = State.DEAD
	Sfx.play(self, "player_death", null, 0.0, 0.0)
	sprite.modulate = Color.WHITE
	_reset_sprite()
	super.die()

func rest() -> void:
	hp = max_hp
	flasks = max_flasks
	stamina = max_stamina
