# Sell bin: an open crate that sells every straw landing in it at the current price; the needle wins the game.
class_name MiniSeller
extends Machine


func footprint() -> Vector3:
	return Vector3(1.5, 1.0, 1.5)


func footprint_center() -> Vector3:
	return Vector3(0, 0.5, 0)


func _build() -> void:
	var wood := Color(0.55, 0.38, 0.22)
	var dark := Color(0.35, 0.24, 0.14)
	var green := Color(0.36, 0.62, 0.3)
	var h := 0.85
	var w := 1.4
	box(Vector3(0, 0.05, 0), Vector3(w, 0.1, w), dark)
	for s in [-1.0, 1.0]:
		box(Vector3(s * (w * 0.5 - 0.05), h * 0.5, 0), Vector3(0.1, h, w), wood)
		box(Vector3(0, h * 0.5, s * (w * 0.5 - 0.05)), Vector3(w, h, 0.1), wood)
	for y in [0.25, 0.6]:
		for s in [-1.0, 1.0]:
			box(Vector3(s * (w * 0.5 + 0.005), y, 0), Vector3(0.02, 0.08, w), dark, false)
			box(Vector3(0, y, s * (w * 0.5 + 0.005)), Vector3(w, 0.08, 0.02), dark, false)
	box(Vector3(0, h + 0.04, w * 0.5), Vector3(w + 0.1, 0.08, 0.12), green, false)
	box(Vector3(0, h + 0.04, -w * 0.5), Vector3(w + 0.1, 0.08, 0.12), green, false)
	for k in 3:
		var cx := -0.3 + k * 0.3
		MeshKit.add_cylinder(_st, Vector3(cx, h + 0.1, w * 0.5 + 0.07), 0.02, 0.09, 0.09, 10, Color(0.98, 0.78, 0.3), Color(0.98, 0.8, 0.35))


func _build_dynamic() -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = HayPiece.LAYER
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 0.9, 1.2)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 0.6, 0)
	area.add_child(cs)
	area.body_entered.connect(_on_body)
	add_child(area)


func sockets() -> Array:
	return [world_socket(Vector3(0, 0, -0.2), Vector3(0, 0, -1), true)]


func _on_body(body: Node3D) -> void:
	var piece := body as HayPiece
	if Net.is_client() or not accepts_straw(piece):
		return
	piece.selling = true
	var at := piece.global_position
	piece.despawn()
	if piece.is_needle:
		main._on_needle_sold(at)
		return
	var price := int(main.stat("sell_price"))
	main.earn(price, at)
	Sfx.play_at("sell", at, -4.0, 0.06)
	if main.sync:
		main.sync.sell_fx(at, price)
