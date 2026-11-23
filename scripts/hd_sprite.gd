class_name HdSprite
extends Node2D
## Plays an 8-direction HD character (SmallScaleInt layout: one sheet per
## animation, 15 frames across, 8 rows = E, SE, S, SW, W, NW, N, NE).
## It answers the same calls as LpcSprite, so the player code can drive
## either; set `facing8` every frame for the 8-way direction.
## The sheets live in res://local/ (paid/licensed art, never published).

signal finished(anim: String)

const FRAMES := 15
const CELL := 128
const FEET := Vector2(64, 99)
# Our animation names -> the pack's sheet names.
const SHEETS := {
	"idle": "Idle", "walk": "Run", "slash": "Melee", "slash_heavy": "Melee2", "thrust": "Melee",
	"jump": "Rolling", "hurt": "Die", "stagger": "TakeDamage", "block_start": "ShieldBlockStart",
	"block": "ShieldBlockMid", "heal": "CastSpell",
}
# Frame counts of the matching LPC animations, to keep the same timings.
const LPC_FRAMES := {"idle": 2, "walk": 9, "slash": 6, "thrust": 8, "hurt": 6, "jump": 5}

static var folder := "res://local/hd_knight/"

var anim := "idle"
var fps := 12.0
var loop := true
var facing8 := Vector2.DOWN
var cell := CELL
var _sprite: Sprite2D
var _t := 0.0
var _frame := 0
var _done := false
var _textures := {}
var pivot := 0.0:
	set(v):
		pivot = v
		position.y = -v
		if _sprite:
			_sprite.offset = -FEET + Vector2(0, v)

static func available() -> bool:
	return ResourceLoader.exists(folder + "Idle.png")

func _init() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.offset = -FEET
	_sprite.hframes = FRAMES
	_sprite.vframes = 8
	add_child(_sprite)
	_show()

func set_layers(_paths: Array) -> void:
	pass  # the HD character is one finished picture

func set_layer_visible(_i: int, _v: bool) -> void:
	pass

func feet() -> Vector2:
	return FEET

func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(folder + SHEETS[name] + ".png")
	return _textures[name]

func play(name: String, speed: float = 8.0, looping: bool = true, restart: bool = false) -> void:
	var hd_fps := speed * FRAMES / float(LPC_FRAMES.get(name, FRAMES))
	if name == anim and not restart and not _done:
		fps = hd_fps
		return
	anim = name
	fps = hd_fps
	loop = looping
	_frame = 0
	_t = 0.0
	_done = false
	_show()

## Shows the point `p` (0..1) of the current animation: used to tie attacks,
## rolls and blocks to gameplay timings instead of a frame rate.
func set_progress(p: float) -> void:
	_frame = clampi(int(p * FRAMES), 0, FRAMES - 1)
	fps = 0.0
	_show()

func set_frame(f: int) -> void:
	var n: int = LPC_FRAMES.get(anim, FRAMES)
	set_progress((f + 0.5) / n)

func get_frame() -> int:
	return _frame

func frame_count() -> int:
	return LPC_FRAMES.get(anim, FRAMES)

func set_dir(_d: int) -> void:
	pass  # uses facing8

func _process(delta: float) -> void:
	_show()
	if _done or fps <= 0.0:
		return
	_t += delta
	var step := 1.0 / fps
	while _t >= step:
		_t -= step
		_frame += 1
		if _frame >= FRAMES:
			if loop:
				_frame = 0
			else:
				_frame = FRAMES - 1
				_done = true
				finished.emit(anim)
				return

func _show() -> void:
	if not SHEETS.has(anim):
		return
	_sprite.texture = _texture(anim)
	var row := posmod(roundi(facing8.angle() / (PI / 4.0)), 8)
	_sprite.frame = row * FRAMES + _frame
