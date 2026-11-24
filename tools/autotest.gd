extends Node
## Scripted play-through used for screenshots and smoke tests:
##   godot -- --autotest=<output folder>
## Drives the player through the level and saves PNGs along the way.

var main: Node
var out := ""
var log_lines: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	log_lines.append("shot " + name)

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _press(action: String, hold: float = 0.08) -> void:
	Input.action_press(action)
	await _wait(hold)
	Input.action_release(action)

## Checks block, parry, riposte and an attack from behind with hand-made hits.
const PARRY_WAIT := Player.PARRY_WINDOW + 0.15

func _lock_test(p: Player) -> void:
	await _wait(0.8)
	p.global_position = main.start_pos + Vector2(0, -110)
	p.facing = Vector2.UP
	var foes := []
	for off in [Vector2(-60, -70), Vector2(70, -60)]:
		var sk := SkeletonEnemy.new()
		sk.player = p
		sk.position = p.global_position + off
		main.world.add_child(sk)
		foes.append(sk)
	await _wait(0.2)
	for sk in foes:
		sk.process_mode = Node.PROCESS_MODE_DISABLED
	await _press("lock")
	await _wait(0.2)
	var first = p.lock_target
	log_lines.append("lock: target %s (left one %s)" % [first != null, first == foes[0]])
	Input.action_press("move_right")
	await _wait(0.6)
	Input.action_release("move_right")
	var to: Vector2 = (first.global_position - p.global_position).normalized()
	log_lines.append("strafe: facing·target %.2f, velocity x %.0f" % [p.facing.dot(to), p.velocity.x])
	await _shot("13_lock")
	await _press("lock_right")
	await _wait(0.1)
	log_lines.append("switch right: now the other one %s" % (p.lock_target == foes[1]))
	p.lock_target.take_hit(9999, 0, p.global_position)
	await _wait(0.2)
	log_lines.append("target killed: relocked on the survivor %s" % (p.lock_target == foes[0]))
	await _press("lock")
	log_lines.append("unlocked %s" % (p.lock_target == null))
	for sk in foes:
		if is_instance_valid(sk):
			sk.queue_free()

