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
	if shots_dir == "":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(name + ".png"))
	print("[autotest] shot ", name)


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
	await _seconds(0.5)
	report["holding_after_pull"] = p.held != null
	await _shot("03_holding_piece")

	p.begin_charge()
	await _seconds(0.9)
	p.look_at_point(p.head.global_position + Vector3(0.6, 0.35, 1.0))
	await _frames(2)
	p.release_throw()
	await _seconds(0.25)
	await _shot("04_throw")

	var throws := 0
	for i in 24:
		p.look_at_point(Vector3(randf_range(-1.2, 1.8), randf_range(0.8, 2.0), 4.6))
		await _frames(2)
		p.primary_press()
		await _seconds(0.25)
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
	var total := 0.0
	for f in _fps_samples:
		total += f
	report["avg_fps"] = snappedf(total / maxf(_fps_samples.size(), 1.0), 0.1)
	print("[autotest] REPORT ", JSON.stringify(report))
	get_tree().quit()
