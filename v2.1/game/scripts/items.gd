# Procedural low-poly models for shop items and handheld tools.
class_name Items
extends RefCounted

const CONVEYOR_REMOTE := "conveyor_remote"
const CONVEYOR_METERS := "conveyor_meters"
const SHOP_REMOTE := "shop_remote"


static func conveyor_remote_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := Color(0.95, 0.74, 0.18)
	var dark := Color(0.12, 0.12, 0.13)
	var steel := Color(0.55, 0.60, 0.66)
	var red := Color(0.85, 0.18, 0.14)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), Vector3(0.12, 0.05, 0.26), body)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.028, 0)), Vector3(0.085, 0.01, 0.22), dark)
	for z in [-0.115, 0.115]:
		for k in 2:
			var rot := Basis(Vector3(1, 0, 0), PI * 0.25 * k)
			MeshKit.add_box(st, Transform3D(rot, Vector3(0, 0.012, z)), Vector3(0.13, 0.036, 0.036), steel)
	for i in 5:
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.034, -0.08 + i * 0.04)), Vector3(0.085, 0.004, 0.006), Color(0.25, 0.25, 0.27))
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.045, 0.06)), Vector3(0.07, 0.05, 0.09), dark)
	MeshKit.add_cylinder(st, Vector3(0.0, -0.075, 0.06), 0.012, 0.018, 0.018, 8, red, red)
	MeshKit.add_cylinder(st, Vector3(0.045, 0.02, -0.12), 0.16, 0.006, 0.004, 6, dark, red)
	return st.commit()


static func shop_remote_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shell := Color(0.30, 0.55, 0.78)
	var dark := Color(0.13, 0.14, 0.16)
	var coin := Color(0.98, 0.80, 0.30)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(0.09, 0.035, 0.2), shell)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0.03)), Vector3(0.07, 0.006, 0.1), dark)
	MeshKit.add_cylinder(st, Vector3(0, 0.018, -0.05), 0.012, 0.025, 0.025, 10, coin, coin)
	MeshKit.add_cylinder(st, Vector3(0.03, 0.0, -0.1), 0.12, 0.005, 0.003, 6, dark, dark)
	return st.commit()


static func meters_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := Color(0.12, 0.12, 0.13)
	var yellow := Color(0.95, 0.74, 0.18)
	var steel := Color(0.55, 0.60, 0.66)
	for i in 3:
		var y := i * 0.09
		var yaw := Basis(Vector3.UP, 0.25 * (i - 1))
		MeshKit.add_box(st, Transform3D(yaw, Vector3(0, y + 0.04, 0)), Vector3(0.5, 0.05, 0.22), dark)
		MeshKit.add_box(st, Transform3D(yaw, Vector3(0, y + 0.07, 0.12)), Vector3(0.5, 0.04, 0.03), yellow)
		MeshKit.add_box(st, Transform3D(yaw, Vector3(0, y + 0.07, -0.12)), Vector3(0.5, 0.04, 0.03), yellow)
		MeshKit.add_box(st, Transform3D(yaw, Vector3(0, y + 0.02, 0)), Vector3(0.52, 0.02, 0.26), steel)
	return st.commit()


static func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _rod(st: SurfaceTool, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var dir := (b - a)
	var basis := MeshKit.basis_along(dir, dir.length())
	var xf := Transform3D(basis, a)
	var sides := 6
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := xf * Vector3(cos(a0) * r / basis.x.length(), 0, sin(a0) * r / basis.z.length())
		var p1 := xf * Vector3(cos(a1) * r / basis.x.length(), 0, sin(a1) * r / basis.z.length())
		var q0 := xf * Vector3(cos(a0) * r / basis.x.length(), 1, sin(a0) * r / basis.z.length())
		var q1 := xf * Vector3(cos(a1) * r / basis.x.length(), 1, sin(a1) * r / basis.z.length())
		var center := (a + b) * 0.5
		MeshKit.add_quad_out(st, p0, p1, q1, q0, center, col)


static func pitchfork_mesh() -> ArrayMesh:
	var st := _st()
	var wood := Color(0.6, 0.42, 0.25)
	var steel := Color(0.62, 0.66, 0.7)
	_rod(st, Vector3(0, 0, 0.55), Vector3(0, 0, -0.35), 0.018, wood)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.38)), Vector3(0.2, 0.03, 0.04), steel)
	for i in 4:
		var x := -0.09 + i * 0.06
		_rod(st, Vector3(x, 0, -0.38), Vector3(x, 0.02, -0.66), 0.008, steel)
	return st.commit()


