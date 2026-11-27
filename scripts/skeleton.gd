class_name SkeletonEnemy
extends Actor
## An enemy of the fantasy pack (skeletons and brigands), with a Souls-like
## behaviour:
## - it stands guard or wanders near its post, and notices the hero in front
##   of it, close by, or running (it can be approached from behind and
##   stabbed in the back); it alerts its companions;
## - in a fight it keeps its distance and circles around the hero while
##   waiting for an opening, then attacks with the moves of its type (taken
##   from the pack's animations, the blow landing on the animation's frame),
##   sometimes chaining them; only two enemies attack at once;
## - its attacks are committed (it tracks the hero during the windup only),
##   leaving a recovery to punish; hit outside an attack it flinches, but not
##   forever; in an attack only a poise break stops it;
## - mages cast bolts, lightning and novas and back away; throwers throw
##   knives; shield bearers block frontal blows until their guard breaks;
## - too far from its post, it gives up and goes back, healing;
## - elites (bigger, darker, much tougher) guard the treasures.

enum State { IDLE, ALERT, COMBAT, ATTACK, HURT, STAGGER, HELD, DOWN, RETURN, DEAD }

const BASE_DAMAGE := 16.0
## Per type: name, health, poise, running speed, sight, souls, sounds, fighting
## style, preferred distance (casters and throwers), damage factor, moves.
const TYPES := {
	"pack/skeleton_a": {"name": "Squelette", "hp": 80, "poise": 30, "run": 64.0, "sight": 150.0, "souls": 60,
		"sound": "skeleton", "style": "melee", "moves": ["chop", "cleave", "lunge", "nova", "blast"]},
	"pack/skeleton_b": {"name": "Squelette mage", "hp": 55, "poise": 18, "run": 58.0, "sight": 200.0, "souls": 75,
		"sound": "skeleton", "style": "caster", "keep": 120.0, "moves": ["staff", "bolt", "lightning", "nova", "blast"]},
	"pack/skeleton_c": {"name": "Squelette au bouclier", "hp": 100, "poise": 40, "run": 52.0, "sight": 140.0, "souls": 90,
		"sound": "skeleton", "style": "guard", "guard": 70.0, "moves": ["slash", "bash", "overhead", "leap"]},
	"pack/brigand_a": {"name": "Brigand", "hp": 60, "poise": 20, "run": 74.0, "sight": 170.0, "souls": 50,
		"sound": "goblin", "style": "agile", "dmg": 0.9, "moves": ["stab", "rip", "spin", "dash", "pounce"]},
	"pack/brigand_b": {"name": "Brute", "hp": 95, "poise": 45, "run": 66.0, "sight": 160.0, "souls": 70,
		"sound": "goblin", "style": "melee", "dmg": 1.25, "moves": ["stab", "rip", "spin", "pounce"]},
	# The king of the bones (scripts/skeleton_king.gd): a giant skeleton, boss of the ruined city.
	"boss/king": {"name": "Ossian, le Roi des Os", "hp": 700, "poise": 150, "run": 60.0, "sight": 9999.0, "souls": 3000,
		"sound": "skeleton", "style": "boss", "leash": 99999.0,
		"moves": ["king_chop", "king_cleave", "king_lunge", "king_blast", "king_nova"],
		"moves2": ["king_storm", "king_breath", "king_summon"]},
	"pack/brigand_c": {"name": "Lanceur de couteaux", "hp": 55, "poise": 20, "run": 72.0, "sight": 200.0, "souls": 55,
		"sound": "goblin", "style": "thrower", "dmg": 0.85, "keep": 105.0, "moves": ["stab", "rip", "throw", "dash"]},
}
## Moves: the pack animation, its length (s), the blow's point in it (0..1),
## the distance range (px) it is used at, damage factor, poise damage, the
## kind of blow, its size and reach, how far it lunges, cooldown (s), weight
## when picking, and a follow-up [move, chance].
## Kinds: "circle" (a swing in front), "rect" (a thrust: size = length x width),
## "nova" (a burst around itself), "blast" (a wave in front, lasting),
## "bolt" / "knife" (missiles), "lightning" (falls where the hero stood).
const MOVES := {
	# Skeletons.
	"chop": {"anim": "Attack1", "time": 1.15, "hit": 0.42, "range": [0, 40], "dmg": 1.0, "poise": 14,
		"kind": "circle", "size": Vector2(22, 0), "reach": 20, "lunge": 16, "next": ["cleave", 0.45]},
	"cleave": {"anim": "Attack2", "time": 1.3, "hit": 0.46, "range": [0, 42], "dmg": 1.3, "poise": 25,
		"kind": "circle", "size": Vector2(27, 0), "reach": 19, "lunge": 22},
	"lunge": {"anim": "AttackRun", "time": 1.25, "hit": 0.48, "range": [55, 110], "dmg": 1.1, "poise": 18,
		"kind": "circle", "size": Vector2(21, 0), "reach": 22, "lunge": 84, "cd": 4.0, "track": 3.0},
	"nova": {"anim": "Attack4", "time": 1.6, "hit": 0.68, "range": [0, 46], "dmg": 1.2, "poise": 30,
		"kind": "nova", "size": Vector2(50, 0), "cd": 7.0, "weight": 0.6, "unblockable": true},
	"blast": {"anim": "Attack5", "time": 1.4, "hit": 0.42, "range": [0, 62], "dmg": 1.1, "poise": 20,
		"kind": "blast", "size": Vector2(66, 46), "reach": 8, "cd": 8.0, "weight": 0.5, "track": 2.5},
	"staff": {"anim": "Attack1", "time": 1.1, "hit": 0.42, "range": [0, 36], "dmg": 0.8, "poise": 10,
		"kind": "circle", "size": Vector2(20, 0), "reach": 18, "lunge": 10},
	"bolt": {"anim": "Attack3", "time": 1.3, "hit": 0.6, "range": [55, 240], "dmg": 1.0, "poise": 12,
		"kind": "bolt", "speed": 150.0, "cd": 1.2, "weight": 2.0, "next": ["bolt", 0.25]},
	"lightning": {"anim": "Special1", "time": 1.8, "hit": 0.75, "range": [50, 220], "dmg": 1.5, "poise": 30,
		"kind": "lightning", "size": Vector2(26, 0), "cd": 6.0, "weight": 1.2, "unblockable": true},
	"slash": {"anim": "Attack1", "time": 1.1, "hit": 0.42, "range": [0, 38], "dmg": 1.0, "poise": 14,
		"kind": "circle", "size": Vector2(22, 0), "reach": 20, "lunge": 14, "next": ["bash", 0.4]},
	"bash": {"anim": "Attack5", "time": 0.95, "hit": 0.36, "range": [0, 32], "dmg": 0.6, "poise": 45,
		"kind": "circle", "size": Vector2(18, 0), "reach": 16, "lunge": 20, "next": ["overhead", 0.3]},
	"overhead": {"anim": "Attack4", "time": 1.45, "hit": 0.62, "range": [0, 40], "dmg": 1.45, "poise": 35,
		"kind": "circle", "size": Vector2(24, 0), "reach": 20, "lunge": 18},
	"leap": {"anim": "Special1", "time": 1.5, "hit": 0.7, "range": [60, 115], "dmg": 1.4, "poise": 35,
		"kind": "circle", "size": Vector2(26, 0), "reach": 16, "lunge": 92, "cd": 4.0, "track": 3.5},
	# Brigands.
	"stab": {"anim": "Attack1", "time": 0.9, "hit": 0.42, "range": [0, 36], "dmg": 0.85, "poise": 10,
		"kind": "rect", "size": Vector2(34, 14), "reach": 14, "lunge": 18, "next": ["rip", 0.55]},
	"rip": {"anim": "Attack4", "time": 1.0, "hit": 0.58, "range": [0, 38], "dmg": 1.0, "poise": 14,
		"kind": "circle", "size": Vector2(22, 0), "reach": 18, "lunge": 16, "next": ["spin", 0.35]},
	"spin": {"anim": "Attack2", "time": 1.15, "hit": 0.6, "range": [0, 40], "dmg": 1.2, "poise": 20,
		"kind": "circle", "size": Vector2(30, 0), "reach": 8, "lunge": 12},
	"dash": {"anim": "AttackRun", "time": 1.25, "hit": 0.5, "range": [50, 115], "dmg": 0.85, "poise": 14,
		"kind": "rect", "size": Vector2(32, 12), "reach": 14, "lunge": 84, "cd": 4.5, "track": 3.0},
	"pounce": {"anim": "Special1", "time": 1.4, "hit": 0.74, "range": [70, 140], "dmg": 1.15, "poise": 24,
		"kind": "circle", "size": Vector2(24, 0), "reach": 14, "lunge": 110, "cd": 6.0, "track": 3.0},
	# The king of the bones: the same blows, much bigger, and spells in his rage.
	"king_chop": {"anim": "Attack1", "time": 1.3, "hit": 0.45, "range": [0, 72], "dmg": 1.6, "poise": 30,
		"kind": "circle", "size": Vector2(38, 0), "reach": 32, "lunge": 24, "next": ["king_cleave", 0.5]},
	"king_cleave": {"anim": "Attack2", "time": 1.45, "hit": 0.48, "range": [0, 76], "dmg": 1.9, "poise": 40,
		"kind": "circle", "size": Vector2(44, 0), "reach": 28, "lunge": 30},
	"king_lunge": {"anim": "AttackRun", "time": 1.55, "hit": 0.52, "range": [80, 200], "dmg": 1.7, "poise": 35,
		"kind": "circle", "size": Vector2(34, 0), "reach": 34, "lunge": 160, "cd": 5.0, "track": 2.5},
	"king_blast": {"anim": "Attack5", "time": 1.6, "hit": 0.42, "range": [0, 120], "dmg": 1.4, "poise": 25,
		"kind": "blast", "size": Vector2(120, 70), "reach": 16, "cd": 7.0, "weight": 0.8, "track": 2.0},
	"king_nova": {"anim": "Attack4", "time": 1.8, "hit": 0.68, "range": [0, 90], "dmg": 1.7, "poise": 40,
		"kind": "nova", "size": Vector2(84, 0), "cd": 8.0, "weight": 0.8, "unblockable": true},
	"king_storm": {"anim": "Special1", "time": 2.0, "hit": 0.72, "range": [0, 320], "dmg": 1.4, "poise": 30,
		"kind": "storm", "size": Vector2(28, 0), "cd": 11.0, "weight": 1.3, "unblockable": true},
	"king_breath": {"anim": "Attack3", "time": 2.2, "hit": 0.4, "range": [0, 150], "dmg": 0.5, "poise": 8,
		"kind": "breath", "size": Vector2(150, 50), "cd": 9.0, "weight": 1.0, "track": 1.1},
	"king_summon": {"anim": "Taunt", "time": 1.7, "hit": 0.55, "range": [0, 400], "dmg": 0.0, "poise": 0,
		"kind": "summon", "cd": 22.0, "weight": 3.0},
	"throw": {"anim": "Attack3", "time": 1.0, "hit": 0.47, "range": [55, 210], "dmg": 0.8, "poise": 8,
		"kind": "knife", "speed": 235.0, "cd": 1.4, "weight": 2.0, "next": ["throw", 0.35]},
}
## Lunging attacks: how long the rush lasts (it ends with the blow). The
## enemy stops turning before it sets off, so a roll to the side dodges it.
const LUNGE_TIME := 0.34
const MAX_ATTACKERS := 2  # enemies hitting the hero in melee at the same time
const LEASH := 430.0  # px from its post before it gives up

