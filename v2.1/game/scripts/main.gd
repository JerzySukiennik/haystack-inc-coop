# Game entry: input map, world, haystack, player, HUD, pause handling, settings and optional autotest.
extends Node3D

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_SENSITIVITY := 0.0045

signal inventory_changed

var player: Player
var haystack: Haystack
var hud: Hud
var menu_open := false
var money := 0
var sell_machine: SellMachine
var conveyor_meters := 0
var levels := {}
var machines := {}
var belt: ToolBelt
var has_conveyor_remote: bool:
	get:
		return int(levels.get("conveyor_remote", 0)) > 0
	set(v):
		levels["conveyor_remote"] = 1 if v else 0
var shop_booth: ShopBooth
var shop: ShopUI
var tool: ConveyorTool
var console: GameConsole
var volume := 80.0
var base_fov := 78.0
var play_time := 0.0
var total_earned := 0
var belt_built := 0
var won := false
var win_screen: WinScreen
var _hotbar_tick := 0.0
var sync: NetSync
var menu: MainMenu
var _net_counter := 0
var _orbit_cam: Camera3D
var _orbit_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	sync = NetSync.new()
	sync.name = "NetSync"
	sync.main = self
	add_child(sync)
	World.build(self)
	haystack = Haystack.new()
	haystack.name = "Haystack"
	haystack.sync = sync
	add_child(haystack)
	sell_machine = SellMachine.new()
	sell_machine.name = "SellMachine"
	add_child(sell_machine)
	sell_machine.position = Vector3(-World.YARD_HALF + SellMachine.SIZE * 0.5 + 0.2, 0.0, World.YARD_HALF - SellMachine.SIZE * 0.5 - 0.2)
	shop_booth = ShopBooth.new()
	shop_booth.name = "ShopBooth"
	add_child(shop_booth)
	shop_booth.position = Vector3(World.SHOP_POS.x, World.ground_height(World.SHOP_POS.x, World.SHOP_POS.z), World.SHOP_POS.z)
	shop_booth.rotation.y = deg_to_rad(-45.0)
	player = Player.new()
	player.name = "Player"
	player.sync = sync
	add_child(player)
	player.global_position = Vector3(0.0, 0.1, 13.0)
	player.look_at_point(Vector3(0, 2.0, 0))
	player.sensitivity = DEFAULT_SENSITIVITY
	hud = Hud.new()
	add_child(hud)
	tool = ConveyorTool.new()
	tool.name = "ConveyorTool"
	tool.main = self
	add_child(tool)
	tool.attach(player)
	belt = ToolBelt.new()
	belt.name = "ToolBelt"
	add_child(belt)
	belt.setup(self, player, tool)
	player.tool = belt
	belt.changed.connect(func() -> void: inventory_changed.emit())
	shop = ShopUI.new()
	shop.main = self
	add_child(shop)
	shop.closed.connect(_on_shop_closed)
	console = GameConsole.new()
	console.main = self
	add_child(console)
	console.opened_changed.connect(func(open: bool) -> void:
		player.input_enabled = not open and not menu_open and not shop.is_open)
	player.hover_changed.connect(func(_k: String) -> void: _update_prompt())
	tool.state_changed.connect(func(_k: String) -> void: _update_prompt())
	tool.dismantle_progress.connect(hud.set_pull)
	inventory_changed.connect(func() -> void:
		hud.set_money(money)
		_refresh_hotbar()
		_update_prompt()
		sync.economy_changed())
	player.charge_changed.connect(hud.set_charge)
	player.pull_progress.connect(hud.set_pull)
	player.pulled_changed.connect(hud.set_pulled)
	haystack.count_changed.connect(hud.set_count)
	haystack.count_changed.connect(func(_n: int) -> void: sync.economy_changed())
	sell_machine.needle_sold.connect(_on_needle_sold)
	haystack.needle_revealed.connect(func() -> void:
		hud.toast("You uncovered something metal in the hay", "money"))
	win_screen = WinScreen.new()
	add_child(win_screen)
	win_screen.keep_playing.connect(_on_keep_playing)
	sell_machine.main = self
	sell_machine.sold.connect(func(amount: int, _at: Vector3) -> void:
		total_earned += amount
		money += amount
		inventory_changed.emit())
	hud.resume_requested.connect(func() -> void: set_menu(false))
	hud.leave_requested.connect(leave_to_menu)
	hud.fov_changed.connect(func(v: float) -> void:
		base_fov = v
		player.set_base_fov(v)
		_save_settings())
	hud.volume_changed.connect(func(v: float) -> void:
		volume = v
		_apply_volume()
		_save_settings())
	hud.sensitivity_changed.connect(func(v: float) -> void:
		player.sensitivity = v
		_save_settings())
	_load_settings()
	apply_stats()
	inventory_changed.emit()
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		var t := preload("res://scripts/autotest.gd").new()
		t.main = self
		add_child(t)
		return
	for a in args:
		if a.begins_with("--net-host"):
			Net.my_name = _arg_value(args, "--name", "Host bot")
			var code := Net.host()
			var path := a.get_slice("=", 1)
			if path != "":
				var f := FileAccess.open(path, FileAccess.WRITE)
				if f:
					f.store_string(code)
			_start_bot(args)
			return
		if a.begins_with("--net-join"):
			Net.my_name = _arg_value(args, "--name", "Join bot")
			player.input_enabled = false
			Net.join(a.get_slice("=", 1))
			_start_bot(args)
			return
	_open_menu()
	for a in args:
		if a.begins_with("--menu-shot="):
			await get_tree().create_timer(3.0).timeout
			get_viewport().get_texture().get_image().save_png(a.get_slice("=", 1))
			get_tree().quit()


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"pause": [KEY_ESCAPE, KEY_P],
		"interact": [KEY_E],
		"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4], "slot_5": [KEY_5],
		"slot_6": [KEY_6], "slot_7": [KEY_7], "slot_8": [KEY_8], "slot_9": [KEY_9],
		"rotate": [KEY_R],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
			var ev2 := InputEventKey.new()
			ev2.keycode = k
			InputMap.action_add_event(action, ev2)


