# Game entry: input map, world, haystack, player, HUD, pause handling, settings and optional autotest.
extends Node3D

const SETTINGS_PATH := "user://settings.cfg"

var player: Player
var haystack: Haystack
var hud: Hud
var menu_open := false
var money := 0
var sell_machine: SellMachine


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
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0.0, 0.1, 13.0)
	player.look_at_point(Vector3(0, 2.0, 0))
	hud = Hud.new()
	add_child(hud)
	player.hover_changed.connect(hud.set_hover)
	player.charge_changed.connect(hud.set_charge)
	player.pull_progress.connect(hud.set_pull)
	player.pulled_changed.connect(hud.set_pulled)
	haystack.count_changed.connect(hud.set_count)
	sell_machine.sold.connect(func(amount: int, _at: Vector3) -> void:
		money += amount
		hud.set_money(money))
	hud.resume_requested.connect(func() -> void: set_menu(false))
	hud.sensitivity_changed.connect(func(v: float) -> void:
		player.sensitivity = v
		_save_settings())
	_load_settings()
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
	if event.is_action_pressed("pause") and not event.is_echo():
		set_menu(not menu_open)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var want := Input.MOUSE_MODE_VISIBLE if menu_open else Input.mouse_mode
	if Input.mouse_mode != want:
		Input.mouse_mode = want


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
	hud.set_menu(open, player.sensitivity)
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
		player.sensitivity = cfg.get_value("input", "sensitivity", player.sensitivity)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "sensitivity", player.sensitivity)
	cfg.save(SETTINGS_PATH)
