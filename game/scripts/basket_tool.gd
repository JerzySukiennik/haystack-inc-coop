# Hay basket: click loose straws to collect them, hold right mouse to pour them out in front of you.
class_name BasketTool
extends HandTool

var tank := CarryTank.new()
var _collecting := false
var _pouring := false
var _collect_cd := 0.0
var _pour_cd := 0.0
var _fill: MeshInstance3D


func _configure_viewmodel(vm: MeshInstance3D) -> void:
	_vm_rest = Vector3(0.0, -0.42, -0.72)
	vm.position = _vm_rest
	vm.rotation = Vector3(0.25, 0.0, 0.0)
	_fill = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.19
	cyl.bottom_radius = 0.15
	cyl.height = 0.02
	_fill.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.74, 0.36)
	m.roughness = 1.0
	_fill.material_override = m
	vm.add_child(_fill)
	_update_fill()


func capacity() -> int:
	return int(stat("basket_capacity"))


func _update_fill() -> void:
	if _fill == null:
		return
	var f := clampf(float(tank.count()) / maxf(capacity(), 1.0), 0.0, 1.0)
	_fill.visible = f > 0.0
	_fill.position.y = lerpf(0.02, 0.2, f)


func primary(pressed: bool) -> void:
	_collecting = pressed
	_collect_cd = 0.0


func secondary(pressed: bool) -> void:
	_pouring = pressed
	_pour_cd = 0.0


func cancel() -> void:
	_collecting = false
	_pouring = false


func _tool_process(delta: float) -> void:
	_collect_cd -= delta
	_pour_cd -= delta
	if _collecting and _collect_cd <= 0.0:
		var hit := ray_hit(float(stat("reach")), 1 | HayPiece.PICK_LAYER, true)
		var piece := HayPiece.from_collider(hit.get("collider"))
		if piece and piece.held_by == null and not piece.selling:
			if tank.count() >= capacity():
				Sfx.play_ui("deny", -12.0)
				main.hud.toast("The basket is full", "error")
				_collecting = false
			else:
				tank.absorb(piece)
				Sfx.play_at("basket_collect", piece.global_position, -6.0)
				kick(0.5)
				_update_fill()
			_collect_cd = 0.12
	if _pouring and _pour_cd <= 0.0 and tank.count() > 0:
		var cam := player.camera
		var fwd := -cam.global_basis.z
		var pos := cam.global_position + fwd * 0.9 + Vector3.DOWN * 0.25
		tank.emit_one(main.haystack, pos, fwd * 2.2 + Vector3(randf_range(-0.4, 0.4), 0.6, randf_range(-0.4, 0.4)) + player.velocity * 0.5)
		_pour_cd = 0.07
		_update_fill()
		_viewmodel.rotation.x = lerpf(_viewmodel.rotation.x, -0.5, 0.3)
		if randf() < 0.3:
			Sfx.play_at("basket_collect", pos, -12.0)
	elif not _pouring:
		_viewmodel.rotation.x = lerpf(_viewmodel.rotation.x, 0.25, 0.2)


func prompt() -> Dictionary:
	var hit := ray_hit(float(stat("reach")), 1 | HayPiece.PICK_LAYER, true)
	var piece := HayPiece.from_collider(hit.get("collider"))
	var spec: Array = []
	if piece:
		spec.append(["LMB", "Toss into basket"])
	if tank.count() > 0:
		spec.append(["RMB", "Hold to pour out"])
	spec.append(["3", "Put away"])
	var warn := "The basket is full" if tank.count() >= capacity() and piece else ""
	return {"spec": spec, "warn": warn, "interact": piece != null}


func hud_info() -> String:
	return "%d / %d straws" % [tank.count(), capacity()]
