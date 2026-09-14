# Shop remote: click to open the shop from anywhere on the plate.
class_name ShopRemoteTool
extends HandTool


func primary(pressed: bool) -> void:
	if pressed:
		kick(1.0)
		Sfx.play_ui("holo_start", -8.0)
		main.open_shop.call_deferred()


func prompt() -> Dictionary:
	return {"spec": [["LMB", "Open the shop"], ["6", "Put away"]], "warn": "", "interact": false}
