# Shared UI kit: farm palette, fonts, clay-style boxes and reusable widgets (keycaps, chips, buttons, prompt rows, sliders).
class_name UI
extends RefCounted

const INK := Color("1f1a14")
const INK_SOFT := Color("2d261d")
const CREAM := Color("f6ecd6")
const CREAM_DIM := Color("cfc2a6")
const HAY := Color("efb943")
const HAY_DEEP := Color("c98f1c")
const BARN := Color("c2462f")
const TRACTOR := Color("6fcf5c")
const SKY := Color("8cc4e8")
const SHADOW := Color(0, 0, 0, 0.45)

static var _body: FontVariation
static var _body_bold: FontVariation
static var _body_black: FontVariation
static var _stencil: FontFile
static var _mono: FontVariation
static var _theme: Theme


static func _variant(path: String, weight: int) -> FontVariation:
	var base := load(path) as FontFile
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return v


static func body() -> FontVariation:
	if _body == null:
		_body = _variant("res://assets/fonts/Nunito-Variable.ttf", 600)
	return _body


static func bold() -> FontVariation:
	if _body_bold == null:
		_body_bold = _variant("res://assets/fonts/Nunito-Variable.ttf", 800)
	return _body_bold


static func black() -> FontVariation:
	if _body_black == null:
		_body_black = _variant("res://assets/fonts/Nunito-Variable.ttf", 900)
	return _body_black


static func stencil() -> FontFile:
	if _stencil == null:
		_stencil = load("res://assets/fonts/SairaStencilOne-Regular.ttf")
	return _stencil


static func mono() -> FontVariation:
	if _mono == null:
		_mono = _variant("res://assets/fonts/JetBrainsMono-Variable.ttf", 500)
	return _mono


static func box(bg: Color, radius := 14, border := Color(0, 0, 0, 0), border_w := 0, pad := 14, shadow := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 6
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.set_content_margin_all(pad)
	if shadow > 0:
		sb.shadow_color = SHADOW
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.4)
	sb.anti_aliasing = true
	return sb


static func hud_box(pad := 12) -> StyleBoxFlat:
	var sb := box(Color(INK, 0.78), 16, Color(CREAM, 0.08), 2, pad, 10)
	return sb


static func label(text: String, size := 16, col := CREAM, font: Font = null, shadow := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else body())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if shadow:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_constant_override("shadow_outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func keycap(text: String, size := 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.set_corner_radius_all(7)
	sb.border_color = CREAM_DIM.darkened(0.25)
	sb.border_width_bottom = 3
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 1
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, size, INK, black(), false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func prompt_pair(key: String, action: String, action_col := CREAM) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in key.split("+"):
		h.add_child(keycap(k.strip_edges()))
	h.add_child(label(action, 17, action_col, bold()))
	return h


static func button(text: String, kind := "primary", size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_override("font", black())
	b.add_theme_font_size_override("font_size", size)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var base := HAY
	var ink := INK
	match kind:
		"secondary":
			base = CREAM
		"danger":
			base = Color("e9d3c8")
			ink = BARN.darkened(0.2)
		"ghost":
			base = Color(CREAM, 0.12)
			ink = CREAM
	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.set_corner_radius_all(14)
	normal.corner_detail = 6
	normal.border_color = base.darkened(0.28) if kind != "ghost" else Color(CREAM, 0.25)
	normal.border_width_bottom = 5 if kind != "ghost" else 2
	normal.border_width_top = 0 if kind != "ghost" else 2
	normal.border_width_left = 0 if kind != "ghost" else 2
	normal.border_width_right = 0 if kind != "ghost" else 2
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 6
	normal.content_margin_bottom = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base.lightened(0.12) if kind != "ghost" else Color(CREAM, 0.2)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_width_bottom = 1 if kind != "ghost" else 2
	pressed.content_margin_top = 10
	pressed.content_margin_bottom = 0
	pressed.bg_color = base.darkened(0.06) if kind != "ghost" else Color(CREAM, 0.08)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(16)
	focus.border_color = SKY
	focus.set_border_width_all(3)
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(CREAM_DIM, 0.55)
	disabled.border_color = Color(CREAM_DIM, 0.3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("disabled", disabled)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, ink)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.45))
	b.button_down.connect(func() -> void: Sfx.play_ui("ui_tap", -14.0))
	return b


static func money_chip(size := 22) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(INK, 0.82), 999, Color(TRACTOR, 0.35), 2, 0, 8)
	sb.content_margin_left = 8
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var coin := CoinIcon.new()
	coin.custom_minimum_size = Vector2(size + 4, size + 4)
	h.add_child(coin)
	var l := label("$0", size, Color("dff5cf"), black())
	l.name = "Amount"
	h.add_child(l)
	p.add_child(h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func slider(min_v: float, max_v: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.custom_minimum_size = Vector2(0, 28)
	s.focus_mode = Control.FOCUS_ALL
	var track := StyleBoxFlat.new()
	track.bg_color = Color(CREAM, 0.14)
	track.set_corner_radius_all(6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = HAY
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture(22, CREAM, HAY_DEEP)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", _knob_texture(24, Color.WHITE, HAY_DEEP))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = SKY
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(8)
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	s.add_theme_stylebox_override("focus", focus)
	return s


static func _knob_texture(size: int, fill: Color, ring: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var r := size * 0.5 - 1.0
			if d <= r:
				var col := fill if d < r - 3.0 else ring
				col.a = clampf(r - d + 0.5, 0.0, 1.0)
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func place(c: Control, preset: Control.LayoutPreset, offset: Vector2, size: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


static func pop(c: Control, amount := 1.12, time := 0.22) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * amount
	c.create_tween().tween_property(c, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
