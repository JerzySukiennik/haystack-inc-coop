# Auto puller: faces the stack, swings its arm to pull a straw out on a timer and drops it onto its output belt.
class_name AutoPuller
extends Machine

const REACH := 2.4

var _arm: Node3D
var _light: MeshInstance3D
var _light_mat: StandardMaterial3D
var _timer := 0.0
var _busy := false
var _hum: AudioStreamPlayer3D


func footprint() -> Vector3:
	return Vector3(1.3, 1.4, 2.9)


func footprint_center() -> Vector3:
	return Vector3(0, 0.8, 0.75)


func _build() -> void:
	var steel := Color(0.36, 0.42, 0.48)
	var dark := Color(0.2, 0.22, 0.25)
	var yellow := Color(0.95, 0.74, 0.18)
	box(Vector3(0, 0.45, -0.1), Vector3(1.2, 0.9, 1.2), steel)
	box(Vector3(0, 0.92, -0.1), Vector3(1.26, 0.06, 1.26), yellow, false)
	box(Vector3(0, 0.05, -0.1), Vector3(1.26, 0.1, 1.26), dark, false)
	box(Vector3(0, 1.1, -0.2), Vector3(0.36, 0.34, 0.36), dark)
	for k in 5:
		box(Vector3(-0.5 + k * 0.25, 0.5, -0.71), Vector3(0.14, 0.5, 0.02), Color(0.85, 0.65, 0.15) if k % 2 == 0 else dark, false)
	belt(Vector3(0, 0, 0.5), Vector3(0, 0, 1), 1.6, true)
	if preview:
		box(Vector3(0, 1.35, -0.8), Vector3(0.12, 0.12, 1.2), yellow, false)


func _build_dynamic() -> void:
	_arm = Node3D.new()
	_arm.position = Vector3(0, 1.28, -0.2)
	add_child(_arm)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var yellow := Color(0.95, 0.74, 0.18)
	var dark := Color(0.2, 0.22, 0.25)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.55)), Vector3(0.14, 0.14, 1.1), yellow)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, -0.08, -1.1)), Vector3(0.24, 0.1, 0.18), dark)
	for s in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(s * 0.09, -0.18, -1.14)), Vector3(0.04, 0.18, 0.06), dark)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = MeshKit.vertex_material(0.6)
	_arm.add_child(mi)
	_light = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	_light.mesh = sm
	_light_mat = StandardMaterial3D.new()
	_light_mat.emission_enabled = true
	_light.material_override = _light_mat
	_light.position = Vector3(0.45, 0.98, 0.35)
	add_child(_light)
	_set_light(true)
	_hum = Sfx.loop_at("machine_hum_loop", self, -24.0)


func _set_light(ok: bool) -> void:
	var c := Color(0.45, 1.0, 0.4) if ok else Color(1.0, 0.35, 0.25)
	_light_mat.albedo_color = c
	_light_mat.emission = c
	_light_mat.emission_energy_multiplier = 2.0


func sockets() -> Array:
	return [world_socket(Vector3(0, 0, 2.1), Vector3(0, 0, 1), false)]


func _stack_point() -> Vector3:
	var stack: Haystack = main.haystack
	var flat := Vector3(global_position.x, 0, global_position.z)
	var a := atan2(flat.z, flat.x) + randf_range(-0.12, 0.12)
	var y := randf_range(0.35, 1.5)
	var r := stack.edge_radius(a)
	var step := 0.05
	while r > 0.2 and stack.surface_height(cos(a) * r, sin(a) * r) < y:
		r -= step
	return Vector3(cos(a) * r, minf(y, stack.surface_height(cos(a) * r, sin(a) * r)), sin(a) * r)


func _process(delta: float) -> void:
	if preview or _busy or main == null:
		return
	_timer += delta
	if _timer < float(main.stat("puller_interval")):
		return
	_timer = 0.0
	_cycle()


func _cycle() -> void:
	var stack: Haystack = main.haystack
	var point := _stack_point()
	var front := global_transform * Vector3(0, 1.1, -0.8)
	if front.distance_to(point) > REACH + 1.2:
		_set_light(false)
		return
	var info := stack.begin_take(point)
	if info.is_empty():
		_set_light(false)
		return
	_set_light(true)
	_busy = true
	var carried := MeshInstance3D.new()
	carried.mesh = MeshKit.straw_mesh()
	carried.material_override = stack.take_material(info)
	main.add_child(carried)
	carried.global_transform = info.transform
	var start_xf: Transform3D = info.transform
	var local_target := to_local(point)
	var yaw := atan2(local_target.x, -local_target.z)
	var pitch := atan2(local_target.y - 1.28, Vector2(local_target.x, local_target.z).length())
	var tray := global_transform * Vector3(0, ConveyorLine.TOP + 0.35, 1.1)
	Sfx.play_at("machine_arm", global_position + Vector3.UP, -10.0)
	var tw := create_tween()
	tw.tween_property(_arm, "rotation", Vector3(pitch * 0.6, -yaw, 0), 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(carried):
			var p := start_xf.origin.lerp(tray, t) + Vector3.UP * sin(t * PI) * 0.8
			carried.global_transform = Transform3D(start_xf.basis, p), 0.0, 1.0, 0.55)
	tw.parallel().tween_property(_arm, "rotation", Vector3(-0.9, 0, 0), 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		var xf := carried.global_transform
		carried.queue_free()
		var piece := stack.finish_take(info, xf)
		piece.linear_velocity = Vector3.ZERO
		piece.global_basis = global_basis * Basis(Vector3.UP, PI * 0.5)
		piece.set_meta("machine_puller", true)
		_busy = false)
	tw.tween_property(_arm, "rotation", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_SINE)
