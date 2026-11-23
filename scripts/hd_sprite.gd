class_name HdSprite
extends Node2D
## Plays an 8-direction character: one sheet per animation, frames across,
## 8 rows = E, SE, S, SW, W, NW, N, NE. Used for the HD hero (SmallScaleInt,
## 15 frames, in res://local/, licensed art never published) and, through
## flare(), for the Flare enemies of the isometric prototype.
## It answers the same calls as AvatarSprite, so the actor code can drive
## either; set `facing8` every frame for the 8-way direction.

signal finished(anim: String)

const FRAMES := 15
const CELL := 128
const FEET := Vector2(64, 99)
# Our animation names -> the HD hero's sheet names.
const HD_SHEETS := {
	"idle": "Idle", "walk": "Run", "slash": "Melee", "slash_heavy": "Melee2", "thrust": "Melee",
	"jump": "Rolling", "hurt": "Die", "stagger": "TakeDamage", "block_start": "ShieldBlockStart",
	"block": "ShieldBlockMid", "heal": "CastSpell",
}
# Frame counts of the matching LPC animations, to keep the same timings.
const LPC_FRAMES := {"idle": 2, "walk": 9, "slash": 6, "thrust": 8, "hurt": 6, "jump": 5}

const HD_FOLDER := "res://local/hd_knight/"

var folder := HD_FOLDER
var sheets: Dictionary = HD_SHEETS
var frames_of := {}  # sheet name -> frame count (default FRAMES)
var looping_sheets := {}  # sheets that loop on their own (Flare)
var feet_point := FEET

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
			_sprite.offset = -feet_point + Vector2(0, v)

static func available() -> bool:
	return ResourceLoader.exists(HD_FOLDER + "Idle.png")

## A Flare enemy converted by tools/convert_flare.py (assets/flare/<name>/).
static func flare(name: String) -> HdSprite:
	var s := HdSprite.new()
	s.folder = "res://assets/flare/%s/" % name
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(s.folder + "anims.json"))
	s.feet_point = Vector2(meta.feet[0], meta.feet[1])
	s.sheets = {"idle": "stance", "walk": "run", "slash": "swing", "slash_heavy": "swing", "thrust": "swing",
		"hurt": "die", "stagger": "hit", "block": "block", "block_start": "block", "jump": "run", "heal": "stance"}
	for a in meta.anims:
		s.frames_of[a] = int(meta.anims[a].frames)
	s._textures.clear()  # _init cached the HD hero's idle sheet
	s._apply_offset()
	s._show()
	return s

func _init() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.vframes = 8
	add_child(_sprite)
	_apply_offset()
	_show()

func _apply_offset() -> void:
	_sprite.offset = -feet_point + Vector2(0, pivot)

func _count() -> int:
	return frames_of.get(sheets.get(anim, ""), FRAMES)

func set_layers(_paths: Array) -> void:
	pass  # the HD character is one finished picture

func set_layer_visible(_i: int, _v: bool) -> void:
	pass

func feet() -> Vector2:
	return feet_point

func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(folder + sheets[name] + ".png")
	return _textures[name]

func play(name: String, speed: float = 8.0, looping: bool = true, restart: bool = false) -> void:
	var hd_fps: float = speed * frames_of.get(sheets.get(name, ""), FRAMES) / float(LPC_FRAMES.get(name, FRAMES))
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
	_frame = clampi(int(p * _count()), 0, _count() - 1)
	fps = 0.0
	_show()

func set_frame(f: int) -> void:
	var n: int = LPC_FRAMES.get(anim, _count())
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
		if _frame >= _count():
			if loop:
				_frame = 0
			else:
				_frame = _count() - 1
				_done = true
				finished.emit(anim)
				return

func _show() -> void:
	if not sheets.has(anim) or not ResourceLoader.exists(folder + sheets[anim] + ".png"):
		return
	_sprite.texture = _texture(anim)
	_sprite.hframes = _count()
	var row := posmod(roundi(facing8.angle() / (PI / 4.0)), 8)
	_sprite.frame = row * _count() + mini(_frame, _count() - 1)
