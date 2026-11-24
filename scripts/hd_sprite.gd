class_name HdSprite
extends Node2D
## Plays an 8-direction character: one sheet per animation, frames across,
## 8 rows = E, SE, S, SW, W, NW, N, NE. Used for the HD hero (SmallScaleInt,
## 15 frames, in res://local/, licensed art never published) and, through
## flare(), for the Flare enemies of the isometric prototype.
## The actor code drives it the same way for every character;
## either; set `facing8` every frame for the 8-way direction.

signal finished(anim: String)

const FRAMES := 15
const CELL := 128
const FEET := Vector2(64, 99)
# Our animation names -> the HD hero's sheet names.
const HD_SHEETS := {
	"idle": "Idle", "walk": "Run", "slash": "Melee", "slash2": "Melee2", "slash3": "MeleeSpin",
	"slash_heavy": "MeleeSpin", "slash_heavy2": "Melee2", "thrust": "Melee",
	"jump": "Rolling", "hurt": "Die", "stagger": "TakeDamage", "block_start": "ShieldBlockStart",
	"block": "ShieldBlockMid", "heal": "CastSpell",
}
# Frame counts of the matching LPC animations, to keep the same timings.
const LPC_FRAMES := {"idle": 2, "walk": 9, "slash": 6, "thrust": 8, "hurt": 6, "jump": 5,
	"strafe_left": 9, "strafe_right": 9, "back": 9, "march": 9}

const HD_FOLDER := "res://local/hd_knight/"

var folder := HD_FOLDER
var sheets: Dictionary = HD_SHEETS
var frames_of := {}  # sheet name -> frame count (default FRAMES)
var looping_sheets := {}  # sheets that loop on their own (Flare)
var feet_point := FEET  # in the sheet's pixels
## Detail factor: the sheets are drawn at 1/res (Flare art is stored at twice
## its size in the world, for a sharp 1280x720 picture).
var res := 1.0
## Packed sheets (Flare art): sheet name -> rects[row][frame] = [x, y, w, h, ox, oy],
## each frame cropped to what it shows, (ox, oy) its corner inside the cell.
var rects := {}

## Every sheet loaded so far, shared by all sprites, so that the first
## attack or the first boss does not stall the game while it decodes.
static var _cache := {}

static func texture(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]

## Loads every sheet of a Flare character in advance (see Game._preload).
static func preload_flare(name: String) -> void:
	var folder := folder_of(name)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "anims.json"))
	for a in meta.anims:
		texture(folder + a + ".png")

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
		position.y = -v - lift
		if _sprite:
			_apply_offset()
## Height of the ground under the character (plateaus, ramps): it is drawn
## that much higher.
var lift := 0.0:
	set(v):
		position.y += lift - v
		lift = v

static func available() -> bool:
	return ResourceLoader.exists(HD_FOLDER + "Idle.png")

## A Flare enemy converted by tools/convert_flare.py (assets/flare/<name>/).
## Characters of SmallScaleInt's isometric fantasy pack (licensed, in
## res://local/fantasy/chars/, see tools/convert_fantasy.py): our animation
## names -> the pack's. They have three different swings for the combo,
## strafing steps and a backward run, used when locked on an enemy.
const PACK_FOLDER := "res://local/fantasy/chars/"
const PACK_SHEETS := {
	"idle": "Idle", "walk": "Run", "march": "Walk", "slash": "Attack1", "slash2": "AttackRun", "slash3": "Attack2",
	"slash_heavy": "Attack4", "slash_heavy2": "Special1", "thrust": "Attack1", "hurt": "Die", "stagger": "TakeDamage", "block": "CrouchIdle",
	"block_start": "Attack5", "jump": "CrouchRun", "heal": "Taunt", "strafe_left": "StrafeLeft",
	"strafe_right": "StrafeRight", "back": "RunBackwards", "crouch": "CrouchIdle", "crouch_run": "CrouchRun",
	# The enemies play the pack's attacks by their own names.
	"Attack1": "Attack1", "Attack2": "Attack2", "Attack3": "Attack3", "Attack4": "Attack4", "Attack5": "Attack5",
	"AttackRun": "AttackRun", "Special1": "Special1", "Taunt": "Taunt", "TakeDamage": "TakeDamage", "Die": "Die",
}
const FLARE_SHEETS := {"idle": "stance", "walk": "run", "slash": "swing", "slash_heavy": "swing", "thrust": "swing",
	"hurt": "die", "stagger": "hit", "block": "block", "block_start": "block", "jump": "run", "heal": "stance"}

## "pack/<name>" is a character of the fantasy pack, anything else a Flare one.
static func folder_of(name: String) -> String:
	if name.begins_with("pack/"):
		return PACK_FOLDER + name.trim_prefix("pack/") + "/"
	return "res://assets/flare/%s/" % name

static func pack_available(name: String = "hero") -> bool:
	return ResourceLoader.exists(PACK_FOLDER + name + "/Idle.png")

## Draws the sheets at 1/r of their size (see res).
func set_res(r: float) -> void:
	res = r
	_sprite.scale = Vector2.ONE / r
	_apply_offset()

func has_anim(name: String) -> bool:
	return sheets.has(name) and ResourceLoader.exists(folder + sheets[name] + ".png")

static func flare(name: String) -> HdSprite:
	var s := HdSprite.new()
	s.folder = folder_of(name)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(s.folder + "anims.json"))
	s.feet_point = Vector2(meta.feet[0], meta.feet[1])
	s.res = float(meta.get("res", 1))
	s._sprite.scale = Vector2.ONE / s.res
	s.sheets = PACK_SHEETS if name.begins_with("pack/") else FLARE_SHEETS
	for a in meta.anims:
		s.frames_of[a] = int(meta.anims[a].frames)
		if meta.anims[a].has("rects"):
			s.rects[a] = meta.anims[a].rects
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
	if not rects.is_empty():
		_show()  # the offset depends on the frame's crop
		return
	_sprite.offset = -feet_point + Vector2(0, pivot * res)

func _count() -> int:
	return frames_of.get(sheets.get(anim, ""), FRAMES)

func set_layers(_paths: Array) -> void:
	pass  # the HD character is one finished picture

func set_layer_visible(_i: int, _v: bool) -> void:
	pass

func feet() -> Vector2:
	return feet_point / res

func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = texture(folder + sheets[name] + ".png")
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
	var row := posmod(roundi(facing8.angle() / (PI / 4.0)), 8)
	var f := mini(_frame, _count() - 1)
	var sheet: String = sheets[anim]
	if rects.has(sheet):
		var r: Array = rects[sheet][row][f]
		_sprite.region_enabled = true
		_sprite.hframes = 1
		_sprite.vframes = 1
		_sprite.region_rect = Rect2(r[0], r[1], r[2], r[3])
		_sprite.offset = -feet_point + Vector2(r[4], r[5] + pivot * res)
		return
	_sprite.hframes = _count()
	_sprite.frame = row * _count() + f
