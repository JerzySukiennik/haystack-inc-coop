# Shop screen: a cozy 3D shop interior in its own world with items on pedestals in a looping left-right carousel.
class_name ShopUI
extends CanvasLayer

signal closed

const SPACING := 1.75

var main: Node
var is_open := false
var selected := 0
var items: Array[Dictionary] = []

var _root: Control
var _viewport: SubViewport
var _world_root: Node3D
var _camera: Camera3D
var _slots: Array[Node3D] = []
var _offset := 0.0
var _offset_tween: Tween
var _name: Label
var _desc: Label
var _price: Label
var _money: Label
var _buttons: HBoxContainer
var _card: PanelContainer
var _time := 0.0
var _badge: Label
var _note: Label
var _dots: HBoxContainer
var _money_chip: PanelContainer
var _last_money := -1


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	items = [
		{"id": Items.CONVEYOR_REMOTE},
		{"id": Items.SHOP_REMOTE},
	]
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(_viewport)
	_build_room()
	_build_overlay()


func _wood_mat(col: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, rough := 0.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _wood_mat(col, rough)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_room() -> void:
	_world_root = Node3D.new()
	_viewport.add_child(_world_root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.11, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.42, 0.32)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	_world_root.add_child(we)

	var floor_root := Node3D.new()
	_world_root.add_child(floor_root)
	for i in 14:
		var shade := 0.9 + 0.1 * sin(i * 2.3)
		_box(floor_root, Vector3(-6.5 + i, -0.05, -1.0), Vector3(0.98, 0.1, 12.0), Color(0.55, 0.36, 0.22) * shade)
	var wall_col := Color(0.93, 0.84, 0.70)
	_box(_world_root, Vector3(0, 2.5, -4.0), Vector3(14, 5.2, 0.2), wall_col, 0.95)
	_box(_world_root, Vector3(-6.2, 2.5, 0), Vector3(0.2, 5.2, 10), wall_col.darkened(0.08), 0.95)
	_box(_world_root, Vector3(6.2, 2.5, 0), Vector3(0.2, 5.2, 10), wall_col.darkened(0.08), 0.95)
	_box(_world_root, Vector3(0, 0.35, -3.88), Vector3(14, 0.7, 0.05), Color(0.45, 0.30, 0.19))
	_box(_world_root, Vector3(0, 5.0, 0), Vector3(14, 0.2, 10), Color(0.40, 0.27, 0.17))
	for x in [-4.5, -1.5, 1.5, 4.5]:
		_box(_world_root, Vector3(x, 4.8, 0), Vector3(0.25, 0.3, 10), Color(0.34, 0.22, 0.14))

	var window := _box(_world_root, Vector3(3.6, 2.7, -3.88), Vector3(2.2, 1.6, 0.04), Color(0.75, 0.88, 1.0))
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.8, 0.92, 1.0)
	wm.emission_enabled = true
	wm.emission = Color(1.0, 0.92, 0.75)
	wm.emission_energy_multiplier = 0.35
	window.material_override = wm
	for dx in [-1.15, 0.0, 1.15]:
		_box(_world_root, Vector3(3.6 + dx, 2.7, -3.84), Vector3(0.08, 1.7, 0.06), Color(0.40, 0.27, 0.17))
	for dy in [-0.85, 0.0, 0.85]:
		_box(_world_root, Vector3(3.6, 2.7 + dy, -3.84), Vector3(2.3, 0.08, 0.06), Color(0.40, 0.27, 0.17))

	var shelf_cols := [Color(0.80, 0.30, 0.22), Color(0.36, 0.58, 0.34), Color(0.98, 0.78, 0.30), Color(0.35, 0.55, 0.78), Color(0.93, 0.88, 0.78)]
	for k in 3:
		var y := 1.4 + k * 0.9
		_box(_world_root, Vector3(-3.3, y, -3.65), Vector3(4.2, 0.08, 0.5), Color(0.45, 0.30, 0.19))
		for j in 8:
			var h := 0.25 + fmod(j * 0.37 + k * 0.21, 0.3)
			_box(_world_root, Vector3(-5.1 + j * 0.5, y + 0.04 + h * 0.5, -3.65), Vector3(0.3, h, 0.3), shelf_cols[(j * 3 + k) % shelf_cols.size()])
	for side in [-5.2, 5.2]:
		_plant(Vector3(side, 0, -2.6))
	_plant(Vector3(1.6, 1.52, -3.62), 0.5)

	_box(_world_root, Vector3(0, 0.45, 2.2), Vector3(9.0, 0.9, 0.9), Color(0.50, 0.33, 0.20))
	_box(_world_root, Vector3(0, 0.92, 2.2), Vector3(9.3, 0.06, 1.05), Color(0.62, 0.43, 0.27))

	for x in [-3.0, 0.0, 3.0]:
		var cord := _box(_world_root, Vector3(x, 4.3, 0.2), Vector3(0.02, 1.2, 0.02), Color(0.1, 0.1, 0.1))
		cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		bulb.mesh = sm
		var bmat := StandardMaterial3D.new()
		bmat.emission_enabled = true
		bmat.emission = Color(1.0, 0.72, 0.4)
		bmat.emission_energy_multiplier = 3.0
		bulb.material_override = bmat
		bulb.position = Vector3(x, 3.6, 0.2)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world_root.add_child(bulb)
		var shade_mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.32
		cyl.height = 0.25
		shade_mi.mesh = cyl
		shade_mi.material_override = _wood_mat(Color(0.25, 0.35, 0.28), 0.6)
		shade_mi.position = Vector3(x, 3.78, 0.2)
		_world_root.add_child(shade_mi)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.78, 0.52)
		light.light_energy = 1.6
		light.omni_range = 6.5
		light.shadow_enabled = true
		light.position = Vector3(x, 3.45, 0.2)
		_world_root.add_child(light)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.92, 0.8)
	spot.light_energy = 4.0
	spot.spot_range = 8.0
	spot.spot_angle = 18.0
	spot.shadow_enabled = true
	spot.position = Vector3(0, 4.6, 1.2)
	spot.rotation_degrees = Vector3(-80, 0, 0)
	_world_root.add_child(spot)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.9, 0.75)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-35, 30, 0)
	_world_root.add_child(fill)

	var dust := GPUParticles3D.new()
	dust.amount = 90
	dust.lifetime = 10.0
	dust.preprocess = 10.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(5, 2, 2)
	pm.gravity = Vector3(0, 0.01, 0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.1
	pm.direction = Vector3(1, 0.3, 0)
	pm.spread = 180.0
	dust.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.02, 0.02)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(1.0, 0.9, 0.7, 0.35)
	q.material = qm
	dust.draw_pass_1 = q
	dust.position = Vector3(0, 2.2, 0)
	_world_root.add_child(dust)

	_camera = Camera3D.new()
	_camera.fov = 45.0
	_camera.position = Vector3(0, 1.9, 4.9)
	_world_root.add_child(_camera)
	_camera.look_at(Vector3(0, 1.3, 0))
	_camera.current = true

	for k in range(-3, 4):
		var slot := Node3D.new()
		var pedestal := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.42
		pc.bottom_radius = 0.48
		pc.height = 0.12
		pedestal.mesh = pc
		pedestal.material_override = _wood_mat(Color(0.66, 0.46, 0.29), 0.6)
		pedestal.position.y = 0.99
		slot.add_child(pedestal)
		var cloth := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 0.36
		cc.bottom_radius = 0.36
		cc.height = 0.02
		cloth.mesh = cc
		cloth.material_override = _wood_mat(Color(0.55, 0.16, 0.14), 0.95)
		cloth.position.y = 1.06
		slot.add_child(cloth)
		var holder := Node3D.new()
		holder.name = "Holder"
		holder.position.y = 1.32
		slot.add_child(holder)
		_world_root.add_child(slot)
		_slots.append(slot)


