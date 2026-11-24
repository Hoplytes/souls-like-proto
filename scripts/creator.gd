extends Control
## Character creator: the hero stands on a plinth on the left, with 8 arrows
## around it to look at him from any side (or LB / RB); the choices
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
var _dir := 2
var _arrows: Array[Control] = []
const PLINTH := Vector2(170, 250)
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
	for k in 8:  # over the hero, so the north arrow stays clickable
		_arrows.append(_make_dir_arrow(k))
	var title := Label.new()
	title.text = "Création du personnage"
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ACCENT)
	add_child(title)
	var hint := Label.new()
	hint.text = "Clic ou ↑↓ ←→ · Entrée : commencer · flèches autour du héros (ou LB / RB) : le tourner"
	hint.position = Vector2(20, 338)
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.55, 0.52, 0.5))
	add_child(hint)

## A clickable arrow on the plinth's rim: turns the hero to face that way.
func _make_dir_arrow(k: int) -> Control:
	var a := k * PI / 4.0
	var dir := Vector2.RIGHT.rotated(a)
	var c := Control.new()
	c.size = Vector2(22, 22)
	c.position = PLINTH + Vector2(dir.x * 112.0, dir.y * 50.0) - c.size / 2.0
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.tooltip_text = ["Est", "Sud-est", "Sud", "Sud-ouest", "Ouest", "Nord-ouest", "Nord", "Nord-est"][k]
	c.draw.connect(func():
		var on := k == _dir
		var hover := c.get_global_rect().has_point(c.get_global_mouse_position())
		var col := ACCENT if on else (Color(0.85, 0.78, 0.65) if hover else Color(0.45, 0.4, 0.34))
		var m := c.size / 2.0
		var d := Vector2(dir.x, dir.y * 0.6).normalized()  # flattened like the plinth
		var side := d.orthogonal()
		var pts := PackedVector2Array([m + d * 8.0, m - d * 5.0 + side * 6.0, m - d * 2.0, m - d * 5.0 - side * 6.0])
		if on:
			c.draw_circle(m, 10.0, Color(ACCENT, 0.15))
		c.draw_colored_polygon(pts, col))
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_face(k))
	c.mouse_entered.connect(c.queue_redraw)
	c.mouse_exited.connect(c.queue_redraw)
	add_child(c)
	return c

func _face(k: int) -> void:
	_dir = posmod(k, 8)
	if _preview:
		_preview.facing8 = Vector2.RIGHT.rotated(_dir * PI / 4.0)
	for arrow in _arrows:
		arrow.queue_redraw()

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
	_info.custom_minimum_size = Vector2(280, 32)
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

const LOAD_TEXT := {
	"light": ["légère", "rapide et longue"],
	"medium": ["moyenne", "normale"],
	"heavy": ["lourde", "courte, avec une longue reprise d'appui"],
}

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
		else "%s — %s\nArmure %s : roulade %s" % [Weapons.DATA[w].name, FAMILY_TEXT[Weapons.DATA[w].family],
			LOAD_TEXT[Player.load_class(HeroConfig.data)][0], LOAD_TEXT[Player.load_class(HeroConfig.data)][1]]
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
	_swing_t += delta
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
	elif e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_LEFT_SHOULDER:
		_face(_dir - 1)
	elif e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_RIGHT_SHOULDER:
		_face(_dir + 1)

func _start() -> void:
	HeroConfig.save()
	# The world takes a moment to build: say so before the screen freezes.
	var cover := ColorRect.new()
	cover.color = Color(0.03, 0.025, 0.04)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var l := Label.new()
	l.text = "Chargement du monde…"
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", ACCENT)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	cover.add_child(l)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/game.tscn")
