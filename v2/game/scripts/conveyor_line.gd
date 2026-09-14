# A placed conveyor built along a smooth path: moving belt pieces, side rails, legs and a scrolling belt surface.
class_name ConveyorLine
extends Node3D

const WIDTH := 0.8
const TOP := 1.0
const SPEED := 1.1
const RAIL_H := 0.2
const BELT_SHADER := """
shader_type spatial;
uniform float speed = 1.1;
void fragment() {
	float s = fract(UV.x * 2.5 - TIME * speed * 2.5);
	float stripe = smoothstep(0.0, 0.08, s) * (1.0 - smoothstep(0.42, 0.5, s));
	ALBEDO = mix(vec3(0.07), vec3(0.15), stripe);
	ROUGHNESS = 0.85;
}
"""

static var speed := 1.1

var points := PackedVector3Array()
var grounds := PackedFloat32Array()
var meters := 0
var splits: Array[Dictionary] = []
var feeds: Dictionary = {}
var _area: Area3D
var _wake := 0.0
var _split_toggle := {}


static func piece_basis(a: Vector3, b: Vector3) -> Basis:
	var x := (b - a).normalized()
	var z := x.cross(Vector3.UP).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


static func side_at(pts: PackedVector3Array, i: int) -> Vector3:
	var a := pts[maxi(i - 1, 0)]
	var b := pts[mini(i + 1, pts.size() - 1)]
	var t := b - a
	t.y = 0.0
	return Vector3(-t.z, 0, t.x).normalized()


static func add_visual(st: SurfaceTool, pts: PackedVector3Array, gnd: PackedFloat32Array, tint := Color(-1, 0, 0)) -> void:
	var yellow := Color(0.95, 0.74, 0.18) if tint.r < 0.0 else tint
	var frame := Color(0.30, 0.33, 0.36) if tint.r < 0.0 else tint
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var basis := piece_basis(a, b)
		var mid := (a + b) * 0.5
		var length := a.distance_to(b) + 0.02
		for s in [-1.0, 1.0]:
			var off: Vector3 = basis.z * s * (WIDTH * 0.5 + 0.04)
			MeshKit.add_box(st, Transform3D(basis, mid + off + basis.y * (RAIL_H * 0.5 - 0.05)), Vector3(length, RAIL_H, 0.08), yellow)
		MeshKit.add_box(st, Transform3D(basis, mid - basis.y * 0.11), Vector3(length, 0.12, WIDTH + 0.02), frame)
	var dist := 0.0
	var next_leg := 0.25
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		while next_leg <= dist + seg:
			var t := (next_leg - dist) / seg
			var p := pts[i].lerp(pts[i + 1], t)
			var g := lerpf(gnd[i], gnd[i + 1], t)
			var h := p.y - 0.17 - g
			if h > 0.05:
				var side := side_at(pts, i)
				for s in [-1.0, 1.0]:
					var leg: Vector3 = Vector3(p.x, g + h * 0.5, p.z) + side * s * (WIDTH * 0.5 - 0.06)
					MeshKit.add_box(st, Transform3D(Basis.IDENTITY, leg), Vector3(0.08, h, 0.08), frame)
			next_leg += 1.5
		dist += seg