static func basket_mesh() -> ArrayMesh:
	var st := _st()
	var wicker := Color(0.72, 0.52, 0.28)
	var dark := Color(0.52, 0.36, 0.18)
	MeshKit.add_cylinder(st, Vector3(0, 0, 0), 0.24, 0.16, 0.21, 10, wicker, dark)
	for k in 3:
		MeshKit.add_cylinder(st, Vector3(0, 0.05 + k * 0.07, 0), 0.02, 0.18 + k * 0.012, 0.18 + k * 0.012, 10, dark, dark)
	var h := 0.24
	for i in 9:
		var t0 := PI * i / 9.0
		var t1 := PI * (i + 1) / 9.0
		var p0 := Vector3(cos(t0) * 0.2, h + sin(t0) * 0.16, 0)
		var p1 := Vector3(cos(t1) * 0.2, h + sin(t1) * 0.16, 0)
		MeshKit.add_box(st, Transform3D(Basis(Vector3(0, 0, 1), atan2(p1.y - p0.y, p1.x - p0.x)), (p0 + p1) * 0.5), Vector3(p0.distance_to(p1) + 0.01, 0.025, 0.025), dark)
	return st.commit()


static func blower_mesh() -> ArrayMesh:
	var st := _st()
	var orange := Color(0.93, 0.47, 0.16)
	var dark := Color(0.16, 0.16, 0.17)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0.08)), Vector3(0.14, 0.16, 0.22), orange)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.09, 0.1)), Vector3(0.04, 0.06, 0.16), dark)
	var rot := Basis(Vector3(1, 0, 0), PI * 0.5)
	MeshKit.add_cylinder(st, Vector3(0, 0, -0.03), 0.04, 0.05, 0.05, 10, dark, dark)
	for k in 6:
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.06 - k * 0.05)), Vector3(0.07 - k * 0.004, 0.07 - k * 0.004, 0.052), orange if k % 2 == 0 else orange.darkened(0.15))
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.36)), Vector3(0.1, 0.05, 0.04), dark)
	return st.commit()


static func vacuum_mesh() -> ArrayMesh:
	var st := _st()
	var teal := Color(0.22, 0.55, 0.58)
	var dark := Color(0.14, 0.15, 0.16)
	var steel := Color(0.62, 0.66, 0.7)
	MeshKit.add_cylinder(st, Vector3(0, -0.12, 0.12), 0.24, 0.1, 0.1, 12, teal, teal.lightened(0.2))
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0.0)), Vector3(0.06, 0.06, 0.2), dark)
	for k in 5:
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, -0.12 - k * 0.06)), Vector3(0.05, 0.05, 0.062), steel if k % 2 == 0 else steel.darkened(0.2))
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, -0.44)), Vector3(0.14, 0.08, 0.05), dark)
	return st.commit()


static func gloves_mesh() -> ArrayMesh:
	var st := _st()
	var leather := Color(0.72, 0.5, 0.26)
	var cuff := Color(0.3, 0.45, 0.6)
	for s in [-1.0, 1.0]:
		var o := Vector3(s * 0.12, 0, 0)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, s * 0.2), o + Vector3(0, 0.08, 0)), Vector3(0.16, 0.16, 0.06), leather)
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, o + Vector3(0, -0.03, 0)), Vector3(0.15, 0.06, 0.07), cuff)
		for f in 4:
			MeshKit.add_box(st, Transform3D(Basis.IDENTITY, o + Vector3(-0.055 + f * 0.037, 0.2, 0)), Vector3(0.03, 0.09, 0.05), leather.darkened(0.05 * f))
		MeshKit.add_box(st, Transform3D(Basis(Vector3(0, 0, 1), s * 0.8), o + Vector3(s * 0.1, 0.1, 0)), Vector3(0.03, 0.08, 0.05), leather)
	return st.commit()


static func coins_mesh() -> ArrayMesh:
	var st := _st()
	var gold := Color(0.98, 0.78, 0.3)
	for k in 6:
		MeshKit.add_cylinder(st, Vector3(0.02 * sin(k * 1.3), k * 0.028, 0.02 * cos(k * 1.7)), 0.024, 0.1, 0.1, 14, gold.darkened(0.08 * (k % 2)), gold)
	MeshKit.add_cylinder(st, Vector3(0.2, 0, 0.02), 0.024, 0.1, 0.1, 14, gold, gold)
	MeshKit.add_cylinder(st, Vector3(0.2, 0.028, 0.02), 0.024, 0.1, 0.1, 14, gold.darkened(0.08), gold)
	return st.commit()


static func motor_mesh() -> ArrayMesh:
	var st := _st()
	var blue := Color(0.28, 0.42, 0.62)
	var steel := Color(0.62, 0.66, 0.7)
	var yellow := Color(0.95, 0.74, 0.18)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), Vector3(0.3, 0.2, 0.2), blue)
	for k in 5:
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(-0.12 + k * 0.06, 0.21, 0)), Vector3(0.03, 0.03, 0.2), blue.darkened(0.15))
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0.2, 0.1, 0)), Vector3(0.1, 0.04, 0.04), steel)
	for i in 8:
		var a := TAU * i / 8.0
		MeshKit.add_box(st, Transform3D(Basis(Vector3(1, 0, 0), a), Vector3(0.26, 0.1, 0) + Vector3(0, cos(a), sin(a)) * 0.09), Vector3(0.03, 0.04, 0.04), yellow)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0.26, 0.1, 0)), Vector3(0.03, 0.16, 0.16), yellow.darkened(0.1))
	return st.commit()