func _plant(pos: Vector3, scale_f := 1.0) -> void:
	var pot := _box(_world_root, pos + Vector3(0, 0.25 * scale_f, 0), Vector3(0.45, 0.5, 0.45) * scale_f, Color(0.72, 0.38, 0.24))
	pot.name = "Pot"
	for i in 7:
		var leaf := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.18, 0.8, 0.05) * scale_f
		leaf.mesh = pm
		leaf.material_override = _wood_mat(Color(0.28, 0.52, 0.26).lightened(i * 0.03), 0.9)
		leaf.position = pos + Vector3(0, 0.8 * scale_f, 0)
		leaf.rotation = Vector3(sin(i * 1.7) * 0.45, TAU * i / 7.0, cos(i * 2.1) * 0.35)
		_world_root.add_child(leaf)


func _place(c: Control, preset: Control.LayoutPreset, offset: Vector2, size: Vector2) -> void:
	UI.place(c, preset, offset, size)


func _arrow(dir: int) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	var b := UI.button("‹" if dir < 0 else "›", "secondary", 34)
	b.custom_minimum_size = Vector2(68, 68)
	b.tooltip_text = "Previous item" if dir < 0 else "Next item"
	b.pressed.connect(func() -> void: step(dir))
	wrap.add_child(b)
	var kc := UI.keycap("A" if dir < 0 else "D")
	kc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(kc)
	return wrap


