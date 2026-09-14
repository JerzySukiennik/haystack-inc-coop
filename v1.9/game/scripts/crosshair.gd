# Crosshair: a center dot, and a small progress/charge bar just below it.
class_name Crosshair
extends Control

const BAR_W := 52.0
const BAR_H := 6.0
const BAR_GAP := 14.0

var interact := false
var progress := 0.0
var charge := 0.0
var warn := false
var _bar_alpha := 0.0


func _process(delta: float) -> void:
	_bar_alpha = lerpf(_bar_alpha, 1.0 if (progress > 0.0 or charge > 0.0) else 0.0, 1.0 - exp(-delta * 20.0))
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, 3.6, Color(0, 0, 0, 0.45))
	draw_circle(c, 2.4, UI.CREAM if not warn else UI.BARN)
	if _bar_alpha > 0.02:
		var amount := progress if progress > 0.0 else charge
		var col := UI.HAY if progress > 0.0 else UI.HAY.lerp(UI.BARN, charge)
		var rect := Rect2(c.x - BAR_W * 0.5, c.y + BAR_GAP, BAR_W, BAR_H)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.55 * _bar_alpha)
		bg.set_corner_radius_all(3)
		bg.expand_margin_left = 2
		bg.expand_margin_right = 2
		bg.expand_margin_top = 2
		bg.expand_margin_bottom = 2
		draw_style_box(bg, rect)
		if amount > 0.0:
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color(col, _bar_alpha)
			fill.set_corner_radius_all(3)
			draw_style_box(fill, Rect2(rect.position, Vector2(maxf(rect.size.x * clampf(amount, 0.0, 1.0), BAR_H), BAR_H)))
