# Win screen shown when the needle is sold: stencil headline, run stats, confetti and a keep-playing button.
class_name WinScreen
extends CanvasLayer

signal keep_playing

var is_open := false
var _root: Control
var _card: PanelContainer
var _stats: GridContainer
var _confetti: CPUParticles2D
var _keep: Button


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec2 d = UV - vec2(0.5, 0.42); float r = length(d * vec2(1.6, 1.0)); vec3 warm = mix(vec3(0.94, 0.72, 0.26), vec3(0.08, 0.06, 0.03), smoothstep(0.0, 0.75, r)); COLOR = vec4(warm, 0.88); }"
	sm.shader = sh
	shade.material = sm
	_root.add_child(shade)

	_confetti = CPUParticles2D.new()
	_confetti.amount = 160
	_confetti.lifetime = 4.5
	_confetti.one_shot = false
	_confetti.emitting = false
	_confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_confetti.direction = Vector2(0, 1)
	_confetti.spread = 25.0
	_confetti.gravity = Vector2(0, 160)
	_confetti.initial_velocity_min = 60.0
	_confetti.initial_velocity_max = 180.0
	_confetti.angular_velocity_min = -360.0
	_confetti.angular_velocity_max = 360.0
	_confetti.scale_amount_min = 5.0
	_confetti.scale_amount_max = 11.0
	var ramp := Gradient.new()
	ramp.set_color(0, UI.HAY)
	ramp.add_point(0.33, UI.CREAM)
	ramp.add_point(0.66, UI.BARN)
	ramp.set_color(ramp.get_point_count() - 1, UI.TRACTOR)
	_confetti.color_initial_ramp = ramp
	_root.add_child(_confetti)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	var eyebrow := UI.label("ONE NEEDLE  ·  ONE MILLION STRAWS", 16, Color(UI.INK, 0.75), UI.black(), false)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(eyebrow)
	var headline := UI.label("FOUND IT", 132, UI.INK, UI.stencil(), false)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.name = "Headline"
	col.add_child(headline)
	var sub := UI.label("The needle went through the sell machine. The farm is yours to keep running.", 20, Color(UI.CREAM, 0.95), UI.bold())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.92), 22, Color(UI.HAY, 0.6), 2, 26, 20))
	_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 18)
	_card.add_child(inner)
	_stats = GridContainer.new()
	_stats.columns = 4
	_stats.add_theme_constant_override("h_separation", 36)
	_stats.add_theme_constant_override("v_separation", 2)
	inner.add_child(_stats)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	inner.add_child(buttons)
	_keep = UI.button("Keep playing", "primary", 20)
	_keep.custom_minimum_size = Vector2(240, 56)
	_keep.pressed.connect(close)
	buttons.add_child(_keep)
	var quit := UI.button("Quit to desktop", "ghost", 17)
	quit.custom_minimum_size = Vector2(0, 56)
	quit.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(quit)


func _format_time(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


func open(stats: Dictionary) -> void:
	is_open = true
	for c in _stats.get_children():
		c.queue_free()
	var rows := [
		["TIME", _format_time(stats.time)],
		["STRAWS PULLED", Hud.group_digits(stats.pulled)],
		["MONEY EARNED", "$" + Hud.group_digits(stats.earned)],
		["BELT BUILT", "%d m" % stats.belt],
	]
	for r in rows:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", -4)
		cell.add_child(UI.label(r[0], 12, Color(UI.CREAM, 0.55), UI.black(), false))
		cell.add_child(UI.label(r[1], 40, UI.HAY, UI.stencil(), false))
		_stats.add_child(cell)
	_root.visible = true
	_root.modulate.a = 0.0
	var vp := get_viewport().get_visible_rect().size
	_confetti.position = Vector2(vp.x * 0.5, -20)
	_confetti.emission_rect_extents = Vector2(vp.x * 0.55, 10)
	_confetti.emitting = true
	var headline := _root.find_child("Headline", true, false) as Control
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.35)
	if headline:
		headline.pivot_offset = headline.size * 0.5
		headline.scale = Vector2.ONE * 0.6
		tw.tween_property(headline, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_keep.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_confetti.emitting = false
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: _root.visible = false)
	keep_playing.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
		close()
		get_viewport().set_input_as_handled()
