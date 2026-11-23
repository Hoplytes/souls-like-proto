class_name GameMenu
extends CanvasLayer
## A small menu over the paused game: a title and a list of buttons, used by
## the pause menu and the teleport menu. Mouse, keyboard (arrows + Enter, or
## the number of an entry) and gamepad (cross + A, B to go back).
## The menu keeps running while the game is paused.

signal closed

var _buttons: Array[Button] = []
var _actions: Array[Callable] = []

## items: [[text, callable], ...]; an empty text adds a gap.
static func open(parent: Node, title: String, items: Array, footer: String = "") -> GameMenu:
	var m := GameMenu.new()
	m.layer = 10
	m.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(m)
	m._build(title, items, footer)
	return m

func _build(title: String, items: Array, footer: String) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.04, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.075, 0.06, 0.96)
	style.border_color = Color(0.62, 0.45, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(230, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", Color(0.92, 0.78, 0.55))
	box.add_child(t)
	var n := 0
	for it in items:
		if it[0] == "":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 4)
			box.add_child(gap)
			continue
		n += 1
		var b := Button.new()
		b.text = "%d · %s" % [n, it[0]] if n <= 9 else it[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(_pick.bind(_buttons.size()))
		box.add_child(b)
		_buttons.append(b)
		_actions.append(it[1])
	if footer != "":
		var f := Label.new()
		f.text = footer
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.add_theme_font_size_override("font_size", 7)
		f.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
		box.add_child(f)
	if not _buttons.is_empty():
		_buttons[0].grab_focus.call_deferred()

func _pick(k: int) -> void:
	_actions[k].call()

func close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var n: int = e.physical_keycode - KEY_1
		if n >= 0 and n < mini(9, _buttons.size()):
			get_viewport().set_input_as_handled()
			_pick(n)
			return
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause") \
			or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_B):
		get_viewport().set_input_as_handled()
		close()