func _input(event: InputEvent) -> void:
	if console.is_open:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not event.is_echo() and not menu_open and not shop.is_open:
		var k := event as InputEventKey
		if k.unicode == 47 or k.keycode == KEY_SLASH or k.keycode == KEY_KP_DIVIDE:
			belt.cancel()
			player.cancel_pull()
			console.open.call_deferred("/")
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause") and not event.is_echo():
		if shop.is_open:
			shop.close()
		elif belt.placing and not menu_open:
			belt.cancel()
		else:
			set_menu(not menu_open)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not event.is_echo():
		if shop.is_open:
			shop.close()
			get_viewport().set_input_as_handled()
		elif not menu_open and player.hover_kind() == "shop":
			open_shop()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotate") and not event.is_echo() and not menu_open and not shop.is_open and belt.equipped:
		belt.rotate_action()
		_update_prompt()
	elif not event.is_echo() and not menu_open and not shop.is_open:
		for i in range(1, 10):
			if event.is_action_pressed("slot_%d" % i):
				belt.equip_slot(i)
				get_viewport().set_input_as_handled()
				return


func _on_needle_sold(_at: Vector3) -> void:
	if won:
		hud.toast("You already found the needle", "money")
		return
	var stats := {"time": play_time, "pulled": player.pulled, "earned": total_earned, "belt": belt_built}
	sync.win(stats)
	show_win(stats)


func show_win(stats: Dictionary) -> void:
	if won:
		return
	won = true
	belt.cancel()
	player.cancel_pull()
	player.drop()
	player.input_enabled = false
	_spawn_trophy()
	win_screen.open(stats)


func next_net_id() -> int:
	_net_counter += 1
	return _net_counter


func _arg_value(args: PackedStringArray, key: String, fallback: String) -> String:
	for a in args:
		if a.begins_with(key + "="):
			return a.get_slice("=", 1)
	return fallback


