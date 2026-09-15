# Scripted multiplayer test player for cross-machine checks: waits for a peer, performs actions, writes a JSON report and screenshots.
extends Node

var main: Node
var args: PackedStringArray
var report := {}
var shots_dir := ""
var report_path := ""
var role := ""


func _ready() -> void:
	for a in args:
		if a.begins_with("--shots="):
			shots_dir = a.get_slice("=", 1)
		elif a.begins_with("--report="):
			report_path = a.get_slice("=", 1)
		elif a.begins_with("--net-host"):
			role = "host"
		elif a.begins_with("--net-join"):
			role = "client"
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	main.player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(n: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(n + ".png"))


func _avatar_shot(n: String) -> void:
	var a: Node3D = main.sync.avatars.values()[0]
	var p: Player = main.player
	var from := a.global_position + (a.global_basis * Vector3(0, 0, -3.2)) + Vector3.UP * 1.7
	p.global_position = Vector3(from.x, 0.1, from.z)
	await _wait(0.15)
	p.look_at_point(a.global_position + Vector3.UP * 1.3)
	await _wait(0.4)
	await _shot(n)


func _save() -> void:
	print("[netbot] REPORT ", JSON.stringify(report))
	if report_path != "":
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(report))


func _run() -> void:
	var p: Player = main.player
	var stack: Haystack = main.haystack
	if role == "host":
		report["code"] = Net.code
		var t := 0.0
		while Net.names.size() < 2 and t < 120.0:
			await _wait(0.5)
			t += 0.5
		report["peer_joined"] = Net.names.size() >= 2
		await _wait(3.0)
		p.global_position = Vector3(1.6, 0.1, 7.3)
		await _wait(0.3)
		p.look_at_point(Vector3(1.2, 1.3, 4.6))
		p.input_enabled = true
		main.levels["gloves"] = 3
		main.apply_stats()
		main.money += 500
		main.inventory_changed.emit()
		report["host_money_set"] = main.money
		await _wait(1.0)
		print("[netbot] host ray ", p.ray.get_collider())
		p.primary_press()
		await _wait(1.2)
		p.primary_release()
		await _wait(0.5)
		report["host_pulled_remaining"] = stack.remaining
		var t2 := 0.0
		while t2 < 40.0:
			await _wait(1.0)
			t2 += 1.0
			if main.sync.avatars.size() > 0:
				report["client_avatar_seen"] = true
			if main.get_tree().get_nodes_in_group("conveyor").size() > 0:
				report["client_built_line_on_host"] = true
			if stack.remaining <= 999996:
				report["client_pulls_reached_host"] = true
			if main.levels.get("pitchfork", 0) > 0:
				report["client_bought_on_host"] = true
			if t2 == 6.0 and main.sync.avatars.size() > 0:
				await _avatar_shot("host_sees_client")
		report["host_remaining_end"] = stack.remaining
		report["host_pieces"] = stack.pieces.size()
		report["host_money_end"] = main.money
		_save()
		await _wait(8.0)
		get_tree().quit()
	else:
		var t := 0.0
		while Net.state != "connected" and t < 60.0:
			await _wait(0.5)
			t += 0.5
		report["connected"] = Net.state == "connected"
		await _wait(3.0)
		report["welcome_money"] = main.money
		report["welcome_pieces"] = stack.pieces.size()
		report["needle_synced"] = stack.needle_pos != Vector3.ZERO
		p.input_enabled = true
		p.global_position = Vector3(-0.6, 0.1, 7.4)
		p.velocity = Vector3.ZERO
		await _wait(0.3)
		p.look_at_point(Vector3(-0.3, 1.3, 4.6))
		await _wait(2.0)
		report["host_avatar_seen"] = main.sync.avatars.has(1)
		report["money_from_host"] = main.money
		await _shot("client_sees_host")
		var rem0 := stack.remaining
		for k in 3:
			p.look_at_point(Vector3(-0.3 + k * 0.25, 1.3, 4.6))
			await _wait(0.1)
			print("[netbot] client ray ", p.ray.get_collider(), " pull_time ", p.pull_time)
			p.primary_press()
			await _wait(float(p.pull_time) + 0.4)
			report["client_holding_%d" % k] = is_instance_valid(p.held)
			if p.held:
				p.look_at_point(p.head.global_position + Vector3(-1, 0.3, 1))
				p.begin_charge()
				await _wait(0.4)
				p.release_throw()
			await _wait(0.6)
		await _wait(1.5)
		report["client_remaining_after_pulls"] = rem0 - stack.remaining
		await _shot("client_threw_straws")
		main.buy("conveyor_remote")
		await _wait(1.0)
		main.buy("belt_meters", 10)
		main.buy("pitchfork")
		await _wait(1.5)
		report["client_owns_remote"] = main.has_conveyor_remote
		report["client_meters"] = main.conveyor_meters
		main.belt.equip("conveyor_remote")
		p.global_position = Vector3(8.0, 0.1, 6.0)
		p.look_at_point(Vector3(10.0, 0.0, 3.0))
		await _wait(0.4)
		main.tool.primary()
		p.look_at_point(Vector3(14.0, 0.0, 3.0))
		await _wait(1.0)
		report["client_holo_valid"] = main.tool.valid
		main.tool.primary()
		await _wait(2.0)
		report["client_sees_line"] = main.get_tree().get_nodes_in_group("conveyor").size() > 0
		main.belt.equip("")
		await _shot("client_built_line")
		_save()
		await _wait(20.0)
		get_tree().quit()
