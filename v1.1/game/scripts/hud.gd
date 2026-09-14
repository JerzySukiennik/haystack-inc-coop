# On-screen UI: crosshair, context prompt, throw charge, haystack counter, controls, pause menu and settings.
class_name Hud
extends CanvasLayer

signal resume_requested
signal sensitivity_changed(value: float)

const INK := Color(1.0, 0.98, 0.93)
const SHADOW := Color(0, 0, 0, 0.55)
const ACCENT := Color(0.98, 0.80, 0.36)
const PROMPTS := {
	"stack": "Hold LMB   Pull a straw",
	"piece": "LMB   Pick up",
	"holding": "Release LMB   Drop        Hold RMB   Throw        Wheel   Distance",
	"charging": "Release RMB   Throw",
	"pulling": "Keep holding LMB   Pulling…",
}

var _dot: Panel
var _prompt: Label
var _charge: ProgressBar
var _pull: ProgressBar
var _count: Label
var _pulled: Label
var _fps: Label
var _menu: Control
var _click: Label
var _sens: HSlider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_dot = Panel.new()
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color(1, 1, 1, 0.9)
	dot_style.set_corner_radius_all(8)
	dot_style.shadow_color = Color(0, 0, 0, 0.4)
	dot_style.shadow_size = 2
	_dot.add_theme_stylebox_override("panel", dot_style)
	_place(_dot, Control.PRESET_CENTER, Vector2(-3, -3), Vector2(6, 6))
	_dot.pivot_offset = _dot.size * 0.5
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dot)

	_prompt = _label(15)
	_place(_prompt, Control.PRESET_CENTER_BOTTOM, Vector2(-450, -52), Vector2(900, 24))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt)

	_charge = ProgressBar.new()
	_place(_charge, Control.PRESET_CENTER_BOTTOM, Vector2(-90, -68), Vector2(180, 6))
	_charge.show_percentage = false
	_charge.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(3)
	_charge.add_theme_stylebox_override("background", bg)
	_charge.add_theme_stylebox_override("fill", fill)
	_charge.visible = false
	root.add_child(_charge)

	_pull = ProgressBar.new()
	_place(_pull, Control.PRESET_CENTER_BOTTOM, Vector2(-90, -68), Vector2(180, 6))
	_pull.show_percentage = false
	_pull.max_value = 1.0
	var pfill := StyleBoxFlat.new()
	pfill.bg_color = Color(1.0, 0.95, 0.8)
	pfill.set_corner_radius_all(4)
	var pbg := bg.duplicate() as StyleBoxFlat
	pbg.set_corner_radius_all(4)
	_pull.add_theme_stylebox_override("background", pbg)
	_pull.add_theme_stylebox_override("fill", pfill)
	_pull.visible = false
	root.add_child(_pull)

	var box := VBoxContainer.new()
	box.position = Vector2(28, 22)
	box.add_theme_constant_override("separation", 2)
	root.add_child(box)
	var title := _label(14)
	title.text = "HAYSTACK INC."
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)
	_count = _label(30)
	box.add_child(_count)
	var sub := _label(15)
	sub.text = "straws left in the stack"
	sub.modulate.a = 0.8
	box.add_child(sub)
	_pulled = _label(15)
	_pulled.modulate.a = 0.8
	box.add_child(_pulled)

	_fps = _label(13)
	_place(_fps, Control.PRESET_TOP_RIGHT, Vector2(-124, 20), Vector2(96, 20))
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps.modulate.a = 0.6
	root.add_child(_fps)


	_click = _label(26)
	_place(_click, Control.PRESET_CENTER, Vector2(-300, -90), Vector2(600, 40))
	_click.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click.text = "Click to play"
	_click.visible = false
	root.add_child(_click)

	_build_menu(root)
	set_count(Haystack.START_COUNT)
	set_pulled(0)


func _place(c: Control, preset: Control.LayoutPreset, offset: Vector2, size: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_menu(root: Control) -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	root.add_child(_menu)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.02, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(shade)
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.13, 0.11, 0.08, 0.92)
	ps.set_corner_radius_all(14)
	ps.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", ps)
	panel.custom_minimum_size = Vector2(380, 0)
	_place(panel, Control.PRESET_CENTER, Vector2(-190, -170), Vector2(380, 340))
	_menu.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var title := _label(28)
	title.text = "Paused"
	col.add_child(title)
	var resume := _button("Resume")
	resume.pressed.connect(func() -> void: resume_requested.emit())
	col.add_child(resume)
	var sl := _label(15)
	sl.text = "Mouse sensitivity"
	col.add_child(sl)
	_sens = HSlider.new()
	_sens.min_value = 0.0006
	_sens.max_value = 0.006
	_sens.step = 0.0001
	_sens.value_changed.connect(func(v: float) -> void: sensitivity_changed.emit(v))
	col.add_child(_sens)
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.add_theme_font_size_override("font_size", 16)
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	col.add_child(fs)
	var quit := _button("Quit")
	quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quit)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.98, 0.80, 0.36)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.88, 0.52)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.15, 0.11, 0.05))
	b.add_theme_color_override("font_hover_color", Color(0.15, 0.11, 0.05))
	b.add_theme_color_override("font_pressed_color", Color(0.15, 0.11, 0.05))
	return b


func _process(_delta: float) -> void:
	_fps.text = "%d fps" % Engine.get_frames_per_second()


static func group_digits(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func set_count(n: int) -> void:
	_count.text = group_digits(n)
	_count.pivot_offset = Vector2(0, 20)
	var tw := create_tween()
	_count.scale = Vector2(1.06, 1.06)
	tw.tween_property(_count, "scale", Vector2.ONE, 0.15)


func set_pulled(n: int) -> void:
	_pulled.text = "you pulled %s" % group_digits(n)


func set_hover(kind: String) -> void:
	_prompt.text = PROMPTS.get(kind, "")
	_prompt.modulate.a = 0.0
	create_tween().tween_property(_prompt, "modulate:a", 0.9, 0.12)
	var big := kind in ["stack", "piece"]
	create_tween().tween_property(_dot, "scale", Vector2.ONE * (2.0 if big else 1.0), 0.1)


func set_pull(amount: float) -> void:
	_pull.visible = amount > 0.0
	_pull.value = amount


func set_charge(amount: float) -> void:
	_charge.visible = amount > 0.0
	_charge.value = amount


func set_menu(open: bool, sensitivity: float) -> void:
	_menu.visible = open
	_sens.set_value_no_signal(sensitivity)


func set_click_hint(show: bool) -> void:
	_click.visible = show