func _shield_test(p: Player) -> void:
	await _wait(1.0)  # let the heavy attack before finish (attacks commit)
	p.global_position = main.start_pos + Vector2(0, -110)
	p.rest()
	var sk := SkeletonEnemy.new()
	sk.player = p
	sk.position = p.global_position + Vector2(0, -30)
	main.world.add_child(sk)
	await _wait(0.3)
	sk.process_mode = Node.PROCESS_MODE_DISABLED  # a target only: its own attacks would blur the test
	var hits: Array[Hitbox] = []
	var make_hit := func(src: Node2D) -> Hitbox:
		var h := Hitbox.new()
		hits.append(h)
		h.source = src
		h.damage = 18
		h.poise_damage = 10
		return h
	Input.action_press("block")
	await _wait(0.05)
	var hp0 := p.hp
	p.receive_hit(make_hit.call(sk))
	log_lines.append("parry: player hp %d->%d, skeleton state %d (stagger=%d)" % [hp0, p.hp, sk.state, SkeletonEnemy.State.STAGGER])
	await _shot("11_parry")
	while p._t < PARRY_WAIT:  # game time, not real time (slow software rendering here)
		await get_tree().physics_frame
	log_lines.append("before block hit: state %d t %.2f invul %s timescale %.2f" % [p.state, p._t, p.invulnerable, Engine.time_scale])
	var st0 := p.stamina
	p.receive_hit(make_hit.call(sk))
	log_lines.append("block: player hp %d, stamina %.0f->%.0f" % [p.hp, st0, p.stamina])
	await _shot("12_block")
	var behind := Node2D.new()
	main.world.add_child(behind)
	behind.global_position = p.global_position - p.facing * 30
	p.receive_hit(make_hit.call(behind))
	log_lines.append("from behind: player hp %d" % p.hp)
	Input.action_release("block")
	while p.state != Player.State.FREE:  # the blow from behind staggered the hero
		await get_tree().physics_frame
	# The parried skeleton is open: a light attack now is a riposte.
	sk.process_mode = Node.PROCESS_MODE_INHERIT
	sk.open_to_riposte(2.0)
	sk.global_position = p.global_position + p.facing * 24.0
	var skhp := sk.hp
	await _wait(0.4)
	await _press("attack_light")
	await _wait(0.2)
	log_lines.append("riposte: player state %d (crit=%d), skeleton state %d" % [p.state, Player.State.CRIT, sk.state])
	await _shot("14_riposte")
	await _wait(1.0)
	log_lines.append("riposte: skeleton hp %d->%d" % [skhp, sk.hp])
	if is_instance_valid(sk):
		sk.queue_free()
	behind.queue_free()
	for h in hits:
		h.free()
	await _wait(0.2)
	# Raised shield in each direction, with no enemy around to turn toward.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is SkeletonEnemy:
			e.queue_free()
	await _wait(0.8)
	Input.action_press("block")
	for dir in ["move_down", "move_left", "move_up", "move_right"]:
		Input.action_press(dir)
		await _wait(0.12)
		log_lines.append("%s pressed: vector %s up=%s down=%s near=%s" % [dir, Input.get_vector("move_left", "move_right", "move_up", "move_down"), Input.is_action_pressed("move_up"), Input.is_action_pressed("move_down"), p._nearest_enemy(150.0)])
		Input.action_release(dir)
		await _wait(0.1)
		log_lines.append("%s: state %d facing %s" % [dir, p.state, p.facing])
		await _shot("block_" + dir)
	Input.action_release("block")
	await _wait(0.6)

## Enemies must never pin the player: walk away from skeletons pressed
## against (or overlapping) the player and check that the player gets away.
func _stick_test(p: Player) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is SkeletonEnemy:
			e.queue_free()
	await _wait(0.1)
	for case in [["adjacent", Vector2(0, -16)], ["overlapping", Vector2(2, -3)], ["two around", Vector2(-14, -8)],
			["side", Vector2(-16, 0)], ["side+attacks", Vector2(-16, 0)], ["blocking", Vector2(0, -16)]]:
		p.global_position = main.start_pos + Vector2(0, -160)
		p.rest()
		var group: Array = []
		var offsets: Array = [case[1]] if case[0] != "two around" else [Vector2(-14, -8), Vector2(14, -8)]
		for o in offsets:
			var sk := SkeletonEnemy.new()
			sk.player = p
			sk.position = p.global_position + o
			main.world.add_child(sk)
			if case[0] != "side+attacks" and case[0] != "blocking":
				sk._cooldown = 99.0  # chase only, never attack
			sk.state = SkeletonEnemy.State.COMBAT
			group.append(sk)
		await _wait(0.4)
		var start := p.global_position
		var dir := "move_right" if case[0].begins_with("side") else "move_down"
		if case[0] == "blocking":
			Input.action_press("block")
		Input.action_press(dir)
		await _wait(1.0)
		Input.action_release(dir)
		Input.action_release("block")
		log_lines.append("stick %s: player moved %.0f px, hp %d, nearest skeleton %.0f px" % [case[0], p.global_position.distance_to(start), p.hp, group[0].global_position.distance_to(p.global_position)])
		for sk in group:
			sk.queue_free()
		await _wait(0.1)

## Clears the enemies around and puts the hero in an open spot of the plain.
func _clear_spot(p: Player) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is SkeletonEnemy:
			e.queue_free()
	p.global_position = main.start_pos + Vector2(0, -110)
	p.rest()
	p.velocity = Vector2.ZERO
	await _wait(0.2)

