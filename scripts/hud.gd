extends Control
## Health, stamina, flasks, souls, weapon, boss bar, on-screen messages and
## the death screen.

var player: Player
var boss: Boss
var show_boss := false
var hint := ""
var message := ""
var message_color := Color.WHITE
var sub_message := ""
var show_help := true
## Black over the whole screen (0..1), for the transitions.
var fade := 0.0
var _msg_t := 0.0
var _msg_id := 0
var _souls_shown := 0.0
var _gain := 0
var _gain_t := 9.0
var _death_t := -1.0
var _death_text := ""
var _t := 0.0

const HELP := [
	"ZQSD / WASD / flèches : se déplacer",
	"Espace : roulade (sans direction : pas en arrière)",
	"  maintenir Espace en marchant : courir",
	"J / clic gauche : attaque légère (combo x3)",
	"K / clic droit : attaque lourde",
	"L ou Maj (maintenir) : bouclier",
	"  lever le bouclier au moment du coup = parade",
	"  attaque légère dans le dos / après parade = critique",
	"R : boire une fiole",
	"I / clic molette : verrouiller   U / O : changer de cible",
	"E : interagir (feu, objets, coffres, brouillard)",
	"H : aide   M : son   N : type de sons",
	"Échap : pause   Tab : carte   T : téléportation (test)",
	"Manette : A/B/X/Y, LB bouclier, LT fiole, RB/RT attaques,",
	"  Start pause, Select carte, R3 verrouiller",
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_souls_shown = float(Progress.data.get("souls", 0))

func flash_message(text: String, col: Color, sub: String = "") -> void:
	message = text
	message_color = col
	sub_message = sub
	_msg_t = 0.0
	_msg_id += 1

## A message that goes away on its own after `duration` seconds.
func announce(text: String, col: Color, sub: String = "", duration: float = 2.5) -> void:
	flash_message(text, col, sub)
	var id := _msg_id
	get_tree().create_timer(duration, true).timeout.connect(func():
		if _msg_id == id:
			message = "")

## Souls just earned: the counter rolls up and shows the gain above it.
func souls_gained(n: int) -> void:
	_gain = (_gain if _gain_t < 2.0 else 0) + n
	_gain_t = 0.0

## The Souls' death screen: a dark band and the big red words, then black.
func death_screen(text: String = "VOUS ÊTES MORT") -> void:
	_death_t = 0.0
	_death_text = text
	message = ""
	hint = ""

func _process(delta: float) -> void:
	_msg_t += delta
	_t += delta
	_gain_t += delta
	if _death_t >= 0.0:
		_death_t += delta
	var souls := float(Progress.data.get("souls", 0))
	if _gain_t > 0.6:  # the gain shows first, then rolls into the counter
		_souls_shown = move_toward(_souls_shown, souls, maxf(60.0, absf(souls - _souls_shown) * 3.0) * delta)
	if souls < _souls_shown and _gain_t > 0.6 and souls == 0:
		_souls_shown = 0.0
	queue_redraw()

func _bar(pos: Vector2, w: float, h: float, ratio: float, col: Color, lag: float = -1.0) -> void:
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.12, 0.1, 0.1))
	if lag > ratio:
		draw_rect(Rect2(pos, Vector2(w * clampf(lag, 0, 1), h)), Color(0.85, 0.7, 0.35))
	draw_rect(Rect2(pos, Vector2(w * clampf(ratio, 0, 1), h)), col)
	draw_rect(Rect2(pos, Vector2(w * clampf(ratio, 0, 1), 1)), col.lightened(0.3))

func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := get_theme_default_font()
	draw_string_outline(f, pos, s, align, width, size, 3, Color(0, 0, 0, col.a))
	draw_string(f, pos, s, align, width, size, col)

var _hp_lag := 1.0

