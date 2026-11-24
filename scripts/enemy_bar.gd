class_name EnemyBar
extends Node2D
## The health bar over an enemy once it has been struck (or while it is
## locked on), with the damage dealt in a row beside it, as in Dark Souls III.

var enemy: Actor
var _show := 0.0
var _sum := 0
var _sum_t := 0.0
var _lag := 1.0

func _ready() -> void:
	z_as_relative = false
	z_index = 60

func show_for(seconds: float) -> void:
	_show = maxf(_show, seconds)

func add_damage(n: int) -> void:
	if _sum_t <= 0.0:
		_sum = 0
	_sum += n
	_sum_t = 2.5
	_show = maxf(_show, 5.0)

func _process(delta: float) -> void:
	_show -= delta
	_sum_t -= delta
	var r := float(enemy.hp) / enemy.max_hp
	_lag = maxf(r, move_toward(_lag, r, delta * 0.45))
	var p = enemy.get("player")
	var locked: bool = p != null and is_instance_valid(p) and p.lock_target == enemy
	visible = (_show > 0.0 or locked) and not enemy.dead
	if visible:
		queue_redraw()

func _draw() -> void:
	var y := -62.0 * enemy.sprite.scale.y - enemy.sprite.lift
	var w := 32.0
	var r := float(enemy.hp) / enemy.max_hp
	draw_rect(Rect2(-w / 2.0 - 1.0, y - 1.0, w + 2.0, 5.0), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(-w / 2.0, y, w * _lag, 3.0), Color(0.85, 0.7, 0.35))
	draw_rect(Rect2(-w / 2.0, y, w * r, 3.0), Color(0.72, 0.1, 0.08))
	if _sum_t > 0.0 and _sum > 0:
		var f := ThemeDB.fallback_font
		var s := str(_sum)
		draw_string_outline(f, Vector2(w / 2.0 + 3.0, y + 4.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(w / 2.0 + 3.0, y + 4.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.95, 0.85))
