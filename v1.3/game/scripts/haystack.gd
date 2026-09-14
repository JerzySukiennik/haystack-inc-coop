# The haystack: low-poly mound with straw fuzz, a virtual piece counter and the physical hay pieces pulled out of it.
class_name Haystack
extends StaticBody3D

signal count_changed(remaining: int)
signal piece_pulled(piece: HayPiece)

const START_COUNT := 1_000_000
const MAX_PIECES := 900
const LOOSE_PIECES := 240
const SHELL_STRAWS := 140000
const SHELL_DEPTH := 0.24
const CELL := 0.5

var radius := 5.6
var height := 4.4
var remaining := START_COUNT
var rescued := 0
var pieces: Array[HayPiece] = []
var pieces_root: Node3D

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _straw_mesh: ArrayMesh
var _materials := {}
var _hay_mat: StandardMaterial3D
var _straw_mat: StandardMaterial3D
var _shell: MultiMesh
var _shell_pos := PackedVector3Array()
var _shell_xf := PackedFloat32Array()
var _shell_col := PackedColorArray()
var _shell_depth := PackedFloat32Array()
var _shell_cells := {}
var _safety_timer := 0.0


func _ready() -> void:
	add_to_group("haystack")
	collision_layer = 1
	collision_mask = 0
	_noise.seed = 4242
	_noise.frequency = 0.35
	_rng.seed = 777
	_hay_mat = MeshKit.vertex_material(0.95, BaseMaterial3D.CULL_DISABLED)
	_straw_mat = MeshKit.vertex_material(0.95, BaseMaterial3D.CULL_DISABLED)
	_straw_mesh = MeshKit.straw_mesh()
	pieces_root = Node3D.new()
	pieces_root.name = "HayPieces"
	get_parent().add_child.call_deferred(pieces_root)
	_build_mound()
	_build_fuzz()


func edge_radius(angle: float) -> float:
	return radius * (1.0 + _noise.get_noise_2d(cos(angle) * 2.0, sin(angle) * 2.0) * 0.16)


func surface_height(x: float, z: float) -> float:
	var t := Vector2(x, z).length() / edge_radius(atan2(z, x))
	if t >= 1.0:
		return -0.2
	var h := height * pow(1.0 - pow(t, 2.3), 0.62)
	h += _noise.get_noise_2d(x * 1.1, z * 1.1) * 0.28 * (1.0 - t * 0.5)
	return h


func surface_normal(x: float, z: float) -> Vector3:
	var e := 0.15
	var dx := surface_height(x + e, z) - surface_height(x - e, z)
	var dz := surface_height(x, z + e) - surface_height(x, z - e)
	return Vector3(-dx / (2.0 * e), 1.0, -dz / (2.0 * e)).normalized()


func _mound_grid(inset: float) -> Array:
	var rings := 26
	var segs := 64
	var grid := []
	for i in rings + 1:
		var row := []
		var t := float(i) / rings
		for j in segs:
			var a := TAU * j / segs + (PI / segs if i % 2 == 1 else 0.0)
			var edge := edge_radius(a) - inset
			var r := edge * minf(t, 0.999) + (0.25 if i == rings else 0.0)
			var x := cos(a) * r
			var z := sin(a) * r
			var y := surface_height(x * (edge + inset) / edge, z * (edge + inset) / edge) - inset if i < rings else -0.25
			row.append(Vector3(x, y, z))
		grid.append(row)
	return grid


func _mound_mesh(inset: float, col_fn: Callable) -> ArrayMesh:
	var grid := _mound_grid(inset)
	var rings := grid.size() - 1
	var segs: int = grid[0].size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0, -2.0, 0)
	var top := Vector3(0, surface_height(0, 0) + 0.05 - inset, 0)
	for j in segs:
		var a: Vector3 = grid[1][j]
		var b: Vector3 = grid[1][(j + 1) % segs]
		MeshKit.add_tri_out(st, top, a, b, center, col_fn.call((top + a + b) / 3.0))
	for i in range(1, rings):
		for j in segs:
			var j1 := (j + 1) % segs
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i][j1]
			var c: Vector3 = grid[i + 1][j1]
			var d: Vector3 = grid[i + 1][j]
			MeshKit.add_tri_out(st, a, b, c, center, col_fn.call((a + b + c) / 3.0))
			MeshKit.add_tri_out(st, a, c, d, center, col_fn.call((a + c + d) / 3.0))
	return st.commit()