static func shoes_mesh(springs: bool) -> ArrayMesh:
	var st := _st()
	var red := Color(0.8, 0.25, 0.2) if not springs else Color(0.3, 0.5, 0.75)
	var sole := Color(0.95, 0.93, 0.88)
	var steel := Color(0.62, 0.66, 0.7)
	for s in [-1.0, 1.0]:
		var o := Vector3(s * 0.09, 0.1 if springs else 0.0, 0)
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, o + Vector3(0, 0.02, 0)), Vector3(0.12, 0.04, 0.3), sole)
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, o + Vector3(0, 0.08, 0.02)), Vector3(0.11, 0.08, 0.24), red)
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, o + Vector3(0, 0.15, 0.08)), Vector3(0.1, 0.08, 0.1), red.darkened(0.1))
		if springs:
			for k in 4:
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, k * 0.6), o + Vector3(0, -0.02 - k * 0.022, 0)), Vector3(0.08, 0.012, 0.08), steel)
	return st.commit()


static func grabber_mesh() -> ArrayMesh:
	var st := _st()
	var yellow := Color(0.95, 0.74, 0.18)
	var dark := Color(0.16, 0.16, 0.17)
	_rod(st, Vector3(0, 0, 0.3), Vector3(0, 0, -0.45), 0.014, Color(0.62, 0.66, 0.7))
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, -0.04, 0.3)), Vector3(0.05, 0.12, 0.08), yellow)
	for s in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, s * 0.35), Vector3(s * 0.03, 0, -0.5)), Vector3(0.015, 0.03, 0.1), dark)
	return st.commit()


static func dumbbell_mesh() -> ArrayMesh:
	var st := _st()
	var dark := Color(0.2, 0.21, 0.23)
	var steel := Color(0.62, 0.66, 0.7)
	_rod(st, Vector3(-0.2, 0.08, 0), Vector3(0.2, 0.08, 0), 0.02, steel)
	for s in [-1.0, 1.0]:
		for k in 2:
			MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(s * (0.13 + k * 0.05), 0.08, 0)), Vector3(0.04, 0.16 - k * 0.03, 0.16 - k * 0.03), dark)
	return st.commit()


static func belt_roll_mesh() -> ArrayMesh:
	var st := _st()
	var dark := Color(0.14, 0.14, 0.15)
	var yellow := Color(0.95, 0.74, 0.18)
	for i in 14:
		var a0 := TAU * i / 14.0
		var a1 := TAU * (i + 1) / 14.0
		for r in [0.08, 0.16]:
			var p0 := Vector3(-0.12, sin(a0) * r + 0.18, cos(a0) * r)
			var p1 := Vector3(-0.12, sin(a1) * r + 0.18, cos(a1) * r)
			var q0 := Vector3(0.12, sin(a0) * r + 0.18, cos(a0) * r)
			var q1 := Vector3(0.12, sin(a1) * r + 0.18, cos(a1) * r)
			MeshKit.add_quad_out(st, p0, p1, q1, q0, Vector3(0, 0.18, 0), dark if r > 0.1 else yellow)
		MeshKit.add_tri(st, Vector3(0.12, sin(a0) * 0.16 + 0.18, cos(a0) * 0.16), Vector3(0.12, sin(a1) * 0.16 + 0.18, cos(a1) * 0.16), Vector3(0.12, 0.18, 0), Vector3.RIGHT, dark.lightened(0.1))
		MeshKit.add_tri(st, Vector3(-0.12, sin(a0) * 0.16 + 0.18, cos(a0) * 0.16), Vector3(-0.12, sin(a1) * 0.16 + 0.18, cos(a1) * 0.16), Vector3(-0.12, 0.18, 0), Vector3.LEFT, dark.lightened(0.1))
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0.28)), Vector3(0.24, 0.02, 0.26), dark)
	return st.commit()


static func mesh_for(id: String) -> ArrayMesh:
	match id:
		CONVEYOR_REMOTE:
			return conveyor_remote_mesh()
		CONVEYOR_METERS, "belt_meters":
			return meters_mesh()
		SHOP_REMOTE:
			return shop_remote_mesh()
		"pitchfork":
			return pitchfork_mesh()
		"basket":
			return basket_mesh()
		"blower":
			return blower_mesh()
		"vacuum":
			return vacuum_mesh()
		"auto_puller", "hopper", "mini_seller":
			return Machine.preview_mesh(id)
		"gloves":
			return gloves_mesh()
		"buyer":
			return coins_mesh()
		"belt_motors", "puller_motors":
			return motor_mesh()
		"running_shoes":
			return shoes_mesh(false)
		"spring_boots":
			return shoes_mesh(true)
		"long_arms":
			return grabber_mesh()
		"strong_arm":
			return dumbbell_mesh()
		"bulk_belt":
			return belt_roll_mesh()
	return conveyor_remote_mesh()
