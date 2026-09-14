# Hopper: a funnel that swallows straws dropped or poured into it and feeds them out one by one onto its belt.
class_name Hopper
extends Machine

var tank := CarryTank.new()
var _cd := 0.0
var absorbed := 0
var emitted := 0


func footprint() -> Vector3:
	return Vector3(1.7, 1.3, 3.0)


func footprint_center() -> Vector3:
	return Vector3(0, 0.7, 0.6)


func _build() -> void:
	var steel := Color(0.36, 0.42, 0.48)
	var dark := Color(0.2, 0.22, 0.25)
	var yellow := Color(0.95, 0.74, 0.18)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box(Vector3(sx * 0.62, 0.3, -0.4 + sz * 0.62), Vector3(0.1, 0.6, 0.1), dark)
	var c := Vector3(0, 0, -0.4)
	var top := 1.25
	var bottom := 0.55
	var rt := 0.8
	var rb := 0.25
	var corners_t := [Vector3(-rt, top, -rt), Vector3(rt, top, -rt), Vector3(rt, top, rt), Vector3(-rt, top, rt)]
	var corners_b := [Vector3(-rb, bottom, -rb), Vector3(rb, bottom, -rb), Vector3(rb, bottom, rb), Vector3(-rb, bottom, rb)]
	for i in 4:
		var a: Vector3 = corners_t[i] + c
		var b: Vector3 = corners_t[(i + 1) % 4] + c
		var d: Vector3 = corners_b[(i + 1) % 4] + c
		var e: Vector3 = corners_b[i] + c
		var col := steel if i % 2 == 0 else steel.darkened(0.12)
		MeshKit.add_quad_out(_st, a, b, d, e, c + Vector3.UP * 3.0, col)
		MeshKit.add_quad_out(_st, a, b, d, e, c + Vector3.DOWN * 3.0, col.darkened(0.3))
	box(c + Vector3(0, top + 0.03, -rt), Vector3(rt * 2.0 + 0.1, 0.08, 0.08), yellow, false)
	box(c + Vector3(0, top + 0.03, rt), Vector3(rt * 2.0 + 0.1, 0.08, 0.08), yellow, false)
	box(c + Vector3(-rt, top + 0.03, 0), Vector3(0.08, 0.08, rt * 2.0 + 0.1), yellow, false)
	box(c + Vector3(rt, top + 0.03, 0), Vector3(0.08, 0.08, rt * 2.0 + 0.1), yellow, false)
	box(c + Vector3(0, bottom - 0.1, 0), Vector3(rb * 2.2, 0.2, rb * 2.2), dark, false)
	if not preview:
		var core := BoxShape3D.new()
		core.size = Vector3(1.1, 0.35, 1.1)
		var ccs := CollisionShape3D.new()
		ccs.shape = core
		ccs.position = c + Vector3(0, 0.72, 0)
		_body.add_child(ccs)
	belt(Vector3(0, 0, 0.45), Vector3(0, 0, 1), 1.5, true)


func _build_dynamic() -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = HayPiece.LAYER
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 1.3, 1.6)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 1.3, -0.4)
	area.add_child(cs)
	area.body_entered.connect(_on_body)
	add_child(area)


func _on_body(body: Node3D) -> void:
	var piece := body as HayPiece
	if not accepts_straw(piece):
		return
	tank.absorb(piece)
	absorbed += 1
	Sfx.play_at("basket_collect", global_position + Vector3.UP, -12.0)


func sockets() -> Array:
	return [world_socket(Vector3(0, 0, -0.4), Vector3(0, 0, -1), true), world_socket(Vector3(0, 0, 1.95), Vector3(0, 0, 1), false)]


func _process(delta: float) -> void:
	if preview or main == null:
		return
	_cd -= delta
	if _cd > 0.0 or tank.count() == 0:
		return
	_cd = clampf(0.6 / maxf(ConveyorLine.speed, 0.1), 0.15, 0.6)
	var pos := global_transform * Vector3(0, ConveyorLine.TOP + 0.2, 1.05)
	var piece := tank.emit_one(main.haystack, pos, Vector3.ZERO)
	if piece:
		emitted += 1
		piece.global_basis = global_basis
		Sfx.play_at("hopper_drop", pos, -12.0)
