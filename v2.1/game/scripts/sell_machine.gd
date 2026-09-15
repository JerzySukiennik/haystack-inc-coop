# Corner sell machine: a block against the yard fence with two intake tunnels, each fed by its own short built-in conveyor.
class_name SellMachine
extends Node3D

signal sold(amount: int, at: Vector3)
signal needle_sold(at: Vector3)

var main: Node

const PRICE := 1
const SIZE := 3.0
const BELT_LENGTH := 2.2
const BELT_WIDTH := 0.8
const BELT_TOP := 0.8
const BELT_SPEED := 0.9
const TUNNEL_W := 0.9
const TUNNEL_BOTTOM := 0.75
const TUNNEL_TOP := 1.3
const BELT_SHADER := """
shader_type spatial;
uniform float speed = 0.9;
uniform float length = 2.2;
void fragment() {
	float s = fract(UV.x * length * 2.5 - TIME * speed * 2.5);
	float stripe = smoothstep(0.0, 0.08, s) * (1.0 - smoothstep(0.42, 0.5, s));
	ALBEDO = mix(vec3(0.07), vec3(0.14), stripe);
	ROUGHNESS = 0.85;
}
"""

var _belt_areas: Array[Area3D] = []
var _wake_timer := 0.0
var _st: SurfaceTool
var _body: StaticBody3D


func _ready() -> void:
	add_to_group("sell_machine")
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	add_child(_body)
	_build_block()
	_build_intake(Vector3(1, 0, 0))
	_build_intake(Vector3(0, 0, -1))
	var mi := MeshInstance3D.new()
	mi.mesh = _st.commit()
	mi.material_override = MeshKit.vertex_material(0.7)
	add_child(mi)


func _solid(from: Vector3, to: Vector3, col: Color, collide := true) -> void:
	var size := (to - from).abs()
	var center := (from + to) * 0.5
	MeshKit.add_box(_st, Transform3D(Basis.IDENTITY, center), size, col)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = center
		_body.add_child(cs)