## Running (roll held), the roll on release, the backstep without direction,
## the running attack.
func _move_test(p: Player) -> void:
	await _clear_spot(p)
	Input.action_press("move_right")
	Input.action_press("roll")
	await _wait(0.8)
	log_lines.append("sprint: sprinting %s speed %.0f (walk %.0f) stamina %.0f/%.0f state %d" % [p.sprinting, p.velocity.length(), Player.SPEED, p.stamina, p.max_stamina, p.state])
	await _shot("15_sprint")
	await _press("attack_light")
	await _wait(0.25)
	log_lines.append("running attack: state %d anim %s" % [p.state, p.sprite.anim])
	Input.action_release("roll")
	Input.action_release("move_right")
	await _wait(1.2)
	log_lines.append("after a long hold: state %d (no roll: %s)" % [p.state, p.state != Player.State.ROLL])
	Input.action_press("move_down")
	await _press("roll", 0.06)
	await _wait(0.05)
	log_lines.append("tap with a direction: state %d (roll=%d)" % [p.state, Player.State.ROLL])
	Input.action_release("move_down")
	await _wait(1.0)
	var at := p.global_position
	await _press("roll", 0.06)
	await _wait(0.05)
	log_lines.append("tap without direction: state %d (backstep=%d)" % [p.state, Player.State.BACKSTEP])
	await _wait(0.6)
	log_lines.append("backstep moved %.0f px" % p.global_position.distance_to(at))

## A backstab on an enemy turned away, and a shield bearer's guard.
func _crit_test(p: Player) -> void:
	await _clear_spot(p)
	var sk := SkeletonEnemy.new()
	sk.player = p
	sk.flare_name = "pack/skeleton_a"
	sk.position = p.global_position + Vector2(0, -40)
	main.world.add_child(sk)
	await _wait(0.1)
	sk.facing = Vector2.UP  # turned away from the hero, who stands south of it
	sk._wander_t = 99.0
	p.global_position = sk.global_position + Vector2(0, 22)
	p.facing = Vector2.UP
	var hp0 := sk.hp
	await _press("attack_light")
	await _wait(0.25)
	log_lines.append("backstab: player state %d (crit=%d), skeleton state %d (held=%d)" % [p.state, Player.State.CRIT, sk.state, SkeletonEnemy.State.HELD])
	await _shot("16_backstab")
	await _wait(0.9)
	log_lines.append("backstab: skeleton hp %d->%d dead %s" % [hp0, sk.hp, sk.dead])
	if is_instance_valid(sk):
		sk.queue_free()
	await _clear_spot(p)
	var sh := SkeletonEnemy.new()
	sh.player = p
	sh.flare_name = "pack/skeleton_c"
	sh.position = p.global_position + Vector2(0, -30)
	main.world.add_child(sh)
	await _wait(0.2)
	sh.state = SkeletonEnemy.State.COMBAT
	sh._cooldown = 99.0
	sh.facing = Vector2.DOWN
	var h := Hitbox.new()
	h.source = p
	h.damage = 18
	h.poise_damage = 12
	var hp1 := sh.hp
	sh.receive_hit(h)
	log_lines.append("shield from the front: hp %d->%d guard %.0f" % [hp1, sh.hp, sh._guard])
	await _shot("17_shield_block")
	for k in 4:
		sh.receive_hit(h)
	log_lines.append("guard after 5 blows: %.0f, state %d (stagger=%d), open %s" % [sh._guard, sh.state, SkeletonEnemy.State.STAGGER, sh.can_riposte()])
	h.free()
	sh.queue_free()
	await _wait(0.2)

