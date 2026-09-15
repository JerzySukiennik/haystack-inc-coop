# Base for placeable machines: shared mesh building, collision body, footprint, conveyor sockets and the factory.
class_name Machine
extends Node3D

var id := ""
var main: Node
var preview := false
var net_id := 0
var _st: SurfaceTool
var _body: StaticBody3D


static func make(machine_id: String) -> Machine:
	var m: Machine
	match machine_id:
		"auto_puller":
			m = AutoPuller.new()
		"hopper":
			m = Hopper.new()
		"mini_seller":
			m = MiniSeller.new()
	m.id = machine_id
	return m


static func preview_mesh(machine_id: String) -> ArrayMesh:
	var m := make(machine_id)
	m.preview = true
	m._st = SurfaceTool.new()
	m._st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m._body = StaticBody3D.new()
	m._build()
	var mesh := m._st.commit()
	m._body.free()
	m.free()
	return mesh


func _ready() -> void:
	add_to_group("machine")
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	if not preview:
		add_child(_body)
	_build()
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _st.commit()
	mi.material_override = MeshKit.vertex_material(0.7)
	add_child(mi)
	if not preview:
		_build_dynamic()


func footprint() -> Vector3:
	return Vector3(1.4, 1.4, 1.4)


func footprint_center() -> Vector3:
	return Vector3(0, 0.75, 0)


func box(center: Vector3, size: Vector3, col: Color, collide := true) -> void:
	MeshKit.add_box(_st, Transform3D(Basis.IDENTITY, center), size, col)
	if collide and not preview:
		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = center
		_body.add_child(cs)


func _build() -> void:
	pass


func _build_dynamic() -> void:
	pass


func belt(start: Vector3, axis: Vector3, length: float, cap_start: bool) -> Area3D:
	if preview:
		var frame := Color(0.30, 0.33, 0.36)
		var basis := Basis(axis, Vector3.UP, axis.cross(Vector3.UP))
		MeshKit.add_box(_st, Transform3D(basis, start + axis * length * 0.5 + Vector3.UP * (ConveyorLine.TOP - 0.05)), Vector3(length, 0.2, ConveyorLine.WIDTH + 0.16), frame)
		return null
	return ConveyorLine.short_belt(self, _st, _body, start, axis, length, cap_start)


func sockets() -> Array:
	return []


func world_socket(local_pos: Vector3, local_out: Vector3, is_input: bool) -> Dictionary:
	var p := global_transform * local_pos
	p.y = 0.0
	return {"pos": p, "out": (global_basis * local_out).normalized(), "owner": self, "input": is_input}


func accepts_straw(piece: HayPiece) -> bool:
	return piece != null and piece.held_by == null and not piece.selling and not piece.freeze
