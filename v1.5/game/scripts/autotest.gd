# Scripted playtest: pulls, carries, drops and throws hay, checks physics sanity, saves screenshots and a JSON report.
extends Node

var main: Node3D
var shots_dir := ""
var report := {}
var _fps_samples: Array[float] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		_fps_samples.append(Engine.get_frames_per_second())


func _seconds(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		_fps_samples.append(Engine.get_frames_per_second())


func _shot(name: String) -> void:
	await _frames(2)
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(name + ".png"))
	print("[autotest] shot ", name)


func _press(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _check_pause_menu() -> bool:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _frames(3)
	await _press(KEY_ESCAPE)
	var opened: bool = main.menu_open and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not main.player.input_enabled
	await _shot("08_pause_menu")
	await _press(KEY_ESCAPE)
	var closed: bool = not main.menu_open and main.player.input_enabled
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[autotest] pause opened=", opened, " closed=", closed)
	return opened and closed


func _rock_test(p: Player, stack: Haystack) -> void:
	var rock: StaticBody3D = null
	var best := 1e9
	for r in get_tree().get_nodes_in_group("rock"):
		var d: float = (r as Node3D).global_position.length()
		if d < best:
			best = d
			rock = r
	if rock == null:
		return
	var top := rock.global_position + Vector3(0, 2.0, 0)
	var space := rock.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(top, rock.global_position - Vector3(0, 2, 0), 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty() or hit.collider != rock:
		report["rock_test"] = "no rock surface hit"
		return
	var surface: Vector3 = hit.position
	var dropped: Array[HayPiece] = []
	for i in 6:
		var piece := stack.spawn_piece(surface + Vector3(randf_range(-0.1, 0.1), 0.25 + i * 0.06, randf_range(-0.1, 0.1)), Basis(Vector3.UP, randf() * TAU), Color(0.85, 0.7, 0.35), 0.45)
		dropped.append(piece)
	await _seconds(4.0)
	var stayed := 0
	for piece in dropped:
		if is_instance_valid(piece) and piece.global_position.y > surface.y - 0.08 and Vector2(piece.global_position.x - surface.x, piece.global_position.z - surface.z).length() < 0.9:
			stayed += 1
	report["rock_straws_stayed"] = "%d/6" % stayed
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.global_position = surface + Vector3(1.2, 0.8, 1.2)
	cam.look_at(surface)
	cam.current = true
	await _seconds(0.3)
	await _shot("10_rock_straws")
	cam.queue_free()


func _sell_test(stack: Haystack) -> void:
	var m: SellMachine = main.sell_machine
	var before: int = main.money
	var h := SellMachine.SIZE * 0.5
	var drops := 0
	for axis in [Vector3(1, 0, 0), Vector3(0, 0, -1)]:
		var a: Vector3 = axis
		for i in 3:
			var p := m.global_position + a * (h + SellMachine.BELT_LENGTH - 0.4 - i * 0.35) + Vector3.UP * (SellMachine.BELT_TOP + 0.3)
			var side := Vector3(-a.z, 0, a.x)
			stack.spawn_piece(p, Basis(side, Vector3.UP, side.cross(Vector3.UP)), Color(0.85, 0.7, 0.35), 0.45)
			drops += 1
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.global_position = m.global_position + Vector3(5.5, 3.2, -5.0)
	cam.look_at(m.global_position + Vector3(0.5, 0.8, -0.5))
	cam.current = true
	await _seconds(1.2)
	await _shot("11_sell_machine_belts")
	await _seconds(5.0)
	report["sold_on_belts"] = "%d/%d" % [main.money - before, drops]
	var mid_money: int = main.money
	var thrown := stack.spawn_piece(m.global_position + Vector3(h + 0.9, 1.05, 0.0), Basis.IDENTITY, Color(0.85, 0.7, 0.35), 0.45)
	thrown.linear_velocity = Vector3(-4.0, 0.0, 0.0)
	await _seconds(1.5)
	report["sold_thrown_into_intake"] = main.money > mid_money
	await _shot("12_sell_machine_after")
	cam.queue_free()


func _shop_and_conveyor_test(p: Player, stack: Haystack) -> void:
	var booth: ShopBooth = main.shop_booth
	var front := booth.global_transform * Vector3(0, 0, 2.6)
	p.global_position = Vector3(front.x, booth.global_position.y + 0.2, front.z)
	p.velocity = Vector3.ZERO
	await _frames(4)
	p.look_at_point(booth.global_transform * Vector3(0, 1.2, 0.8))
	await _frames(4)
	report["booth_prompt"] = p.hover_kind() == "shop"
	await _shot("13_booth")
	main.money = 100
	main.inventory_changed.emit()
	main.open_shop()
	await _seconds(0.8)
	await _shot("14_shop_remote")
	main.shop.step(1)
	await _seconds(0.6)
	await _shot("15_shop_next")
	main.shop.step(-1)
	await _seconds(0.5)
	main.shop.buy_primary()
	await _seconds(0.3)
	main.shop.buy_primary()
	main.shop._buy("meters", 5)
	await _seconds(0.6)
	await _shot("16_shop_meters")
	report["shop_bought"] = main.has_conveyor_remote and main.conveyor_meters == 6 and main.money == 100 - 15 - 18
	main.shop.close()
	await _seconds(0.4)
	main.conveyor_meters = 12
	var m: SellMachine = main.sell_machine
	var intake_end := m.global_position + Vector3(SellMachine.SIZE * 0.5 + SellMachine.BELT_LENGTH - 0.3, 0, 0)
	p.global_position = intake_end + Vector3(9.0, 0.2, -3.0)
	p.velocity = Vector3.ZERO
	await _frames(3)
	main.tool.set_equipped(true)
	var start_pt := intake_end + Vector3(6.5, 0, 0)
	p.look_at_point(start_pt)
	await _frames(3)
	main.tool.primary()
	report["tool_started"] = main.tool.placing
	p.look_at_point(intake_end + Vector3(0, 0, 0))
	await _seconds(0.8)
	await _shot("17_hologram")
	report["hologram_valid"] = main.tool.valid
	report["hologram_meters"] = main.tool.length_meters()
	main.tool.scroll(-4)
	await _seconds(0.3)
	await _shot("17b_hologram_bent")
	main.tool.scroll(4)
	await _seconds(0.3)
	var before_lines := get_tree().get_nodes_in_group("conveyor").size()
	main.tool.primary()
	await _frames(3)
	report["conveyor_placed"] = get_tree().get_nodes_in_group("conveyor").size() == before_lines + 1
	main.tool.set_equipped(false)
	var money0: int = main.money
	var lines := get_tree().get_nodes_in_group("conveyor")
	if not lines.is_empty():
		var line: ConveyorLine = lines[lines.size() - 1]
		for i in 4:
			var pt := line.points[mini(1 + i, line.points.size() - 1)]
			stack.spawn_piece(pt + Vector3(0, 0.3, 0), Basis.IDENTITY, Color(0.85, 0.7, 0.35), 0.45)
		var cam := Camera3D.new()
		main.add_child(cam)
		cam.global_position = intake_end + Vector3(5.0, 3.5, 5.5)
		cam.look_at(intake_end + Vector3(2.5, 0.8, 0))
		cam.current = true
		await _seconds(1.5)
		await _shot("18_conveyor_running")
		await _seconds(8.0)
		report["conveyor_sold"] = "%d/4" % (main.money - money0)
		cam.queue_free()
		p.camera.current = true


func _type(text: String) -> void:
	for ch in text:
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.unicode = ch.unicode_at(0)
		ev.keycode = OS.find_keycode_from_string(ch) if ch != " " else KEY_SPACE
		Input.parse_input_event(ev)
		await _frames(1)


func _key(k: Key, shift := false) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = k
	ev.physical_keycode = k
	ev.shift_pressed = shift
	Input.parse_input_event(ev)
	await _frames(2)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _console_test() -> void:
	var c: GameConsole = main.console
	var money0: int = main.money
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_SLASH
	ev.unicode = 47
	Input.parse_input_event(ev)
	await _frames(4)
	report["console_opens"] = c.is_open and c._line.text == "/"
	await _type("gi")
	await _frames(2)
	var first: String = c._suggestions[0].text if not c._suggestions.is_empty() else ""
	await _key(KEY_TAB)
	report["tab_completes_command"] = first == "give" and c._line.text.begins_with("/give")
	await _type("mo")
	await _frames(2)
	await _shot("19_console_suggest")
	await _key(KEY_TAB)
	await _type(" 250")
	await _key(KEY_ENTER)
	await _frames(3)
	report["console_give_money"] = main.money == money0 + 250 and not c.is_open
	c.open("/mony 5")
	await _frames(3)
	report["console_typo_fix"] = not c._suggestions.is_empty() and c._suggestions[0].text == "money"
	await _shot("20_console_typo")
	await _key(KEY_TAB)
	report["console_typo_tab"] = c._line.text.begins_with("/money")
	c.close()
	c.execute("/tp shop")
	await _frames(3)
	report["console_tp"] = main.player.global_position.distance_to(main.shop_booth.global_position) < 5.0
	c.execute("/speed 2")
	report["console_speed"] = is_equal_approx(main.player.speed_mult, 2.0)
	c.execute("/speed 1")
	await _frames(2)


func _run() -> void:
	var p: Player = main.player
	var stack: Haystack = main.haystack
	await _seconds(2.5)
	await _shot("01_arrival")

	p.global_position = Vector3(0.6, 0.1, 7.4)
	p.velocity = Vector3.ZERO
	await _frames(3)
	p.look_at_point(Vector3(0.3, 1.3, 4.6))
	await _frames(3)
	var hover_stack := p.ray.get_collider() is Haystack
	report["looking_at_stack"] = hover_stack
	await _shot("02_stack_closeup")

	var start_count := stack.remaining
	p.primary_press()
	await _seconds(1.0)
	report["pulling_midway"] = p.pulling and p.held == null
	await _shot("03a_pulling")
	p.primary_release()
	await _frames(2)
	report["release_cancels_pull"] = not p.pulling and stack.remaining == start_count
	var aim := Vector3(0.3, 1.3, 4.6)
	for k in 12:
		p.look_at_point(aim)
		await _frames(2)
		p.primary_press()
		await _seconds(2.15)
		if p.held:
			p.look_at_point(p.head.global_position + Vector3(1.0, 0.4, 0.3))
			p.begin_charge()
			await _seconds(0.4)
			p.release_throw()
			await _seconds(0.35)
	report["hole_dug_after_12"] = stack.remaining == start_count - 12
	p.look_at_point(aim)
	await _shot("03c_hole")

	p.primary_press()
	await _seconds(2.3)
	report["holding_after_pull"] = p.held != null
	if p.held:
		p.global_position = Vector3(0.6, 0.1, 6.3)
		p.look_at_point(Vector3(0.3, 1.0, 0.0))
		p.hold_distance = Player.HOLD_MAX
		await _seconds(1.0)
		var h := p.held.global_position
		var inside := Vector2(h.x, h.z).length() < stack.edge_radius(atan2(h.z, h.x)) and h.y < stack.surface_height(h.x, h.z) - 0.05
		report["held_straw_outside_stack"] = not inside
		await _shot("03b_held_against_stack")
		p.global_position = Vector3(0.6, 0.1, 7.4)
		p.look_at_point(Vector3(0.3, 1.3, 4.6))
		await _frames(3)
	await _shot("03_holding_piece")

	p.begin_charge()
	await _seconds(0.9)
	p.look_at_point(p.head.global_position + Vector3(0.6, 0.35, 1.0))
	await _frames(2)
	p.release_throw()
	await _seconds(0.25)
	await _shot("04_throw")

	var throws := 0
	for i in 10:
		p.look_at_point(Vector3(randf_range(-1.2, 1.8), randf_range(0.8, 2.0), 4.6))
		await _frames(2)
		p.primary_press()
		await _seconds(2.2)
		if p.held == null:
			continue
		if i % 3 == 0:
			p.primary_release()
		else:
			p.look_at_point(p.head.global_position + Vector3(randf_range(-1, 1), randf_range(0.1, 0.5), 1.0))
			p.begin_charge()
			await _seconds(randf_range(0.1, 0.9))
			p.release_throw()
			throws += 1
		await _seconds(0.15)
	report["pulled"] = start_count - stack.remaining
	report["throws"] = throws

	await _seconds(3.0)
	var nearest: HayPiece = null
	var best := 1e9
	for piece in stack.pieces:
		var flat := Vector2(piece.global_position.x, piece.global_position.z).length()
		if flat < stack.radius + 1.5 or flat > 14.0 or piece.global_position.y > 0.3:
			continue
		var d := piece.global_position.distance_to(p.global_position)
		if d < best:
			best = d
			nearest = piece
	if nearest:
		p.global_position = nearest.global_position + Vector3(0, 0, 1.6)
		p.global_position.y = 0.1
		await _frames(3)
		p.look_at_point(nearest.global_position)
		await _frames(3)
		p.primary_press()
		await _seconds(0.4)
		report["regrab_loose_piece"] = p.held == nearest
		p.global_position += Vector3(0, 0, 2.0)
		await _seconds(0.6)
		report["carried_distance_ok"] = p.held != null and p.held.global_position.distance_to(p.camera.global_position) < 3.0
		p.primary_release()

	var cam := Camera3D.new()
	main.add_child(cam)
	cam.global_position = Vector3(11.0, 6.5, 13.0)
	cam.look_at(Vector3(0, 1.4, 0))
	cam.current = true
	await _seconds(0.5)
	await _shot("05_overview")
	cam.global_position = Vector3(-24.0, 14.0, 30.0)
	cam.look_at(Vector3(-2, 1.5, 0))
	await _seconds(0.5)
	await _shot("06_yard_wide")
	cam.global_position = Vector3(2.5, 1.2, 8.8)
	cam.look_at(Vector3(0.0, 0.3, 5.5))
	await _seconds(0.5)
	await _shot("07_ground_pieces")

	await _rock_test(p, stack)
	var min_h := 1e9
	for piece in stack.pieces:
		var flat := Vector2(piece.global_position.x, piece.global_position.z).length()
		if piece.sleeping and flat > stack.radius + 1.2 and flat < 9.0:
			min_h = minf(min_h, piece.global_position.y)
	report["min_resting_center_height_on_dirt"] = snappedf(min_h, 0.001)
	cam.global_position = Vector3(3.0, 0.9, 9.5)
	cam.look_at(Vector3(0.5, 0.0, 7.0))
	cam.current = true
	await _seconds(0.4)
	await _shot("09_ground_macro")
	p.camera.current = true
	await _sell_test(stack)
	await _shop_and_conveyor_test(p, stack)
	await _console_test()
	var input_ok := await _check_pause_menu()
	report["esc_releases_cursor"] = input_ok

	var below := 0
	var asleep := 0
	for piece in stack.pieces:
		if piece.global_position.y < -0.5:
			below += 1
		if piece.sleeping:
			asleep += 1
	report["pieces_alive"] = stack.pieces.size()
	report["pieces_fell_through_ground"] = below
	report["pieces_sleeping"] = asleep
	report["remaining"] = stack.remaining
	report["rescued_below_ground"] = stack.rescued
	var total := 0.0
	for f in _fps_samples:
		total += f
	report["avg_fps"] = snappedf(total / maxf(_fps_samples.size(), 1.0), 0.1)
	print("[autotest] REPORT ", JSON.stringify(report))
	get_tree().quit()
