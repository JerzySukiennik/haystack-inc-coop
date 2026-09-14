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


static func mesh_for(id: String) -> ArrayMesh:
	match id:
		CONVEYOR_REMOTE:
			return conveyor_remote_mesh()
		CONVEYOR_METERS:
			return meters_mesh()
		SHOP_REMOTE:
			return shop_remote_mesh()
	return conveyor_remote_mesh()
