extends Node2D
## Builds the prototype level: a ruined path guarded by skeletons, a
## bonfire checkpoint and the arena of Asterion the Minotaur.
## The isometric prototype (iso_main.gd) extends this script and replaces
## the steps marked "level step".

const WORLD := Rect2(0, 0, 1200, 1500)
const ARENA_C := Vector2(600, 330)
const ARENA_R := 230.0
const START := Vector2(600, 1360)
const PATH := [Vector2(600, 1360), Vector2(600, 1150), Vector2(560, 950), Vector2(620, 780), Vector2(600, 560)]
const SKELETONS := [Vector2(560, 1080), Vector2(660, 960), Vector2(520, 800), Vector2(700, 760)]

var world: Node2D
var player: Player
var boss: Boss
var hud
var bonfire: Bonfire
var _gate: StaticBody2D
var _gate_closed := false
var _ended := false
var _skeletons: Array = []
var music: Music

var world_rect := WORLD
var start_pos := START
var arena_center := ARENA_C
var arena_radius := ARENA_R
var skeleton_spots: Array = SKELETONS

func _ready() -> void:
	_setup_inputs()
	_build_ground()

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	bonfire = Bonfire.new()
	bonfire.position = start_pos + Vector2(0, -30)
	world.add_child(bonfire)

	player = Player.new()
	player.position = start_pos
	world.add_child(player)
	var cam := Camera2D.new()
	cam.position = Vector2(0, -20)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.limit_left = int(world_rect.position.x)
	cam.limit_top = int(world_rect.position.y)
	cam.limit_right = int(world_rect.end.x)
	cam.limit_bottom = int(world_rect.end.y)
	player.add_child(cam)
	Fx.camera = cam
	player.died.connect(_on_player_died)

	_build_level()
	_spawn_skeletons()

	boss = _make_boss()
	boss.player = player
	world.add_child(boss)
	boss.died.connect(_on_boss_died)
	boss.phase_changed.connect(func(_p): music.play("boss_phase2", 2.5))

	_atmosphere(cam)
	Sfx.start_ambience(self)
	music = Music.new()
	add_child(music)

	var layer := CanvasLayer.new()
	add_child(layer)
	var vignette := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.05, 1.05)
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.02, 0.0, 0.05, 0.0))
	grad.gradient.set_color(1, Color(0.02, 0.0, 0.05, 0.75))
	grad.gradient.add_point(0.55, Color(0.02, 0.0, 0.05, 0.0))
	vignette.texture = grad
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vignette)
	hud = Control.new()
	hud.set_script(load("res://scripts/hud.gd"))
	layer.add_child(hud)
	hud.player = player
	hud.boss = boss
	get_tree().create_timer(12.0).timeout.connect(func(): hud.show_help = false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--showcase="):
			var sc: Node = load("res://tools/showcase.gd").new()
			sc.main = self
			sc.out = a.trim_prefix("--showcase=")
			add_child(sc)
		if a.begins_with("--autotest="):
			var t: Node = load("res://tools/autotest.gd").new()
			t.main = self
			t.out = a.trim_prefix("--autotest=")
			add_child(t)

## Level step: the ground under everything.
func _build_ground() -> void:
	var ground := Node2D.new()
	ground.set_script(load("res://scripts/ground.gd"))
	ground.world_rect = WORLD
	ground.arena_center = ARENA_C
	ground.arena_radius = ARENA_R
	ground.path_points = PackedVector2Array(PATH)
	ground.clearings = [[START + Vector2(0, -20), 64], [Vector2(560, 950), 70], [Vector2(620, 780), 60]]
	add_child(ground)

## Level step: the boss and where it waits.
func _make_boss() -> Boss:
	var b := Boss.new()
	b.position = ARENA_C + Vector2(0, -60)
	return b

## Level step: lighting and weather.
func _atmosphere(cam: Camera2D) -> void:
	var cm := CanvasModulate.new()
	cm.color = Color(0.74, 0.7, 0.82)  # dusk
	add_child(cm)
	_add_leaves(cam)

## Level step: one enemy of the patrol.
func _make_skeleton(i: int) -> SkeletonEnemy:
	var s := SkeletonEnemy.new()
	s.kind = "spear" if i % 2 == 1 else "sword"
	return s

## A point just outside the arena, on the way in (used by tests).
func arena_entry() -> Vector2:
	return ARENA_C + Vector2(0, ARENA_R * 0.65)

## Level step: is this point inside the boss arena (where the gate closes)?
func _in_arena(p: Vector2) -> bool:
	return p.distance_to(ARENA_C) < ARENA_R - 30

## Level step: scenery, walls and props.
func _build_level() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Invisible borders; the forest drawn along them shows the limit.
	_wall(Rect2(WORLD.position.x - 20, WORLD.position.y - 20, WORLD.size.x + 40, 40))
	_wall(Rect2(WORLD.position.x - 20, WORLD.end.y - 20, WORLD.size.x + 40, 40))
	_wall(Rect2(WORLD.position.x - 20, WORLD.position.y, 40, WORLD.size.y))
	_wall(Rect2(WORLD.end.x - 20, WORLD.position.y, 40, WORLD.size.y))
	var forest := ["tree_pine_a", "tree_pine_b", "tree_pine_c", "tree_dead", "tree_pine_a", "tree_red_b"]
	var y := WORLD.position.y + 10.0
	while y < WORLD.end.y + 40:
		for side in [WORLD.position.x + 10, WORLD.end.x - 10]:
			for k in 2:
				_tree(forest, Vector2(side + (k * 34 if side < 600 else -k * 34) + rng.randf_range(-8, 8), y + rng.randf_range(-10, 10)), rng)
		y += rng.randf_range(26, 40)
	var x := WORLD.position.x + 60.0
	while x < WORLD.end.x - 60:
		_tree(forest, Vector2(x, WORLD.position.y + 30 + rng.randf_range(-6, 10)), rng)
		_tree(forest, Vector2(x + 18, WORLD.end.y - 6 + rng.randf_range(-8, 4)), rng)
		x += rng.randf_range(30, 44)

	# Arena: an invisible ring wall, dressed as a ruined Greek temple
	# (see _build_temple), open to the south.
	for i in 40:
		var a := i * TAU / 40
		if absf(wrapf(a - PI / 2, -PI, PI)) < 0.22:
			continue
		var p := ARENA_C + Vector2.RIGHT.rotated(a) * (ARENA_R + 12)
		_wall(Rect2(p - Vector2(20, 20), Vector2(40, 40)), false)
	_build_temple(rng)
	# Ruins along the path, guarded by the skeletons.
	for p in [Vector2(530, 1170), Vector2(680, 1020), Vector2(520, 880), Vector2(690, 660), Vector2(510, 650), Vector2(680, 880)]:
		Prop.make(world, ["pillar", "pillar_broken", "pillar_dark_broken"][rng.randi() % 3], p)
	# Countryside: dead and autumn trees, rocks, tall grass.
	var keep_out := func(p: Vector2) -> bool:
		if p.distance_to(ARENA_C) < ARENA_R + 50 or p.distance_to(START) < 80:
			return true
		for i in range(PATH.size() - 1):
			if Geometry2D.get_closest_point_to_segment(p, PATH[i], PATH[i + 1]).distance_to(p) < 60:
				return true
		return false
	var scatter := [["tree_dead", 10], ["tree_pine_b", 4], ["tree_red_a", 2], ["tree_orange", 1], ["rock_big", 2],
		["rock_low", 3], ["rock_mid", 3], ["stump", 3], ["grass_tall_a", 10], ["grass_tall_b", 10],
		["grass_short_a", 10], ["grass_short_b", 10], ["fern", 3], ["bush_a", 3], ["bush_c", 3], ["mushroom_a", 3], ["pebble", 4]]
	var bag: Array[String] = []
	for e in scatter:
		for i in e[1]:
			bag.append(e[0])
	for i in 260:
		var p := Vector2(rng.randf_range(90, WORLD.end.x - 90), rng.randf_range(90, WORLD.end.y - 50))
		if keep_out.call(p):
			continue
		var k: String = bag[rng.randi() % bag.size()]
		if k.begins_with("tree_"):
			_tree([k], p, rng)
		else:
			Prop.make(world, k, p, rng.randf() < 0.5)
	# Grass along the path edges.
	for i in range(PATH.size() - 1):
		var a: Vector2 = PATH[i]
		var b: Vector2 = PATH[i + 1]
		var n := (b - a).normalized().orthogonal()
		var d := 0.0
		while d < a.distance_to(b):
			for side in [-1, 1]:
				if rng.randf() < 0.5:
					var p: Vector2 = a + (b - a).normalized() * d + n * side * rng.randf_range(38, 52)
					if p.distance_to(ARENA_C) > ARENA_R + 30:
						Prop.make(world, ["grass_short_a", "grass_short_b", "grass_tall_a"][rng.randi() % 3], p, rng.randf() < 0.5)
			d += 18
	# Stones around the bonfire.
	for i in 7:
		Prop.make(world, "pebble", bonfire.position + Vector2.RIGHT.rotated(i * TAU / 7) * 18 + Vector2(0, 4))

## The boss arena: a ring of marble columns, standing at the back and
## broken at the front so they never hide the fight, fallen columns and
## drums, rubble and four burning braziers.
func _build_temple(rng: RandomNumberGenerator) -> void:
	var n := 18
	for i in n:
		var a := i * TAU / n + PI / 2  # i = 0 is the gate, due south
		if i == 0:
			continue
		var p := ARENA_C + Vector2.RIGHT.rotated(a) * (ARENA_R + 8)
		var front := sin(a) > 0.35
		var k := "marble_column"
		if i == 1 or i == n - 1:
			k = "marble_column"  # the two columns framing the gate
		elif front:
			k = ["marble_stump", "marble_stump", "marble_drum"][rng.randi() % 3]
		elif rng.randf() < 0.3:
			k = "marble_stump_tall"
		Prop.make(world, k, p, rng.randf() < 0.5)
		if front and rng.randf() < 0.6:
			Prop.make(world, "pebble", p + Vector2(rng.randf_range(-14, 14), rng.randf_range(4, 12)))
	# Fallen columns and drums, inside along the edge and outside the ring.
	for spot in [[-2.3, ARENA_R - 30], [-0.55, ARENA_R - 34], [2.55, ARENA_R + 46], [0.35, ARENA_R + 50], [-1.2, ARENA_R + 52]]:
		Prop.make(world, "marble_fallen", ARENA_C + Vector2.RIGHT.rotated(spot[0]) * spot[1], rng.randf() < 0.5)
	for i in 6:
		var p := ARENA_C + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(ARENA_R - 50, ARENA_R - 20)
		if sin((p - ARENA_C).angle()) < 0.6:
			Prop.make(world, ["marble_drum", "pebble", "rock_small"][rng.randi() % 3], p, rng.randf() < 0.5)
	for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var b := Brazier.new()
		b.position = ARENA_C + Vector2.RIGHT.rotated(a) * (ARENA_R - 34)
		world.add_child(b)

func _tree(kinds: Array, p: Vector2, rng: RandomNumberGenerator) -> void:
	Prop.make(world, kinds[rng.randi() % kinds.size()], p, rng.randf() < 0.5)

func _wall(r: Rect2, add_to_root: bool = true) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = r.size
	cs.shape = s
	cs.position = r.get_center()
	b.add_child(cs)
	add_child(b)

## Falling leaves drifting across the screen.
func _add_leaves(cam: Camera2D) -> void:
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(380, 220)
	p.direction = Vector2(-0.6, 1)
	p.spread = 25
	p.gravity = Vector2(0, 4)
	p.initial_velocity_min = 8
	p.initial_velocity_max = 20
	p.angular_velocity_min = -90
	p.angular_velocity_max = 90
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.z_index = 40
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.45, 0.15, 0.0))
	ramp.add_point(0.15, Color(0.85, 0.4, 0.15, 0.9))
	ramp.add_point(0.85, Color(0.7, 0.25, 0.1, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.2, 0.1, 0.0))
	p.color_ramp = ramp
	cam.add_child(p)

