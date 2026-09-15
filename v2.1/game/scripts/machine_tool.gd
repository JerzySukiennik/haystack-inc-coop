# Places machines from the inventory with a green/red ghost; R rotates, hold right mouse on a placed machine to pick it up.
class_name MachineTool
extends HandTool

const RANGE := 14.0
const PICKUP_TIME := 0.7

var _ghost: Machine
var _ghost_mat: ShaderMaterial
var _yaw := 0.0
var _valid := false
var _reason := ""
var _hover: Machine
var _picking := false
var _pick_t := 0.0


func setup(p_main: Node, p_player: Player, p_id: String) -> void:
	super.setup(p_main, p_player, p_id)
	_ghost_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = ConveyorTool.HOLO_SHADER
	_ghost_mat.shader = sh


func _configure_viewmodel(vm: MeshInstance3D) -> void:
	vm.mesh = Items.conveyor_remote_mesh()
	_vm_rest = Vector3(0.24, -0.2, -0.46)
	vm.position = _vm_rest
	vm.rotation = Vector3(0.55, 0.45, 0.1)
	vm.scale = Vector3.ONE * 0.7


func count() -> int:
	return int(main.machines.get(id, 0))


func set_equipped(on: bool) -> void:
	super.set_equipped(on)
	if on:
		_make_ghost()
	elif is_instance_valid(_ghost):
		_ghost.queue_free()
		_ghost = null


func _make_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = Machine.make(id)
	_ghost.preview = true
	main.add_child(_ghost)
	var mi := _ghost.get_node_or_null("Mesh") as MeshInstance3D
	if mi:
		mi.material_override = _ghost_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false


func rotate_action() -> void:
	_yaw += PI * 0.5
	Sfx.play_ui("holo_start", -12.0)


func primary(pressed: bool) -> void:
	if not pressed:
		return
	if count() <= 0:
		main.hud.toast("Buy another %s in the shop" % Catalog.item(id).name, "error")
		Sfx.play_ui("deny", -8.0)
		return
	if not _valid:
		Sfx.play_ui("deny", -8.0)
		return
	if Net.is_client():
		main.sync.req_place_machine.rpc_id(1, id, _ghost.global_transform)
	else:
		place_machine(main, id, _ghost.global_transform)
	Sfx.play_at("machine_place", _ghost.global_position, -2.0)
	main.hud.toast("Placed a %s" % Catalog.item(id).name.to_lower(), "success")


static func place_machine(p_main: Node, type: String, xf: Transform3D) -> Machine:
	var m := Machine.make(type)
	m.main = p_main
	m.net_id = p_main.next_net_id()
	p_main.add_child(m)
	m.global_transform = xf
	p_main.machines[type] = int(p_main.machines.get(type, 0)) - 1
	p_main.inventory_changed.emit()
	if p_main.sync:
		p_main.sync.machine_placed(m)
	return m


static func pickup_machine(p_main: Node, m: Machine) -> void:
	var mid: String = m.id
	p_main.machines[mid] = int(p_main.machines.get(mid, 0)) + 1
	if p_main.sync:
		p_main.sync.machine_removed(m.net_id)
	m.queue_free()
	p_main.inventory_changed.emit()


func secondary(pressed: bool) -> void:
	_picking = pressed and is_instance_valid(_hover)
	_pick_t = 0.0
	if not pressed:
		main.hud.set_pull(0.0)


func cancel() -> void:
	_picking = false
	_pick_t = 0.0
	if main and main.hud:
		main.hud.set_pull(0.0)
	if is_instance_valid(_ghost):
		_ghost.visible = false


func _tool_process(delta: float) -> void:
	var hit := ray_hit(RANGE, 1)
	_hover = null
	if not hit.is_empty():
		var n: Node = hit.collider
		while n and not (n is Machine):
			n = n.get_parent()
		if n is Machine:
			_hover = n
	if _picking:
		if not is_instance_valid(_hover):
			cancel()
		else:
			_pick_t = minf(_pick_t + delta / PICKUP_TIME, 1.0)
			main.hud.set_pull(_pick_t)
			if _pick_t >= 1.0:
				var mid: String = _hover.id
				Sfx.play_at("machine_pickup", _hover.global_position, -4.0)
				main.hud.toast("Picked up the %s" % Catalog.item(mid).name.to_lower(), "info")
				if Net.is_client():
					main.sync.req_pickup_machine.rpc_id(1, _hover.net_id)
				else:
					pickup_machine(main, _hover)
				_hover = null
				cancel()
	if not is_instance_valid(_ghost):
		return
	if hit.is_empty() or _hover != null:
		_ghost.visible = false
		_valid = false
		return
	var p: Vector3 = hit.position
	p = Vector3(snappedf(p.x, 0.25), 0.0, snappedf(p.z, 0.25))
	var yaw := _yaw
	if id == "auto_puller":
		yaw = atan2(p.x, p.z)
	_ghost.global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
	_ghost.visible = true
	_validate()
	_ghost_mat.set_shader_parameter("tint", Color(0.3, 1.0, 0.45, 0.35) if _valid else Color(1.0, 0.25, 0.2, 0.4))


func _validate() -> void:
	_valid = true
	_reason = ""
	var xf := _ghost.global_transform
	var fp := _ghost.footprint()
	var center := xf * _ghost.footprint_center()
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			var corner: Vector3 = xf * (_ghost.footprint_center() + Vector3(fp.x * sx, 0, fp.z * sz))
			if not World.on_plate(corner.x, corner.z):
				_valid = false
				_reason = "Machines have to stay on the plate"
				return
	if id == "auto_puller":
		var stack: Haystack = main.haystack
		var flat := Vector2(xf.origin.x, xf.origin.z)
		var edge := stack.edge_radius(atan2(flat.y, flat.x))
		var gap := flat.length() - edge
		if gap > 1.6:
			_valid = false
			_reason = "Put the puller right next to the stack"
			return
		if gap < 0.3:
			_valid = false
			_reason = "Too close, the arm needs a little room"
			return
	var shape := BoxShape3D.new()
	shape.size = Vector3(fp.x - 0.1, fp.y - 0.25, fp.z - 0.1)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(xf.basis, center + Vector3.UP * 0.1)
	params.collision_mask = 1 | 16
	var excl: Array[RID] = [player.get_rid()]
	var ground: Node = main.get_node_or_null("Ground")
	if ground:
		excl.append((ground as CollisionObject3D).get_rid())
	params.exclude = excl
	for h in get_world_3d().direct_space_state.intersect_shape(params, 6):
		if h.collider is HayPiece:
			continue
		_valid = false
		_reason = "Something is in the way"
		return
	if count() <= 0:
		_valid = false
		_reason = "You have no %s left, buy one in the shop" % Catalog.item(id).name.to_lower()


func prompt() -> Dictionary:
	var slot := str(Catalog.item(id).slot)
	if _picking:
		return {"spec": [["RMB", "Keep holding"]], "warn": "", "interact": true}
	if is_instance_valid(_hover):
		return {"spec": [["RMB", "Hold to pick up"], [slot, "Put away"]], "warn": "", "interact": true}
	var spec: Array = [["LMB", "Place"]]
	if id != "auto_puller":
		spec.append(["R", "Rotate"])
	spec.append([slot, "Put away"])
	return {"spec": spec, "warn": _reason if not _valid and _ghost and _ghost.visible else "", "interact": false}


func hud_info() -> String:
	var placed := 0
	for m in get_tree().get_nodes_in_group("machine"):
		if (m as Machine).id == id and not (m as Machine).preview:
			placed += 1
	return "%d to place · %d placed" % [count(), placed]
