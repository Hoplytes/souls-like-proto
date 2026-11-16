class_name LpcSprite
extends Node2D
## Stack of LPC sheet layers (back weapon, body, front weapon) that always
## show the same frame. Sheets are built by tools/compose_lpc.py:
## 128 px cells, one row per direction (up, left, down, right).

signal finished(anim: String)

const CELL := 128
const FEET := Vector2(64, 94)  # where the feet sit inside a cell
const COLS := 9
const ROWS := 17
const ANIMS := {
	"idle": {"row": 0, "frames": 2, "dirs": 4},
	"walk": {"row": 4, "frames": 9, "dirs": 4},
	"slash": {"row": 8, "frames": 6, "dirs": 4},
	"thrust": {"row": 12, "frames": 8, "dirs": 4},
	"hurt": {"row": 16, "frames": 6, "dirs": 1},
}
enum Dir { UP, LEFT, DOWN, RIGHT }

var anim := "idle"
var dir := Dir.DOWN
var fps := 4.0
var loop := true
var first_frame := 0  # walk loops skip its standing frame
var _t := 0.0
var _frame := 0
var _done := false
var _layers: Array[Sprite2D] = []

func set_layers(paths: Array) -> void:
	for s in _layers:
		s.queue_free()
	_layers.clear()
	for p in paths:
		if p == "":
			continue
		var s := Sprite2D.new()
		s.texture = load(p)
		s.centered = false
		s.offset = -FEET
		s.hframes = COLS
		s.vframes = ROWS
		add_child(s)
		_layers.append(s)
	_apply()

func play(name: String, speed: float = 8.0, looping: bool = true, restart: bool = false) -> void:
	if name == anim and not restart and not _done:
		fps = speed
		return
	anim = name
	fps = speed
	loop = looping
	first_frame = 1 if name == "walk" else 0
	_frame = first_frame
	_t = 0.0
	_done = false
	_apply()

func set_frame(f: int) -> void:
	_frame = clampi(f, 0, ANIMS[anim].frames - 1)
	_apply()

func get_frame() -> int:
	return _frame

func frame_count() -> int:
	return ANIMS[anim].frames

func set_dir(d: int) -> void:
	if d != dir:
		dir = d
		_apply()

static func dir_from_vector(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return Dir.RIGHT if v.x > 0 else Dir.LEFT
	return Dir.DOWN if v.y > 0 else Dir.UP

static func vector_from_dir(d: int) -> Vector2:
	match d:
		Dir.UP: return Vector2.UP
		Dir.LEFT: return Vector2.LEFT
		Dir.RIGHT: return Vector2.RIGHT
	return Vector2.DOWN

func _process(delta: float) -> void:
	if _done or fps <= 0.0:
		return
	_t += delta
	var step := 1.0 / fps
	while _t >= step:
		_t -= step
		_frame += 1
		if _frame >= ANIMS[anim].frames:
			if loop:
				_frame = first_frame
			else:
				_frame = ANIMS[anim].frames - 1
				_done = true
				_apply()
				finished.emit(anim)
				return
		_apply()

func _apply() -> void:
	var a: Dictionary = ANIMS[anim]
	var row: int = a.row + (dir if a.dirs == 4 else 0)
	for s in _layers:
		s.frame = row * COLS + _frame
