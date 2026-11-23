extends Control
## Character creator: the hero turns on a plinth on the left, the choices
## are on the right. Keyboard/pad: up/down to pick a line, left/right to
## change it, Enter to start. Mouse: click the arrows.
## Test runs (--autotest=, --showcase=) go straight to the game.

const LINES := [
	["model", "Modèle"], ["body", "Corps"], ["head", "Tête"], ["helm", "Coiffe"], ["chest", "Torse"],
	["hands", "Mains"], ["legs", "Jambes"], ["feet", "Pieds"], ["weapon", "Arme"], ["shield", "Bouclier"],
	["tint", "Teinte d'armure"],
]
const FAMILY_TEXT := {
	"dagger": "Très rapide, dégâts faibles, fente en attaque lourde",
	"sword": "Équilibrée",
	"axe": "Coups puissants, un peu plus lents",
	"blunt": "Brise la garde et l'équilibre des ennemis",
	"great": "À deux mains : lente, dévastatrice, sans bouclier",
}
const ACCENT := Color(0.9, 0.78, 0.5)

var _preview: Node2D
var _preview_root: Node2D
var _rows := []  # [key, value label, row container]
var _sel := 0
var _turn_t := 0.0
var _dir := 2
var _info: Label
var _swing_t := 0.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--autotest=") or a.begins_with("--showcase="):
			get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")
			return
	Game.setup_inputs()
	HeroConfig.load_saved()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_preview()
	_build_panel()
	_refresh()

func _build_preview() -> void:
	var plinth := Node2D.new()
	plinth.position = Vector2(170, 250)
	plinth.draw.connect(func():
		plinth.draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.42))
		plinth.draw_circle(Vector2.ZERO, 90, Color(0.12, 0.1, 0.11))
		plinth.draw_arc(Vector2.ZERO, 90, 0, TAU, 64, Color(0.35, 0.28, 0.2), 3)
		plinth.draw_arc(Vector2.ZERO, 70, 0, TAU, 64, Color(0.22, 0.18, 0.15), 1.5))
	add_child(plinth)
	_preview_root = Node2D.new()
	_preview_root.position = Vector2(170, 252)
	_preview_root.scale = Vector2(2.2, 2.2)
	_preview_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # smoother when enlarged
	add_child(_preview_root)
	var title := Label.new()
	title.text = "Création du personnage"
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ACCENT)
	add_child(title)
	var hint := Label.new()
	hint.text = "Clic ou ↑↓ ←→ · Entrée : commencer · la tenue tourne toute seule"
	hint.position = Vector2(20, 338)
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.55, 0.52, 0.5))
	add_child(hint)

func _build_panel() -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(345, 30)
	panel.custom_minimum_size = Vector2(280, 0)
	panel.add_theme_constant_override("separation", 2)
	add_child(panel)
	for i in LINES.size():
		var key: String = LINES[i][0]
		if key == "model" and HeroConfig.options("model").size() < 2:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var name := Label.new()
		name.text = LINES[i][1]
		name.custom_minimum_size = Vector2(88, 0)
		name.add_theme_font_size_override("font_size", 9)
		row.add_child(name)
		var prev := _arrow("<", key, -1)
		row.add_child(prev)
		var value := Label.new()
		value.custom_minimum_size = Vector2(150, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 9)
		value.clip_text = true
		row.add_child(value)
		row.add_child(_arrow(">", key, 1))
		panel.add_child(row)
		_rows.append([key, value, row])
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 8)
	_info.add_theme_color_override("font_color", Color(0.75, 0.7, 0.62))
	_info.custom_minimum_size = Vector2(280, 22)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_info)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var rnd := Button.new()
	rnd.text = "Au hasard"
	rnd.add_theme_font_size_override("font_size", 10)
	rnd.focus_mode = Control.FOCUS_NONE
	rnd.pressed.connect(_randomize)
	buttons.add_child(rnd)
	var go := Button.new()
	go.text = "Commencer  ▶"
	go.add_theme_font_size_override("font_size", 12)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(_start)
	buttons.add_child(go)
	panel.add_child(buttons)

func _arrow(text: String, key: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(16, 0)
	b.add_theme_font_size_override("font_size", 9)
	b.pressed.connect(func():
		_sel = _row_index(key)
		_change(key, step))
	return b

func _row_index(key: String) -> int:
	for i in _rows.size():
		if _rows[i][0] == key:
			return i
	return 0

func _change(key: String, step: int) -> void:
	var opts: Array = HeroConfig.options(key)
	var i := opts.find(HeroConfig.data[key])
	HeroConfig.data[key] = opts[posmod(i + step, opts.size())]
	if key == "body":
		HeroConfig.data.head = HeroConfig.options("head")[0]
	_refresh()

func _randomize() -> void:
	for key in ["body", "head", "helm", "chest", "hands", "legs", "feet", "weapon", "shield", "tint"]:
		var opts: Array = HeroConfig.options(key)
		HeroConfig.data[key] = opts[randi() % opts.size()]
	HeroConfig.data.head = HeroConfig.options("head")[randi() % HeroConfig.options("head").size()]
	_refresh()

func _refresh() -> void:
	var knight: bool = HeroConfig.data.model == "hd_knight"
	for i in _rows.size():
		var key: String = _rows[i][0]
		_rows[i][1].text = HeroConfig.label(key, HeroConfig.data[key])
		var row: HBoxContainer = _rows[i][2]
		var greyed := knight and key != "model"
		row.modulate = Color(0.45, 0.45, 0.45) if greyed else (Color(1.15, 1.05, 0.85) if i == _sel else Color(0.85, 0.85, 0.85))
	var w: String = HeroConfig.data.weapon
	_info.text = "Chevalier HD : épée et bouclier, ses propres animations (roulade, blocage)." if knight \
		else "%s — %s" % [Weapons.DATA[w].name, FAMILY_TEXT[Weapons.DATA[w].family]]
	if _preview:
		_preview.queue_free()
	if knight:
		_preview = HdSprite.new()
	else:
		_preview = AvatarSprite.new()
		_preview.build(HeroConfig.data)
	_preview_root.add_child(_preview)
	_preview.play("idle", 2.0)
	_preview.facing8 = Vector2.RIGHT.rotated(_dir * PI / 4.0)

func _process(delta: float) -> void:
	if _preview == null:
		return
	_turn_t += delta
	_swing_t += delta
	if _turn_t > 1.4:
		_turn_t = 0.0
		_dir = (_dir + 1) % 8
		_preview.facing8 = Vector2.RIGHT.rotated(_dir * PI / 4.0)
	if _swing_t > 4.0:  # show the weapon now and then
		_swing_t = 0.0
		_preview.play("slash", 10.0, false, true)
		get_tree().create_timer(0.7).timeout.connect(func(): if is_instance_valid(_preview): _preview.play("idle", 2.0, true, true))

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_down"):
		_sel = (_sel + 1) % _rows.size()
		_refresh()
	elif e.is_action_pressed("ui_up"):
		_sel = posmod(_sel - 1, _rows.size())
		_refresh()
	elif e.is_action_pressed("ui_right"):
		_change(_rows[_sel][0], 1)
	elif e.is_action_pressed("ui_left"):
		_change(_rows[_sel][0], -1)
	elif e.is_action_pressed("ui_accept"):
		_start()

func _start() -> void:
	HeroConfig.save()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
