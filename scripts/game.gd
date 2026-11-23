extends Node2D
class_name Game
## The game: a dungeon hall built from Flare tiles (CC-BY-SA 3.0), with
## skeletons, zombies, a bonfire checkpoint and the arena of the Minotaur.
## The hero comes from the character creator (scenes/creator.tscn).
## Map cell (i, j) is drawn at ((i - j) * 48, (i + j) * 24): the top corner
## of the screen is cell (0, 0), the player starts at the bottom.

const TW := 96.0
const TH := 48.0
const N := 22  # the hall is N x N cells
const ARENA_CELL := Vector2(6.5, 6.5)
const ARENA_CELLS := 4.6  # arena radius, in cells
const FLOOR_PLAIN := [16, 17, 18, 19, 22, 23, 26, 29, 30, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47]
const FLOOR_COBBLE := [32, 33, 34, 35]

var world: Node2D
var player: Player
var boss: Boss
var hud
var bonfire: Bonfire
var _gate_closed := false
var _ended := false
var _skeletons: Array = []
var music: Music
var world_rect := Rect2()
var start_pos := Vector2.ZERO
var arena_center := Vector2.ZERO
var arena_radius := 0.0
var skeleton_spots: Array = []
var _anchors := {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 5
	_anchors = JSON.parse_string(FileAccess.get_file_as_string("res://assets/flare/tiles/anchors.json"))
	world_rect = Rect2(-N * TW / 2.0 - 40, -260, N * TW + 80, N * TH + 300)
	start_pos = cell_pos(18.5, 18.5)
	arena_center = cell_pos(ARENA_CELL.x, ARENA_CELL.y)
	arena_radius = ARENA_CELLS * TW / sqrt(2.0)
	skeleton_spots = [cell_pos(14, 16), cell_pos(16, 12.5), cell_pos(11, 14), cell_pos(13, 10.5), cell_pos(10, 11)]
	setup_inputs()
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

# --- level ----------------------------------------------------------------

static func cell_pos(i: float, j: float) -> Vector2:
	return Vector2((i - j) * TW / 2.0, (i + j) * TH / 2.0)

static func to_cell(p: Vector2) -> Vector2:
	return Vector2((p.y / (TH / 2.0) + p.x / (TW / 2.0)) / 2.0, (p.y / (TH / 2.0) - p.x / (TW / 2.0)) / 2.0)

# --- tiles -----------------------------------------------------------------

func _tile(id: int, at: Vector2, parent: Node, z: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/flare/tiles/%d.png" % id)
	s.centered = false
	var a: Array = _anchors[str(id)]
	s.offset = -Vector2(a[0], a[1])
	s.position = at
	s.z_index = z
	parent.add_child(s)
	return s

## A solid piece of scenery: a tile plus a small collision at its base.
func _solid(id: int, at: Vector2, radius: float) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.position = at
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	b.add_child(cs)
	world.add_child(b)
	_tile(id, Vector2.ZERO, b)
	return b

func _arena_dist(i: float, j: float) -> float:
	return Vector2(i, j).distance_to(ARENA_CELL)

# --- level steps -------------------------------------------------------------

func _build_ground() -> void:
	var floor_node := Node2D.new()
	floor_node.z_index = -10
	add_child(floor_node)
	for i in N:
		for j in N:
			var ids: Array = FLOOR_COBBLE if _arena_dist(i + 0.5, j + 0.5) < ARENA_CELLS + 0.6 else FLOOR_PLAIN
			_tile(ids[_rng.randi() % ids.size()], cell_pos(i + 0.5, j + 0.5), floor_node)
	# Glowing runes and a summoning circle in the arena.
	_tile(265, arena_center, floor_node, 1)
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		var c := ARENA_CELL + Vector2.RIGHT.rotated(a) * 2.6
		_tile(60 + k, cell_pos(c.x, c.y), floor_node, 1)

func _build_level() -> void:
	# The hall's edges: walls at the back, an invisible limit at the front.
	var top := cell_pos(0, 0)
	var left := cell_pos(0, N)
	var right := cell_pos(N, 0)
	var bottom := cell_pos(N, N)
	for seg in [[top, left], [top, right], [left, bottom], [right, bottom]]:
		_edge(seg[0], seg[1])
	# Back walls: the upper-left edge shows its right face, the upper-right
	# edge its left face (the Flare tiles come in left/right pairs).
	for k in range(-1, N):
		var right_face: int = [65, 69, 103, 97, 99, 65, 107, 69][posmod(k, 8)]
		var left_face: int = [64, 68, 102, 96, 98, 64, 106, 68][posmod(k + 3, 8)]
		if k == -1:
			_tile(66, cell_pos(-0.5, -0.5), world)
			continue
		_tile(right_face, cell_pos(-0.5, k + 0.5), world)
		_tile(left_face, cell_pos(k + 0.5, -0.5), world)
	# Columns around the arena, open toward the hall.
	for k in 10:
		var a := k * TAU / 10.0
		var c := ARENA_CELL + Vector2.RIGHT.rotated(a) * (ARENA_CELLS + 0.9)
		if absf(wrapf(a - PI / 4.0, -PI, PI)) < 0.5:
			continue  # the way in, facing the start
		if c.x < 0.6 or c.y < 0.6:
			continue
		_solid(111, cell_pos(c.x, c.y), 12)
	# Statues guarding the hall, sarcophagi, braziers and bones.
	for spot in [[128, Vector2(1.2, 14)], [129, Vector2(14, 1.2)], [130, Vector2(1.2, 18)], [131, Vector2(18, 1.2)]]:
		_solid(spot[0], cell_pos(spot[1].x, spot[1].y), 16)
	for spot in [[194, Vector2(15, 15)], [199, Vector2(9.5, 16.5)], [200, Vector2(17, 9)]]:
		_solid(spot[0], cell_pos(spot[1].x, spot[1].y), 22)
	for c in [Vector2(17, 20), Vector2(20, 17), Vector2(12, 12.5), Vector2(3, 10), Vector2(10, 3)]:
		_brazier(cell_pos(c.x, c.y))
	for k in 26:
		var c := Vector2(_rng.randf_range(1, N - 1), _rng.randf_range(1, N - 1))
		if c.distance_to(Vector2(18.5, 18.5)) < 2.5:
			continue
		var id: int = 176 + _rng.randi() % 8
		_tile(id, cell_pos(c.x, c.y), world).z_index = -5

func _edge(a: Vector2, b: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = a
	seg.b = b
	cs.shape = seg
	body.add_child(cs)
	add_child(body)

func _brazier(at: Vector2) -> void:
	var b := _solid(151, at, 10)
	var fire := _tile(167, Vector2(0, -14), b)
	fire.z_index = 1
	var light := PointLight2D.new()
	light.texture = _light_texture()
	light.color = Color(1.0, 0.6, 0.3)
	light.energy = 0.9
	light.texture_scale = 1.4
	light.position = Vector2(0, -20)
	b.add_child(light)

func _light_texture() -> GradientTexture2D:
	var g := GradientTexture2D.new()
	g.width = 256
	g.height = 256
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(1, 1, 1, 1))
	g.gradient.set_color(1, Color(1, 1, 1, 0))
	return g

func _make_skeleton(i: int) -> SkeletonEnemy:
	var s := SkeletonEnemy.new()
	s.kind = "sword"
	s.flare_name = "zombie" if i % 3 == 2 else "skeleton"
	return s

func _make_boss() -> Boss:
	var b := Boss.new()
	b.flare_name = "minotaur"
	b.position = arena_center + Vector2(0, -20)
	return b

func _atmosphere(cam: Camera2D) -> void:
	var cm := CanvasModulate.new()
	cm.color = Color(0.36, 0.34, 0.44)  # a dark dungeon, lit by braziers
	add_child(cm)
	var torch := PointLight2D.new()  # the hero's own light
	torch.texture = _light_texture()
	torch.color = Color(1.0, 0.85, 0.7)
	torch.energy = 0.7
	torch.texture_scale = 1.6
	torch.position = Vector2(0, -20)
	player.add_child(torch)

func arena_entry() -> Vector2:
	var c := ARENA_CELL + Vector2(1, 1).normalized() * (ARENA_CELLS + 0.2)
	return cell_pos(c.x, c.y)

func _in_arena(p: Vector2) -> bool:
	var c := to_cell(p)
	return _arena_dist(c.x, c.y) < ARENA_CELLS - 0.8

## A ring of blue light closes the arena.
func _seal_arena() -> void:
	var ring := Node2D.new()
	ring.z_index = -4
	var pts := PackedVector2Array()
	for k in 49:
		var a := k * TAU / 48.0
		var c := ARENA_CELL + Vector2.RIGHT.rotated(a) * (ARENA_CELLS + 0.3)
		pts.append(cell_pos(c.x, c.y))
	ring.draw.connect(func():
		ring.draw_polyline(pts, Color(0.4, 0.6, 1.0, 0.85), 3.0)
		ring.draw_polyline(pts, Color(0.6, 0.8, 1.0, 0.35), 9.0))
	add_child(ring)
	for k in 48:
		_edge(pts[k], pts[k + 1])
	Fx.shake(5)
	Sfx.play(self, "parry", null, -2.0, 0.0)

# --- game flow ------------------------------------------------------------

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
		get_tree().change_scene_to_file("res://scenes/creator.tscn")
	if Input.is_action_just_pressed("help"):
		hud.show_help = not hud.show_help
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

static func setup_inputs() -> void:
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
		"interact": [[KEY_E], ["btn", JOY_BUTTON_A]],
		"help": [[KEY_H], ["btn", JOY_BUTTON_START]],
		"mute": [[KEY_M]],
		"sound_set": [[KEY_N]],
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
