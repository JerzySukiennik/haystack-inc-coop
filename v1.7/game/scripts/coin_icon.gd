# Custom-drawn coin glyph used in money chips.
class_name CoinIcon
extends Control


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	draw_circle(c + Vector2(0, 1.5), r - 1.0, UI.HAY_DEEP.darkened(0.35))
	draw_circle(c, r - 1.0, UI.HAY_DEEP)
	draw_circle(c, r - 3.5, UI.HAY)
	draw_arc(c, r - 6.0, 0.0, TAU, 24, Color(UI.HAY_DEEP, 0.7), 1.5, true)
	draw_line(c + Vector2(0, -r * 0.42), c + Vector2(0, r * 0.42), UI.HAY_DEEP.darkened(0.2), 2.0, true)