var player: Player
var flare_name := "pack/skeleton_a"
var type: Dictionary
var state := State.IDLE
var home := Vector2.ZERO
var home_facing := Vector2.DOWN
var facing := Vector2.DOWN
var souls := 50
var _t := 0.0
var _move := ""
var _m: Dictionary
var _struck := false
var _cooldown := 0.0
var _cds := {}  # move -> time when it can be used again
var _think := 0.0
var _intent := "approach"
var _strafe := 1.0
var _wander := Vector2.ZERO
var _wander_t := 0.0
var _flinches := 0
var _flinch_reset := 0.0
var _hold_time := 0.6
var _target_pos := Vector2.ZERO
var _guard := 0.0
var _guard_wait := 0.0
var _far_t := 0.0
var _clock := 0.0
var _bar: EnemyBar
var _crit_kill := false
## A tougher one guarding a treasure: more health, poise, damage and souls.
var elite := false
var _dmg_mult := 1.0
## The type, when it is not the sprite's (the boss); the body's radius.
var type_key := ""
var body_radius := 7.0
## Moves come out this much slower (< 1: faster, for an enraged boss).
var tempo := 1.0
## A skeleton lying as a heap of bones, rising when the hero comes near.
var dormant := false
var _heap: AnimatedSprite2D
const WAKE_RANGE := 80.0

