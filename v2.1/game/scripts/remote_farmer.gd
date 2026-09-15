# Another player's avatar: low-poly farmer with a straw hat, name tag and the item in hand, interpolated from network state.
class_name RemoteFarmer
extends Node3D

const COLORS := [Color("c2462f"), Color("3a7bd5"), Color("6fcf5c"), Color("9b59b6"), Color("e67e22"), Color("16a085")]

var peer_id := 0
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _pitch := 0.0
var _head: Node3D
var _hand: MeshInstance3D
var _label: Label3D
var _tool := ""
var _has := false


func _ready() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shirt: Color = COLORS[peer_id % COLORS.size()]
	var denim := Color(0.24, 0.33, 0.52)
	var skin := Color(0.93, 0.76, 0.6)
	var boots := Color(0.25, 0.18, 0.12)
	for s in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(s * 0.12, 0.42, 0)), Vector3(0.18, 0.84, 0.22), denim)
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(s * 0.12, 0.06, 0.03)), Vector3(0.2, 0.12, 0.3), boots)
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(s * 0.33, 1.12, 0)), Vector3(0.14, 0.56, 0.16), shirt.darkened(0.1))
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(s * 0.33, 0.8, 0)), Vector3(0.12, 0.12, 0.14), skin)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 1.12, 0)), Vector3(0.52, 0.6, 0.3), shirt)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0.16)), Vector3(0.36, 0.3, 0.02), denim)
	var body := MeshInstance3D.new()
	body.mesh = st.commit()
	body.material_override = MeshKit.vertex_material(0.8)
	add_child(body)
	_head = Node3D.new()
	_head.position.y = 1.55
	add_child(_head)
	var hs := SurfaceTool.new()
	hs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var straw := Color(0.93, 0.8, 0.45)
	MeshKit.add_box(hs, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), Vector3(0.3, 0.3, 0.3), skin)
	MeshKit.add_box(hs, Transform3D(Basis.IDENTITY, Vector3(0.07, 0.06, -0.151)), Vector3(0.05, 0.05, 0.01), Color(0.1, 0.1, 0.1))
	MeshKit.add_box(hs, Transform3D(Basis.IDENTITY, Vector3(-0.07, 0.06, -0.151)), Vector3(0.05, 0.05, 0.01), Color(0.1, 0.1, 0.1))
	MeshKit.add_cylinder(hs, Vector3(0, 0.17, 0), 0.03, 0.34, 0.34, 12, straw.darkened(0.1), straw)
	MeshKit.add_cylinder(hs, Vector3(0, 0.2, 0), 0.14, 0.17, 0.13, 10, straw, straw.lightened(0.1))
	MeshKit.add_cylinder(hs, Vector3(0, 0.2, 0), 0.03, 0.175, 0.175, 10, Color("c2462f"), Color("c2462f"))
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = hs.commit()
	head_mi.material_override = MeshKit.vertex_material(0.8)
	_head.add_child(head_mi)
	_hand = MeshInstance3D.new()
	_hand.material_override = MeshKit.vertex_material(0.6)
	_hand.position = Vector3(0.36, 0.95, -0.25)
	_hand.rotation = Vector3(-0.3, 0.0, 0.0)
	add_child(_hand)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.15
	_label.font_size = 64
	_label.pixel_size = 0.004
	_label.outline_size = 14
	_label.modulate = UI.CREAM
	_label.outline_modulate = Color(0.08, 0.06, 0.04)
	_label.font = UI.black()
	_label.no_depth_test = false
	add_child(_label)


func set_display_name(n: String) -> void:
	if _label:
		_label.text = n


func set_state(pos: Vector3, yaw: float, pitch: float, tool: String, _held: int) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_pitch = pitch
	if not _has:
		global_position = pos
		rotation.y = yaw
		_has = true
	if tool != _tool:
		_tool = tool
		_hand.mesh = Items.mesh_for(tool) if tool != "" and not Catalog.item(tool).get("kind", "") == "machine" else (Items.conveyor_remote_mesh() if tool != "" else null)


func _process(delta: float) -> void:
	if not _has:
		return
	var k := 1.0 - exp(-delta * 12.0)
	global_position = global_position.lerp(_target_pos, k)
	rotation.y = lerp_angle(rotation.y, _target_yaw, k)
	_head.rotation.x = lerpf(_head.rotation.x, _pitch, k)