func _spawn_skeletons() -> void:
	for s in _skeletons:
		if is_instance_valid(s):
			s.queue_free()
	_skeletons.clear()
	for i in skeleton_spots.size():
		var s := _make_skeleton(i)
		s.position = skeleton_spots[i]
		s.player = player
		world.add_child(s)
		_skeletons.append(s)

func _physics_process(delta: float) -> void:
	Fx.update_shake(delta)
	if _ended:
		return
	var near_fire := player.global_position.distance_to(bonfire.global_position) < 40 and not _gate_closed
	hud.hint = "[E] Se reposer au feu" if near_fire and not player.dead else ""
	if near_fire and Input.is_action_just_pressed("interact"):
		player.rest()
		_spawn_skeletons()
		Sfx.play(self, "bonfire", null, -2.0, 0.0)
		Fx.ring(world, bonfire.global_position, 4, 60, Color(1, 0.7, 0.3), 0.6)
		hud.flash_message("Feu allumé", Color(1, 0.75, 0.35), "Santé et fioles restaurées. Les ennemis sont revenus.")
		get_tree().create_timer(2.0).timeout.connect(func(): if not _ended: hud.message = "")
	if not _gate_closed and _in_arena(player.global_position):
		_close_gate()
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	if Input.is_action_just_pressed("help"):
		hud.show_help = not hud.show_help
	if Input.is_action_just_pressed("switch_hero"):
		player.set_hero(not player.hd)
	if Input.is_action_just_pressed("sound_set"):
		Fx.float_text(world, player.global_position + Vector2(0, -60), Sfx.toggle_set(self), Color(0.8, 0.9, 1))
	if Input.is_action_just_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))