func _start_bot(args: PackedStringArray) -> void:
	var bot := preload("res://scripts/net_bot.gd").new()
	bot.main = self
	bot.args = args
	add_child(bot)


func _open_menu() -> void:
	menu = MainMenu.new()
	menu.main = self
	add_child(menu)
	player.input_enabled = false
	hud.visible = false
	_orbit_cam = Camera3D.new()
	_orbit_cam.fov = 60.0
	add_child(_orbit_cam)
	_orbit_cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_menu() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
	menu = null
	if is_instance_valid(_orbit_cam):
		_orbit_cam.queue_free()
	_orbit_cam = null
	player.camera.current = true
	hud.visible = true
	player.input_enabled = not Net.is_client() or Net.state == "connected"
	_capture(true)


func on_joined_world() -> void:
	player.input_enabled = true
	if is_instance_valid(menu):
		close_menu()
	hud.toast("Joined %s's farm" % Net.names.get(1, "the host"), "success")


func leave_to_menu() -> void:
	Net.leave()
	get_tree().reload_current_scene()


func _on_keep_playing() -> void:
	player.input_enabled = not menu_open and not shop.is_open
	if not "--autotest" in OS.get_cmdline_user_args():
		_capture(true)
	hud.toast("The golden needle is on display next to the sell machine", "money")


func _spawn_trophy() -> void:
	var trophy := Node3D.new()
	trophy.name = "Trophy"
	add_child(trophy)
	trophy.position = sell_machine.global_position + Vector3(4.2, 0, 1.2)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshKit.add_cylinder(st, Vector3.ZERO, 0.25, 0.55, 0.5, 10, Color(0.36, 0.25, 0.16), Color(0.45, 0.31, 0.2))
	MeshKit.add_cylinder(st, Vector3(0, 0.25, 0), 0.8, 0.28, 0.24, 10, Color(0.93, 0.88, 0.78), Color(0.93, 0.88, 0.78))
	MeshKit.add_cylinder(st, Vector3(0, 1.05, 0), 0.08, 0.36, 0.36, 10, Color(0.45, 0.31, 0.2), Color(0.56, 0.16, 0.12))
	var base := MeshInstance3D.new()
	base.mesh = st.commit()
	base.material_override = MeshKit.vertex_material(0.7)
	trophy.add_child(base)
	var body := StaticBody3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 1.15
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.57
	body.add_child(cs)
	trophy.add_child(body)
	var needle := MeshInstance3D.new()
	needle.mesh = MeshKit.straw_mesh()
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.28)
	gold.metallic = 1.0
	gold.roughness = 0.2
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.2)
	gold.emission_energy_multiplier = 0.6
	needle.material_override = gold
	var spin := Node3D.new()
	spin.position.y = 1.55
	trophy.add_child(spin)
	needle.transform = Transform3D(Basis(Vector3(0, 0, 1), 0.35).scaled(Vector3(1.4, 0.6, 1.4)), Vector3(0, -0.3, 0))
	spin.add_child(needle)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.45)
	light.light_energy = 1.4
	light.omni_range = 3.0
	light.position.y = 1.8
	trophy.add_child(light)
	var tw := spin.create_tween().set_loops()
	tw.tween_property(spin, "rotation:y", TAU, 4.0).from(0.0)


func _process(_delta: float) -> void:
	if is_instance_valid(_orbit_cam):
		_orbit_t += _delta * 0.05
		_orbit_cam.global_position = Vector3(cos(_orbit_t) * 19.0, 7.5, sin(_orbit_t) * 19.0)
		_orbit_cam.look_at(Vector3(0, 2.2, 0))
	if not won:
		play_time += _delta
	if player.global_position.y < -15.0:
		player.global_position = Vector3(0.0, 0.5, 13.0)
		player.velocity = Vector3.ZERO
		hud.toast("You fell off the plate", "info")
	var want := Input.MOUSE_MODE_VISIBLE if (menu_open or shop.is_open or win_screen.is_open or is_instance_valid(menu)) else Input.mouse_mode
	if Input.mouse_mode != want:
		Input.mouse_mode = want
	if belt.equipped:
		_update_prompt()
		_hotbar_tick += _delta
		if _hotbar_tick > 0.2:
			_hotbar_tick = 0.0
			_refresh_hotbar()