func _build_mound() -> void:
	var surface := _mound_mesh(0.0, func(_p: Vector3) -> Color: return Color.WHITE)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(surface.get_faces())
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)
	var core := MeshInstance3D.new()
	core.mesh = _mound_mesh(SHELL_DEPTH, func(p: Vector3) -> Color:
		return Color(0.30, 0.21, 0.09).lerp(Color(0.40, 0.29, 0.12), clampf(_noise.get_noise_2d(p.x * 4.0, p.z * 4.0) + 0.5, 0.0, 1.0)))
	core.material_override = MeshKit.vertex_material(1.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)


func _surface_point(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var a := rng.randf() * TAU
		var r := edge_radius(a) * sqrt(rng.randf()) * 0.995
		var x := cos(a) * r
		var z := sin(a) * r
		var n := surface_normal(x, z)
		if rng.randf() < 0.3 / maxf(n.y, 0.3):
			return Vector3(x, surface_height(x, z), z)
	return Vector3.ZERO


func _build_fuzz() -> void:
	var count := SHELL_STRAWS
	_shell = MultiMesh.new()
	_shell.transform_format = MultiMesh.TRANSFORM_3D
	_shell.use_colors = true
	_shell.mesh = _straw_mesh
	_shell.instance_count = count
	_shell_pos.resize(count)
	_shell_xf.resize(count * 12)
	_shell_col.resize(count)
	_shell_depth.resize(count)
	for i in count:
		var s := _surface_point(_rng)
		var n := surface_normal(s.x, s.z)
		var depth := pow(_rng.randf(), 1.6) * SHELL_DEPTH
		var tangent := n.cross(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))).normalized()
		var tilt := _rng.randf_range(-0.2, 0.3) if _rng.randf() > 0.07 else _rng.randf_range(0.4, 1.0)
		var dir := (tangent * cos(tilt) + n * sin(tilt)).normalized()
		var length := _rng.randf_range(0.32, 0.58)
		var mid := s - n * depth
		var p := mid - dir * length * 0.5
		var xf := Transform3D(MeshKit.basis_along(dir, length), p)
		_shell.set_instance_transform(i, xf)
		_store_xf(i, xf)
		var shade := clampf(depth / SHELL_DEPTH, 0.0, 1.0)
		var base := MeshKit.hay_color(_rng)
		base = base.lerp(Color(0.62, 0.46, 0.20), clampf(0.35 - s.y * 0.25, 0.0, 0.35))
		var col := base.darkened(shade * 0.45 + _rng.randf_range(0.0, 0.08))
		_shell.set_instance_color(i, col)
		_shell_col[i] = col
		_shell_pos[i] = mid
		_shell_depth[i] = depth
		var key := _cell_key(mid)
		if not _shell_cells.has(key):
			_shell_cells[key] = PackedInt32Array()
		var arr: PackedInt32Array = _shell_cells[key]
		arr.append(i)
		_shell_cells[key] = arr
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _shell
	mmi.material_override = _straw_mat
	add_child(mmi)


func _store_xf(i: int, xf: Transform3D) -> void:
	var o := i * 12
	var b := xf.basis
	for k in 3:
		_shell_xf[o + k] = b.x[k]
		_shell_xf[o + 3 + k] = b.y[k]
		_shell_xf[o + 6 + k] = b.z[k]
		_shell_xf[o + 9 + k] = xf.origin[k]


func _load_xf(i: int) -> Transform3D:
	var o := i * 12
	return Transform3D(
		Vector3(_shell_xf[o], _shell_xf[o + 1], _shell_xf[o + 2]),
		Vector3(_shell_xf[o + 3], _shell_xf[o + 4], _shell_xf[o + 5]),
		Vector3(_shell_xf[o + 6], _shell_xf[o + 7], _shell_xf[o + 8]),
		Vector3(_shell_xf[o + 9], _shell_xf[o + 10], _shell_xf[o + 11]))


func _cell_key(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))


func _find_shell_straw(point: Vector3) -> int:
	var c := _cell_key(point)
	for reach in [1, 2, 3]:
		var best := -1
		var best_score := 1e9
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				for dz in range(-reach, reach + 1):
					var key := c + Vector3i(dx, dy, dz)
					if not _shell_cells.has(key):
						continue
					for idx: int in _shell_cells[key]:
						if _shell_depth[idx] < 0.0:
							continue
						var score: float = _shell_pos[idx].distance_to(point) + _shell_depth[idx] * 2.5
						if score < best_score:
							best_score = score
							best = idx
		if best >= 0:
			return best
	return -1