## Each enemy type fights the (unkillable) hero for a while: which moves it
## used, and screenshots of their attacks.
func _ai_test(p: Player) -> void:
	for model in SkeletonEnemy.TYPES:
		await _clear_spot(p)
		p.max_hp = 99999
		p.hp = 99999
		var sk := SkeletonEnemy.new()
		sk.player = p
		sk.flare_name = model
		sk.position = p.global_position + Vector2(-60, -50)
		main.world.add_child(sk)
		sk.facing = Vector2(60, 50).normalized()  # it sees the hero
		var moves := {}
		var states := {}
		var shot := false
		var t := 0.0
		while t < 7.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			if not is_instance_valid(sk):
				break
			states[SkeletonEnemy.State.keys()[sk.state]] = true
			if sk.state == SkeletonEnemy.State.ATTACK:
				moves[sk._move] = true
				if not shot and sk._t > sk._m.time * sk._m.hit:
					shot = true
					await _shot("ai_" + model.trim_prefix("pack/"))
		log_lines.append("ai %s: states %s moves %s, hero hp lost %d" % [model, states.keys(), moves.keys(), 99999 - p.hp])
		if is_instance_valid(sk):
			sk.queue_free()
	p.apply_stats(true)

## Souls, a level bought at the bonfire, the travel menu, an unlit bonfire.
func _bonfire_test(p: Player) -> void:
	await _clear_spot(p)
	Progress.add_souls(600)
	var fire: Vector2 = main._bonfires.prairie.global_position
	p.global_position = fire + Vector2(0, 24)
	await _wait(0.3)
	log_lines.append("at the bonfire: hint '%s'" % main.hud.hint)
	await _press("interact")
	await _wait(0.4)
	await _shot("18_bonfire_menu")
	var hp0 := p.max_hp
	main._open_level_menu("prairie")
	await _wait(0.3)
	await _shot("19_level_menu")
	main._level_up("vigor", "prairie", 0)
	await _wait(0.3)
	await _shot("20_level_up")
	log_lines.append("level up: level %d, max hp %d->%d, souls %d" % [Progress.data.level, hp0, p.max_hp, Progress.data.souls])
	Progress.data.lit.append("ruins")
	main._open_travel_menu("prairie")
	await _wait(0.3)
	await _shot("21_travel_menu")
	Progress.data.lit.erase("ruins")
	main._close_menu()
	await _wait(0.3)
	log_lines.append("menus closed: paused %s, player state %d" % [get_tree().paused, p.state])
	main.teleport_to_cell(main.PLACES.ruins.cell)
	p.global_position = main._bonfires.ruins.global_position + Vector2(0, 24)
	await _wait(0.5)
	log_lines.append("unlit bonfire: hint '%s'" % main.hud.hint)
	await _press("interact")
	await _wait(0.6)
	await _shot("22_bonfire_lit")
	log_lines.append("lit: %s, ruins in list %s" % [main._bonfires.ruins.lit, "ruins" in Progress.data.lit])

## A chest, an item, the bloodstain and its souls.
func _loot_test(p: Player) -> void:
	main.teleport_to_cell(WorldMap.CAMP + Vector2(0.5, 1.0))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is SkeletonEnemy:
			e.queue_free()
	await _wait(0.5)
	p.global_position = main.cell_of(WorldMap.CAMP + Vector2(-0.9, -0.9)) + Vector2(0, 20)
	await _wait(0.3)
	var f0 := p.max_flasks
	log_lines.append("chest: hint '%s'" % main.hud.hint)
	await _press("interact")
	await _wait(0.4)
	await _shot("23_chest")
	log_lines.append("chest opened: flasks max %d->%d, taken %s" % [f0, p.max_flasks, Progress.data.taken.keys()])
	await _wait(2.0)
	# The bloodstain of a death, here.
	Progress.data.stain = {"x": p.global_position.x + 40.0, "y": p.global_position.y - 10.0, "souls": 345}
	main._spawn_stain()
	var s0 := int(Progress.data.souls)
	await _wait(0.3)
	await _shot("24_bloodstain")
	p.global_position += Vector2(40, -14)
	await _wait(0.3)
	log_lines.append("bloodstain: hint '%s'" % main.hud.hint)
	await _press("interact")
	await _wait(0.5)
	log_lines.append("bloodstain taken: souls %d->%d, stain %s" % [s0, Progress.data.souls, Progress.data.stain])
	await _shot("25_souls_back")
	# A message on the ground, by the start.
	var msg: Vector2 = main.cell_of(Vector2(main.PLACES.prairie.cell) + main.MESSAGES[0][0])
	p.global_position = msg + Vector2(0, 10)
	await _wait(0.4)
	log_lines.append("message: hint '%s'" % main.hud.hint)
	await _press("interact")
	await _wait(0.4)
	log_lines.append("message read: '%s'" % main.hud.message)
	await _shot("27_message")

