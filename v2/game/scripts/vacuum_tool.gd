# Hay vacuum: hold to suck loose straws into the tank, hold right mouse to shoot them back out as a stream.
class_name VacuumTool
extends HandTool

const RANGE := 8.0
const ANGLE := 22.0

var tank := CarryTank.new()
var _sucking := false
var _shooting := false
var _shoot_cd := 0.0
var _loop: AudioStreamPlayer3D


func _configure_viewmodel(vm: MeshInstance3D) -> void:
	_vm_rest = Vector3(0.3, -0.3, -0.62)
	vm.position = _vm_rest
	vm.rotation = Vector3(0.05, 0.12, 0.0)
	vm.scale = Vector3.ONE * 0.7


func capacity() -> int:
	return int(stat("vacuum_capacity"))


func primary(pressed: bool) -> void:
	_sucking = pressed
	if pressed:
		_shooting = false
	_update_loop()


func secondary(pressed: bool) -> void:
	_shooting = pressed
	if pressed:
		_sucking = false
	_update_loop()


func _update_loop() -> void:
	Sfx.stop_loop(_loop)
	_loop = null
	if _sucking:
		_loop = Sfx.loop_at("vacuum_loop", player.camera, -10.0)
	elif _shooting and tank.count() > 0:
		_loop = Sfx.loop_at("vacuum_shoot_loop", player.camera, -10.0)


func cancel() -> void:
	_sucking = false
	_shooting = false
	_update_loop()


func nozzle() -> Vector3:
	var cam := player.camera
	return cam.global_position - cam.global_basis.z * 0.75 + cam.global_basis.y * -0.15


func _tool_process(delta: float) -> void:
	_shoot_cd -= delta
	if _sucking:
		var n := nozzle()
		for piece in pieces_in_cone(RANGE, ANGLE):
			var to := n - piece.global_position
			if to.length() < 0.55:
				if tank.count() < capacity():
					tank.absorb(piece)
					kick(0.3)
				continue
			piece.sleeping = false
			var pull := to.normalized() * lerpf(10.0, 4.0, clampf(to.length() / RANGE, 0.0, 1.0))
			piece.linear_velocity = piece.linear_velocity.lerp(pull, 1.0 - exp(-delta * 6.0))
		_viewmodel.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.0015
	if _shooting and tank.count() > 0 and _shoot_cd <= 0.0:
		var fwd := -player.camera.global_basis.z
		tank.emit_one(main.haystack, nozzle() + fwd * 0.2, fwd * 13.0 + player.velocity + Vector3(randf_range(-0.6, 0.6), randf_range(-0.2, 0.6), randf_range(-0.6, 0.6)))
		_shoot_cd = 0.05
		kick(0.25)
		if tank.count() == 0:
			_update_loop()


func prompt() -> Dictionary:
	var spec: Array = [["LMB", "Hold to suck up straws"]]
	if tank.count() > 0:
		spec.append(["RMB", "Hold to shoot them out"])
	spec.append(["5", "Put away"])
	var warn := "The tank is full" if _sucking and tank.count() >= capacity() else ""
	return {"spec": spec, "warn": warn, "interact": false}


func hud_info() -> String:
	return "%d / %d straws" % [tank.count(), capacity()]
