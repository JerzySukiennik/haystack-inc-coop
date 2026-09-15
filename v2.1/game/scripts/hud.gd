# In-game HUD: stencil stack counter, money chip, crosshair rings, keycap prompts, hotbar, toasts and the pause/settings menu.
class_name Hud
extends CanvasLayer

signal resume_requested
signal sensitivity_changed(value: float)
signal fov_changed(value: float)
signal volume_changed(value: float)
signal leave_requested

const PROMPTS := {
	"stack": [["LMB", "Hold to pull a straw"]],
	"piece": [["LMB", "Pick up"]],
	"holding": [["LMB", "Release to drop"], ["RMB", "Hold to throw"], ["Wheel", "Distance"]],
	"charging": [["RMB", "Release to throw"]],
	"pulling": [["LMB", "Keep holding"]],
	"shop": [["E", "Open shop"]],
}

var _crosshair: Crosshair
var _prompt_row: HBoxContainer
var _warn: Label
var _money_chip: PanelContainer
var _money: Label
var _hotbar: HBoxContainer
var _hotbar_label: Label
var _icons: IconBaker
var _last_slots: Array = []
var _prompt_wrap: VBoxContainer
var _slot_key := ""
var _toasts: VBoxContainer
var _menu: Control
var _menu_card: PanelContainer
var _click: PanelContainer
var _sens: HSlider
var _sens_value: Label
var _fov: HSlider
var _fov_value: Label
var _vol: HSlider
var _vol_value: Label
var _resume: Button
var _room: Label
var _copy: Button
var _leave: Button
var _prompt_key := ""
var _last_money := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_crosshair = Crosshair.new()
	UI.place(_crosshair, Control.PRESET_CENTER, Vector2(-40, -40), Vector2(80, 80))
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)

	var top := CenterContainer.new()
	UI.place(top, Control.PRESET_TOP_WIDE, Vector2(0, 20), Vector2(0, 52))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_money_chip = UI.money_chip(34)
	top.add_child(_money_chip)
	_money = _money_chip.find_child("Amount", true, false) as Label


	_prompt_wrap = VBoxContainer.new()
	var prompt_wrap := _prompt_wrap
	prompt_wrap.alignment = BoxContainer.ALIGNMENT_END
	prompt_wrap.add_theme_constant_override("separation", 8)
	UI.place(prompt_wrap, Control.PRESET_CENTER_BOTTOM, Vector2(-600, -120), Vector2(1200, 96))
	prompt_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_wrap)
	_warn = UI.label("", 15, Color("ffb4a3"), UI.black())
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_wrap.add_child(_warn)
	var row_center := CenterContainer.new()
	row_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_wrap.add_child(row_center)
	_prompt_row = HBoxContainer.new()
	_prompt_row.add_theme_constant_override("separation", 26)
	_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_center.add_child(_prompt_row)

	_hotbar = HBoxContainer.new()
	_hotbar.add_theme_constant_override("separation", 8)
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.place(_hotbar, Control.PRESET_CENTER_BOTTOM, Vector2(-450, -104), Vector2(900, 86))
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hotbar)
	_hotbar_label = UI.label("", 15, UI.CREAM, UI.black())
	_hotbar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.place(_hotbar_label, Control.PRESET_CENTER_BOTTOM, Vector2(-450, -134), Vector2(900, 24))
	root.add_child(_hotbar_label)
	_icons = IconBaker.new()
	add_child(_icons)
	_icons.baked.connect(func(_id: String, _t: Texture2D) -> void:
		if not _last_slots.is_empty():
			set_hotbar(_last_slots, true))

	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 30
	add_child(toast_layer)
	var toast_root := Control.new()
	toast_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.add_child(toast_root)
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 8)
	UI.place(_toasts, Control.PRESET_CENTER_TOP, Vector2(-300, 88), Vector2(600, 260))
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_root.add_child(_toasts)

	_click = PanelContainer.new()
	_click.add_theme_stylebox_override("panel", UI.hud_box(16))
	UI.place(_click, Control.PRESET_CENTER, Vector2(-150, -110), Vector2(300, 56))
	var ch := HBoxContainer.new()
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_theme_constant_override("separation", 10)
	ch.add_child(UI.keycap("LMB"))
	ch.add_child(UI.label("Click to continue", 17, UI.CREAM, UI.black()))
	_click.add_child(ch)
	_click.visible = false
	_click.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_click)

	_build_menu(root)
	set_count(Haystack.START_COUNT)
	set_pulled(0)
	set_money(0)


