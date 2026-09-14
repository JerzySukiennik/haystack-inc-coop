# Procedural low-poly mesh helpers: flat-shaded triangles, straws, boxes, cones, blobs.
class_name MeshKit
extends RefCounted

const HAY_COLORS := [
	Color(0.84, 0.66, 0.29),
	Color(0.90, 0.74, 0.38),
	Color(0.74, 0.56, 0.23),
	Color(0.93, 0.80, 0.46),
	Color(0.80, 0.62, 0.26),
]


static func add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(v)


static func add_tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - center) < 0.0:
		n = -n
	add_tri(st, a, b, c, n, col)


static func add_tri_up(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	add_tri(st, a, b, c, n, col)


static func add_quad_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, center: Vector3, col: Color) -> void:
	add_tri_out(st, a, b, c, center, col)
	add_tri_out(st, a, c, d, center, col)


static func add_prism(st: SurfaceTool, a: Vector3, b: Vector3, t_a: float, t_b: float, col: Color) -> void:
	var dir := (b - a).normalized()
	var ref := Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT
	var u := dir.cross(ref).normalized()
	var w := dir.cross(u).normalized()
	var offs: Array[Vector3] = []
	for k in 3:
		var ang := TAU * k / 3.0
		offs.append(u * cos(ang) + w * sin(ang))
	for k in 3:
		var o0 := offs[k]
		var o1 := offs[(k + 1) % 3]
		var n := (o0 + o1).normalized()
		add_tri(st, a + o0 * t_a, a + o1 * t_a, b + o1 * t_b, n, col)
		add_tri(st, a + o0 * t_a, b + o1 * t_b, b + o0 * t_b, n, col)


static func add_box(st: SurfaceTool, xf: Transform3D, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var c := xf.origin
	var corners: Array[Vector3] = []
	for i in 8:
		var p := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		corners.append(xf * p)
	var faces := [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]
	for f in faces:
		add_quad_out(st, corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]], c, col)


static func add_cylinder(st: SurfaceTool, base: Vector3, height: float, r0: float, r1: float, segs: int, col: Color, col_top: Color) -> void:
	var center := base + Vector3.UP * height * 0.5
	for j in segs:
		var a0 := TAU * j / segs
		var a1 := TAU * (j + 1) / segs
		var p0 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p1 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var q0 := base + Vector3(cos(a0) * r1, height, sin(a0) * r1)
		var q1 := base + Vector3(cos(a1) * r1, height, sin(a1) * r1)
		add_tri_out(st, p0, p1, q1, center, col)
		if r1 > 0.001:
			add_tri_out(st, p0, q1, q0, center, col)
			add_tri(st, base + Vector3.UP * height, q0, q1, Vector3.UP, col_top)
		add_tri(st, base, p0, p1, Vector3.DOWN, col)


static func add_blob(st: SurfaceTool, center: Vector3, radius: Vector3, rng: RandomNumberGenerator, jitter: float, cols: Array) -> void:
	var rings := 5
	var segs := 8
	var pts := []
	for i in rings + 1:
		var row := []
		var phi := PI * i / rings
		for j in segs:
			var theta := TAU * j / segs + (0.3 if i % 2 == 1 else 0.0)
			var d := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var k := 1.0 + rng.randf_range(-jitter, jitter) if i > 0 and i < rings else 1.0
			row.append(center + d * radius * k)
		pts.append(row)
	for i in rings:
		for j in segs:
			var j1 := (j + 1) % segs
			var col: Color = cols[rng.randi() % cols.size()]
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j1]
			var c: Vector3 = pts[i + 1][j1]
			var d: Vector3 = pts[i + 1][j]
			if i == 0:
				add_tri_out(st, a, c, d, center, col)
			elif i == rings - 1:
				add_tri_out(st, a, b, d, center, col)
			else:
				add_quad_out(st, a, b, c, d, center, col)


static func hay_color(rng: RandomNumberGenerator) -> Color:
	var base: Color = HAY_COLORS[rng.randi() % HAY_COLORS.size()]
	var v := rng.randf_range(-0.05, 0.05)
	return Color(base.r + v, base.g + v, base.b + v * 0.5)



static func straw_piece(rng: RandomNumberGenerator, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 5
	var segs := 4
	var bend := Vector3(0, rng.randf_range(-0.012, 0.012), rng.randf_range(-0.02, 0.02))
	var base := hay_color(rng)
	var tip := base.lightened(rng.randf_range(0.08, 0.2))
	var knot := rng.randi_range(1, segs - 1)
	var rings := []
	for i in segs + 1:
		var t := float(i) / segs
		var center := Vector3((t - 0.5) * length, 0, 0) + bend * sin(t * PI)
		var r := lerpf(0.011, 0.006, t) * (1.25 if i == knot else 1.0)
		var ring := []
		for k in sides:
			var a := TAU * k / sides
			ring.append(center + Vector3(0, cos(a) * r, sin(a) * r))
		rings.append(ring)
	for i in segs:
		var t := (i + 0.5) / segs
		var col := base.lerp(tip, t)
		if i == knot or i + 1 == knot:
			col = col.darkened(0.12)
		for k in sides:
			var k1 := (k + 1) % sides
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k1]
			var c: Vector3 = rings[i + 1][k1]
			var d: Vector3 = rings[i + 1][k]
			var axis := (a + b + c + d) * 0.25
			axis.y = 0.0
			axis.z = 0.0
			axis += bend * sin(t * PI)
			var n := ((a + b + c + d) * 0.25 - axis).normalized()
			add_tri(st, a, b, c, n, col)
			add_tri(st, a, c, d, n, col)
	for end in [0, segs]:
		var ring: Array = rings[end]
		var mid := Vector3.ZERO
		for v in ring:
			mid += v
		mid /= sides
		var n := Vector3.LEFT if end == 0 else Vector3.RIGHT
		for k in sides:
			add_tri(st, mid, ring[k], ring[(k + 1) % sides], n, base.darkened(0.2))
	return st.commit()


static func straw_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_prism(st, Vector3.ZERO, Vector3.UP, 0.012, 0.004, Color.WHITE)
	return st.commit()


static func vertex_material(roughness := 0.9, cull := BaseMaterial3D.CULL_BACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	m.cull_mode = cull
	return m


static func basis_along(dir: Vector3, length: float) -> Basis:
	var d := dir.normalized()
	var ref := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	var x := d.cross(ref).normalized()
	var z := x.cross(d).normalized()
	return Basis(x, d * length, z)
