# Game entry: input map, world, haystack, player, HUD, pause handling, settings and optional autotest.
extends Node3D

const SETTINGS_PATH := "user://settings.cfg"
const REMOTE_PRICE := 15
const METER_PRICE := 3
const DEFAULT_SENSITIVITY := 0.0045

signal inventory_changed

var player: Player
var haystack: Haystack
var hud: Hud
var menu_open := false
var money := 0
var sell_machine: SellMachine
var has_conveyor_remote := false
var conveyor_meters := 0
var shop_booth: ShopBooth
var shop: ShopUI
var tool: ConveyorTool
var console: GameConsole
var volume := 80.0
var base_fov := 78.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	World.build(self)
	haystack = Haystack.new()
	haystack.name = "Haystack"
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
	player.tool = tool
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
		hud.set_inventory(has_conveyor_remote, conveyor_meters, tool.equipped)
		_update_prompt())
	player.charge_changed.connect(hud.set_charge)
	player.pull_progress.connect(hud.set_pull)
	player.pulled_changed.connect(hud.set_pulled)
	haystack.count_changed.connect(hud.set_count)
	sell_machine.sold.connect(func(amount: int, _at: Vector3) -> void:
		money += amount
		inventory_changed.emit())
	hud.resume_requested.connect(func() -> void: set_menu(false))
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
	inventory_changed.emit()
	if "--autotest" in OS.get_cmdline_user_args():
		var t := preload("res://scripts/autotest.gd").new()
		t.main = self
		add_child(t)
	else:
		_capture(true)


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
		"slot_1": [KEY_1],
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
			tool.cancel()
			player.cancel_pull()
			console.open.call_deferred("/")
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause") and not event.is_echo():
		if shop.is_open:
			shop.close()
		elif tool.placing and not menu_open:
			tool.cancel()
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
	elif event.is_action_pressed("rotate") and not event.is_echo() and not menu_open and not shop.is_open and tool.equipped:
		tool.rotate_action()
		_update_prompt()
	elif event.is_action_pressed("slot_1") and not event.is_echo() and not menu_open and not shop.is_open:
		if has_conveyor_remote:
			tool.set_equipped(not tool.equipped)
			inventory_changed.emit()
		else:
			Sfx.play_ui("deny", -10.0)


func _process(_delta: float) -> void:
	var want := Input.MOUSE_MODE_VISIBLE if (menu_open or shop.is_open) else Input.mouse_mode
	if Input.mouse_mode != want:
		Input.mouse_mode = want
	if tool.placing or tool.equipped:
		_update_prompt()


func _update_prompt() -> void:
	var kind := player.hover_kind()
	var spec: Array = []
	var warn := ""
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
		"tool_blocked":
			warn = "Something is in the way"
			spec = [["Wheel", "Bend"], ["RMB", "Cancel"]]
	if spec.is_empty() and warn == "":
		spec = Hud.PROMPTS.get(kind, [])
	hud.set_prompt(spec, kind in ["stack", "piece", "shop"] and not tool.equipped, warn)


func open_shop() -> void:
	tool.cancel()
	player.cancel_pull()
	player.drop()
	player.input_enabled = false
	shop.open()


func _on_shop_closed() -> void:
	player.input_enabled = not menu_open
	if not menu_open and not "--autotest" in OS.get_cmdline_user_args():
		_capture(true)


func buy_conveyor_remote() -> bool:
	if has_conveyor_remote:
		return false
	if money < REMOTE_PRICE:
		hud.toast("You need $%d more" % (REMOTE_PRICE - money), "error")
		return false
	money -= REMOTE_PRICE
	has_conveyor_remote = true
	inventory_changed.emit()
	hud.toast("Bought the conveyor remote · press 1 to use it", "success")
	return true


func buy_meters(amount: int) -> bool:
	var cost := METER_PRICE * amount
	if not has_conveyor_remote:
		return false
	if money < cost:
		hud.toast("You need $%d more" % (cost - money), "error")
		return false
	money -= cost
	conveyor_meters += amount
	inventory_changed.emit()
	hud.toast("Bought %d m of belt" % amount, "success")
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not menu_open:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture(true)
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and player and not menu_open and not "--autotest" in OS.get_cmdline_user_args():
		player.drop()
		hud.set_click_hint(true)


func set_menu(open: bool) -> void:
	menu_open = open
	hud.set_menu(open, player.sensitivity, base_fov, volume)
	player.input_enabled = not open
	if open:
		player.cancel_pull()
		player.drop()
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
