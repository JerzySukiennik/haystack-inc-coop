# Pitchfork: hold on the stack to rip out a forkful of straws at once; they spill out toward your feet.
class_name PitchforkTool
extends HandTool

var _holding := false
var _t := 0.0
var _point := Vector3.ZERO
var _normal := Vector3.UP


func _configure_viewmodel(vm: MeshInstance3D) -> void:
	_vm_rest = Vector3(0.34, -0.36, -0.62)
	vm.position = _vm_rest
	vm.rotation = Vector3(0.1, 0.35, -0.25)
	vm.scale = Vector3.ONE * 0.75


func primary(pressed: bool) -> void:
	if not pressed:
		_holding = false
		_t = 0.0
		main.hud.set_pull(0.0)
		return
	var hit := ray_hit(float(stat("reach")), 1)
	if hit.is_empty() or not (hit.collider is Haystack):
		Sfx.play_ui("deny", -12.0)
		return
	_holding = true
	_t = 0.0
	_point = hit.position
	_normal = hit.normal


func cancel() -> void:
	_holding = false
	_t = 0.0
	if main and main.hud:
		main.hud.set_pull(0.0)


func _tool_process(delta: float) -> void:
	if not _holding:
		return
	var hit := ray_hit(float(stat("reach")), 1)
	if hit.is_empty() or not (hit.collider is Haystack) or (hit.position as Vector3).distance_to(_point) > 0.8:
		cancel()
		return
	var total := float(stat("pull_time")) * 0.9
	_t = minf(_t + delta / total, 1.0)
	_viewmodel.position.z = _vm_rest.z - 0.15 * sin(_t * PI * 6.0) * (1.0 - _t)
	main.hud.set_pull(_t)
	if _t >= 1.0:
		_fork_out()
		_t = 0.0
		_holding = false
		main.hud.set_pull(0.0)


func _fork_out() -> void:
	var stack: Haystack = main.haystack
	var n := int(stat("fork_count"))
	var toward := (player.global_position - _point)
	toward.y = 0.0
	toward = toward.normalized()
	var got := 0
	for k in n:
		var jitter := Vector3(randf_range(-0.25, 0.25), randf_range(-0.2, 0.2), randf_range(-0.25, 0.25))
		var info := stack.begin_take(_point + jitter)
		if info.is_empty():
			break
		var xf: Transform3D = info.transform
		var out := _normal * 0.35 + Vector3.UP * 0.1
		var piece := stack.finish_take(info, Transform3D(xf.basis, xf.origin + out))
		piece.linear_velocity = toward * randf_range(1.5, 3.0) + Vector3.UP * randf_range(1.5, 3.0) + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
		piece.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		got += 1
	if got > 0:
		player.pulled += got
		player.pulled_changed.emit(player.pulled)
		Sfx.play_at("pitchfork_stab", _point, -3.0)
		Sfx.play_at("hay_pull", _point, -6.0)
		kick(1.0)


func prompt() -> Dictionary:
	var hit := ray_hit(float(stat("reach")), 1)
	var on_stack := not hit.is_empty() and hit.collider is Haystack
	if _holding:
		return {"spec": [["LMB", "Keep holding"]], "warn": "", "interact": true}
	if on_stack:
		return {"spec": [["LMB", "Hold to fork out %d straws" % int(stat("fork_count"))], ["2", "Put away"]], "warn": "", "interact": true}
	return {"spec": [["2", "Put away"]], "warn": "", "interact": false}


func hud_info() -> String:
	return "%d per forkful" % int(stat("fork_count"))