static func belt_mesh(pts: PackedVector3Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var sa := side_at(pts, i) * WIDTH * 0.5
		var sb := side_at(pts, i + 1) * WIDTH * 0.5
		var d2 := dist + a.distance_to(b)
		var lift := Vector3.UP * 0.003
		var quad := [a - sa + lift, a + sa + lift, b + sb + lift, b - sb + lift]
		var uvs := [Vector2(dist, 0), Vector2(dist, 1), Vector2(d2, 1), Vector2(d2, 0)]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			var p0: Vector3 = quad[tri[0]]
			var p1: Vector3 = quad[tri[1]]
			var p2: Vector3 = quad[tri[2]]
			var n := (p1 - p0).cross(p2 - p0).normalized()
			if n.y < 0.0:
				n = -n
				var tmp: int = tri[1]
				tri[1] = tri[2]
				tri[2] = tmp
			if (quad[tri[1]] - quad[tri[0]]).cross(quad[tri[2]] - quad[tri[0]]).dot(n) > 0.0:
				var tmp2: int = tri[1]
				tri[1] = tri[2]
				tri[2] = tmp2
			for k in 3:
				st.set_normal(n)
				st.set_uv(uvs[tri[k]])
				st.add_vertex(quad[tri[k]])
		dist = d2
	return st.commit()


static func flat_dir(a: Vector3, b: Vector3) -> Vector3:
	var d := b - a
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else Vector3.FORWARD


static func set_global_speed(tree: SceneTree, v: float) -> void:
	speed = v
	for body in tree.get_nodes_in_group("moving_belt"):
		var b := body as StaticBody3D
		b.constant_linear_velocity = (b.get_meta("dir") as Vector3) * v
	for mi in tree.get_nodes_in_group("belt_surface"):
		var m := (mi as MeshInstance3D).material_override as ShaderMaterial
		if m:
			m.set_shader_parameter("speed", v * float(mi.get_meta("sign", 1.0)))


static func short_belt(parent: Node3D, st: SurfaceTool, rails: StaticBody3D, start: Vector3, axis: Vector3, length: float, cap_start: bool) -> Area3D:
	var basis := Basis(axis, Vector3.UP, axis.cross(Vector3.UP))
	var side := axis.cross(Vector3.UP)
	var mid := start + axis * length * 0.5 + Vector3.UP * TOP
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("dir", axis)
	body.add_to_group("moving_belt")
	body.constant_linear_velocity = axis * speed
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 0.1, WIDTH)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(basis, mid - Vector3.UP * 0.05)
	body.add_child(cs)
	parent.add_child(body)
	var quad := PlaneMesh.new()
	quad.size = Vector2(length, WIDTH)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BELT_SHADER
	mat.shader = sh
	mat.set_shader_parameter("speed", speed)
	var surface := MeshInstance3D.new()
	surface.mesh = quad
	surface.material_override = mat
	surface.add_to_group("belt_surface")
	surface.set_meta("sign", 1.0)
	surface.transform = Transform3D(basis, mid + Vector3.UP * 0.003)
	parent.add_child(surface)
	var yellow := Color(0.95, 0.74, 0.18)
	var frame := Color(0.30, 0.33, 0.36)
	for s in [-1.0, 1.0]:
		var rc: Vector3 = mid + side * s * (WIDTH * 0.5 + 0.04) + Vector3.UP * (RAIL_H * 0.5 - 0.05)
		MeshKit.add_box(st, Transform3D(basis, rc), Vector3(length, RAIL_H, 0.08), yellow)
		var rs := BoxShape3D.new()
		rs.size = Vector3(length, RAIL_H, 0.08)
		var rcs := CollisionShape3D.new()
		rcs.shape = rs
		rcs.transform = Transform3D(basis, rc)
		rails.add_child(rcs)
		for t in [0.15, length - 0.15]:
			var leg: Vector3 = start + axis * t + side * s * (WIDTH * 0.5 - 0.06)
			MeshKit.add_box(st, Transform3D(Basis.IDENTITY, leg + Vector3.UP * (TOP - 0.17) * 0.5), Vector3(0.08, TOP - 0.17, 0.08), frame)
	MeshKit.add_box(st, Transform3D(basis, mid - Vector3.UP * 0.11), Vector3(length, 0.12, WIDTH + 0.02), frame)
	if cap_start:
		var cap_c := start + Vector3.UP * (TOP + 0.05)
		MeshKit.add_box(st, Transform3D(basis, cap_c), Vector3(0.08, 0.3, WIDTH + 0.16), yellow)
		var cap := BoxShape3D.new()
		cap.size = Vector3(0.08, 0.3, WIDTH + 0.16)
		var ccs := CollisionShape3D.new()
		ccs.shape = cap
		ccs.transform = Transform3D(basis, cap_c)
		rails.add_child(ccs)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = HayPiece.LAYER
	var ashape := BoxShape3D.new()
	ashape.size = Vector3(length, 0.5, WIDTH)
	var acs := CollisionShape3D.new()
	acs.shape = ashape
	acs.transform = Transform3D(basis, mid + Vector3.UP * 0.25)
	area.add_child(acs)
	parent.add_child(area)
	return area


func length() -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


func point_at(d: float) -> Dictionary:
	var acc := 0.0
	for i in points.size() - 1:
		var seg := points[i].distance_to(points[i + 1])
		if acc + seg >= d or i == points.size() - 2:
			var t := clampf((d - acc) / maxf(seg, 0.0001), 0.0, 1.0)
			return {"pos": points[i].lerp(points[i + 1], t), "dir": flat_dir(points[i], points[i + 1]), "index": i}
		acc += seg
	return {"pos": points[points.size() - 1], "dir": flat_dir(points[points.size() - 2], points[points.size() - 1]), "index": points.size() - 2}