func _ready() -> void:
	type = TYPES.get(type_key if type_key != "" else flare_name, TYPES["pack/skeleton_a"])
	max_hp = type.hp
	max_poise = type.poise
	_dmg_mult = float(type.get("dmg", 1.0))
	if elite:
		max_hp = int(type.hp * 2.6)
		max_poise = type.poise * 1.8
		_dmg_mult *= 1.35
	poise_regen = 10.0
	souls = type.souls * (5 if elite else 1)
	_guard = type.get("guard", 0.0)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	if not dormant:
		add_to_group("enemies")  # a heap of bones is not one yet
	hit_sound = "hit_bone" if flare_name.contains("skeleton") else "hit_flesh"
	setup_body([], 16, body_radius)
	home = global_position
	facing = Vector2.RIGHT.rotated(randi_range(0, 7) * PI / 4.0)
	home_facing = facing
	shadow_size = Vector2.ZERO  # the pack's sprites draw their own shadow
	sprite.play("idle", 2.0)
	if elite:
		sprite.scale = Vector2.ONE * 1.2
		sprite.modulate = base_modulate()
	_wander_t = randf_range(1.0, 4.0)
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_bar = EnemyBar.new()
	_bar.enemy = self
	add_child(_bar)
	if dormant:
		sprite.visible = false
		invulnerable = true
		collision_layer = 0
		hurtbox.set_deferred("monitorable", false)
		_heap = Fx.pack("fx_bones", Vector2.ZERO, self, true, 0.85, true)
		_heap.stop()
		_heap.frame = _heap.sprite_frames.get_frame_count("default") - 1