## The boss's fog: no way in until [E].
func _fog_test(p: Player) -> void:
	p.global_position = main.arena_entry()
	await _wait(0.3)
	Input.action_press("move_up")
	await _wait(1.6)
	Input.action_release("move_up")
	await _wait(0.2)
	log_lines.append("fog: hint '%s', sealed %s, dist %.1f" % [main.hud.hint, main._sealed.keys(), main._arena_dist(p.global_position, "minotaur")])
	await _shot("26_fog")
	await _press("interact")
	await _wait(1.3)
	log_lines.append("through the fog: sealed %s, dist %.1f, boss state %d" % [main._sealed.keys(), main._arena_dist(p.global_position, "minotaur"), main.boss.state])

## Dying: the souls stay in a bloodstain, the death screen.
func _death_test(p: Player) -> void:
	main._ended = false
	Progress.data.souls = 777
	p.invulnerable = false
	p.take_hit(99999, 0, p.global_position + Vector2(10, 0))
	await _wait(2.5)
	await _shot("98_death")
	log_lines.append("death: souls %d, stain %s, deaths %d" % [Progress.data.souls, Progress.data.stain, Progress.data.deaths])

func _music_state() -> String:
	var out := []
	for pl in main.music._players:
		if pl.playing:
			out.append("%s at %.0f dB" % [pl.stream.resource_name, pl.volume_db])
	return ", ".join(out) if out else "silent"

