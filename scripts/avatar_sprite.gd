class_name AvatarSprite
extends Node2D
## The modular hero: one HdSprite per equipment slot (Flare avatar pieces),
## all playing the same animation, stacked in the order Flare uses for each
## of the 8 directions (mods/fantasycore/engine/hero_layers.txt).
## It answers the same calls as HdSprite.

signal finished(anim: String)

const SLOTS := ["main", "feet", "legs", "hands", "chest", "off", "head"]
## Bottom-to-top order per direction row (E, SE, S, SW, W, NW, N, NE).
const ORDER := [
	["feet", "legs", "hands", "chest", "off", "head", "main"],  # E
	["feet", "legs", "hands", "main", "chest", "head", "off"],  # SE
	["main", "feet", "legs", "hands", "chest", "head", "off"],  # S
	["main", "feet", "legs", "hands", "chest", "off", "head"],  # SW
	["main", "feet", "legs", "hands", "chest", "off", "head"],  # W
	["main", "feet", "legs", "hands", "chest", "off", "head"],  # NW
	["feet", "legs", "hands", "chest", "off", "head", "main"],  # N
	["feet", "legs", "hands", "chest", "off", "head", "main"],  # NE
]
const ARMOUR := ["head", "chest", "hands", "legs", "feet"]

var facing8 := Vector2.DOWN
var cell := 160
var anim := "idle"
var _layers := {}  # slot -> HdSprite
var pivot := 0.0:
	set(v):
		pivot = v
		position.y = -v
		for l in _layers.values():
			l.pivot = v
			l.position.y = 0.0

## Builds the layers from a HeroConfig-style dictionary.
func build(cfg: Dictionary) -> void:
	for l in _layers.values():
		l.queue_free()
	_layers.clear()
	var body: String = cfg.body
	var pieces := {
		"head": cfg.helm if cfg.helm != "" else cfg.head,
		"chest": cfg.chest, "hands": cfg.hands, "legs": cfg.legs, "feet": cfg.feet,
		"main": cfg.weapon,
		"off": "" if Weapons.two_handed(cfg.weapon) else cfg.shield,
	}
	var tint: Color = HeroConfig.TINTS[int(cfg.tint)][1]
	for slot in SLOTS:
		if pieces[slot] == "":
			continue
		var l := HdSprite.flare(HeroConfig.piece_folder(body, pieces[slot]))
		l.pivot = pivot
		l.position.y = 0.0
		var armour: bool = slot in ARMOUR and not pieces[slot].begins_with("default_") and not pieces[slot].begins_with("head_")
		if armour or slot == "off":
			l.modulate = tint
		add_child(l)
		_layers[slot] = l
	_row = -1
	_sync()

func set_layers(_paths: Array) -> void:
	pass

func set_layer_visible(_i: int, _v: bool) -> void:
	pass

func play(name: String, speed: float = 8.0, looping: bool = true, restart: bool = false) -> void:
	anim = name
	for l in _layers.values():
		l.play(name, speed, looping, restart)

func set_progress(p: float) -> void:
	for l in _layers.values():
		l.set_progress(p)

func set_frame(f: int) -> void:
	for l in _layers.values():
		l.set_frame(f)

func get_frame() -> int:
	return _layers.values()[0].get_frame() if _layers.size() > 0 else 0

func frame_count() -> int:
	return _layers.values()[0].frame_count() if _layers.size() > 0 else 1

func set_dir(_d: int) -> void:
	pass

func _process(_delta: float) -> void:
	_sync()

## Same direction for every layer, and the stacking order of that direction
## (as child order, so the hero still y-sorts with the scenery).
var _row := -1

func _sync() -> void:
	var row := posmod(roundi(facing8.angle() / (PI / 4.0)), 8)
	for l in _layers.values():
		l.facing8 = facing8
	if row == _row:
		return
	_row = row
	var i := 0
	for slot in ORDER[row]:
		if _layers.has(slot):
			move_child(_layers[slot], i)
			i += 1