## The bones gather and the skeleton stands up, ready to fight.
func _rise() -> void:
	dormant = false
	_heap.play_backwards()
	Sfx.play(self, "skeleton_death", global_position, -4.0)
	Fx.dust(get_parent(), global_position, Vector2.ZERO)
	_go(State.ALERT)
	_t = -0.75  # while the bones gather
	var t := create_tween()
	t.tween_interval(0.75)
	t.tween_callback(func():
		if dead:
			return
		_heap.queue_free()
		sprite.visible = true
		invulnerable = false
		collision_layer = 4
		hurtbox.set_deferred("monitorable", true)
		add_to_group("enemies")
		Sfx.flare(self, "enemies/skeleton_phys", global_position, -6.0))

func make_sprite():
	return HdSprite.flare(flare_name)

func base_modulate() -> Color:
	return Color(0.95, 0.62, 0.6) if elite else Color.WHITE

func _physics_process(delta: float) -> void:
	sprite.facing8 = facing
	if dead:
		velocity = apply_knockback(delta)
		move_and_slide()
		return
	_clock += delta
	regen_poise(delta)
	_t += delta
	_cooldown -= delta
	_think -= delta
	_flinch_reset -= delta
	if _flinch_reset <= 0.0:
		_flinches = 0
	_guard_wait -= delta
	if _guard_wait <= 0.0 and type.has("guard"):
		_guard = minf(type.guard, _guard + 18.0 * delta)
	var ok := is_instance_valid(player) and not player.dead
	var to_p := player.global_position - global_position if is_instance_valid(player) else Vector2.ZERO
	var dist := to_p.length()
	match state:
		State.IDLE:
			if dormant:
				velocity = Vector2.ZERO
				if ok and dist < WAKE_RANGE:
					facing = to_p.normalized()
					_rise()
			else:
				_idle(delta)
				if ok and _notices(to_p, dist):
					alert()
		State.ALERT:
			velocity = Vector2.ZERO
			if _t < 0.0:  # still rising from its bones
				move_and_slide()
				return
			_turn(to_p, 9.0, delta)
			sprite.play("idle", 2.0)
			if _t >= 0.4:
				_go(State.COMBAT)
		State.COMBAT:
			if not ok:
				_go(State.RETURN)
			else:
				_combat(to_p, dist, delta)
		State.ATTACK:
			_attack(to_p, dist, delta)
		State.HURT, State.STAGGER, State.DOWN:
			velocity = Vector2.ZERO
			sprite.set_progress(minf(0.99, _t / _hold_time))
			if _t >= _hold_time:
				sprite.modulate = base_modulate()
				_go(State.COMBAT if ok else State.RETURN)
				_think = 0.0
				if state == State.COMBAT and _flinches >= 2:
					_cooldown = 0.0  # it shrugs it off and hits back
		State.HELD:
			velocity = Vector2.ZERO
			if _t > 1.6:
				_go(State.COMBAT)
		State.RETURN:
			_return(delta)
	velocity += apply_knockback(delta)
	move_and_slide()

func _go(s: State) -> void:
	if state == State.ATTACK and s != State.ATTACK:
		remove_from_group("attacking")
	state = s
	_t = 0.0

# --- calm: guard post and wandering ---------------------------------------------

func _idle(delta: float) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(2.0, 5.0)
		var r := randf()
		if r < 0.35:
			_wander = Vector2.ZERO
			facing = Vector2.RIGHT.rotated(randi_range(0, 7) * PI / 4.0)  # looks around
		elif r < 0.7 and global_position.distance_to(home) < 50.0:
			_wander = Vector2.RIGHT.rotated(randf() * TAU) * 20.0
		else:
			_wander = (home - global_position).limit_length(20.0)
	if _wander_t < 1.2:
		_wander = Vector2.ZERO
	velocity = _wander
	if _wander.length() > 1.0:
		_turn(_wander, 5.0, delta)
		sprite.play("march", 7.0)
	else:
		sprite.play("crouch" if type.style == "guard" else "idle", 2.0)

