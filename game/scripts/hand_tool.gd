# Base for handheld tools: equip animation, viewmodel, reach raycasts and the prompt contract used by the tool belt.
class_name HandTool
extends Node3D

var main: Node
var player: Player
var id := ""
var equipped := false
var _viewmodel: MeshInstance3D
var _vm_rest := Vector3(0.28, -0.26, -0.5)
var _vm_kick := 0.0


func setup(p_main: Node, p_player: Player, p_id: String) -> void:
	main = p_main
	player = p_player
	id = p_id
	_viewmodel = MeshInstance3D.new()
	_viewmodel.mesh = Items.mesh_for(id)
	_viewmodel.material_override = MeshKit.vertex_material(0.6)
	_viewmodel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_viewmodel.visible = false
	_configure_viewmodel(_viewmodel)
	player.camera.add_child(_viewmodel)


func _configure_viewmodel(vm: MeshInstance3D) -> void:
	vm.position = _vm_rest
	vm.rotation = Vector3(0.3, 0.35, 0.0)


func set_equipped(on: bool) -> void:
	if on == equipped:
		return
	equipped = on
	_viewmodel.visible = on
	if on:
		player.drop()
		player.cancel_pull()
		_viewmodel.position = _vm_rest + Vector3(0, -0.25, 0)
		create_tween().tween_property(_viewmodel, "position", _vm_rest, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play_ui("equip", -12.0)
	else:
		cancel()


func level() -> int:
	return int(main.levels.get(id, 0))


func stat(name: String) -> Variant:
	return main.stat(name)


func primary(_pressed: bool) -> void:
	pass


func secondary(_pressed: bool) -> void:
	pass


func rotate_action() -> void:
	pass


func scroll(_steps: int) -> bool:
	return false


func cancel() -> void:
	pass


func captures_scroll() -> bool:
	return false


func prompt() -> Dictionary:
	return {"spec": [], "warn": "", "interact": false}


func hud_info() -> String:
	return ""


func ray_hit(range_m: float, mask: int, areas := false) -> Dictionary:
	var cam := player.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * range_m, mask)
	q.exclude = [player.get_rid()]
	q.collide_with_areas = areas
	return get_world_3d().direct_space_state.intersect_ray(q)


func kick(amount := 1.0) -> void:
	_vm_kick = amount


func _process(delta: float) -> void:
	if not equipped or _viewmodel == null:
		return
	_vm_kick = move_toward(_vm_kick, 0.0, delta * 5.0)
	_viewmodel.position = _viewmodel.position.lerp(_vm_rest + Vector3(0, 0, -0.12 * _vm_kick), 1.0 - exp(-delta * 18.0))
	_tool_process(delta)


func _tool_process(_delta: float) -> void:
	pass


func pieces_in_cone(range_m: float, angle_deg: float) -> Array[HayPiece]:
	var out: Array[HayPiece] = []
	var cam := player.camera
	var origin := cam.global_position
	var fwd := -cam.global_basis.z
	var cos_a := cos(deg_to_rad(angle_deg))
	var stack: Haystack = main.haystack
	for piece: HayPiece in stack.pieces:
		if piece.held_by != null or piece.selling or piece.freeze:
			continue
		var to := piece.global_position - origin
		var d := to.length()
		if d > range_m or d < 0.05:
			continue
		if to.normalized().dot(fwd) >= cos_a:
			out.append(piece)
	return out