func _close_gate() -> void:
	_gate_closed = true
	_seal_arena()
	boss.activate()
	music.play("boss_phase1", 1.0)
	hud.show_boss = true
	hud.flash_message(Boss.BOSS_NAME, Color(0.9, 0.8, 0.6))
	get_tree().create_timer(2.0).timeout.connect(func(): if not _ended: hud.message = "")

## Level step: block the way out of the arena.
func _seal_arena() -> void:
	# The gate collapses: a column falls across the way out.
	for spot in [[Vector2(0, ARENA_R + 14), "marble_fallen"], [Vector2(-40, ARENA_R + 22), "marble_drum"], [Vector2(38, ARENA_R + 24), "rock_low"]]:
		var r := Prop.make(world, spot[1], ARENA_C + spot[0])
		r.collision_layer = 1
		Fx.dust(world, r.position, Vector2.UP)
	_wall(Rect2(ARENA_C + Vector2(-60, ARENA_R), Vector2(120, 30)))
	Fx.shake(6)
	Sfx.play(self, "rocks_fall", null, 0.0, 0.0)
	Sfx.play(self, "rocks", null, 0.0)

func _on_player_died() -> void:
	_ended = true
	hud.flash_message("VOUS ÊTES MORT", Color(0.75, 0.08, 0.06))
	music.stop(1.0)
	Sfx.play(self, "you_died", null, -2.0, 0.0)
	get_tree().create_timer(3.5).timeout.connect(get_tree().reload_current_scene)

