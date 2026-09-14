# Tool belt: owns every handheld tool, maps hotbar keys 1-9 to owned items and routes mouse input to the tool in hand.
class_name ToolBelt
extends Node3D

signal changed

var main: Node
var player: Player
var conveyor: ConveyorTool
var tools := {}
var current := ""


func setup(p_main: Node, p_player: Player, p_conveyor: ConveyorTool) -> void:
	main = p_main
	player = p_player
	conveyor = p_conveyor
	var classes := {
		"pitchfork": PitchforkTool, "basket": BasketTool, "blower": BlowerTool, "vacuum": VacuumTool,
		"shop_remote": ShopRemoteTool, "auto_puller": MachineTool, "hopper": MachineTool, "mini_seller": MachineTool,
	}
	for tid in classes:
		var t: HandTool = (classes[tid] as GDScript).new()
		t.name = tid
		add_child(t)
		t.setup(main, player, tid)
		tools[tid] = t


var equipped: bool:
	get:
		return current != ""


var placing: bool:
	get:
		return (current == "conveyor_remote" and conveyor.placing) or (current != "" and tools.has(current) and (tools[current] as HandTool).captures_scroll())


func owned(tid: String) -> bool:
	var it := Catalog.item(tid)
	if it.kind == "machine":
		if int(main.machines.get(tid, 0)) > 0:
			return true
		for m in get_tree().get_nodes_in_group("machine"):
			if (m as Machine).id == tid and not (m as Machine).preview:
				return true
		return false
	return int(main.levels.get(tid, 0)) > 0


func slots() -> Array:
	var out: Array = []
	for tid in Catalog.slot_items():
		if owned(tid):
			out.append(tid)
	return out


func equip_slot(slot: int) -> void:
	for tid in Catalog.slot_items():
		if int(Catalog.item(tid).slot) == slot:
			if not owned(tid):
				Sfx.play_ui("deny", -10.0)
				return
			equip(tid if current != tid else "")
			return


func equip(tid: String) -> void:
	if current == tid:
		return
	if current == "conveyor_remote":
		conveyor.set_equipped(false)
	elif current != "":
		(tools[current] as HandTool).set_equipped(false)
	current = tid
	if tid == "conveyor_remote":
		conveyor.set_equipped(true)
	elif tid != "":
		(tools[tid] as HandTool).set_equipped(true)
	changed.emit()


func active() -> HandTool:
	return tools.get(current) as HandTool if tools.has(current) else null


func primary() -> void:
	if current == "conveyor_remote":
		conveyor.primary()
	elif active():
		active().primary(true)


func primary_up() -> void:
	if active():
		active().primary(false)


func secondary(pressed: bool) -> void:
	if current == "conveyor_remote":
		conveyor.secondary(pressed)
	elif active():
		active().secondary(pressed)


func scroll(steps: int) -> void:
	if current == "conveyor_remote":
		conveyor.scroll(steps)
	elif active():
		active().scroll(steps)


func pan(dy: float) -> void:
	if current == "conveyor_remote":
		conveyor.pan(dy)


func rotate_action() -> void:
	if current == "conveyor_remote":
		conveyor.rotate_action()
	elif active():
		active().rotate_action()


func cancel() -> void:
	if current == "conveyor_remote":
		conveyor.cancel()
	elif active():
		active().cancel()


func prompt() -> Dictionary:
	if active():
		return active().prompt()
	return {}


func hud_info(tid: String) -> String:
	if tid == "conveyor_remote":
		return "%d m of belt" % int(main.conveyor_meters)
	if tools.has(tid):
		return (tools[tid] as HandTool).hud_info()
	return ""
