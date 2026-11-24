extends Node
## Walks the hero across biome borders and logs the slow frames, with what
## the game was doing (godot -- --profile=<folder>).

var main: Game
var out := ""
var _log: Array[String] = []
var _last_biome := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _process(delta: float) -> void:
	if main == null or main.player == null:
		return
	var ms := delta * 1000.0
	_avg = lerpf(_avg, ms, 0.05)
	var b: String = main._biome
	if b != _last_biome:
		_log.append("%d  biome -> %s" % [Engine.get_process_frames(), b])
		_last_biome = b
	if ms > _threshold():
		_log.append("%d  slow frame %.0f ms (process %.1f, physics %.1f, objects %d, draw calls %d)" % [
			Engine.get_process_frames(), ms,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])

var _avg := 40.0

## A frame is slow when it takes much longer than the recent ones (the
## software renderer of the test machine is slow on every frame).
func _threshold() -> float:
	return _avg * 1.6

func _physics_process(_d: float) -> void:
	pass

func _walk(action: String, t: float) -> void:
	Input.action_press(action)
	await get_tree().create_timer(t).timeout
	Input.action_release(action)

func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	main.player.invulnerable = true
	_log.append("--- start -> north, along the road to the dead lands")
	main.teleport_to_cell(Vector2(88, 82))
	await get_tree().create_timer(1.0).timeout
	await _walk("move_up", 6.0)
	_log.append("--- -> snow (east)")
	await _walk("move_right", 7.0)
	_log.append("--- -> caves -> ruins (west)")
	await _walk("move_left", 14.0)
	var f := FileAccess.open(out.path_join("profile.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_log))
	get_tree().quit()
