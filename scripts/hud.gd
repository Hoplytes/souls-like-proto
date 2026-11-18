extends Control
## Health, stamina, flasks, weapon, boss bar and on-screen messages.

var player: Player
var boss: Boss
var show_boss := false
var hint := ""
var message := ""
var message_color := Color.WHITE
var sub_message := ""
var show_help := true
var _msg_t := 0.0

const HELP := [
	"ZQSD / WASD / flèches : se déplacer",
	"Espace : roulade (invincible)",
	"J / clic gauche : attaque légère (combo x3)",
	"K / clic droit : attaque lourde",
	"L ou Maj (maintenir) : bouclier",
	"  lever le bouclier au moment du coup = parade",
	"R : boire une fiole    Tab : changer d'arme",
	"E : feu de camp   H : aide   M : son   N : type de sons",
	"Manette : A/B/X/Y, LB bouclier, LT fiole, RB/RT attaques",
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func flash_message(text: String, col: Color, sub: String = "") -> void:
	message = text
	message_color = col
	sub_message = sub
	_msg_t = 0.0

func _process(delta: float) -> void:
	_msg_t += delta
	queue_redraw()

func _bar(pos: Vector2, w: float, h: float, ratio: float, col: Color) -> void:
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.12, 0.1, 0.1))
	draw_rect(Rect2(pos, Vector2(w * clampf(ratio, 0, 1), h)), col)
	draw_rect(Rect2(pos, Vector2(w * clampf(ratio, 0, 1), 1)), col.lightened(0.3))

func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := get_theme_default_font()
	draw_string_outline(f, pos, s, align, width, size, 3, Color(0, 0, 0, col.a))
	draw_string(f, pos, s, align, width, size, col)

func _draw() -> void:
	if player == null:
		return
	var vw := get_viewport_rect().size.x
	var vh := get_viewport_rect().size.y
	_bar(Vector2(10, 10), player.max_hp * 1.3, 6, float(player.hp) / player.max_hp, Color(0.7, 0.12, 0.1))
	_bar(Vector2(10, 20), player.max_stamina * 1.1, 4, player.stamina / player.max_stamina, Color(0.25, 0.6, 0.3))
	for i in player.max_flasks:
		var p := Vector2(14 + i * 10, 36)
		var c := Color(1, 0.6, 0.2) if i < player.flasks else Color(0.25, 0.22, 0.2)
		draw_rect(Rect2(p + Vector2(-1, -9), Vector2(3, 3)), Color(0.5, 0.4, 0.3))
		draw_circle(p, 3.5, c)
	_text(Vector2(10, vh - 10), "Arme : " + Weapons.DATA[player.weapon].name + "   [Tab]", 8, Color(0.85, 0.8, 0.65))
	if show_boss and boss:
		var w := 360.0
		var x := (vw - w) / 2
		_text(Vector2(x, vh - 30), Boss.BOSS_NAME, 10, Color(0.9, 0.85, 0.75))
		_bar(Vector2(x, vh - 24), w, 5, float(boss.hp) / boss.max_hp, Color(0.65, 0.1, 0.08))
	if hint != "":
		_text(Vector2(0, vh * 0.68), hint, 9, Color(1, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER, vw)
	if show_help:
		draw_rect(Rect2(vw - 212, 8, 204, 12 + HELP.size() * 11), Color(0, 0, 0, 0.55))
		for i in HELP.size():
			_text(Vector2(vw - 206, 20 + i * 11), HELP[i], 8, Color(0.85, 0.85, 0.85))
	if message != "":
		var a := clampf(_msg_t * 1.5, 0, 1)
		draw_rect(Rect2(0, vh * 0.38, vw, 56), Color(0, 0, 0, 0.6 * a))
		_text(Vector2(0, vh * 0.38 + 34), message, 24, Color(message_color, a), HORIZONTAL_ALIGNMENT_CENTER, vw)
		if sub_message != "":
			_text(Vector2(0, vh * 0.38 + 50), sub_message, 8, Color(0.8, 0.8, 0.8, a), HORIZONTAL_ALIGNMENT_CENTER, vw)
