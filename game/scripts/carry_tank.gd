# Storage shared by the basket and the vacuum: absorbs physical straws and spawns them back out, keeping needles.
class_name CarryTank
extends RefCounted

var items: Array[Dictionary] = []


func count() -> int:
	return items.size()


func absorb(piece: HayPiece) -> void:
	var col := Color(0.85, 0.7, 0.35)
	var mat := piece.get_child(0) as MeshInstance3D
	if mat and mat.material_override is StandardMaterial3D:
		col = (mat.material_override as StandardMaterial3D).albedo_color
	items.append({"needle": piece.is_needle, "color": col, "length": piece.length})
	piece.selling = true
	piece.despawn()


func emit_one(stack: Haystack, pos: Vector3, velocity: Vector3) -> HayPiece:
	if items.is_empty():
		return null
	var it: Dictionary = items.pop_back()
	var piece := stack.spawn_piece(pos, Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)), it.color, it.length)
	if it.needle:
		piece.make_needle(stack.needle_material())
	piece.linear_velocity = velocity
	piece.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	piece.set_meta("junction_until", 0)
	return piece