func project(p: Vector3) -> Dictionary:
	var best := {}
	var best_d := 1e9
	var acc := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(p.x - a.x, p.z - a.z)
		var len2 := ab.length_squared()
		var t := clampf(ap.dot(ab) / maxf(len2, 0.0001), 0.0, 1.0)
		var q := a.lerp(b, t)
		var d := Vector2(p.x - q.x, p.z - q.z).length()
		if d < best_d:
			best_d = d
			var dir := flat_dir(a, b)
			var side := Vector3(-dir.z, 0, dir.x)
			var sign := 1.0 if side.dot(Vector3(p.x - q.x, 0, p.z - q.z)) >= 0.0 else -1.0
			best = {"pos": q, "along": acc + a.distance_to(b) * t, "dir": dir, "side": side * sign, "dist": d}
		acc += a.distance_to(b)
	return best


func add_split(along: float, branch: ConveyorLine) -> void:
	splits.append({"along": along, "line": branch})
	_build_junctions()


func set_feed(target: ConveyorLine, along: float) -> void:
	feeds = {"line": target, "along": along}
	_build_junctions()


func clear_links() -> void:
	for s in splits:
		var other: ConveyorLine = s.line
		if is_instance_valid(other) and other.feeds.get("line") == self:
			other.feeds = {}
			other._build_junctions()
	splits.clear()
	for line in get_tree().get_nodes_in_group("conveyor"):
		var l := line as ConveyorLine
		if l == self:
			continue
		var changed := false
		for s in l.splits.duplicate():
			if s.line == self:
				l.splits.erase(s)
				changed = true
		if changed:
			l._build_junctions()
	if not feeds.is_empty():
		feeds = {}
	_build_junctions()


func _build_junctions() -> void:
	var old := get_node_or_null("Junctions")
	if old:
		remove_child(old)
		old.free()
	var root := Node3D.new()
	root.name = "Junctions"
	add_child(root)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for s in splits:
		var branch: ConveyorLine = s.line
		if not is_instance_valid(branch) or branch.points.size() < 2:
			continue
		var at := point_at(s.along)
		_junction_visual(st, at.pos, branch.points[0])
		var area := _junction_area(at.pos, at.dir)
		area.body_entered.connect(func(body: Node3D) -> void: _on_split_body(body, s))
		root.add_child(area)
		any = true
	if not feeds.is_empty() and is_instance_valid(feeds.line):
		var target: ConveyorLine = feeds.line
		var end := points[points.size() - 1]
		var at: Dictionary = target.point_at(feeds.along)
		_junction_visual(st, at.pos, end)
		var area := _junction_area(end - flat_dir(points[points.size() - 2], end) * 0.25, flat_dir(points[points.size() - 2], end))
		area.body_entered.connect(func(body: Node3D) -> void: _transfer(body, target, feeds.along, 0.0))
		root.add_child(area)
		any = true
	if any:
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = MeshKit.vertex_material(0.6)
		root.add_child(mi)


func _junction_visual(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5
	var dir := flat_dir(a, b)
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	var span := Vector2(a.x - b.x, a.z - b.z).length()
	var steel := Color(0.36, 0.42, 0.48)
	var yellow := Color(0.95, 0.74, 0.18)
	var dark := Color(0.12, 0.12, 0.13)
	MeshKit.add_box(st, Transform3D(basis, mid + Vector3.UP * 0.25), Vector3(span, 0.08, 0.5), steel)
	MeshKit.add_box(st, Transform3D(basis, a + Vector3.UP * 0.42), Vector3(0.36, 0.3, 0.7), yellow)
	MeshKit.add_box(st, Transform3D(basis, a + Vector3.UP * 0.58), Vector3(0.38, 0.04, 0.72), dark)
	for k in 3:
		var p := mid + dir * (k - 1) * span * 0.25 + Vector3.UP * 0.3
		var side := dir.cross(Vector3.UP)
		MeshKit.add_tri(st, p + dir * 0.12, p - dir * 0.04 + side * 0.12, p - dir * 0.04 - side * 0.12, Vector3.UP, yellow)


func _junction_area(pos: Vector3, dir: Vector3) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = HayPiece.LAYER
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.45, 0.6, WIDTH)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	area.add_child(cs)
	area.transform = Transform3D(Basis(dir, Vector3.UP, dir.cross(Vector3.UP)), pos + Vector3.UP * 0.25)
	return area


