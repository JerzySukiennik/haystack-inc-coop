# Wooden shop booth outside the yard fence with a striped awning and a coin emblem; press E nearby to open the shop.
class_name ShopBooth
extends StaticBody3D


func _ready() -> void:
	add_to_group("shop_booth")
	collision_layer = 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.58, 0.40, 0.24)
	var wood_dark := Color(0.42, 0.28, 0.17)
	var wood_light := Color(0.72, 0.53, 0.33)
	var red := Color(0.80, 0.22, 0.18)
	var cream := Color(0.95, 0.90, 0.80)
	var gold := Color(0.98, 0.78, 0.26)
	var green := Color(0.30, 0.55, 0.28)
	var w := 3.2
	var d := 2.0
	var box := func(center: Vector3, size: Vector3, col: Color, collide: bool) -> void:
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, center), size, col)
		if collide:
			var shape := BoxShape3D.new()
			shape.size = size
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = center
			add_child(cs)
	box.call(Vector3(0, 0.1, 0), Vector3(w + 0.4, 0.2, d + 0.4), wood_dark, true)
	box.call(Vector3(0, 1.4, -d * 0.5 + 0.06), Vector3(w, 2.6, 0.12), wood, true)
	box.call(Vector3(-w * 0.5 + 0.06, 1.4, 0), Vector3(0.12, 2.6, d), wood, true)
	box.call(Vector3(w * 0.5 - 0.06, 1.4, 0), Vector3(0.12, 2.6, d), wood, true)
	box.call(Vector3(0, 0.6, d * 0.5 - 0.1), Vector3(w, 1.0, 0.2), wood_light, true)
	box.call(Vector3(0, 1.13, d * 0.5 - 0.05), Vector3(w + 0.1, 0.08, 0.45), wood_dark, false)
	for i in 8:
		var y := 0.25 + i * 0.1
		box.call(Vector3(0, y, d * 0.5 + 0.005), Vector3(w - 0.05, 0.015, 0.01), wood_dark, false)
	for s in [-1.0, 1.0]:
		box.call(Vector3(s * (w * 0.5 - 0.1), 1.7, d * 0.5 - 0.1), Vector3(0.14, 2.8, 0.14), wood_dark, true)
	box.call(Vector3(0, 2.75, 0), Vector3(w + 0.3, 0.12, d + 0.2), wood_dark, false)
	var stripes := 8
	for i in stripes:
		var x := -w * 0.5 - 0.15 + (w + 0.3) * (i + 0.5) / stripes
		var col := red if i % 2 == 0 else cream
		var a := Vector3(x - (w + 0.3) / stripes * 0.5, 2.8, -0.2)
		var b := Vector3(x + (w + 0.3) / stripes * 0.5, 2.8, -0.2)
		var c := Vector3(b.x, 2.35, d * 0.5 + 0.7)
		var e := Vector3(a.x, 2.35, d * 0.5 + 0.7)
		MeshKit.add_quad_out(st, a, b, c, e, Vector3(x, 0.0, 0.0), col)
		MeshKit.add_quad_out(st, e, c, b, a, Vector3(x, 5.0, 0.0), col)
		var fl := Vector3(x, 2.2, d * 0.5 + 0.72)
		MeshKit.add_tri(st, e, c, fl, Vector3(0, 0, 1), col)
	for k in 3:
		var shelf_y := 1.35 + k * 0.45
		box.call(Vector3(0, shelf_y, -d * 0.5 + 0.3), Vector3(w - 0.3, 0.05, 0.36), wood_dark, false)
		for j in 5:
			var cx := -w * 0.5 + 0.45 + j * 0.58
			var colors := [red, green, gold, Color(0.35, 0.55, 0.78), cream]
			box.call(Vector3(cx, shelf_y + 0.12, -d * 0.5 + 0.3), Vector3(0.22, 0.2 + (j % 3) * 0.04, 0.2), colors[(j + k) % colors.size()], false)
	var sign_c := Vector3(0, 3.35, d * 0.5 - 0.2)
	box.call(sign_c, Vector3(1.3, 0.9, 0.08), wood_dark, false)
	box.call(sign_c + Vector3(0, 0, 0.05), Vector3(1.15, 0.75, 0.04), cream, false)
	for ring in 2:
		var r := 0.28 if ring == 0 else 0.2
		var col := gold if ring == 0 else Color(0.90, 0.66, 0.18)
		var center := sign_c + Vector3(0, 0, 0.08 + ring * 0.02)
		for j in 16:
			var a0 := TAU * j / 16.0
			var a1 := TAU * (j + 1) / 16.0
			MeshKit.add_tri(st, center, center + Vector3(cos(a0) * r, sin(a0) * r, 0), center + Vector3(cos(a1) * r, sin(a1) * r, 0), Vector3(0, 0, 1), col)
	box.call(sign_c + Vector3(0, 0, 0.13), Vector3(0.05, 0.22, 0.01), gold.darkened(0.35), false)
	for s in [-1.0, 1.0]:
		box.call(Vector3(s * 0.45, 3.0, d * 0.5 - 0.2), Vector3(0.03, 0.4, 0.03), wood_dark, false)
	box.call(Vector3(-0.9, 1.26, d * 0.5 - 0.1), Vector3(0.3, 0.18, 0.3), gold, false)
	box.call(Vector3(1.0, 1.3, d * 0.5 - 0.1), Vector3(0.18, 0.26, 0.18), green, false)
	var pick := Area3D.new()
	pick.collision_layer = HayPiece.PICK_LAYER
	pick.collision_mask = 0
	pick.monitoring = false
	var pick_shape := BoxShape3D.new()
	pick_shape.size = Vector3(w, 2.6, d + 0.6)
	var pcs := CollisionShape3D.new()
	pcs.shape = pick_shape
	pcs.position = Vector3(0, 1.4, 0.3)
	pick.add_child(pcs)
	add_child(pick)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.5)
	lamp.light_energy = 1.2
	lamp.omni_range = 4.0
	lamp.position = Vector3(0, 2.4, 0.3)
	add_child(lamp)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = MeshKit.vertex_material(0.85, BaseMaterial3D.CULL_DISABLED)
	add_child(mi)
