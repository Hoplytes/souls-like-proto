extends Node2D
## Builds the prototype level: a ruined path guarded by skeletons, a
## bonfire checkpoint and the arena of Gorvak.

const WORLD := Rect2(0, 0, 1200, 1500)
const ARENA_C := Vector2(600, 330)
const ARENA_R := 230.0
const START := Vector2(600, 1360)
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

func _ready() -> void:
	_setup_inputs()
	var ground := Node2D.new()
	ground.set_script(load("res://scripts/ground.gd"))
	ground.world_rect = WORLD
	ground.arena_center = ARENA_C
	ground.arena_radius = ARENA_R
	ground.path_points = PackedVector2Array([START, Vector2(600, 1150), Vector2(560, 950), Vector2(620, 780), Vector2(600, 560)])
	add_child(ground)

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	bonfire = Bonfire.new()
	bonfire.position = START + Vector2(0, -30)
	world.add_child(bonfire)

	player = Player.new()
	player.position = START
	world.add_child(player)
	var cam := Camera2D.new()
	cam.position = Vector2(0, -20)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.limit_left = int(WORLD.position.x)
	cam.limit_top = int(WORLD.position.y)
	cam.limit_right = int(WORLD.end.x)
	cam.limit_bottom = int(WORLD.end.y)
	player.add_child(cam)
	Fx.camera = cam
	player.died.connect(_on_player_died)

	_build_level()
	_spawn_skeletons()

	boss = Boss.new()
	boss.position = ARENA_C + Vector2(0, -60)
	boss.player = player
	world.add_child(boss)
	boss.died.connect(_on_boss_died)

	var cm := CanvasModulate.new()
	cm.color = Color(0.82, 0.8, 0.9)
	add_child(cm)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_script(load("res://scripts/hud.gd"))
	layer.add_child(hud)
	hud.player = player
	hud.boss = boss
	get_tree().create_timer(12.0).timeout.connect(func(): hud.show_help = false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			var t: Node = load("res://tools/autotest.gd").new()
			t.main = self
			t.out = a.trim_prefix("--autotest=")
			add_child(t)

func _build_level() -> void:
	# Outer cliffs.
	_wall(Rect2(WORLD.position.x, WORLD.position.y, WORLD.size.x, 24))
	_wall(Rect2(WORLD.position.x, WORLD.end.y - 24, WORLD.size.x, 24))
	_wall(Rect2(WORLD.position.x, WORLD.position.y, 24, WORLD.size.y))
	_wall(Rect2(WORLD.end.x - 24, WORLD.position.y, 24, WORLD.size.y))
	# The arena wall: a ring of wall segments with an opening to the south.
	for i in 28:
		var a := i * TAU / 28
		if absf(wrapf(a - PI / 2, -PI, PI)) < 0.2:
			continue  # the gate
		var p := ARENA_C + Vector2.RIGHT.rotated(a) * (ARENA_R + 14)
		Prop.make(world, "wall", p + Vector2(0, 10), Vector2(56, 34))
	for i in 6:
		var a := i * TAU / 6 + 0.3
		Prop.make(world, "pillar", ARENA_C + Vector2.RIGHT.rotated(a) * (ARENA_R - 40), Vector2(14, 44))
	# Ruins and graves along the path.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 70:
		var p := Vector2(rng.randf_range(60, WORLD.end.x - 60), rng.randf_range(620, WORLD.end.y - 60))
		if absf(p.x - 600) < 110 or p.distance_to(START) < 90:
			continue
		var k: String = ["tree", "tree", "grave", "rock", "pillar"][rng.randi() % 5]
		Prop.make(world, k, p, Vector2(14, rng.randf_range(24, 46)) if k == "pillar" else Vector2.ZERO)
	for i in 40:
		var a := rng.randf() * TAU
		var p := ARENA_C + Vector2.RIGHT.rotated(a) * rng.randf_range(ARENA_R + 60, ARENA_R + 260)
		if WORLD.grow(-50).has_point(p) and absf(p.x - 600) > 70:
			Prop.make(world, "tree", p)
	for p in [Vector2(540, 1180), Vector2(670, 1010), Vector2(540, 880), Vector2(680, 650), Vector2(520, 640)]:
		Prop.make(world, "pillar", p, Vector2(14, rng.randf_range(20, 40)))

func _wall(r: Rect2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = r.size
	cs.shape = s
	cs.position = r.get_center()
	b.add_child(cs)
	add_child(b)
	var vis := ColorRect.new()
	vis.color = Color(0.08, 0.08, 0.1)
	vis.position = r.position
	vis.size = r.size
	b.add_child(vis)

func _spawn_skeletons() -> void:
	for s in _skeletons:
		if is_instance_valid(s):
			s.queue_free()
	_skeletons.clear()
	for p in SKELETONS:
		var s := SkeletonEnemy.new()
		s.position = p
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
		Fx.ring(world, bonfire.global_position, 4, 60, Color(1, 0.7, 0.3), 0.6)
		hud.flash_message("Feu allumé", Color(1, 0.75, 0.35), "Santé et fioles restaurées. Les ennemis sont revenus.")
		get_tree().create_timer(2.0).timeout.connect(func(): if not _ended: hud.message = "")
	if not _gate_closed and player.global_position.distance_to(ARENA_C) < ARENA_R - 30:
		_close_gate()
	if Input.is_action_just_pressed("help"):
		hud.show_help = not hud.show_help

func _close_gate() -> void:
	_gate_closed = true
	_gate = Prop.make(world, "wall", ARENA_C + Vector2(0, ARENA_R + 24), Vector2(80, 34))
	boss.activate()
	hud.show_boss = true
	hud.flash_message(Boss.BOSS_NAME, Color(0.9, 0.8, 0.6))
	get_tree().create_timer(2.0).timeout.connect(func(): if not _ended: hud.message = "")

func _on_player_died() -> void:
	_ended = true
	hud.flash_message("VOUS ÊTES MORT", Color(0.75, 0.08, 0.06))
	get_tree().create_timer(3.5).timeout.connect(get_tree().reload_current_scene)

func _on_boss_died() -> void:
	_ended = true
	Fx.hitstop(get_tree(), 0.25)
	hud.show_boss = false
	hud.flash_message("ENNEMI ABATTU", Color(0.95, 0.8, 0.35), "Merci d'avoir testé le prototype ! (rechargement dans 6 s)")
	get_tree().create_timer(6.0).timeout.connect(get_tree().reload_current_scene)

# --- controls ------------------------------------------------------------

func _setup_inputs() -> void:
	var map := {
		"move_up": [[KEY_W], [KEY_UP], ["axis", JOY_AXIS_LEFT_Y, -1.0], ["btn", JOY_BUTTON_DPAD_UP]],
		"move_down": [[KEY_S], [KEY_DOWN], ["axis", JOY_AXIS_LEFT_Y, 1.0], ["btn", JOY_BUTTON_DPAD_DOWN]],
		"move_left": [[KEY_A], [KEY_LEFT], ["axis", JOY_AXIS_LEFT_X, -1.0], ["btn", JOY_BUTTON_DPAD_LEFT]],
		"move_right": [[KEY_D], [KEY_RIGHT], ["axis", JOY_AXIS_LEFT_X, 1.0], ["btn", JOY_BUTTON_DPAD_RIGHT]],
		"roll": [[KEY_SPACE], [KEY_SHIFT], ["btn", JOY_BUTTON_B]],
		"attack_light": [[KEY_J], ["mouse", MOUSE_BUTTON_LEFT], ["btn", JOY_BUTTON_X], ["btn", JOY_BUTTON_RIGHT_SHOULDER]],
		"attack_heavy": [[KEY_K], ["mouse", MOUSE_BUTTON_RIGHT], ["btn", JOY_BUTTON_Y], ["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
		"heal": [[KEY_R], ["btn", JOY_BUTTON_LEFT_SHOULDER]],
		"switch_weapon": [[KEY_TAB], ["btn", JOY_BUTTON_BACK]],
		"interact": [[KEY_E], ["btn", JOY_BUTTON_A]],
		"help": [[KEY_H], ["btn", JOY_BUTTON_START]],
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