func _update_prompt() -> void:
	var kind := player.hover_kind()
	var spec: Array = []
	var warn := ""
	if belt.equipped and belt.current != "conveyor_remote":
		var pr := belt.prompt()
		hud.set_prompt(pr.get("spec", []), pr.get("interact", false), pr.get("warn", ""))
		return
	match tool._kind:
		"tool_idle":
			spec = [["LMB", "Start conveyor"], ["1", "Put away"]]
		"tool_conveyor":
			var m := tool.hover_line.meters if is_instance_valid(tool.hover_line) else 0
			spec = [["RMB", "Hold to dismantle (+%d m)" % m], ["R", "Reverse"], ["LMB", "Branch from here"]]
		"tool_valid":
			var label := "Build %d m" % tool.length_meters()
			match tool.junction_kind():
				"split":
					label = "Build splitter · %d m" % tool.length_meters()
				"merge":
					label = "Build merge · %d m" % tool.length_meters()
			spec = [["LMB", label], ["Wheel", "Bend"], ["R", "Flip direction"], ["RMB", "Cancel"]]
		"tool_meters":
			warn = "Not enough belt — this needs %d m, you have %d m" % [tool.length_meters(), conveyor_meters]
			spec = [["Wheel", "Bend"], ["RMB", "Cancel"]]
		"tool_short":
			warn = "Walk further to lay at least 1 m"
			spec = [["RMB", "Cancel"]]
		"tool_offplate":
			warn = "Belts have to stay on the plate"
			spec = [["RMB", "Cancel"]]
		"tool_blocked":
			warn = "Something is in the way"
			spec = [["Wheel", "Bend"], ["RMB", "Cancel"]]
	if spec.is_empty() and warn == "":
		spec = Hud.PROMPTS.get(kind, [])
	hud.set_prompt(spec, kind in ["stack", "piece", "shop"] and not belt.equipped, warn)


func open_shop() -> void:
	belt.cancel()
	player.cancel_pull()
	player.drop()
	player.input_enabled = false
	shop.open()


func _on_shop_closed() -> void:
	player.input_enabled = not menu_open
	if not menu_open and not "--autotest" in OS.get_cmdline_user_args():
		_capture(true)


func stat(name: String) -> Variant:
	for id in Catalog.ITEMS:
		var it: Dictionary = Catalog.ITEMS[id]
		if it.get("stat", "") != name:
			continue
		var lvl := int(levels.get(id, 0))
		var tiers: Array = it.get("tiers", [])
		if it.kind == "upgrade":
			return it.base if lvl <= 0 else tiers[mini(lvl, tiers.size()) - 1].value
		return Catalog.TOOL_DEFAULTS.get(name, 0) if lvl <= 0 else tiers[mini(lvl, tiers.size()) - 1].value
	return 0


func next_price(id: String, amount := 1) -> int:
	var it := Catalog.item(id)
	match it.kind:
		"meters":
			return int(stat("meter_price")) * amount
		"machine":
			return int(it.price) * amount
	var lvl := int(levels.get(id, 0))
	var tiers: Array = it.get("tiers", [])
	if lvl >= tiers.size():
		return -1
	return int(tiers[lvl].price)


func _toast(peer: int, text: String, kind: String) -> void:
	if peer == 0 or peer == Net.my_id():
		hud.toast(text, kind)
	else:
		sync.toast_to(peer, text, kind)