func _build_overlay() -> void:
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	var vs := Shader.new()
	vs.code = "shader_type canvas_item;\nvoid fragment(){ vec2 d = UV - 0.5; float v = smoothstep(0.35, 0.85, length(d * vec2(1.1, 1.0))); COLOR = vec4(0.08, 0.05, 0.02, v * 0.55); }"
	vm.shader = vs
	vignette.material = vm
	_root.add_child(vignette)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	_place(top, Control.PRESET_TOP_WIDE, Vector2(28, 24), Vector2(0, 60))
	top.offset_right = -28
	_root.add_child(top)
	var leave := UI.button("Leave", "ghost", 16)
	leave.custom_minimum_size = Vector2(0, 46)
	leave.pressed.connect(close)
	top.add_child(leave)
	var esc := UI.keycap("Esc")
	esc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(esc)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", -6)
	title_col.alignment = BoxContainer.ALIGNMENT_CENTER
	var eyebrow := UI.label("FEED & MACHINE STORE", 12, Color(UI.CREAM, 0.7), UI.black())
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_col.add_child(eyebrow)
	var title := UI.label("Hay Supply Co.", 30, UI.CREAM, UI.stencil())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_col.add_child(title)
	top.add_child(title_col)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer2)
	var chip := UI.money_chip(24)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(chip)
	_money = chip.find_child("Amount", true, false) as Label
	_money_chip = chip

	var left := _arrow(-1)
	_place(left, Control.PRESET_CENTER_LEFT, Vector2(36, -60), Vector2(68, 110))
	_root.add_child(left)
	var right := _arrow(1)
	_place(right, Control.PRESET_CENTER_RIGHT, Vector2(-104, -60), Vector2(68, 110))
	_root.add_child(right)

	_card = PanelContainer.new()
	var cs := UI.box(UI.CREAM, 20, UI.HAY_DEEP, 0, 0, 18)
	cs.border_width_top = 8
	cs.border_color = UI.BARN
	cs.content_margin_left = 26
	cs.content_margin_right = 26
	cs.content_margin_top = 18
	cs.content_margin_bottom = 20
	_card.add_theme_stylebox_override("panel", cs)
	_place(_card, Control.PRESET_CENTER_BOTTOM, Vector2(-380, -300), Vector2(760, 230))
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", -2)
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_col)
	_badge = UI.label("", 12, UI.BARN, UI.black(), false)
	name_col.add_child(_badge)
	_name = UI.label("", 30, UI.INK, UI.black(), false)
	name_col.add_child(_name)
	_price = UI.label("", 38, UI.BARN, UI.stencil(), false)
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_price)
	_desc = UI.label("", 16, Color(UI.INK, 0.75), UI.body(), false)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(700, 0)
	col.add_child(_desc)
	_note = UI.label("", 14, UI.BARN, UI.black(), false)
	col.add_child(_note)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	col.add_child(_buttons)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 22)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(bottom, Control.PRESET_CENTER_BOTTOM, Vector2(-400, -50), Vector2(800, 32))
	_root.add_child(bottom)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 8)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(_dots)
	bottom.add_child(UI.prompt_pair("A+D", "Browse"))
	bottom.add_child(UI.prompt_pair("Space", "Buy"))
	bottom.add_child(UI.prompt_pair("Esc", "Leave"))


