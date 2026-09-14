# Crosshair: center dot, interaction ring and progress rings for pulling, dismantling and throw charge.
class_name Crosshair
extends Control

var interact := false
var progress := 0.0
var charge := 0.0
var warn := false
var _ring := 0.0


func _process(delta: float) -> void:
	_ring = lerpf(_ring, 1.0 if interact or progress > 0.0 else 0.0, 1.0 - exp(-delta * 18.0))
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, 3.6, Color(0, 0, 0, 0.45))
	draw_circle(c, 2.4, UI.CREAM if not warn else UI.BARN)
	if _ring > 0.02:
		var r := lerpf(4.0, 13.0, _ring)
		draw_arc(c, r, 0.0, TAU, 40, Color(0, 0, 0, 0.35 * _ring), 4.0, true)
		draw_arc(c, r, 0.0, TAU, 40, Color(UI.CREAM, 0.55 * _ring), 2.0, true)
	if progress > 0.0:
		draw_arc(c, 13.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, UI.HAY, 3.5, true)
	if charge > 0.0:
		var col := UI.HAY.lerp(UI.BARN, charge)
		draw_arc(c, 19.0, PI * 0.75, PI * 0.75 + PI * 1.5 * charge, 40, Color(0, 0, 0, 0.35), 6.0, true)
		draw_arc(c, 19.0, PI * 0.75, PI * 0.75 + PI * 1.5 * charge, 40, col, 3.5, true)