## Sight: in front of it (the hero can sneak up from behind), close by, or
## running nearby.
func _notices(to_p: Vector2, dist: float) -> bool:
	if dist > type.sight:
		return false
	if dist < 46.0:
		return true
	if player.sprinting and dist < type.sight * 0.75:
		return true
	return facing.dot(to_p / dist) > -0.15

func alert() -> void:
	if state != State.IDLE and state != State.RETURN:
		return
	if dormant:
		_rise()  # its companions' fight wakes it
		return
	_go(State.ALERT)
	_cooldown = randf_range(0.2, 0.8)
	var snd: String = "enemies/%s_ment" % type.sound
	Sfx.flare(self, snd if type.sound == "goblin" else "enemies/skeleton_phys", global_position, -8.0)
	# Its companions around come too.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e is SkeletonEnemy and e.state == State.IDLE \
				and e.global_position.distance_to(global_position) < 150.0:
			e.call_deferred("alert")

# --- the fight ---------------------------------------------------------------------

func _combat(to_p: Vector2, dist: float, delta: float) -> void:
	# Too far from its post, or the hero ran away: it gives up.
	var leash: float = type.get("leash", LEASH)
	if global_position.distance_to(home) > leash or dist > type.sight * 2.4:
		_far_t += delta
		if _far_t > 1.5 or global_position.distance_to(home) > leash * 1.3:
			_go(State.RETURN)
			return
	else:
		_far_t = 0.0
	_turn(to_p, 7.0, delta)
	if _think <= 0.0:
		_think = randf_range(0.18, 0.32)
		if _cooldown <= 0.0:
			var m := _pick_move(dist)
			if m != "":
				_start_move(m, to_p)
				return
		_intent = _choose_intent(dist)
		if randf() < 0.12:
			_strafe = -_strafe
	var guard: bool = type.style == "guard" and _guard > 0.0
	var dir := to_p / maxf(dist, 1.0)
	match _intent:
		"approach":
			var sp: float = type.run * (0.55 if guard else 1.0)
			velocity = dir * sp
			sprite.play("crouch_run" if guard else "walk", 9.0 * (0.8 if guard else type.run / 80.0))
		"strafe":
			var want := 58.0 if not type.has("keep") else float(type.keep)
			var radial := clampf((dist - want) / 30.0, -1.0, 1.0)
			velocity = dir.orthogonal() * _strafe * 34.0 + dir * radial * 26.0
			if guard:
				sprite.play("crouch_run", 6.0)
			else:
				sprite.play("strafe_right" if _strafe > 0 else "strafe_left", 6.0)
		"back":
			velocity = -dir * 46.0
			sprite.play("back", 7.0)
		_:
			velocity = Vector2.ZERO
			sprite.play("crouch" if guard else "idle", 2.0)

func _choose_intent(dist: float) -> String:
	if type.has("keep"):  # casters and throwers keep their distance
		var keep: float = type.keep
		if dist < keep * 0.5:
			return "back"
		if dist > keep * 1.35:
			return "approach"
		return "strafe"
	if dist > 72.0:
		return "approach"
	if _cooldown > 0.0 or not _token_free():
		return "strafe"
	return "approach"

func _token_free() -> bool:
	return get_tree().get_nodes_in_group("attacking").size() < MAX_ATTACKERS

func _pick_move(dist: float) -> String:
	var options := []
	var total := 0.0
	for name in type.moves:
		var m: Dictionary = MOVES[name]
		if dist < m.range[0] or dist > m.range[1] or _cds.get(name, 0.0) > _clock:
			continue
		var ranged: bool = m.kind in ["bolt", "knife", "lightning"]
		if not ranged and not _token_free():
			continue
		var w: float = m.get("weight", 1.0)
		options.append([name, w])
		total += w
	if options.is_empty():
		return ""
	var r := randf() * total
	for o in options:
		r -= o[1]
		if r <= 0.0:
			return o[0]
	return options[-1][0]