func _setting_row(parent: Container, title: String, s: HSlider) -> Label:
	var head := HBoxContainer.new()
	var t := UI.label(title, 15, UI.CREAM, UI.bold(), false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var v := UI.label("", 15, UI.HAY, UI.black(), false)
	head.add_child(v)
	parent.add_child(head)
	parent.add_child(s)
	return v


func _build_menu(root: Control) -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	root.add_child(_menu)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.05, 0.03, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	_menu_card = PanelContainer.new()
	_menu_card.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.96), 24, Color(UI.CREAM, 0.1), 2, 30, 24))
	_menu_card.custom_minimum_size = Vector2(440, 0)
	center.add_child(_menu_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_menu_card.add_child(col)
	var head := HBoxContainer.new()
	var title := UI.label("Paused", 34, UI.CREAM, UI.black(), false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.prompt_pair("Esc", "Back", Color(UI.CREAM, 0.6)))
	col.add_child(head)
	_room = UI.label("", 16, UI.HAY, UI.black(), false)
	col.add_child(_room)
	_copy = UI.button("Copy room code", "ghost", 15)
	_copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(Net.code)
		toast("Copied %s" % Net.code, "info"))
	col.add_child(_copy)
	_resume = UI.button("Resume")
	_resume.pressed.connect(func() -> void: resume_requested.emit())
	col.add_child(_resume)
	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(UI.CREAM, 0.1)
	line.thickness = 2
	sep.add_theme_stylebox_override("separator", line)
	col.add_child(sep)
	col.add_child(UI.label("SETTINGS", 12, Color(UI.CREAM, 0.5), UI.black(), false))
	_sens = UI.slider(0.001, 0.012, 0.0001)
	_sens_value = _setting_row(col, "Mouse sensitivity", _sens)
	_sens.value_changed.connect(func(v: float) -> void:
		_sens_value.text = "%.1f" % (v * 1000.0)
		sensitivity_changed.emit(v))
	_fov = UI.slider(60, 110, 1)
	_fov_value = _setting_row(col, "Field of view", _fov)
	_fov.value_changed.connect(func(v: float) -> void:
		_fov_value.text = "%d°" % int(v)
		fov_changed.emit(v))
	_vol = UI.slider(0, 100, 1)
	_vol_value = _setting_row(col, "Volume", _vol)
	_vol.value_changed.connect(func(v: float) -> void:
		_vol_value.text = "%d%%" % int(v)
		volume_changed.emit(v))
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.focus_mode = Control.FOCUS_ALL
	fs.add_theme_font_override("font", UI.bold())
	fs.add_theme_font_size_override("font_size", 15)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		fs.add_theme_color_override(key, UI.CREAM)
	fs.add_theme_stylebox_override("focus", UI.box(Color(0, 0, 0, 0), 10, UI.SKY, 2, 0, 0))
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	col.add_child(fs)
	_leave = UI.button("Leave to title screen", "secondary", 16)
	_leave.pressed.connect(func() -> void: leave_requested.emit())
	col.add_child(_leave)
	var quit := UI.button("Quit to desktop", "danger", 16)
	quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quit)