func _build_block() -> void:
	var h := SIZE * 0.5
	var steel := Color(0.34, 0.42, 0.50)
	var steel_dark := Color(0.24, 0.29, 0.35)
	var yellow := Color(0.95, 0.74, 0.18)
	var inside := Color(0.05, 0.05, 0.05)
	var tw := TUNNEL_W * 0.5
	var depth := 1.0
	_solid(Vector3(-h, 0, -h), Vector3(h, TUNNEL_BOTTOM, h), steel_dark)
	_solid(Vector3(-h, TUNNEL_TOP, -h), Vector3(h, 2.6, h), steel)
	_solid(Vector3(-h, TUNNEL_BOTTOM, -h + depth), Vector3(h - depth, TUNNEL_TOP, h), steel)
	_solid(Vector3(h - depth, TUNNEL_BOTTOM, -h + depth), Vector3(h, TUNNEL_TOP, -tw), steel)
	_solid(Vector3(h - depth, TUNNEL_BOTTOM, tw), Vector3(h, TUNNEL_TOP, h), steel)
	_solid(Vector3(-h, TUNNEL_BOTTOM, -h), Vector3(-tw, TUNNEL_TOP, -h + depth), steel)
	_solid(Vector3(tw, TUNNEL_BOTTOM, -h), Vector3(h, TUNNEL_TOP, -h + depth), steel)
	_solid(Vector3(h - depth - 0.02, TUNNEL_BOTTOM, -tw), Vector3(h - depth, TUNNEL_TOP, tw), inside, false)
	_solid(Vector3(-tw, TUNNEL_BOTTOM, -h + depth), Vector3(tw, TUNNEL_TOP, -h + depth + 0.02), inside, false)
	_solid(Vector3(-h - 0.02, 2.6, -h - 0.02), Vector3(h + 0.02, 2.72, h + 0.02), yellow, false)
	_solid(Vector3(-h - 0.02, 0.0, -h - 0.02), Vector3(h + 0.02, 0.1, h + 0.02), yellow, false)
	_solid(Vector3(-h + 0.3, 2.72, h - 1.0), Vector3(-h + 0.8, 3.6, h - 0.5), steel_dark)
	_solid(Vector3(-h + 0.25, 3.6, h - 1.05), Vector3(-h + 0.85, 3.7, h - 0.45), yellow, false)
	for sign_axis in [Vector3(1, 0, 0), Vector3(0, 0, -1)]:
		var ax: Vector3 = sign_axis
		var side := Vector3(-ax.z, 0, ax.x)
		var face := ax * (h + 0.01)
		for y in [TUNNEL_BOTTOM - 0.05, TUNNEL_TOP + 0.05]:
			var c: Vector3 = face + Vector3.UP * y
			_solid(c - side * (tw + 0.1) - ax * 0.02 - Vector3.UP * 0.05, c + side * (tw + 0.1) + ax * 0.03 + Vector3.UP * 0.05, yellow, false)
		for k in 6:
			var x := -tw + TUNNEL_W * (k + 0.5) / 6.0
			var top := face + side * x + Vector3.UP * TUNNEL_TOP
			_solid(top - side * 0.06 - Vector3.UP * 0.42, top + side * 0.06 + ax * 0.02, Color(0.12, 0.12, 0.12), false)
	var inside_shape := BoxShape3D.new()
	inside_shape.size = Vector3(TUNNEL_W, TUNNEL_TOP - TUNNEL_BOTTOM, depth)
	for axis in [Vector3(1, 0, 0), Vector3(0, 0, -1)]:
		var a: Vector3 = axis
		var area := Area3D.new()
		area.collision_layer = 0
		area.collision_mask = HayPiece.LAYER
		var cs := CollisionShape3D.new()
		cs.shape = inside_shape
		area.add_child(cs)
		area.position = a * (h - depth * 0.5) + Vector3.UP * (TUNNEL_BOTTOM + TUNNEL_TOP) * 0.5
		area.rotation.y = PI * 0.5 if absf(a.x) > 0.5 else 0.0
		area.body_entered.connect(_on_intake_body)
		add_child(area)


func _build_intake(axis: Vector3) -> void:
	var h := SIZE * 0.5
	var side := Vector3(-axis.z, 0, axis.x)
	var start := axis * h
	var end := axis * (h + BELT_LENGTH)
	var mid := (start + end) * 0.5
	var basis := Basis(axis, Vector3.UP, axis.cross(Vector3.UP))
	var belt := StaticBody3D.new()
	belt.collision_layer = 1
	belt.set_meta("dir", -axis)
	belt.add_to_group("moving_belt")
	belt.constant_linear_velocity = -axis * ConveyorLine.speed
	var shape := BoxShape3D.new()
	shape.size = Vector3(BELT_LENGTH, 0.1, BELT_WIDTH)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(basis, mid + Vector3.UP * (BELT_TOP - 0.05))
	belt.add_child(cs)
	add_child(belt)
	var quad := PlaneMesh.new()
	quad.size = Vector2(BELT_LENGTH, BELT_WIDTH)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BELT_SHADER
	mat.shader = sh
	mat.set_shader_parameter("speed", -ConveyorLine.speed)
	mat.set_shader_parameter("length", BELT_LENGTH)
	var surface := MeshInstance3D.new()
	surface.mesh = quad
	surface.material_override = mat
	surface.add_to_group("belt_surface")
	surface.set_meta("sign", -1.0)
	surface.transform = Transform3D(basis, mid + Vector3.UP * (BELT_TOP + 0.002))
	add_child(surface)
	var frame := Color(0.30, 0.33, 0.36)
	var yellow := Color(0.95, 0.74, 0.18)
	for s in [-1.0, 1.0]:
		var rail_c: Vector3 = mid + side * s * (BELT_WIDTH * 0.5 + 0.04) + Vector3.UP * (BELT_TOP + 0.02)
		var rail_size := Vector3(BELT_LENGTH, 0.22, 0.08)
		MeshKit.add_box(_st, Transform3D(basis, rail_c), rail_size, yellow)
		var rs := BoxShape3D.new()
		rs.size = rail_size
		var rcs := CollisionShape3D.new()
		rcs.shape = rs
		rcs.transform = Transform3D(basis, rail_c)
		_body.add_child(rcs)
		for t in [0.2, BELT_LENGTH - 0.2]:
			var leg: Vector3 = start + axis * t + side * s * (BELT_WIDTH * 0.5 - 0.05)
			MeshKit.add_box(_st, Transform3D(Basis.IDENTITY, leg + Vector3.UP * (BELT_TOP - 0.1) * 0.5), Vector3(0.08, BELT_TOP - 0.1, 0.08), frame)
	MeshKit.add_box(_st, Transform3D(basis, mid + Vector3.UP * (BELT_TOP - 0.12)), Vector3(BELT_LENGTH, 0.12, BELT_WIDTH + 0.02), frame)
	var end_cap := end + Vector3.UP * (BELT_TOP + 0.02)
	MeshKit.add_box(_st, Transform3D(basis, end_cap), Vector3(0.08, 0.22, BELT_WIDTH + 0.16), yellow)
	var cap := BoxShape3D.new()
	cap.size = Vector3(0.08, 0.22, BELT_WIDTH + 0.16)
	var ccs := CollisionShape3D.new()
	ccs.shape = cap
	ccs.transform = Transform3D(basis, end_cap)
	_body.add_child(ccs)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = HayPiece.LAYER
	var ashape := BoxShape3D.new()
	ashape.size = Vector3(BELT_LENGTH, 0.5, BELT_WIDTH)
	var acs := CollisionShape3D.new()
	acs.shape = ashape
	acs.transform = Transform3D(basis, mid + Vector3.UP * (BELT_TOP + 0.25))
	area.add_child(acs)
	add_child(area)
	_belt_areas.append(area)


