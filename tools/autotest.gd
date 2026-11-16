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

func _run() -> void:
	var p: Player = main.player
	await _wait(1.0)
	await _shot("01_start")
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
	p.global_position = Vector2(250, 1250)
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
	await _press("switch_weapon")
	await _press("attack_heavy")
	await _wait(0.4)
	await _shot("05_spear_heavy")
	log_lines.append("player hp %d stamina %d" % [p.hp, int(p.stamina)])
	# Teleport to the arena entrance and wake the boss.
	p.invulnerable = true
	p.global_position = main.ARENA_C + Vector2(0, 150)
	await _wait(0.3)
	Input.action_press("move_up")
	await _wait(0.5)
	Input.action_release("move_up")
	await _wait(0.8)
	await _shot("06_boss_intro")
	await _wait(1.2)
	await _shot("07_boss_attack")
	await _wait(0.6)
	await _shot("08_boss_attack2")
	# Damage the boss to phase 2.
	main.boss.take_hit(240, 0, p.global_position)
	await _wait(0.8)
	await _shot("09_phase2")
	await _wait(1.5)
	await _shot("10_phase2_attack")
	log_lines.append("boss hp %d phase %d" % [main.boss.hp, main.boss.phase])
	var f := FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	get_tree().quit()