func buy(id: String, amount := 1, peer := 0) -> bool:
	var it := Catalog.item(id)
	if it.is_empty():
		return false
	if Net.is_client():
		var p := next_price(id, amount)
		if p < 0 or money < p:
			_toast(peer, "You need $%d more" % maxi(p - money, 0) if p >= 0 else "%s is already at max level" % it.name, "error")
			return false
		sync.req_buy.rpc_id(1, id, amount)
		return true
	if it.has("requires") and int(levels.get(it.requires, 0)) <= 0 and int(machines.get(it.requires, 0)) <= 0 and not _has_placed(it.requires):
		_toast(peer, "You need the %s first" % Catalog.item(it.requires).name.to_lower(), "error")
		return false
	var price := next_price(id, amount)
	if price < 0:
		_toast(peer, "%s is already at max level" % it.name, "info")
		return false
	if money < price:
		_toast(peer, "You need $%d more" % (price - money), "error")
		return false
	money -= price
	var lvl := int(levels.get(id, 0))
	match it.kind:
		"meters":
			conveyor_meters += amount
			_toast(peer, "Bought %d m of belt" % amount, "success")
		"machine":
			machines[id] = int(machines.get(id, 0)) + amount
			_toast(peer, "Bought a %s · press %d to place it" % [it.name.to_lower(), int(it.slot)], "success")
		"tool":
			levels[id] = lvl + 1
			if lvl == 0:
				_toast(peer, "Bought the %s · press %d to use it" % [it.name.to_lower(), int(it.slot)], "success")
			else:
				_toast(peer, "%s upgraded to level %d" % [it.name, lvl + 1], "success")
		"upgrade":
			levels[id] = lvl + 1
			_toast(peer, "%s · level %d" % [it.name, lvl + 1], "success")
	apply_stats()
	inventory_changed.emit()
	return true


func _has_placed(machine_id: String) -> bool:
	for m in get_tree().get_nodes_in_group("machine"):
		if (m as Machine).id == machine_id and not (m as Machine).preview:
			return true
	return false


func buy_conveyor_remote() -> bool:
	return buy("conveyor_remote")


func buy_meters(amount: int) -> bool:
	return buy("belt_meters", amount)


func earn(amount: int, _at: Vector3) -> void:
	total_earned += amount
	money += amount
	inventory_changed.emit()


func apply_stats() -> void:
	player.pull_time = float(stat("pull_time"))
	player.reach = float(stat("reach"))
	player.throw_max = float(stat("throw_power"))
	player.jump_speed = float(stat("jump"))
	player.move_mult = float(stat("move_speed"))
	ConveyorLine.set_global_speed(get_tree(), float(stat("belt_speed")))


func _refresh_hotbar() -> void:
	var slots: Array = []
	for tid in belt.slots():
		slots.append({"id": tid, "slot": int(Catalog.item(tid).slot), "name": Catalog.item(tid).name, "info": belt.hud_info(tid), "active": belt.current == tid})
	hud.set_hotbar(slots)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not menu_open and not is_instance_valid(menu):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture(true)
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and player and not menu_open and not is_instance_valid(menu) and not "--autotest" in OS.get_cmdline_user_args() and OS.get_cmdline_user_args().is_empty():
		player.drop()
		hud.set_click_hint(true)


func set_menu(open: bool) -> void:
	menu_open = open
	var room := ""
	if Net.is_online():
		room = "Room %s  ·  %d farmer%s" % [Net.code, Net.names.size(), "" if Net.names.size() == 1 else "s"]
	hud.set_menu(open, player.sensitivity, base_fov, volume, room, not is_instance_valid(menu))
	player.input_enabled = not open and not is_instance_valid(menu)
	if open:
		player.cancel_pull()
		player.drop()
	if not is_instance_valid(menu):
		_capture(not open)


func _capture(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
	hud.set_click_hint(false)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		player.sensitivity = cfg.get_value("input", "sensitivity_v2", DEFAULT_SENSITIVITY)
		base_fov = cfg.get_value("video", "fov", 78.0)
		volume = cfg.get_value("audio", "volume", 80.0)
	player.set_base_fov(base_fov)
	_apply_volume()


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume / 100.0, 0.0001)))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "sensitivity_v2", player.sensitivity)
	cfg.set_value("video", "fov", base_fov)
	cfg.set_value("audio", "volume", volume)
	cfg.save(SETTINGS_PATH)