func open() -> void:
	if is_open:
		return
	is_open = true
	_root.visible = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)
	_rebuild_slots()
	_refresh()
	Sfx.play_music("shop_music_loop", -14.0)


func close() -> void:
	if not is_open:
		return
	is_open = false
	Sfx.stop_music()
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		if not is_open:
			_root.visible = false
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	closed.emit()


func _item_state(id: String) -> Dictionary:
	match id:
		Items.CONVEYOR_REMOTE:
			if not main.has_conveyor_remote:
				return {
					"mesh": Items.CONVEYOR_REMOTE,
					"badge": "TOOL",
					"name": "Conveyor remote",
					"desc": "Click where a belt should start, walk to where it ends and click again. Snaps to other belts and the sell machine. Belt is sold by the meter.",
					"price": "$%d" % main.REMOTE_PRICE,
					"buttons": [["Buy for $%d" % main.REMOTE_PRICE, "remote", main.REMOTE_PRICE]],
				}
			return {
				"mesh": Items.CONVEYOR_METERS,
				"badge": "BELT  ·  YOU HAVE %d M" % main.conveyor_meters,
				"name": "More belt",
				"desc": "Every meter of conveyor you build uses one meter of belt. Dismantling gives it back.",
				"price": "$%d / m" % main.METER_PRICE,
				"buttons": [
					["+1 m · $%d" % main.METER_PRICE, "meters", 1],
					["+5 m · $%d" % (main.METER_PRICE * 5), "meters", 5],
					["+10 m · $%d" % (main.METER_PRICE * 10), "meters", 10],
				],
			}
		Items.SHOP_REMOTE:
			return {
				"mesh": Items.SHOP_REMOTE,
				"badge": "COMING SOON",
				"name": "Shop remote",
				"desc": "Opens this shop from anywhere on the farm, so you never have to walk out the gate.",
				"price": "",
				"buttons": [],
			}
	return {}


func _refresh() -> void:
	_money.text = "$%s" % Hud.group_digits(main.money)
	if _last_money >= 0 and main.money != _last_money:
		UI.pop(_money_chip, 0.92 if main.money < _last_money else 1.08, 0.25)
	_last_money = main.money
	var state := _item_state(items[selected].id)
	_badge.text = state.badge
	_name.text = state.name
	_desc.text = state.desc
	_price.text = state.price
	_note.text = ""
	for c in _buttons.get_children():
		c.queue_free()
	var first := true
	for spec in state.buttons:
		var b := UI.button(spec[0], "primary" if first else "secondary", 17)
		first = false
		var kind: String = spec[1]
		var amount: int = spec[2]
		b.pressed.connect(func() -> void: _buy(kind, amount))
		_buttons.add_child(b)
	if state.buttons.is_empty():
		var soon := UI.button("Not in stock yet", "secondary", 17)
		soon.disabled = true
		_buttons.add_child(soon)
	for c in _dots.get_children():
		c.queue_free()
	for i in items.size():
		var d := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = UI.HAY if i == selected else Color(UI.CREAM, 0.4)
		sb.set_corner_radius_all(6)
		d.add_theme_stylebox_override("panel", sb)
		d.custom_minimum_size = Vector2(22 if i == selected else 10, 10)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(d)