func _draw() -> void:
	if player == null:
		return
	var vw := get_viewport_rect().size.x
	var vh := get_viewport_rect().size.y
	var ratio := float(player.hp) / player.max_hp
	_hp_lag = maxf(ratio, move_toward(_hp_lag, ratio, get_process_delta_time() * 0.6))
	# Low health: the screen's edges throb red.
	if ratio < 0.3 and not player.dead:
		var a := (0.3 - ratio) / 0.3 * (0.18 + 0.1 * sin(_t * 6.0))
		for k in 6:
			var m := float(k) * 6.0
			draw_rect(Rect2(m, m, vw - m * 2.0, vh - m * 2.0), Color(0.6, 0.0, 0.0, a * (1.0 - k / 6.0)), false, 6.0)
	# The bars grow with the levels (as in the Souls), up to a limit.
	_bar(Vector2(10, 10), minf(player.max_hp * 1.3, vw * 0.45), 6, ratio, Color(0.7, 0.12, 0.1), _hp_lag)
	_bar(Vector2(10, 20), minf(player.max_stamina * 1.1, vw * 0.4), 4, player.stamina / player.max_stamina,
		Color(0.25, 0.6, 0.3))
	for i in player.max_flasks:
		var p := Vector2(14 + i * 10, 36)
		var c := Color(1, 0.6, 0.2) if i < player.flasks else Color(0.25, 0.22, 0.2)
		draw_rect(Rect2(p + Vector2(-1, -9), Vector2(3, 3)), Color(0.5, 0.4, 0.3))
		draw_circle(p, 3.5, c)
	# Souls, bottom right, in a dark box.
	var box := Rect2(vw - 96, vh - 34, 86, 16)
	draw_rect(box, Color(0, 0, 0, 0.55))
	draw_rect(box, Color(0.55, 0.45, 0.3, 0.6), false, 1.0)
	draw_circle(box.position + Vector2(9, 8), 3.5, Color(0.75, 0.85, 1.0, 0.35))
	draw_circle(box.position + Vector2(9, 8), 2.0, Color(0.9, 0.95, 1.0))
	_text(Vector2(box.position.x, box.position.y + 12), str(int(round(_souls_shown))), 10, Color(0.95, 0.92, 0.85),
		HORIZONTAL_ALIGNMENT_RIGHT, box.size.x - 6)
	if _gain_t < 2.2 and _gain > 0:
		var ga := clampf(2.2 - _gain_t, 0.0, 1.0)
		_text(Vector2(box.position.x, box.position.y - 3), "+%d" % _gain, 9, Color(0.85, 0.9, 1.0, ga),
			HORIZONTAL_ALIGNMENT_RIGHT, box.size.x - 6)
	_text(Vector2(vw - 70, vh - 6), "version " + BuildInfo.VERSION, 7, Color(0.7, 0.7, 0.7, 0.6))
	_text(Vector2(10, vh - 10), "Arme : " + Weapons.DATA[player.weapon].name, 8, Color(0.85, 0.8, 0.65))
	if show_boss and boss and is_instance_valid(boss) and _death_t < 0.0:
		var w := 360.0
		var x := (vw - w) / 2
		_text(Vector2(x, vh - 30), boss.boss_name, 10, Color(0.9, 0.85, 0.75))
		_bar(Vector2(x, vh - 24), w, 5, float(boss.hp) / boss.max_hp, Color(0.65, 0.1, 0.08))
	if hint != "" and _death_t < 0.0:
		_text(Vector2(0, vh * 0.68), hint, 9, Color(1, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER, vw)
	if show_help:
		draw_rect(Rect2(vw - 232, 8, 224, 12 + HELP.size() * 11), Color(0, 0, 0, 0.55))
		for i in HELP.size():
			_text(Vector2(vw - 226, 20 + i * 11), HELP[i], 8, Color(0.85, 0.85, 0.85))
	if message != "":
		var a := clampf(_msg_t * 1.5, 0, 1)
		draw_rect(Rect2(0, vh * 0.38, vw, 56), Color(0, 0, 0, 0.6 * a))
		_text(Vector2(0, vh * 0.38 + 34), message, 24, Color(message_color, a), HORIZONTAL_ALIGNMENT_CENTER, vw)
		if sub_message != "":
			_text(Vector2(0, vh * 0.38 + 50), sub_message, 8, Color(0.8, 0.8, 0.8, a), HORIZONTAL_ALIGNMENT_CENTER, vw)
	if _death_t >= 0.0:
		_draw_death(vw, vh)
	if fade > 0.0:
		draw_rect(Rect2(0, 0, vw, vh), Color(0, 0, 0, fade))

func _draw_death(vw: float, vh: float) -> void:
	var a := clampf((_death_t - 0.4) / 1.6, 0.0, 1.0)
	var band := vh * 0.42
	draw_rect(Rect2(0, 0, vw, vh), Color(0, 0, 0, 0.25 * a))
	# The band fades softly into the picture at its top and bottom.
	for k in 8:
		var h := 70.0 - k * 6.0
		draw_rect(Rect2(0, band + 20 - h / 2.0, vw, h), Color(0, 0, 0, 0.12 * a))
	var size := int(round(30.0 + 3.0 * minf(_death_t / 5.0, 1.0)))
	var f := get_theme_default_font()
	var col := Color(0.62, 0.05, 0.04, a)
	var spaced := " ".join(_death_text.split(""))
	draw_string(f, Vector2(0, band + 31), spaced, HORIZONTAL_ALIGNMENT_CENTER, vw, size, Color(0.25, 0.0, 0.0, a * 0.6))
	draw_string(f, Vector2(0, band + 30), spaced, HORIZONTAL_ALIGNMENT_CENTER, vw, size, col)