func _on_boss_died() -> void:
	_ended = true
	Fx.hitstop(get_tree(), 0.25)
	hud.show_boss = false
	music.stop(2.5)
	get_tree().create_timer(1.2).timeout.connect(func(): Sfx.play(self, "victory", null, -2.0, 0.0))
	hud.flash_message("ENNEMI ABATTU", Color(0.95, 0.8, 0.35), "Merci d'avoir testé le prototype ! (rechargement dans 6 s)")
	get_tree().create_timer(6.0).timeout.connect(get_tree().reload_current_scene)

# --- controls ------------------------------------------------------------

func _setup_inputs() -> void:
	var map := {
		"move_up": [[KEY_W], [KEY_UP], ["axis", JOY_AXIS_LEFT_Y, -1.0], ["btn", JOY_BUTTON_DPAD_UP]],
		"move_down": [[KEY_S], [KEY_DOWN], ["axis", JOY_AXIS_LEFT_Y, 1.0], ["btn", JOY_BUTTON_DPAD_DOWN]],
		"move_left": [[KEY_A], [KEY_LEFT], ["axis", JOY_AXIS_LEFT_X, -1.0], ["btn", JOY_BUTTON_DPAD_LEFT]],
		"move_right": [[KEY_D], [KEY_RIGHT], ["axis", JOY_AXIS_LEFT_X, 1.0], ["btn", JOY_BUTTON_DPAD_RIGHT]],
		"roll": [[KEY_SPACE], ["btn", JOY_BUTTON_B]],
		"block": [[KEY_L], [KEY_SHIFT], ["btn", JOY_BUTTON_LEFT_SHOULDER]],
		"attack_light": [[KEY_J], ["mouse", MOUSE_BUTTON_LEFT], ["btn", JOY_BUTTON_X], ["btn", JOY_BUTTON_RIGHT_SHOULDER]],
		"attack_heavy": [[KEY_K], ["mouse", MOUSE_BUTTON_RIGHT], ["btn", JOY_BUTTON_Y], ["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
		"heal": [[KEY_R], ["axis", JOY_AXIS_TRIGGER_LEFT, 1.0]],
		"switch_weapon": [[KEY_TAB], ["btn", JOY_BUTTON_BACK]],
		"interact": [[KEY_E], ["btn", JOY_BUTTON_A]],
		"help": [[KEY_H], ["btn", JOY_BUTTON_START]],
		"mute": [[KEY_M]],
		"sound_set": [[KEY_N]],
		"switch_hero": [[KEY_C]],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.3)
		for e in map[action]:
			var ev: InputEvent
			if e[0] is String and e[0] == "axis":
				ev = InputEventJoypadMotion.new()
				ev.axis = e[1]
				ev.axis_value = e[2]
			elif e[0] is String and e[0] == "btn":
				ev = InputEventJoypadButton.new()
				ev.button_index = e[1]
			elif e[0] is String and e[0] == "mouse":
				ev = InputEventMouseButton.new()
				ev.button_index = e[1]
			else:
				ev = InputEventKey.new()
				ev.physical_keycode = e[0]  # physical: ZQSD on AZERTY = WASD on QWERTY
			InputMap.action_add_event(action, ev)