func buy_primary() -> void:
	var state := _item_state(items[selected].id)
	if state.buttons.is_empty():
		Sfx.play_ui("deny", -6.0)
		return
	var spec: Array = state.buttons[0]
	_buy(spec[1], spec[2])


func _buy(kind: String, amount: int) -> void:
	var ok := false
	match kind:
		"remote":
			ok = main.buy_conveyor_remote()
		"meters":
			ok = main.buy_meters(amount)
	if ok:
		Sfx.play_ui("purchase", -4.0)
		_bounce_center()
		_rebuild_slots()
	else:
		Sfx.play_ui("deny", -4.0)
		var tw := create_tween()
		for i in 4:
			tw.tween_property(_card, "position:x", _card.position.x + (8.0 if i % 2 == 0 else -8.0), 0.04)
		tw.tween_property(_card, "position:x", _card.position.x, 0.04)
	_refresh()
	if not ok:
		var cost: int = main.REMOTE_PRICE if kind == "remote" else main.METER_PRICE * amount
		if main.money < cost:
			_note.text = "You need $%d more" % (cost - main.money)


func _bounce_center() -> void:
	var holder := _slots[3].get_node("Holder") as Node3D
	holder.scale = Vector3.ONE * 1.35
	create_tween().tween_property(holder, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func step(dir: int) -> void:
	if not is_open:
		return
	selected = posmod(selected + dir, items.size())
	_rebuild_slots()
	_offset = float(dir)
	if _offset_tween:
		_offset_tween.kill()
	_offset_tween = create_tween()
	_offset_tween.tween_property(self, "_offset", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play_ui("slide", -8.0)
	_refresh()


func _rebuild_slots() -> void:
	for i in _slots.size():
		var holder := _slots[i].get_node("Holder") as Node3D
		for c in holder.get_children():
			c.queue_free()
		var idx := posmod(selected + i - 3, items.size())
		var state := _item_state(items[idx].id)
		var mi := MeshInstance3D.new()
		mi.mesh = Items.mesh_for(state.mesh)
		mi.material_override = MeshKit.vertex_material(0.55)
		var s := 5.5 if state.mesh != Items.CONVEYOR_METERS else 2.6
		mi.scale = Vector3.ONE * s
		if state.mesh == Items.CONVEYOR_METERS:
			mi.position.y = -0.22
		holder.add_child(mi)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not event.is_echo():
		match (event as InputEventKey).physical_keycode:
			KEY_A, KEY_LEFT:
				step(-1)
			KEY_D, KEY_RIGHT:
				step(1)
			KEY_SPACE, KEY_ENTER:
				buy_primary()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				step(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				step(1)


func _process(delta: float) -> void:
	if not is_open:
		return
	_time += delta
	for i in _slots.size():
		var f := float(i - 3) + _offset
		var af := absf(f)
		var slot := _slots[i]
		slot.position = Vector3(f * SPACING, -pow(af, 1.6) * 0.05, -pow(af, 1.3) * 0.9)
		var sc := clampf(1.0 - af * 0.18, 0.0, 1.0) * clampf(3.2 - af, 0.0, 1.0)
		slot.scale = Vector3.ONE * maxf(sc, 0.001)
		var holder := slot.get_node("Holder") as Node3D
		var spin := 0.9 if af < 0.5 else 0.25
		holder.rotation.y += delta * spin
		holder.position.y = 1.32 + (sin(_time * 2.0 + i) * 0.04 if af < 0.5 else 0.0)
	_camera.position.x = sin(_time * 0.3) * 0.08
	_camera.position.y = 2.0 + sin(_time * 0.45) * 0.04