func _run() -> void:
	var p: Player = main.player
	await _wait(1.0)
	await _shot("01_start")
	log_lines.append("hero: %s, weapon %s" % [HeroConfig.data.model, p.weapon])
	# Walk up to the first skeleton and fight it.
	Input.action_press("move_up")
	await _wait(1.6)
	Input.action_release("move_up")
	await _shot("02_walk")
	for i in 3:
		await _press("attack_light")
		await _wait(0.12)
	await _wait(0.05)
	await _shot("03_attack")
	await _press("roll")
	await _wait(0.12)
	await _shot("04_roll")
	await _wait(1.0)
	# Roll sideways and downwards in a clear spot, capturing the tumble.
	var back := p.global_position
	p.global_position = main.start_pos + Vector2(0, -110)
	await _wait(0.6)
	for dir in ["move_right", "move_down"]:
		var start := p.global_position
		Input.action_press(dir)
		await _press("roll", 0.05)
		for i in 5:
			await _wait(0.08)
			await _shot("roll_%s_%d" % [dir, i])
		Input.action_release(dir)
		await _wait(0.4)
		log_lines.append("roll %s distance %.0f" % [dir, p.global_position.distance_to(start)])
		await _wait(0.6)
	p.global_position = back
	await _wait(0.3)
	await _press("attack_heavy")
	await _wait(0.4)
	await _shot("05_spear_heavy")
	log_lines.append("player hp %d stamina %d" % [p.hp, int(p.stamina)])
	await _shield_test(p)
	await _stick_test(p)
	await _lock_test(p)
	await _move_test(p)
	await _crit_test(p)
	await _ai_test(p)
	await _bonfire_test(p)
	await _loot_test(p)
	# The pause menu, then the teleport menu.
	main.open_pause_menu()
	await _wait(0.3)
	await _shot("menu_pause")
	main.open_teleport_menu()
	await _wait(0.3)
	await _shot("menu_teleport")
	log_lines.append("paused %s" % get_tree().paused)
	main._close_menu()
	await _wait(0.2)
	log_lines.append("after close: paused %s" % get_tree().paused)
	main.open_map()
	await _wait(0.3)
	await _shot("menu_map")
	main._map_screen.get_child(0).closed.emit()
	await _wait(0.2)
	log_lines.append("after map: paused %s" % get_tree().paused)
	# Weight: how long the hero takes to reach full speed, and to stop.
	var t0 := p.global_position
	Input.action_press("move_right")
	await _wait(0.1)
	log_lines.append("speed after 0.1 s: %.0f" % p.velocity.length())
	await _wait(0.4)
	log_lines.append("speed after 0.5 s: %.0f" % p.velocity.length())
	Input.action_release("move_right")
	await _wait(0.1)
	log_lines.append("speed 0.1 s after release: %.0f (moved %.0f px)" % [p.velocity.length(), p.global_position.distance_to(t0)])
	# A tour of every place of the teleport menu.
	p.invulnerable = true
	var places: Array = main.teleport_places()
	for k in places.size():
		main.teleport_to_cell(places[k][1], places[k][0])
		await _wait(1.6)
		await _shot("tour_%d" % k)
		log_lines.append("tour %d %s: biome %s, music %s" % [k, places[k][0], main._biome, main.music.current_track])
	main.teleport_to_cell(main.ARENAS.wyvern_water.center + Vector2(1.2, 1.2))
	await _wait(2.0)
	await _shot("tour_wyvern")
	var wy = main._bosses.wyvern_water
	log_lines.append("wyvern: state %d, sealed %s, pos %s player %s, sprite %s %s frames %d" % [wy.state, main._sealed.keys(), wy.global_position, p.global_position, wy.sprite.anim, wy.sprite._sprite.texture, wy.sprite.frame_count()])
	wy.take_hit(9999, 0, wy.global_position + Vector2(0, 30))
	await _wait(4.5)
	log_lines.append("wyvern dead %s, sealed %s, defeated %s" % [wy.dead, main._sealed.keys(), Progress.data.defeated])
	# Through the fog to the Minotaur.
	p.invulnerable = false
	await _fog_test(p)
	await _wait(0.3)
	await _shot("06_boss_intro")
	log_lines.append("music after boss intro: " + _music_state())
	await _wait(1.2)
	await _shot("07_boss_attack")
	var bs = main.boss.sprite
	log_lines.append("boss sprite: anim %s frame %d tex %s vis %s pos %s scale %s mod %s state %d boss_pos %s player %s" % [bs.anim, bs.get_frame(), bs._sprite.texture.resource_path if bs is HdSprite and bs._sprite.texture else "-", bs.visible, bs.position, bs.scale, bs.modulate, main.boss.state, main.boss.global_position, p.global_position])
	await _wait(0.6)
	await _shot("08_boss_attack2")
	# Damage the boss to phase 2.
	main.boss.take_hit(240, 0, p.global_position)
	await _wait(0.8)
	await _shot("09_phase2")
	await _wait(1.5)
	await _shot("10_phase2_attack")
	log_lines.append("boss hp %d phase %d" % [main.boss.hp, main.boss.phase])
	log_lines.append("music in phase 2: " + _music_state())
	await _death_test(p)
	# A wide view of the whole level.
	main._ended = true  # stops the game from moving the camera limits back
	main.show_all_chunks()
	var cam: Camera2D = Fx.camera
	cam.reparent(main)
	cam.position_smoothing_enabled = false
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	cam.global_position = main.world_rect.get_center()
	cam.zoom = Vector2.ONE * minf(640.0 / main.world_rect.size.x, 360.0 / main.world_rect.size.y)
	await _wait(0.3)
	await _shot("99_overview")
	var f := FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	get_tree().quit()
