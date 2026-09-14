# Builds the yard: lighting, sky, low-poly terrain, wind-blown grass, trees, rocks, fence, shed and dust motes.
class_name World
extends RefCounted

const YARD_HALF := 19.0
const SHOP_POS := Vector3(25.0, 0.0, -25.0)
const CLEAR_ZONES := [Vector3(25.0, -25.0, 6.5), Vector3(-17.3, 17.3, 5.0)]
const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float wind = 0.09;
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float gust = sin(TIME * 0.6 + wp.x * 0.05) * 0.5 + 0.5;
	VERTEX.x += sin(TIME * 1.8 + wp.x * 0.35 + wp.z * 0.22) * wind * h * (0.6 + gust);
	VERTEX.z += cos(TIME * 1.4 + wp.z * 0.31) * wind * 0.6 * h;
}
void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
"""

static var noise: FastNoiseLite


static func ground_height(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var hills := smoothstep(34.0, 110.0, d) * (7.0 + noise.get_noise_2d(x * 0.55, z * 0.55) * 11.0) + smoothstep(150.0, 300.0, d) * 22.0
	var bumps := noise.get_noise_2d(x * 2.4, z * 2.4) * 0.22 * smoothstep(8.0, 22.0, d)
	return hills + bumps


static func is_clear(x: float, z: float, extra := 0.0) -> bool:
	for c: Vector3 in CLEAR_ZONES:
		if Vector2(x - c.x, z - c.y).length() < c.z + extra:
			return false
	return true


static func build(root: Node3D) -> void:
	noise = FastNoiseLite.new()
	noise.seed = 1337
	noise.frequency = 0.02
	_environment(root)
	_ground(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	_grass(root, rng)
	_trees(root, rng)
	_rocks(root, rng)
	_fence(root)
	_shed(root, Vector3(-11.5, 0, -12.5), deg_to_rad(28.0))
	_crates(root, rng)
	_dust(root)


static func _environment(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -38, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	root.add_child(sun)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.46, 0.82)
	sky_mat.sky_horizon_color = Color(0.70, 0.80, 0.88)
	sky_mat.ground_horizon_color = Color(0.72, 0.70, 0.62)
	sky_mat.ground_bottom_color = Color(0.32, 0.30, 0.24)
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.62, 0.58, 0.50)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.ssao_enabled = not "--no-ssao" in OS.get_cmdline_user_args()
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.sdfgi_enabled = false
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.82, 0.86)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0012
	env.volumetric_fog_albedo = Color(1.0, 0.95, 0.85)
	env.volumetric_fog_length = 64.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)


static func _ground(root: Node3D) -> void:
	var size := 640.0
	var cell := 4.0
	var n := int(size / cell)
	var half := size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for i in n + 1:
		var row := []
		for j in n + 1:
			var x := -half + j * cell
			var z := -half + i * cell
			if i > 0 and i < n and j > 0 and j < n:
				x += noise.get_noise_2d(x * 5.0, z * 5.0) * cell * 0.3
				z += noise.get_noise_2d(z * 5.0, x * 5.0) * cell * 0.3
			row.append(Vector3(x, ground_height(x, z), z))
		pts.append(row)
	for i in n:
		for j in n:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j + 1]
			var c: Vector3 = pts[i + 1][j + 1]
			var d: Vector3 = pts[i + 1][j]
			MeshKit.add_tri_up(st, a, b, c, _ground_color((a + b + c) / 3.0))
			MeshKit.add_tri_up(st, a, c, d, _ground_color((a + c + d) / 3.0))
	var mesh := st.commit()
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MeshKit.vertex_material(1.0)
	body.add_child(mi)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)


static func _ground_color(p: Vector3) -> Color:
	var d := Vector2(p.x, p.z).length()
	var v := noise.get_noise_2d(p.x * 4.0, p.z * 4.0)
	var dirt := Color(0.48, 0.37, 0.24).lerp(Color(0.56, 0.44, 0.29), v * 0.5 + 0.5)
	var grass := Color(0.35, 0.53, 0.22).lerp(Color(0.46, 0.60, 0.26), v * 0.5 + 0.5)
	var hill := Color(0.52, 0.60, 0.30).lerp(Color(0.40, 0.55, 0.25), noise.get_noise_2d(p.x, p.z) * 0.5 + 0.5)
	var blend := smoothstep(7.5, 12.5, d + v * 2.5)
	var c := dirt.lerp(grass, blend)
	return c.lerp(hill, smoothstep(2.0, 9.0, p.y))


static func _grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 5:
		var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
		var side := Vector3(cos(a), 0, sin(a)) * 0.06
		var lean := Vector3(-sin(a), 0, cos(a)) * rng.randf_range(-0.1, 0.1)
		var h := rng.randf_range(0.2, 0.38)
		var root_col := Color(0.62, 0.62, 0.62)
		MeshKit.add_tri(st, -side, side, lean + Vector3.UP * h, Vector3.UP, root_col)
	var mesh := st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	for v in verts:
		cols.append(Color(0.78, 0.8, 0.72).lerp(Color(1.12, 1.12, 1.0), clampf(v.y / 0.35, 0.0, 1.0)))
	arrays[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func _grass(root: Node3D, rng: RandomNumberGenerator) -> void:
	var count := 30000
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _grass_mesh()
	mm.instance_count = count
	var placed := 0
	while placed < count:
		var d := lerpf(9.5, 95.0, pow(rng.randf(), 1.6))
		var a := rng.randf() * TAU
		var x := cos(a) * d
		var z := sin(a) * d
		if absf(x) < 3.0 and z > YARD_HALF - 2.0 and z < 40.0:
			continue
		if not is_clear(x, z):
			continue
		var s := rng.randf_range(0.7, 1.5)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(x, ground_height(x, z) - 0.02, z))
		mm.set_instance_transform(placed, xf)
		var tint := Color(0.33, 0.52, 0.20).lerp(Color(0.50, 0.62, 0.26), rng.randf())
		mm.set_instance_color(placed, tint)
		placed += 1
	var mmi := MultiMeshInstance3D.new()
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GRASS_SHADER
	mat.shader = sh
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 140.0
	root.add_child(mmi)


static func _tree_mesh(kind: int, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.40, 0.28, 0.18)
	if kind == 0:
		MeshKit.add_cylinder(st, Vector3.ZERO, 1.6, 0.28, 0.2, 6, bark, bark)
		var greens := [Color(0.20, 0.42, 0.24), Color(0.24, 0.47, 0.26), Color(0.17, 0.37, 0.22)]
		var y := 1.1
		var r := 2.3
		for i in 4:
			var g: Color = greens[i % greens.size()]
			MeshKit.add_cylinder(st, Vector3(0, y, 0), 2.6 - i * 0.25, r, 0.0, 7, g, g)
			y += 1.55
			r *= 0.74
	else:
		MeshKit.add_cylinder(st, Vector3.ZERO, 2.6, 0.32, 0.2, 6, bark, bark)
		var greens := [Color(0.35, 0.55, 0.22), Color(0.42, 0.62, 0.26), Color(0.30, 0.50, 0.20)]
		MeshKit.add_blob(st, Vector3(0, 3.7, 0), Vector3(2.3, 1.9, 2.3), rng, 0.18, greens)
		MeshKit.add_blob(st, Vector3(1.1, 3.1, 0.6), Vector3(1.4, 1.2, 1.4), rng, 0.2, greens)
		MeshKit.add_blob(st, Vector3(-0.9, 3.3, -0.7), Vector3(1.5, 1.3, 1.5), rng, 0.2, greens)
	return st.commit()


static func _trees(root: Node3D, rng: RandomNumberGenerator) -> void:
	var meshes: Array[ArrayMesh] = []
	for k in 6:
		meshes.append(_tree_mesh(k % 2, rng))
	var mat := MeshKit.vertex_material(0.95)
	var count := 0
	var tries := 0
	while count < 90 and tries < 2000:
		tries += 1
		var d := rng.randf_range(27.0, 120.0)
		var a := rng.randf() * TAU
		var x := cos(a) * d
		var z := sin(a) * d
		if absf(x) < 5.0 and z > 0.0 and d < 60.0:
			continue
		if not is_clear(x, z, 3.0):
			continue
		var y := ground_height(x, z)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[rng.randi() % meshes.size()]
		mi.material_override = mat
		var s := rng.randf_range(0.8, 1.45)
		mi.scale = Vector3.ONE * s
		body.add_child(mi)
		var shape := CylinderShape3D.new()
		shape.radius = 0.3 * s
		shape.height = 3.0 * s
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position.y = 1.5 * s
		body.add_child(cs)
		body.position = Vector3(x, y - 0.1, z)
		body.rotation.y = rng.randf() * TAU
		root.add_child(body)
		count += 1


static func _rocks(root: Node3D, rng: RandomNumberGenerator) -> void:
	var greys := [Color(0.52, 0.51, 0.49), Color(0.60, 0.59, 0.56), Color(0.46, 0.45, 0.44)]
	var mat := MeshKit.vertex_material(0.9)
	for i in 26:
		var d := rng.randf_range(15.0, 70.0)
		var a := rng.randf() * TAU
		var x := cos(a) * d
		var z := sin(a) * d
		if not is_clear(x, z, 1.5):
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var s := Vector3(rng.randf_range(0.4, 1.4), rng.randf_range(0.3, 0.9), rng.randf_range(0.4, 1.3))
		MeshKit.add_blob(st, Vector3.ZERO, s, rng, 0.25, greys)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_convex_shape(true, false)
		body.add_child(cs)
		body.add_to_group("rock")
		body.position = Vector3(x, ground_height(x, z) + s.y * 0.2, z)
		body.rotation.y = rng.randf() * TAU
		root.add_child(body)


static func _fence(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.55, 0.40, 0.26)
	var wood_dark := Color(0.45, 0.32, 0.21)
	var body := StaticBody3D.new()
	body.name = "Fence"
	body.collision_layer = 1
	var h := YARD_HALF
	var sides := [
		[Vector3(-h, 0, -h), Vector3(h, 0, -h)],
		[Vector3(h, 0, -h), Vector3(h, 0, h)],
		[Vector3(h, 0, h), Vector3(2.8, 0, h)],
		[Vector3(-2.8, 0, h), Vector3(-h, 0, h)],
		[Vector3(-h, 0, h), Vector3(-h, 0, -h)],
	]
	for side in sides:
		var a: Vector3 = side[0]
		var b: Vector3 = side[1]
		var length := a.distance_to(b)
		var dir := (b - a).normalized()
		var basis := Basis(Vector3.UP, atan2(-dir.z, dir.x))
		var posts := int(ceil(length / 2.5))
		for k in posts + 1:
			var p := a + dir * (length * k / posts)
			var tilt := Basis(Vector3(1, 0, 0), sin(p.x * 3.1 + p.z) * 0.04)
			MeshKit.add_box(st, Transform3D(basis * tilt, p + Vector3.UP * 0.62), Vector3(0.16, 1.24, 0.16), wood_dark)
		for rail_y in [0.48, 0.98]:
			var mid: Vector3 = (a + b) * 0.5 + Vector3.UP * rail_y
			MeshKit.add_box(st, Transform3D(basis, mid + basis.z * 0.1), Vector3(length, 0.13, 0.05), wood)
		var shape := BoxShape3D.new()
		shape.size = Vector3(length, 1.3, 0.3)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = Transform3D(basis, (a + b) * 0.5 + Vector3.UP * 0.65)
		body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = MeshKit.vertex_material(0.9)
	body.add_child(mi)
	root.add_child(body)


static func _shed(root: Node3D, pos: Vector3, yaw: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 6.5
	var d := 5.0
	var wall_h := 3.0
	var roof_h := 1.9
	var red := Color(0.62, 0.23, 0.17)
	var red_dark := Color(0.52, 0.19, 0.14)
	var trim := Color(0.90, 0.87, 0.80)
	var roof := Color(0.30, 0.28, 0.27)
	for k in 9:
		var x := -w * 0.5 + w * (k + 0.5) / 9.0
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(x, wall_h * 0.5, d * 0.5)), Vector3(w / 9.0 - 0.02, wall_h, 0.12), red if k % 2 == 0 else red_dark)
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(x, wall_h * 0.5, -d * 0.5)), Vector3(w / 9.0 - 0.02, wall_h, 0.12), red if k % 2 == 1 else red_dark)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(w * 0.5, wall_h * 0.5, 0)), Vector3(0.12, wall_h, d), red_dark)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(-w * 0.5, wall_h * 0.5, 0)), Vector3(0.12, wall_h, d), red_dark)
	for sx in [-1.0, 1.0]:
		var a := Vector3(sx * w * 0.5, wall_h, d * 0.5 + 0.02)
		var b := Vector3(sx * w * 0.5, wall_h, -d * 0.5 - 0.02)
		var peak_f := Vector3(0, wall_h + roof_h, d * 0.5 + 0.02)
		var peak_b := Vector3(0, wall_h + roof_h, -d * 0.5 - 0.02)
		MeshKit.add_tri_out(st, a, Vector3(0, wall_h, a.z), peak_f, Vector3(0, wall_h, 0), red)
		MeshKit.add_tri_out(st, b, Vector3(0, wall_h, b.z), peak_b, Vector3(0, wall_h, 0), red)
	var over := 0.45
	var roof_center := Vector3(0, wall_h + roof_h * 0.4, 0)
	for sx in [-1.0, 1.0]:
		var e0 := Vector3(sx * (w * 0.5 + over), wall_h - over * roof_h / (w * 0.5), d * 0.5 + over)
		var e1 := Vector3(sx * (w * 0.5 + over), wall_h - over * roof_h / (w * 0.5), -d * 0.5 - over)
		var p0 := Vector3(0, wall_h + roof_h + 0.08, d * 0.5 + over)
		var p1 := Vector3(0, wall_h + roof_h + 0.08, -d * 0.5 - over)
		MeshKit.add_quad_out(st, e0, e1, p1, p0, roof_center, roof)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 1.1, d * 0.5 + 0.08)), Vector3(2.2, 2.2, 0.06), Color(0.36, 0.14, 0.10))
	for s: Vector3 in [Vector3(0, 2.25, d * 0.5 + 0.1), Vector3(-1.13, 1.1, d * 0.5 + 0.1), Vector3(1.13, 1.1, d * 0.5 + 0.1)]:
		var size: Vector3 = Vector3(2.4, 0.12, 0.08) if s.y > 2.0 else Vector3(0.12, 2.3, 0.08)
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, s), size, trim)
	MeshKit.add_box(st, Transform3D(Basis(Vector3(0, 0, 1), 0.78), Vector3(0, 1.1, d * 0.5 + 0.12)), Vector3(2.9, 0.12, 0.06), trim)
	var body := StaticBody3D.new()
	body.name = "Shed"
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = MeshKit.vertex_material(0.85)
	body.add_child(mi)
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, wall_h + roof_h * 0.6, d)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = shape.size.y * 0.5
	body.add_child(cs)
	body.position = pos
	body.rotation.y = yaw
	root.add_child(body)


static func _crates(root: Node3D, rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c0 := Color(0.66, 0.50, 0.32)
	var c1 := Color(0.50, 0.37, 0.24)
	MeshKit.add_box(st, Transform3D(), Vector3(0.9, 0.9, 0.9), c0)
	for y in [-0.36, 0.36]:
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, y, 0)), Vector3(0.94, 0.12, 0.94), c1)
	var mesh := st.commit()
	var mat := MeshKit.vertex_material(0.9)
	var spots := [Vector3(-7.2, 0.45, -15.5), Vector3(-6.2, 0.45, -15.9), Vector3(-6.7, 1.35, -15.7), Vector3(15.5, 0.45, 9.0)]
	for p in spots:
		var body := RigidBody3D.new()
		body.mass = 18.0
		body.collision_layer = 16
		body.collision_mask = 1 | 2 | 4 | 16
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		body.add_child(mi)
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.92, 0.92, 0.92)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		body.position = p
		body.rotation.y = rng.randf_range(-0.4, 0.4)
		root.add_child(body)


static func _dust(root: Node3D) -> void:
	var parts := GPUParticles3D.new()
	parts.amount = 380
	parts.lifetime = 9.0
	parts.preprocess = 9.0
	parts.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 12, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 3.5, 14)
	pm.direction = Vector3(1, 0.2, 0.3)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0.05, 0.01, 0.02)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.scale_min = 0.3
	pm.scale_max = 0.8
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	parts.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 0.92, 0.72, 0.35)
	quad.material = mat
	parts.draw_pass_1 = quad
	parts.position = Vector3(0, 2.5, 0)
	root.add_child(parts)
