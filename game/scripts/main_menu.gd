# Title menu over the live farm: name, play solo, host a room, join by code, settings and quit, with connection status.
class_name MainMenu
extends CanvasLayer

var main: Node
var _root: Control
var _name: LineEdit
var _code: LineEdit
var _status: Label
var _join_row: HBoxContainer
var _buttons: Array[Button] = []
var _card: PanelContainer


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ float x = UV.x; COLOR = vec4(0.07, 0.055, 0.035, mix(0.86, 0.0, smoothstep(0.18, 0.75, x))); }"
	sm.shader = sh
	shade.material = sm
	_root.add_child(shade)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	UI.place(col, Control.PRESET_CENTER_LEFT, Vector2(80, -330), Vector2(520, 660))
	_root.add_child(col)
	var eyebrow := UI.label("ONE NEEDLE  ·  A MILLION STRAWS", 15, Color(UI.CREAM, 0.7), UI.black())
	col.add_child(eyebrow)
	var title := UI.label("HAYSTACK", 104, UI.HAY, UI.stencil())
	title.add_theme_constant_override("line_spacing", -30)
	col.add_child(title)
	var inc := UI.label("INC.", 104, UI.CREAM, UI.stencil())
	inc.position.y = -40
	col.add_child(inc)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	col.add_child(spacer)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	col.add_child(name_row)
	var nl := UI.label("Your name", 16, UI.CREAM, UI.bold())
	nl.custom_minimum_size = Vector2(110, 0)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(nl)
	_name = _field("Farmer", 16)
	_name.text = _load_name()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_changed.connect(func(_t: String) -> void: _save_name())
	name_row.add_child(_name)

	var solo := _menu_button("Play solo", "primary")
	solo.pressed.connect(_play_solo)
	col.add_child(solo)
	var host := _menu_button("Host co-op", "secondary")
	host.pressed.connect(_host)
	col.add_child(host)
	var join := _menu_button("Join co-op", "secondary")
	join.pressed.connect(func() -> void:
		_join_row.visible = not _join_row.visible
		if _join_row.visible:
			_code.grab_focus())
	col.add_child(join)
	_join_row = HBoxContainer.new()
	_join_row.add_theme_constant_override("separation", 10)
	_join_row.visible = false
	col.add_child(_join_row)
	_code = _field("ROOM CODE", 22)
	_code.max_length = 5
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.add_theme_font_override("font", UI.mono())
	_code.text_changed.connect(func(t: String) -> void:
		var caret := _code.caret_column
		_code.text = t.to_upper()
		_code.caret_column = caret)
	_code.text_submitted.connect(func(_t: String) -> void: _join())
	_join_row.add_child(_code)
	var go := UI.button("Join", "primary", 18)
	go.custom_minimum_size = Vector2(110, 52)
	go.pressed.connect(_join)
	_join_row.add_child(go)
	var settings := _menu_button("Settings", "ghost")
	settings.pressed.connect(func() -> void: main.set_menu(true))
	col.add_child(settings)
	var quit := _menu_button("Quit", "ghost")
	quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quit)
	_status = UI.label("", 16, UI.CREAM, UI.bold())
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(500, 0)
	col.add_child(_status)

	var foot := UI.label("Co-op works over the internet with a 5-letter room code. No accounts, no install.", 13, Color(UI.CREAM, 0.55), UI.bold())
	UI.place(foot, Control.PRESET_BOTTOM_LEFT, Vector2(80, -48), Vector2(900, 22))
	_root.add_child(foot)
	Net.state_changed.connect(_on_net_state)
	solo.grab_focus()
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.4)


func _field(placeholder: String, size: int) -> LineEdit:
	var f := LineEdit.new()
	f.placeholder_text = placeholder
	f.custom_minimum_size = Vector2(0, 52)
	f.add_theme_font_override("font", UI.black())
	f.add_theme_font_size_override("font_size", size)
	f.add_theme_color_override("font_color", UI.INK)
	f.add_theme_color_override("font_placeholder_color", Color(UI.INK, 0.4))
	f.add_theme_color_override("caret_color", UI.BARN)
	var sb := UI.box(UI.CREAM, 12, UI.HAY_DEEP, 0, 12, 0)
	sb.border_width_bottom = 4
	sb.border_color = UI.CREAM_DIM.darkened(0.25)
	var focus := sb.duplicate() as StyleBoxFlat
	focus.border_color = UI.SKY
	focus.set_border_width_all(3)
	f.add_theme_stylebox_override("normal", sb)
	f.add_theme_stylebox_override("focus", focus)
	return f


func _menu_button(text: String, kind: String) -> Button:
	var b := UI.button(text, kind, 22)
	b.custom_minimum_size = Vector2(0, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_buttons.append(b)
	return b


func _load_name() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("user://profile.cfg") == OK:
		return str(cfg.get_value("player", "name", ""))
	return ""


func _save_name() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", _name.text.strip_edges())
	cfg.save("user://profile.cfg")


func _player_name() -> String:
	var n := _name.text.strip_edges()
	return n.substr(0, 16) if n != "" else "Farmer"


func _play_solo() -> void:
	Net.leave()
	main.close_menu()


func _host() -> void:
	Net.my_name = _player_name()
	var code := Net.host()
	if code == "":
		return
	main.close_menu()
	main.hud.toast("Room %s is open · friends join with this code" % code, "success")


func _join() -> void:
	var code := _code.text.strip_edges().to_upper()
	if code.length() != 5:
		_status.text = "Room codes have 5 characters."
		_status.add_theme_color_override("font_color", Color("ffb4a3"))
		return
	Net.my_name = _player_name()
	_status.text = "Looking for room %s…" % code
	_status.add_theme_color_override("font_color", UI.CREAM)
	Net.join(code)


func _on_net_state(state: String, detail: String) -> void:
	match state:
		"joining":
			_status.text = "Knocking on room %s…" % detail
		"connecting":
			_status.text = "Found the host, connecting…"
		"connected":
			_status.text = "Connected, loading the farm…"
		"failed":
			_status.text = detail
			_status.add_theme_color_override("font_color", Color("ffb4a3"))