func intake_sockets() -> Array:
	var out: Array = []
	var h := SIZE * 0.5
	for axis in [Vector3(1, 0, 0), Vector3(0, 0, -1)]:
		var world_axis: Vector3 = (global_basis * axis).normalized()
		var outer: Vector3 = global_transform * (axis * (h + BELT_LENGTH))
		out.append({"pos": outer - world_axis * 0.6, "out": world_axis, "owner": self, "input": true})
	return out


func _on_intake_body(body: Node3D) -> void:
	if Net.is_client():
		return
	var piece := body as HayPiece
	if piece == null or piece.held_by != null or piece.is_queued_for_deletion() or piece.selling:
		return
	piece.selling = true
	var at := piece.global_position
	if piece.is_needle:
		piece.despawn()
		Sfx.play_at("purchase", at, 0.0, 0.0)
		needle_sold.emit(at)
		return
	piece.despawn()
	var price := int(main.stat("sell_price")) if main else PRICE
	Sfx.play_at("sell", at, -3.0, 0.06)
	_pop(at, price)
	if main and main.sync:
		main.sync.sell_fx(at, price)
	sold.emit(price, at)


func _pop(at: Vector3, price: int) -> void:
	var label := Label3D.new()
	label.text = "+$%d" % price
	label.font_size = 72
	label.pixel_size = 0.004
	label.outline_size = 14
	label.modulate = Color(0.55, 1.0, 0.45)
	label.outline_modulate = Color(0.05, 0.15, 0.05)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	get_parent().add_child(label)
	label.global_position = at + Vector3.UP * 0.6
	var tw := label.create_tween().set_parallel(true)
	tw.tween_property(label, "global_position", label.global_position + Vector3.UP * 0.9, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tw.chain().tween_callback(label.queue_free)


func _physics_process(delta: float) -> void:
	_wake_timer += delta
	if _wake_timer < 0.25:
		return
	_wake_timer = 0.0
	for area in _belt_areas:
		for body in area.get_overlapping_bodies():
			if body is RigidBody3D and (body as RigidBody3D).sleeping:
				(body as RigidBody3D).sleeping = false
