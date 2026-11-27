class_name SkeletonKing
extends SkeletonEnemy
## Ossian, the King of the Bones: the boss of the ruined city of Hélos, a
## giant skeleton of the fantasy pack. He waits on the plaza behind the fog;
## his axe chops and cleaves, he rushes, his magic bursts around him and
## sweeps in front of him. Below half his health he rages: faster, he calls
## lightning down around the hero, breathes fire and raises the dead.
## He cannot be stabbed in the back; a parry wears his poise down, and when
## it breaks he is open to a riposte.

signal phase_changed(phase: int)

const SCALE := 1.9
var boss_name := "Ossian, le Roi des Os"
var phase := 1
var active := false
var _adds: Array = []

func _init() -> void:
	type_key = "boss/king"
	flare_name = "pack/skeleton_a"
	body_radius = 13.0
	body_height = 74.0

func _ready() -> void:
	super._ready()
	sprite.scale = Vector2.ONE * SCALE
	sprite.modulate = base_modulate()
	hit_sound = "hit_heavy"
	_bar.boss_hidden = true
	invulnerable = true  # until the hero comes through the fog
	facing = Vector2(0, 1)
	home_facing = facing

func base_modulate() -> Color:
	return Color(0.95, 0.85, 0.7) if phase == 1 else Color(1.15, 0.65, 0.55)

func souls_reward() -> int:
	return souls

func activate() -> void:
	if active:
		return
	active = true
	invulnerable = false
	_go(State.COMBAT)
	_cooldown = 1.0
	Sfx.play(self, "boss_roar", global_position, 2.0, 0.0)

## Asleep until the fight: nothing wakes him but the fog crossed.
func _idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	sprite.play("idle", 2.0)

func _notices(_to_p: Vector2, _dist: float) -> bool:
	return active

func alert() -> void:
	if active:
		super.alert()

func can_backstab() -> bool:
	return false

func crit_reach() -> float:
	return 22.0

func on_hurt() -> void:
	pass  # no flinching

func on_parried() -> void:
	poise -= 50.0
	if poise <= 0.0:
		poise = max_poise
		open_to_riposte(1.8)
		_hold(State.STAGGER, 1.8)
	else:
		_hold(State.HURT, 0.45)

func on_stagger() -> void:
	_hold(State.STAGGER, 1.5)
	Fx.float_text(get_parent(), global_position + Vector2(-20, -130), "Brisé !", Color(1, 0.8, 0.3))

func after_critical() -> void:
	_hold(State.DOWN, 1.6)

func knockback_strength(_dmg: int) -> float:
	return 12.0

func take_hit(dmg: int, poise_dmg: float, from: Vector2) -> bool:
	var hit := super.take_hit(dmg, poise_dmg, from)
	if hit:
		_check_phase()
	return hit

func take_critical(dmg: int, from: Vector2) -> void:
	super.take_critical(dmg, from)
	_check_phase()

## Below half his health: rage.
func _check_phase() -> void:
	if phase != 1 or dead or hp > max_hp / 2:
		return
	phase = 2
	tempo = 0.85
	type = type.duplicate()
	type.moves = type.moves + type.moves2
	_cds["king_summon"] = 0.0
	sprite.modulate = base_modulate()
	Fx.pack("fx_torus", global_position, get_parent(), true, 2.2)
	Fx.ring(get_parent(), global_position, 10, 130, Color(1, 0.3, 0.2), 0.6, 4)
	Fx.float_text(get_parent(), global_position + Vector2(-50, -140), "Ossian entre en rage !", Color(1, 0.35, 0.3))
	Fx.shake(8)
	Sfx.play(self, "boss_rage", global_position, 3.0, 0.0)
	phase_changed.emit(2)

## Two of the dead rise from heaps of bones beside him.
func _summon() -> void:
	_adds = _adds.filter(func(a): return is_instance_valid(a) and not a.dead)
	for k in 2 - _adds.size():
		var at := global_position + Vector2(-70 if k == 0 else 70, 30)
		var bones := Fx.pack("fx_bones", at, get_parent(), true, 0.85, true)
		bones.play_backwards()
		Sfx.play(self, "skeleton_death", at, -4.0)
		var rise := func() -> void:
			if is_instance_valid(bones):
				bones.queue_free()
			if dead:
				return
			var s := SkeletonEnemy.new()
			s.flare_name = "pack/skeleton_a"
			s.player = player
			s.position = at
			s.souls = 0
			get_parent().add_child(s)
			s.souls = 0  # raised by the king: no souls
			s.facing = (player.global_position - at).normalized()
			s.alert()
			_adds.append(s)
		get_tree().create_timer(1.0, false).timeout.connect(rise)

func die() -> void:
	for a in _adds:  # his dead fall with him
		if is_instance_valid(a) and not a.dead:
			a.take_hit(9999, 0.0, global_position)
	super.die()
