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

var points := PackedVector3Array()
var grounds := PackedFloat32Array()
var meters := 0
var _area: Area3D
var _wake := 0.0


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
	mat.set_shader_parameter("speed", SPEED)
	belt.material_override = mat
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
		body.constant_linear_velocity = basis.x * SPEED
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