func _start_move(name: String, to_p: Vector2) -> void:
	_go(State.ATTACK)
	_move = name
	_m = MOVES[name]
	if not _m.kind in ["bolt", "knife", "lightning", "storm", "summon"]:
		add_to_group("attacking")  # only the melee blows take a turn
	_struck = false
	if to_p.length() > 1.0:
		facing = to_p.normalized()
	if _m.has("cd"):
		_cds[name] = _clock + float(_m.cd)
	sprite.play(_m.anim, 0.0, false, true)
	var windup: float = _m.time * tempo * _m.hit
	match _m.kind:
		"storm":
			# Lightning falls four times, one after the other: where the hero
			# is heading, then around him.
			_storm.clear()
			_storm.append(player.global_position + player.velocity * 0.35)
			for k in 3:
				_storm.append(player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(35.0, 95.0))
			for k in _storm.size():
				Fx.zone(get_parent(), _storm[k], 0, "circle", _m.size, windup + k * 0.22, Color(0.7, 0.5, 1.0))
			Sfx.flare(self, "powers/shock", global_position, -6.0)
		"breath", "summon":
			Sfx.play(self, "boss_effort", global_position, -2.0)
		"lightning":
			# It falls where the hero is heading: roll away when the circle fills.
			_target_pos = player.global_position + player.velocity * 0.35
			Fx.zone(get_parent(), _target_pos, 0, "circle", _m.size, windup, Color(0.7, 0.5, 1.0))
			Sfx.flare(self, "powers/shock", global_position, -10.0)
		"nova":
			Fx.zone(get_parent(), global_position, 0, "circle", _m.size, windup, Color(0.8, 0.3, 1.0))

func _attack(to_p: Vector2, dist: float, delta: float) -> void:
	var time: float = _m.time * tempo
	var hit_t: float = time * float(_m.hit)
	sprite.set_progress(_t / time)
	velocity = Vector2.ZERO
	var lunge: float = _m.get("lunge", 0.0)
	var rush := lunge >= 40.0  # a long rush, not a step
	var rush_from := hit_t - LUNGE_TIME + 0.04
	# Tracking during the windup only (and never during a rush): a late roll
	# to the side dodges it.
	var track_until := minf(hit_t * 0.8, rush_from - 0.1) if rush else hit_t * 0.8
	if _t < track_until and dist > 1.0:
		_turn(to_p, float(_m.get("track", 5.0)), delta)
	# A glint before the blow; before a rush, it comes earlier and stronger.
	var glint_from := rush_from - 0.3 if rush else hit_t - 0.22
	if not _struck and _t > glint_from:
		var k := clampf((_t - glint_from) / (hit_t - glint_from), 0, 1)
		sprite.modulate = base_modulate().lerp(Color(1.7, 1.35, 1.2) if rush else Color(1.5, 1.3, 1.25), k)
	if rush and _t >= rush_from and _t - get_physics_process_delta_time() < rush_from:
		Fx.dust(get_parent(), global_position, -facing)  # it sets off
		Sfx.play(self, "roll", global_position, -6.0)
	if lunge > 0.0:
		var from := rush_from if rush else hit_t - 0.24
		var span := LUNGE_TIME if rush else 0.28
		if _t > from and _t < from + span and dist > 20.0:
			velocity = facing * lunge / span
	if not _struck and _t >= hit_t:
		_struck = true
		sprite.modulate = base_modulate()
		_strike()
	# A breath of fire sweeps slowly after the hero, burning while it lasts.
	if _m.kind == "breath" and _struck and _t < hit_t + 0.8:
		_turn(to_p, float(_m.get("track", 1.0)), delta)
		if is_instance_valid(_cone):
			_cone.rotation = facing.angle()
		_breath_tick -= delta
		if _breath_tick <= 0.0:
			_breath_tick = 0.16
			var dmg := int(round(BASE_DAMAGE * float(_m.dmg) * _dmg_mult))
			Hitbox.spawn(get_parent(), self, global_position + Vector2(0, -18) + facing * (_m.size.x * 0.5 + 10.0),
				facing.angle(), "rect", _m.size, dmg, int(_m.poise), 8, 0.1)
	# Chained attacks cut the recovery short.
	if _struck and _m.has("next") and _t >= time * 0.78:
		var nxt: Array = _m.next
		if randf() < nxt[1] and dist < float(MOVES[nxt[0]].range[1]) + 10.0:
			_start_move(nxt[0], to_p)
			return
		_m = _m.duplicate()
		_m.erase("next")
	if _t >= time:
		_go(State.COMBAT)
		_cooldown = randf_range(0.35, 1.1) * (0.6 if type.style == "agile" else 1.0)
		_think = 0.0
		if type.style == "agile" and randf() < 0.35:
			_intent = "back"  # brigands hop back after their combo
			_think = 0.5

var _storm: Array[Vector2] = []
var _cone: AnimatedSprite2D
var _breath_tick := 0.0

## Raising the dead (the boss): see SkeletonKing.
func _summon() -> void:
	pass

