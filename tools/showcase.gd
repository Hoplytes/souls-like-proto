extends Node
## Records the player doing each move, for a preview GIF:
##   godot -- --showcase=<output folder>
## Saves one PNG per captured frame, cropped around the player.

var main: Node
var out := ""
var _n := 0
var _recording := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _physics_process(_d: float) -> void:
	if _recording and Engine.get_physics_frames() % 2 == 0:
		_grab()

func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var c := Vector2i(320, 170)
	img = img.get_region(Rect2i(c - Vector2i(110, 75), Vector2i(220, 150)))
	img.save_png(out.path_join("f_%04d.png" % _n))
	_n += 1

func _hold(action: String, t: float) -> void:
	Input.action_press(action)
	await _wait(t)
	Input.action_release(action)

func _run() -> void:
	var p: Player = main.player
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is SkeletonEnemy:
			e.queue_free()
	p.global_position = main.start_pos + Vector2(0, -180)
	await _wait(0.8)
	_recording = true
	for d in ["move_down", "move_right", "move_up", "move_left"]:
		await _hold(d, 0.45)
	await _wait(0.3)
	for i in 3:
		await _hold("attack_light", 0.06)
		await _wait(0.28)
	await _wait(0.4)
	await _hold("attack_heavy", 0.06)
	await _wait(0.9)
	Input.action_press("move_right")
	await _hold("roll", 0.06)
	await _wait(0.5)
	Input.action_release("move_right")
	Input.action_press("move_down")
	await _hold("roll", 0.06)
	await _wait(0.5)
	Input.action_release("move_down")
	await _wait(0.2)
	await _hold("block", 0.9)
	await _wait(0.3)
	_recording = false
	get_tree().quit()
