# Leaf blower: hold to push loose straws away in a cone in front of you.
class_name BlowerTool
extends HandTool

const RANGE := 7.0
const ANGLE := 32.0

var _blowing := false
var _air: GPUParticles3D
var _loop: AudioStreamPlayer3D
var _net_dt := 0.0


func _configure_viewmodel(vm: MeshInstance3D) -> void:
	_vm_rest = Vector3(0.3, -0.3, -0.6)
	vm.position = _vm_rest
	vm.rotation = Vector3(0.05, 0.08, 0.0)
	_air = GPUParticles3D.new()
	_air.amount = 60
	_air.lifetime = 0.5
	_air.emitting = false
	_air.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 12.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 12.0
	pm.gravity = Vector3.ZERO
	pm.damping_min = 6.0
	pm.damping_max = 10.0
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.35))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	_air.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(0.92, 0.95, 1.0, 0.6)
	q.material = qm
	_air.draw_pass_1 = q
	_air.position = Vector3(0, 0.02, -0.34)
	vm.add_child(_air)


func primary(pressed: bool) -> void:
	_blowing = pressed
	_air.emitting = pressed
	if pressed:
		_loop = Sfx.loop_at("blower_loop", player.camera, -10.0)
	else:
		Sfx.stop_loop(_loop)
		_loop = null


func cancel() -> void:
	if _blowing:
		primary(false)


static func blow(stack: Haystack, origin: Vector3, fwd: Vector3, force: float, delta: float) -> void:
	var cos_a := cos(deg_to_rad(ANGLE))
	for piece in stack.pieces:
		if piece.held_by != null or piece.selling or piece.freeze:
			continue
		var to := piece.global_position - origin
		var d := to.length()
		if d > RANGE or d < 0.05 or to.normalized().dot(fwd) < cos_a:
			continue
		var fall := 1.0 - d / RANGE
		var push := (fwd * 0.8 + to.normalized() * 0.4).normalized()
		piece.sleeping = false
		piece.linear_velocity += push * 22.0 * force * fall * delta + Vector3.UP * 2.5 * force * fall * delta


func _tool_process(delta: float) -> void:
	if not _blowing:
		return
	var fwd := -player.camera.global_basis.z
	var origin := player.camera.global_position
	if Net.is_client():
		_net_dt += delta
		if _net_dt >= 0.066:
			main.sync.req_blow.rpc_id(1, origin, fwd, _net_dt)
			_net_dt = 0.0
	else:
		blow(main.haystack, origin, fwd, float(stat("blower_force")), delta)
	_viewmodel.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.002


func prompt() -> Dictionary:
	return {"spec": [["LMB", "Hold to blow"], ["4", "Put away"]], "warn": "", "interact": false}


func hud_info() -> String:
	return "%.1fx force" % float(stat("blower_force"))
