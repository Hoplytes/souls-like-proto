extends Control
## Title screen: pick the top-down prototype or the isometric one.
## Command-line test runs (--autotest=, --showcase=) skip it; add --iso to
## test the isometric level.

const TOPDOWN := "res://scenes/main.tscn"
const ISO := "res://scenes/iso.tscn"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--autotest=") or a.begins_with("--showcase="):
			get_tree().change_scene_to_file.call_deferred(ISO if "--iso" in args else TOPDOWN)
			return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(300, 0)
	center.add_child(box)
	var title := Label.new()
	title.text = "Souls-like Proto"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Choisis un prototype"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color(0.65, 0.62, 0.6))
	box.add_child(sub)
	var b1 := _button("1 · Vue de dessus (temple grec)", TOPDOWN)
	box.add_child(b1)
	box.add_child(_button("2 · Isométrique (donjon)", ISO))
	var hint := Label.new()
	hint.text = "Échap en jeu : revenir ici"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	box.add_child(hint)
	b1.grab_focus()

func _button(text: String, scene: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(func(): get_tree().change_scene_to_file(scene))
	return b

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.physical_keycode == KEY_1:
			get_tree().change_scene_to_file(TOPDOWN)
		elif e.physical_keycode == KEY_2:
			get_tree().change_scene_to_file(ISO)
