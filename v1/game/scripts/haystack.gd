# The haystack: low-poly mound with straw fuzz, a virtual piece counter and the physical hay pieces pulled out of it.
class_name Haystack
extends StaticBody3D

signal count_changed(remaining: int)
signal piece_pulled(piece: HayPiece)

const START_COUNT := 1_000_000
const MAX_PIECES := 450
const LOOSE_PIECES := 48

var radius := 5.6
var height := 4.4
var remaining := START_COUNT
var pieces: Array[HayPiece] = []
var pieces_root: Node3D

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _clumps: Array[ArrayMesh] = []
var _hay_mat: StandardMaterial3D
var _straw_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("haystack")
	collision_layer = 1
	collision_mask = 0
	_noise.seed = 4242
	_noise.frequency = 0.35
	_rng.seed = 777
	_hay_mat = MeshKit.vertex_material(0.95, BaseMaterial3D.CULL_DISABLED)
	_straw_mat = MeshKit.vertex_material(0.95, BaseMaterial3D.CULL_DISABLED)
	for i in 10:
		_clumps.append(MeshKit.hay_clump(_rng))
	pieces_root = Node3D.new()
	pieces_root.name = "HayPieces"
	get_parent().add_child.call_deferred(pieces_root)
	_build_mound()
	_build_fuzz()
	_build_ground_straws()
	_spawn_loose.call_deferred()


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


func _mound_color(p: Vector3) -> Color:
	var n := _noise.get_noise_2d(p.x * 3.0 + 100.0, p.z * 3.0 + p.y * 2.0)
	var base := Color(0.78, 0.59, 0.25).lerp(Color(0.90, 0.73, 0.37), clampf(n * 0.9 + 0.5, 0.0, 1.0))
	return Color(0.46, 0.34, 0.15).lerp(base, clampf(p.y / 1.3 + 0.25, 0.0, 1.0))


func _build_mound() -> void:
	var rings := 26
	var segs := 64
	var grid := []
	for i in rings + 1:
		var row := []
		var t := float(i) / rings
		for j in segs:
			var a := TAU * j / segs + (PI / segs if i % 2 == 1 else 0.0)
			var r := edge_radius(a) * minf(t, 0.999) + (0.25 if i == rings else 0.0)
			var x := cos(a) * r
			var z := sin(a) * r
			var y := surface_height(x, z) if i < rings else -0.25
			row.append(Vector3(x, y, z))
		grid.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0, -2.0, 0)
	var top := Vector3(0, surface_height(0, 0) + 0.05, 0)
	for j in segs:
		var a: Vector3 = grid[1][j]
		var b: Vector3 = grid[1][(j + 1) % segs]
		MeshKit.add_tri_out(st, top, a, b, center, _mound_color((top + a + b) / 3.0))
	for i in range(1, rings):
		for j in segs:
			var j1 := (j + 1) % segs
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i][j1]
			var c: Vector3 = grid[i + 1][j1]
			var d: Vector3 = grid[i + 1][j]
			MeshKit.add_tri_out(st, a, b, c, center, _mound_color((a + b + c) / 3.0))
			MeshKit.add_tri_out(st, a, c, d, center, _mound_color((a + c + d) / 3.0))
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MeshKit.vertex_material(1.0)
	add_child(mi)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)


func _build_fuzz() -> void:
	var count := 14000
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = MeshKit.straw_mesh()
	mm.instance_count = count
	for i in count:
		var a := _rng.randf() * TAU
		var r := edge_radius(a) * sqrt(_rng.randf()) * 0.985
		var x := cos(a) * r
		var z := sin(a) * r
		var n := surface_normal(x, z)
		var tangent := n.cross(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))).normalized()
		var tilt := _rng.randf_range(0.05, 0.75)
		var dir := (tangent * cos(tilt) + n * sin(tilt)).normalized()
		var length := _rng.randf_range(0.3, 0.75)
		var p := Vector3(x, surface_height(x, z), z) - dir * length * 0.3
		mm.set_instance_transform(i, Transform3D(MeshKit.basis_along(dir, length), p))
		mm.set_instance_color(i, _mound_color(p).lerp(MeshKit.hay_color(_rng), 0.5).darkened(_rng.randf_range(0.0, 0.2)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _straw_mat
	add_child(mmi)


func _build_ground_straws() -> void:
	var count := 4200
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = MeshKit.straw_mesh()
	mm.instance_count = count
	for i in count:
		var a := _rng.randf() * TAU
		var r := edge_radius(a) * 0.95 + pow(_rng.randf(), 2.2) * 5.5
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.0, 0.12), _rng.randf_range(-1, 1)).normalized()
		var length := _rng.randf_range(0.25, 0.6)
		var p := Vector3(cos(a) * r, 0.01, sin(a) * r) - dir * length * 0.5
		mm.set_instance_transform(i, Transform3D(MeshKit.basis_along(dir, length), p))
		mm.set_instance_color(i, MeshKit.hay_color(_rng).darkened(_rng.randf_range(0.0, 0.25)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _straw_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _spawn_loose() -> void:
	for i in LOOSE_PIECES:
		var a := _rng.randf() * TAU
		var r := edge_radius(a) + _rng.randf_range(0.2, 3.2)
		var pos := Vector3(cos(a) * r, _rng.randf_range(0.3, 1.2), sin(a) * r)
		spawn_piece(pos, Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)))


func spawn_piece(pos: Vector3, basis: Basis = Basis.IDENTITY) -> HayPiece:
	var piece := HayPiece.new()
	piece.setup(_clumps[_rng.randi() % _clumps.size()], _hay_mat)
	pieces_root.add_child(piece)
	piece.global_transform = Transform3D(basis, pos)
	pieces.append(piece)
	piece.tree_exited.connect(func() -> void: pieces.erase(piece))
	_enforce_cap()
	return piece


func pull_piece(point: Vector3, normal: Vector3) -> HayPiece:
	if remaining <= 0:
		return null
	remaining -= 1
	count_changed.emit(remaining)
	var pos := point + normal * 0.35
	pos.y = maxf(pos.y, 0.35)
	var piece := spawn_piece(pos, Basis.from_euler(Vector3(0, _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3))))
	_burst(point, normal)
	piece_pulled.emit(piece)
	return piece


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
	parts.amount = 26
	parts.lifetime = 1.4
	parts.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.direction = normal
	pm.spread = 55.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 3.2
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