func begin_take(point: Vector3) -> Dictionary:
	if remaining <= 0:
		return {}
	var idx := _find_shell_straw(point)
	if idx < 0:
		return {}
	var xf := _load_xf(idx)
	var info := {
		"index": idx,
		"transform": global_transform * xf,
		"color": _shell_col[idx],
		"length": xf.basis.y.length(),
		"depth": _shell_depth[idx],
	}
	_shell_depth[idx] = -1.0
	_shell.set_instance_transform(idx, Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin))
	return info


func restore_take(info: Dictionary) -> void:
	if info.is_empty():
		return
	var idx: int = info.index
	_shell_depth[idx] = info.depth
	_shell.set_instance_transform(idx, global_transform.affine_inverse() * (info.transform as Transform3D))


func straw_material(color: Color) -> StandardMaterial3D:
	var key := Color(snappedf(color.r, 0.02), snappedf(color.g, 0.02), snappedf(color.b, 0.02))
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = key
		m.roughness = 0.95
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = m
	return _materials[key]


func finish_take(info: Dictionary, mesh_xf: Transform3D) -> HayPiece:
	remaining -= 1
	count_changed.emit(remaining)
	var length: float = info.length
	var dir := mesh_xf.basis.y.normalized()
	var center := mesh_xf.origin + dir * length * 0.5
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var piece := spawn_piece(center, Basis(dir, side.cross(dir).normalized(), side), info.color, length)
	_burst(center, surface_normal(center.x, center.z))
	piece_pulled.emit(piece)
	return piece


func _spawn_loose() -> void:
	for i in LOOSE_PIECES:
		var a := _rng.randf() * TAU
		var r := edge_radius(a) + pow(_rng.randf(), 1.8) * 4.0 + 0.1
		var pos := Vector3(cos(a) * r, _rng.randf_range(0.35, 0.8), sin(a) * r)
		var basis := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))
		spawn_piece(pos, basis, MeshKit.hay_color(_rng).darkened(_rng.randf_range(0.0, 0.2)), _rng.randf_range(0.32, 0.58))


func spawn_piece(pos: Vector3, basis: Basis, color: Color, length: float) -> HayPiece:
	var piece := HayPiece.new()
	piece.setup(_straw_mesh, straw_material(color), length)
	pieces_root.add_child(piece)
	piece.global_transform = Transform3D(basis.orthonormalized(), pos)
	pieces.append(piece)
	piece.tree_exited.connect(func() -> void: pieces.erase(piece))
	_enforce_cap()
	return piece


func _physics_process(delta: float) -> void:
	_safety_timer += delta
	if _safety_timer < 0.5:
		return
	_safety_timer = 0.0
	for piece in pieces:
		if piece.global_position.y < -0.6 and piece.held_by == null:
			var flat := Vector2(piece.global_position.x, piece.global_position.z)
			var up := maxf(surface_height(flat.x, flat.y), 0.0) + 0.4
			piece.global_position = Vector3(flat.x, up, flat.y)
			piece.linear_velocity = Vector3.ZERO
			rescued += 1


func _enforce_cap() -> void:
	var i := 0
	while pieces.size() > MAX_PIECES and i < pieces.size():
		var p := pieces[i]
		if p.held_by == null:
			pieces.remove_at(i)
			p.despawn()
		else:
			i += 1


func _burst(point: Vector3, normal: Vector3) -> void:
	var parts := GPUParticles3D.new()
	parts.one_shot = true
	parts.amount = 10
	parts.lifetime = 1.4
	parts.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.direction = normal
	pm.spread = 55.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, -6.0, 0)
	pm.angular_velocity_min = -540.0
	pm.angular_velocity_max = 540.0
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.scale_min = 0.12
	pm.scale_max = 0.3
	pm.color = Color(0.9, 0.76, 0.42)
	parts.process_material = pm
	parts.draw_pass_1 = MeshKit.straw_mesh()
	parts.material_override = _straw_mat
	get_parent().add_child(parts)
	parts.global_position = point
	parts.emitting = true
	get_tree().create_timer(2.0).timeout.connect(parts.queue_free)