static func group_digits(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func set_count(_n: int) -> void:
	pass


func set_pulled(_n: int) -> void:
	pass


func set_money(n: int) -> void:
	_money.text = "$%s" % group_digits(n)
	if n != _last_money and is_inside_tree():
		UI.pop(_money_chip, 1.08 if n > _last_money else 0.94, 0.25)
	_last_money = n


func set_prompt(spec: Array, interact: bool, warn := "") -> void:
	_crosshair.interact = interact
	_crosshair.warn = warn != ""
	var key := str(spec) + warn
	if key == _prompt_key:
		return
	_prompt_key = key
	_warn.text = warn
	for c in _prompt_row.get_children():
		c.queue_free()
	for pair in spec:
		_prompt_row.add_child(UI.prompt_pair(pair[0], pair[1]))
	_prompt_row.modulate.a = 0.0
	create_tween().tween_property(_prompt_row, "modulate:a", 1.0, 0.12)


func set_inventory(_has_remote: bool, _meters: int, _equipped: bool) -> void:
	pass


func set_hotbar(slots: Array, force := false) -> void:
	_last_slots = slots
	var lift := 0.0 if slots.is_empty() else 118.0
	_prompt_wrap.offset_top = -120 - lift
	_prompt_wrap.offset_bottom = -24 - lift
	var key := ""
	var active_text := ""
	for sl in slots:
		key += "%s:%s;" % [sl.id, sl.active]
		if sl.active:
			active_text = "%s  ·  %s" % [sl.name, sl.info] if sl.info != "" else sl.name
	_hotbar_label.text = active_text
	if key == _slot_key and not force:
		for c in _hotbar.get_children():
			var info := c.find_child("Info", true, false) as Label
			if info:
				for sl in slots:
					if sl.id == c.name:
						info.text = sl.info
		return
	_slot_key = key
	for c in _hotbar.get_children():
		c.queue_free()
	for sl in slots:
		var card := PanelContainer.new()
		card.name = sl.id
		var sb := UI.hud_box(0)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 6
		sb.content_margin_bottom = 4
		if sl.active:
			sb.border_color = UI.HAY
			sb.set_border_width_all(3)
			sb.bg_color = Color(UI.INK_SOFT, 0.92)
		card.add_theme_stylebox_override("panel", sb)
		card.custom_minimum_size = Vector2(74, 74)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stack := Control.new()
		stack.custom_minimum_size = Vector2(62, 62)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(stack)
		var tex := _icons.get_icon(sl.id)
		if tex:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2(2, 2)
			icon.size = Vector2(60, 60)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.add_child(icon)
		var kc := UI.keycap(str(sl.slot), 12)
		kc.position = Vector2(-2, -4)
		stack.add_child(kc)
		_hotbar.add_child(card)
		if sl.active:
			UI.pop(card, 1.08, 0.2)


func set_charge(amount: float) -> void:
	_crosshair.charge = amount


func set_pull(amount: float) -> void:
	_crosshair.progress = amount


func toast(text: String, kind := "info") -> void:
	var p := PanelContainer.new()
	var accents := {"info": UI.SKY, "success": UI.TRACTOR, "error": UI.BARN, "money": UI.HAY}
	var accent: Color = accents.get(kind, UI.SKY)
	var sb := UI.hud_box(0)
	sb.content_margin_left = 16
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_color = accent
	sb.border_width_left = 6
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_child(UI.label(text, 16, UI.CREAM, UI.black(), false))
	_toasts.add_child(p)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.16)
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


func set_menu(open: bool, sensitivity: float, fov := 78.0, volume := 80.0, room := "", in_game := true) -> void:
	_menu.visible = open
	if open:
		_room.text = room
		_room.visible = room != ""
		_copy.visible = room != ""
		_leave.visible = in_game
		_resume.text = "Resume" if in_game else "Back"
		_sens.set_value_no_signal(sensitivity)
		_sens_value.text = "%.1f" % (sensitivity * 1000.0)
		_fov.set_value_no_signal(fov)
		_fov_value.text = "%d°" % int(fov)
		_vol.set_value_no_signal(volume)
		_vol_value.text = "%d%%" % int(volume)
		_resume.grab_focus()
		_menu_card.pivot_offset = _menu_card.size * 0.5
		_menu_card.scale = Vector2.ONE * 0.96
		_menu_card.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_menu_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_menu_card, "modulate:a", 1.0, 0.14)


func set_click_hint(show: bool) -> void:
	_click.visible = show