func _strike() -> void:
	var dmg := int(round(BASE_DAMAGE * float(_m.dmg) * _dmg_mult))
	var poise_dmg := int(_m.poise)
	var chest := global_position + Vector2(0, -18)
	var parent := get_parent()
	match _m.kind:
		"circle":
			Hitbox.spawn(parent, self, chest + facing * float(_m.reach), 0, "circle", _m.size, dmg, poise_dmg, 8, 0.1,
				_m.get("unblockable", false))
			Sfx.play(self, "swing_heavy" if _m.dmg >= 1.3 else "skeleton_swing", global_position, -4.0)
		"rect":
			Hitbox.spawn(parent, self, chest + facing * (float(_m.reach) + _m.size.x * 0.5), facing.angle(), "rect",
				_m.size, dmg, poise_dmg, 8, 0.1)
			Sfx.play(self, "thrust", global_position, -4.0)
		"nova":
			Hitbox.spawn(parent, self, global_position, 0, "circle", _m.size, dmg, poise_dmg, 8, 0.12, true)
			var fx := Fx.pack("fx_aoe", global_position, parent, true, _m.size.x * 2.4 / Fx.pack_width("fx_aoe"))
			fx.z_index = 1
			Fx.ring(parent, global_position, 6, _m.size.x, Color(0.85, 0.4, 1.0), 0.3, 3)
			Sfx.flare(self, "powers/quake", global_position, -4.0)
			Fx.shake(3)
		"blast":
			var h := Hitbox.spawn(parent, self, chest + facing * (float(_m.reach) + _m.size.x * 0.5), facing.angle(), "rect",
				_m.size, dmg, poise_dmg, 8, 0.3)
			h.unblockable = false
			Sfx.flare(self, "powers/shock", global_position, -4.0)
		"bolt", "knife":
			var aim := (player.global_position + player.velocity * 0.15) - global_position
			Projectile.launch(parent, self, global_position + facing * 12.0, aim if aim.length() > 1.0 else facing,
				float(_m.speed), dmg, poise_dmg, _m.kind)
			if _m.kind == "bolt":
				Sfx.flare(self, "powers/fireball", global_position, -8.0)
			else:
				Sfx.play(self, "swing_light", global_position, -4.0)
		"storm":
			for k in _storm.size():
				var at: Vector2 = _storm[k]
				var strike := func() -> void:
					Fx.lightning(parent, at)
					Fx.ring(parent, at, 4, _m.size.x, Color(0.8, 0.7, 1.0), 0.3, 3)
					Hitbox.spawn(parent, self, at + Vector2(0, -14), 0, "circle", _m.size, dmg, poise_dmg, 8, 0.12, true)
					Sfx.flare(self, "powers/thunder", at, -4.0)
					Fx.shake(2)
				if k == 0:
					strike.call()
				else:
					get_tree().create_timer(k * 0.22, false).timeout.connect(strike)
		"breath":
			_breath_tick = 0.0
			_cone = Fx.pack("fx_cone", Vector2(0, -26) * sprite.scale.y + facing * 8.0, self, true, 0.85)
			_cone.rotation = facing.angle()
			_cone.z_index = 2
			Sfx.flare(self, "powers/fireball", global_position, -2.0)
			Sfx.flare(self, "powers/burn", global_position, -4.0)
		"summon":
			_summon()
		"lightning":
			Fx.lightning(parent, _target_pos)
			Fx.ring(parent, _target_pos, 4, _m.size.x, Color(0.8, 0.7, 1.0), 0.3, 3)
			Hitbox.spawn(parent, self, _target_pos + Vector2(0, -14), 0, "circle", _m.size, dmg, poise_dmg, 8, 0.12, true)
			Sfx.flare(self, "powers/thunder", _target_pos, -2.0)
			Fx.shake(3)

func _turn(to: Vector2, speed: float, delta: float) -> void:
	if to.length() < 0.5:
		return
	facing = Vector2.from_angle(rotate_toward(facing.angle(), to.angle(), speed * delta))

# --- giving up and going back ---------------------------------------------------

func _return(delta: float) -> void:
	var to_home := home - global_position
	if to_home.length() < 8.0:
		hp = max_hp  # back at its post: healed, as if nothing happened
		poise = max_poise
		_go(State.IDLE)
		facing = home_facing
		return
	velocity = to_home.normalized() * type.run * 0.8
	_turn(to_home, 8.0, delta)
	sprite.play("walk", 8.0)

# --- being hit --------------------------------------------------------------------