func _on_split_body(body: Node3D, split: Dictionary) -> void:
	var piece := body as HayPiece
	if piece == null or piece.held_by != null or piece.selling:
		return
	if Time.get_ticks_msec() < int(piece.get_meta("junction_until", 0)):
		return
	var key := str(split.along)
	var go := bool(_split_toggle.get(key, false))
	_split_toggle[key] = not go
	if not go:
		piece.set_meta("junction_until", Time.get_ticks_msec() + 700)
		return
	var branch: ConveyorLine = split.line
	if is_instance_valid(branch):
		_transfer(piece, branch, 0.3, 0.0)


func _transfer(body: Node3D, target: ConveyorLine, along: float, _unused: float) -> void:
	var piece := body as HayPiece
	if piece == null or piece.held_by != null or piece.selling or not is_instance_valid(target):
		return
	if Time.get_ticks_msec() < int(piece.get_meta("junction_until", 0)):
		return
	piece.set_meta("junction_until", Time.get_ticks_msec() + 1200)
	var at: Dictionary = target.point_at(along)
	var dest: Vector3 = at.pos + Vector3.UP * 0.12
	var start := piece.global_position
	piece.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	piece.freeze = true
	var tw := piece.create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(piece):
			piece.global_position = start.lerp(dest, t) + Vector3.UP * sin(t * PI) * 0.35, 0.0, 1.0, 0.35)
	tw.tween_callback(func() -> void:
		if is_instance_valid(piece):
			piece.freeze = false
			piece.linear_velocity = (at.dir as Vector3) * speed
			piece.sleeping = false)


func sockets() -> Array:
	var n := points.size()
	return [
		{"pos": points[0], "out": -flat_dir(points[0], points[1]), "owner": self, "input": true},
		{"pos": points[n - 1], "out": flat_dir(points[n - 2], points[n - 1]), "owner": self, "input": false},
	]


func reverse() -> void:
	var pts := points.duplicate()
	pts.reverse()
	var gnd := grounds.duplicate()
	gnd.reverse()
	clear_links()
	for c in get_children():
		remove_child(c)
		c.free()
	build(pts, gnd)


func build(pts: PackedVector3Array, gnd: PackedFloat32Array) -> void:
	points = pts
	grounds = gnd
	add_to_group("conveyor")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_visual(st, pts, gnd)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = MeshKit.vertex_material(0.7)
	add_child(mi)
	var belt := MeshInstance3D.new()
	belt.mesh = belt_mesh(pts)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BELT_SHADER
	mat.shader = sh
	mat.set_shader_parameter("speed", speed)
	belt.material_override = mat
	belt.add_to_group("belt_surface")
	belt.set_meta("sign", 1.0)
	add_child(belt)
	var rails := StaticBody3D.new()
	rails.collision_layer = 1
	add_child(rails)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = HayPiece.LAYER
	add_child(_area)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var basis := piece_basis(a, b)
		var mid := (a + b) * 0.5
		var length := a.distance_to(b) + 0.03
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.set_meta("dir", basis.x)
		body.add_to_group("moving_belt")
		body.constant_linear_velocity = basis.x * speed
		var shape := BoxShape3D.new()
		shape.size = Vector3(length, 0.1, WIDTH)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = Transform3D(basis, mid - basis.y * 0.05)
		body.add_child(cs)
		add_child(body)
		for s in [-1.0, 1.0]:
			var rs := BoxShape3D.new()
			rs.size = Vector3(length, RAIL_H, 0.08)
			var rcs := CollisionShape3D.new()
			rcs.shape = rs
			rcs.transform = Transform3D(basis, mid + basis.z * s * (WIDTH * 0.5 + 0.04) + basis.y * (RAIL_H * 0.5 - 0.05))
			rails.add_child(rcs)
		var ashape := BoxShape3D.new()
		ashape.size = Vector3(length, 0.5, WIDTH)
		var acs := CollisionShape3D.new()
		acs.shape = ashape
		acs.transform = Transform3D(basis, mid + basis.y * 0.25)
		_area.add_child(acs)


func _physics_process(delta: float) -> void:
	_wake += delta
	if _wake < 0.25 or _area == null:
		return
	_wake = 0.0
	for body in _area.get_overlapping_bodies():
		if body is RigidBody3D and (body as RigidBody3D).sleeping:
			(body as RigidBody3D).sleeping = false
