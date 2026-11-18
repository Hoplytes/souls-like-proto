class_name Prop
extends StaticBody2D
## A piece of scenery from assets/env/: the sprite stands on its origin so it
## y-sorts with the characters, with a small collision box at its base.

static var _cache := {}

const SOLID := {  # collision size at the base; missing = walk-through
	"tree_dead": Vector2(10, 6), "tree_pine_a": Vector2(12, 6), "tree_pine_b": Vector2(12, 6),
	"tree_pine_c": Vector2(12, 6), "tree_red_a": Vector2(12, 6), "tree_red_b": Vector2(12, 6),
	"tree_orange": Vector2(12, 6), "stump": Vector2(26, 8), "rock_big": Vector2(54, 16),
	"rock_wide": Vector2(52, 14), "rock_flat": Vector2(50, 10), "rock_low": Vector2(52, 10),
	"rock_mid": Vector2(26, 10), "rock_small": Vector2(22, 8), "pillar": Vector2(26, 10),
	"pillar_broken": Vector2(26, 10), "pillar_dark": Vector2(26, 10), "pillar_dark_broken": Vector2(26, 10),
	"marble_column": Vector2(26, 10), "marble_stump": Vector2(26, 10), "marble_stump_tall": Vector2(26, 10),
	"marble_fallen": Vector2(88, 12), "marble_drum": Vector2(28, 10),
}
const SWAY := ["grass_tall_a", "grass_tall_b", "grass_short_a", "grass_short_b", "fern"]

var kind := ""
var sprite: Sprite2D
var _phase := 0.0
var _t := 0.0

static func texture(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = load("res://assets/env/%s.png" % name)
	return _cache[name]

static func make(parent: Node, k: String, pos: Vector2, flip: bool = false) -> Prop:
	var p := Prop.new()
	p.kind = k
	p.position = pos
	p.collision_layer = 1 if SOLID.has(k) else 0
	p.sprite = Sprite2D.new()
	p.sprite.texture = texture(k)
	p.sprite.centered = false
	p.sprite.flip_h = flip
	var size := p.sprite.texture.get_size()
	p.sprite.offset = Vector2(-size.x / 2.0, -size.y + _foot(k))
	p.add_child(p.sprite)
	if SOLID.has(k):
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = SOLID[k]
		cs.shape = r
		cs.position = Vector2(0, -r.size.y / 2.0)
		p.add_child(cs)
	p._phase = pos.x * 0.05
	p.set_process(k in SWAY)
	parent.add_child(p)
	return p

## How far the drawn base sits above the bottom of the image (roots, etc).
static func _foot(k: String) -> float:
	if k.begins_with("tree_"):
		return 6.0
	if k.begins_with("rock_big"):
		return 4.0
	return 1.0

func _process(delta: float) -> void:
	_t += delta
	sprite.skew = sin(_t * 1.6 + _phase) * 0.06

func _draw() -> void:
	var w := 0.0
	if kind.begins_with("tree_"):
		w = 20.0
	elif kind.begins_with("rock") or kind.begins_with("pillar") or kind.begins_with("marble") or kind == "stump":
		w = sprite.texture.get_width() * 0.45
	if w > 0.0:
		draw_set_transform(Vector2(2, 0), 0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, w, Color(0.05, 0.03, 0.08, 0.35))