## Shield bearers block blows from the front with their shield, until their
## guard breaks (heavy blows wear it down faster); then they are open.
func receive_hit(h: Hitbox) -> void:
	if dead or invulnerable:
		return
	var from := h.origin()
	if _blocking() and not h.unblockable and facing.dot((from - global_position).normalized()) > 0.35:
		_guard -= h.damage + h.poise_damage * 0.6
		_guard_wait = 1.5
		_bar.show_for(3.0)
		var spark := global_position + Vector2(0, -22) + facing * 10.0
		Fx.hit_spark(get_parent(), spark)
		knockback = (global_position - from).normalized() * 40.0
		if _guard > 0.0:
			Sfx.play(self, "block", global_position, -2.0)
			_cooldown = minf(_cooldown, 0.15)  # it answers at once
			_think = 0.0
			if h.source is Player:
				h.source.knockback = (from - global_position).normalized() * 70.0
			return
		Sfx.play(self, "guard_break", global_position)
		Fx.float_text(get_parent(), global_position + Vector2(0, -60), "Garde brisée", Color(1, 0.75, 0.3))
		_guard = 0.0
		_guard_wait = 4.0
		open_to_riposte(1.6)
		_hold(State.STAGGER, 1.4)
		return
	if state in [State.IDLE, State.ALERT, State.RETURN]:
		_go(State.COMBAT)  # struck by surprise
		alert_others()
	take_hit(h.damage, h.poise_damage, from)

func _blocking() -> bool:
	return type.style == "guard" and _guard > 0.0 and state in [State.COMBAT, State.ALERT]

func alert_others() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e is SkeletonEnemy and e.state == State.IDLE \
				and e.global_position.distance_to(global_position) < 150.0:
			e.call_deferred("alert")

func take_hit(dmg: int, poise_dmg: float, from: Vector2) -> bool:
	var hit := super.take_hit(dmg, poise_dmg, from)
	if hit:
		_bar.add_damage(dmg)
		if not dead and randf() < 0.5:
			Sfx.flare(self, "enemies/%s_hit" % type.sound, global_position, -8.0)
	return hit

## Outside its attacks it flinches, but after two flinches in a row it
## shrugs the blows off and strikes back.
func on_hurt() -> void:
	if state == State.ATTACK:
		return  # hyper armour: only a poise break stops an attack
	if state in [State.HELD, State.DOWN, State.STAGGER]:
		return
	_flinches += 1
	_flinch_reset = 1.6
	if _flinches > 2:
		_go(State.COMBAT)
		_cooldown = 0.0
		_think = 0.0
		return
	_hold(State.HURT, 0.32)

func on_stagger() -> void:
	_hold(State.STAGGER, 0.9)
	Fx.float_text(get_parent(), global_position + Vector2(0, -50), "Brisé !", Color(1, 0.8, 0.3))

func on_parried() -> void:
	open_to_riposte(1.6)
	_hold(State.STAGGER, 1.5)

func _hold(s: State, seconds: float) -> void:
	_go(s)
	_hold_time = seconds
	sprite.modulate = base_modulate()
	sprite.play("stagger", 0.0, false, true)

# --- critical hits ---------------------------------------------------------------

func can_backstab() -> bool:
	return not dead and state not in [State.HELD, State.DOWN]

func begin_critical(by: Node2D, kind: String) -> void:
	_riposte_until = 0
	_go(State.HELD)
	sprite.modulate = base_modulate()
	if kind == "backstab":
		facing = (global_position - by.global_position).normalized()
	sprite.play("stagger", 0.0, false, true)
	sprite.set_progress(0.3)

func take_critical(dmg: int, from: Vector2) -> void:
	_bar.add_damage(dmg)
	_crit_kill = dmg >= hp
	super.take_critical(dmg, from)

func after_critical() -> void:
	_hold(State.DOWN, 1.3)

func die() -> void:
	_go(State.DEAD)
	var crit: bool = _crit_kill and type.sound == "skeleton"
	Sfx.flare(self, "enemies/%s_%s" % [type.sound, "critdie" if crit else "die"], global_position, -6.0)
	sprite.modulate = base_modulate()
	super.die()
	_bar.queue_free()
	var t := create_tween()
	if type.sound == "skeleton":
		# A skeleton falls to pieces: a heap of bones in a puff of dust.
		sprite.visible = false
		var bones := Fx.pack("fx_bones", global_position + Vector2(0, -sprite.lift), get_parent(), true,
			0.85 * sprite.scale.x, true)
		bones.modulate = base_modulate()
		bones.z_index = z_index
		Sfx.play(self, "skeleton_death", global_position, -6.0)
		var bt := bones.create_tween()
		bt.tween_interval(6.0)
		bt.tween_property(bones, "modulate:a", 0.0, 2.0)
		bt.tween_callback(bones.queue_free)
		t.tween_interval(0.2)
		t.tween_callback(queue_free)
		return
	t.tween_interval(1.5)
	t.tween_property(self, "modulate:a", 0.0, 1.0)
	t.tween_callback(queue_free)
