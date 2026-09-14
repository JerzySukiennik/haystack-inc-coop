# Hotbar glyph of the conveyor remote: a short belt with rollers and an antenna.
class_name ConveyorGlyph
extends Control

var active := false


func _draw() -> void:
	var w := size.x
	var h := size.y
	var body := Rect2(w * 0.14, h * 0.42, w * 0.72, h * 0.3)
	draw_style_box(UI.box(UI.HAY if active else UI.CREAM_DIM, 6, Color(0, 0, 0, 0), 0, 0, 0), body)
	draw_rect(Rect2(body.position + Vector2(4, 4), Vector2(body.size.x - 8, body.size.y * 0.42)), UI.INK_SOFT)
	for i in 5:
		var x := body.position.x + 8 + i * (body.size.x - 16) / 4.0
		draw_line(Vector2(x, body.position.y + 5), Vector2(x, body.position.y + body.size.y * 0.42 + 3), Color(UI.CREAM, 0.35), 1.5)
	for x in [body.position.x, body.end.x]:
		draw_circle(Vector2(x, body.get_center().y), body.size.y * 0.42, Color("8b96a1"))
	draw_line(Vector2(body.end.x - 8, body.position.y), Vector2(body.end.x + 2, h * 0.14), UI.INK, 2.5, true)
	draw_circle(Vector2(body.end.x + 2, h * 0.14), 3.0, UI.BARN)
