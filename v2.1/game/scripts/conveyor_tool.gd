# Conveyor remote: click a start point, walk while a green/red hologram follows live, scroll to bend, click again to build.
class_name ConveyorTool
extends Node3D

signal state_changed(kind: String)
signal placed(line: ConveyorLine)
signal dismantle_progress(amount: float)

const RANGE := 22.0
const STEP := 0.5
const MAX_BEND := 7
const SNAP_RADIUS := 1.3
const DISMANTLE_TIME := 0.7
const HOVER_RANGE := 7.0
const HOLO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.3, 1.0, 0.45, 0.4);
void fragment() {
	float scan = 0.75 + 0.25 * sin(TIME * 5.0 + FRAGCOORD.y * 0.08);
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	ALBEDO = tint.rgb * (0.8 + rim * 0.6);
	ALPHA = tint.a * scan + rim * 0.25;
}
"""

var main: Node
var player: Player
var equipped := false
var placing := false
var valid := false
var reason := ""
var bend := 0
var start := Vector3.ZERO
var start_dir := Vector3.FORWARD
var _end := Vector3.ZERO
var _end_smooth := Vector3.ZERO
var _points := PackedVector3Array()
var _grounds := PackedFloat32Array()
var _holo: MeshInstance3D
var _holo_mat: ShaderMaterial
var _viewmodel: MeshInstance3D
var _pan := 0.0
var _kind := ""
var flip := false
var start_snap := {}
var end_snap := {}
var hover_line: ConveyorLine
var _dismantling := false
var _dismantle_t := 0.0
var _flow_forward := true
var last_link := ""


func _ready() -> void:
	_holo = MeshInstance3D.new()
	_holo_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = HOLO_SHADER
	_holo_mat.shader = sh
	_holo.material_override = _holo_mat
	_holo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holo.visible = false
	add_child(_holo)


func attach(p: Player) -> void:
	player = p
	_viewmodel = MeshInstance3D.new()
	_viewmodel.mesh = Items.conveyor_remote_mesh()
	_viewmodel.material_override = MeshKit.vertex_material(0.6)
	_viewmodel.position = Vector3(0.24, -0.2, -0.46)
	_viewmodel.rotation = Vector3(0.55, 0.45, 0.1)
	_viewmodel.scale = Vector3.ONE * 0.7
	_viewmodel.visible = false
	_viewmodel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.camera.add_child(_viewmodel)


func meters_owned() -> int:
	return main.conveyor_meters


func set_equipped(on: bool) -> void:
	if on == equipped:
		return
	equipped = on
	if not on:
		cancel()
	_viewmodel.visible = on
	if on:
		player.drop()
		player.cancel_pull()
		_viewmodel.position.y = -0.42
		create_tween().tween_property(_viewmodel, "position:y", -0.2, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_emit_state()


func _aim_point() -> Dictionary:
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		var flat := from - cam.global_basis.z * RANGE
		return {"point": Vector3(flat.x, _ground_at(flat), flat.z), "ok": false}
	return {"point": hit.position, "ok": true}


func _ground_at(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 60.0, p.z), Vector3(p.x, -20.0, p.z), 1)
	q.collide_with_areas = false
	var body: Node = main.get_node_or_null("Ground")
	if body:
		var space := get_world_3d().direct_space_state
		var hits := 0
		while hits < 6:
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			if hit.collider == body:
				return hit.position.y
			var ex: Array[RID] = q.exclude
			ex.append(hit.rid)
			q.exclude = ex
			hits += 1
	return World.ground_height(p.x, p.z)


func primary() -> void:
	if not equipped:
		return
	if not placing:
		var aim := _aim_point()
		if not aim.ok:
			Sfx.play_ui("deny", -8.0)
			return
		placing = true
		bend = 0
		flip = false
		end_snap = {}
		start_snap = find_socket(aim.point)
		start = start_snap.pos if not start_snap.is_empty() else aim.point
		start.y = _ground_at(start)
		var f := -player.camera.global_basis.z
		f.y = 0.0
		start_dir = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
		_end_smooth = start + start_dir * 1.0
		_holo.visible = true
		Sfx.play_ui("holo_start", -6.0)
		_update_path(0.0)
	elif valid:
		_place()
	else:
		Sfx.play_ui("deny", -6.0)
	_emit_state()


func cancel() -> void:
	if placing:
		Sfx.play_ui("holo_cancel", -8.0)
	placing = false
	_holo.visible = false
	_emit_state()


func scroll(steps: int) -> void:
	if not placing:
		return
	bend = clampi(bend + steps, -MAX_BEND, MAX_BEND)


func pan(delta_y: float) -> void:
	_pan += delta_y
	while absf(_pan) >= 1.0:
		scroll(-1 if _pan > 0.0 else 1)
		_pan -= signf(_pan)


func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t


func _update_path(delta: float) -> void:
	var aim := _aim_point()
	_end = aim.point
	end_snap = find_socket(_end, start_snap.get("owner", null), true)
	var k := 1.0 - exp(-delta * 14.0) if delta > 0.0 else 1.0
	if not end_snap.is_empty():
		_end_smooth = _end_smooth.lerp(end_snap.pos, maxf(k, 0.5))
	else:
		_end_smooth = _end_smooth.lerp(_end, k)
	var p0 := Vector3(start.x, 0, start.z)
	var p3 := Vector3(_end_smooth.x, 0, _end_smooth.z)
	var chord := p0.distance_to(p3)
	var along := (p3 - p0).normalized() if chord > 0.01 else start_dir
	var angle := deg_to_rad(bend * 12.0)
	var t0: Vector3 = start_snap.out if not start_snap.is_empty() else along.rotated(Vector3.UP, angle)
	var t1: Vector3 = -(end_snap.out as Vector3) if not end_snap.is_empty() else along.rotated(Vector3.UP, -angle)
	var p1 := p0 + t0 * chord * 0.38
	var p2 := p3 - t1 * chord * 0.38
	var auto_forward := true
	if not start_snap.is_empty():
		auto_forward = not start_snap.input
	elif not end_snap.is_empty():
		auto_forward = end_snap.input
	_flow_forward = auto_forward != flip
	var dense := PackedVector3Array()
	for i in 65:
		dense.append(_bezier(p0, p1, p2, p3, i / 64.0))
	var total := 0.0
	for i in dense.size() - 1:
		total += dense[i].distance_to(dense[i + 1])
	_points = PackedVector3Array()
	_grounds = PackedFloat32Array()
	var count := maxi(int(ceil(total / STEP)), 1)
	var seg := total / count
	var want := 0.0
	var acc := 0.0
	var j := 0
	for n in count + 1:
		want = n * seg
		while j < dense.size() - 2 and acc + dense[j].distance_to(dense[j + 1]) < want:
			acc += dense[j].distance_to(dense[j + 1])
			j += 1
		var l := dense[j].distance_to(dense[j + 1])
		var t := clampf((want - acc) / maxf(l, 0.0001), 0.0, 1.0)
		var flat := dense[j].lerp(dense[j + 1], t)
		var g := _ground_at(flat)
		_grounds.append(g)
		_points.append(Vector3(flat.x, g + ConveyorLine.TOP, flat.z))
	_validate(total)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if _points.size() >= 2:
		ConveyorLine.add_visual(st, _points, _grounds, Color.WHITE)
		st.append_from(ConveyorLine.belt_mesh(_points), 0, Transform3D.IDENTITY)
		_add_arrows(st)
	_holo.mesh = st.commit()
	_holo_mat.set_shader_parameter("tint", Color(0.3, 1.0, 0.45, 0.35) if valid else Color(1.0, 0.25, 0.2, 0.4))


func length_meters() -> int:
	if _points.size() < 2:
		return 0
	var total := 0.0
	for i in _points.size() - 1:
		var a := _points[i]
		var b := _points[i + 1]
		total += Vector2(a.x - b.x, a.z - b.z).length()
	return maxi(int(ceil(total - 0.05)), 1)


func _validate(total: float) -> void:
	valid = true
	reason = ""
	var need := length_meters()
	if total < 0.9:
		valid = false
		reason = "short"
		return
	if need > meters_owned():
		valid = false
		reason = "meters"
	var space := get_world_3d().direct_space_state
	var ground: Node = main.get_node_or_null("Ground")
	var shape := BoxShape3D.new()
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = 1 | 16
	var excl: Array[RID] = [player.get_rid()]
	if ground:
		excl.append((ground as CollisionObject3D).get_rid())
	params.exclude = excl
	for g in _grounds:
		if g < -1.0:
			valid = false
			reason = "offplate"
			return
	var dist := 0.0
	for i in _points.size() - 1:
		var a := _points[i]
		var b := _points[i + 1]
		var slope := absf(b.y - a.y) / maxf(Vector2(a.x - b.x, a.z - b.z).length(), 0.01)
		if slope > 0.6:
			valid = false
			reason = "blocked"
			return
		dist += a.distance_to(b)
		var basis := ConveyorLine.piece_basis(a, b)
		var mid := (a + b) * 0.5
		var low := minf(_grounds[i], _grounds[i + 1]) + 0.3
		var height := mid.y + 0.15 - low
		shape.size = Vector3(a.distance_to(b), maxf(height, 0.1), ConveyorLine.WIDTH + 0.16)
		params.transform = Transform3D(basis, Vector3(mid.x, low + height * 0.5, mid.z))
		for hit in space.intersect_shape(params, 8):
			var node: Node = hit.collider
			if node is HayPiece:
				continue
			var near_end := total - dist < 1.4
			if near_end and _belongs_to_sell_machine(node):
				continue
			var owner := _owner_of(node)
			if owner != null:
				if not start_snap.is_empty() and owner == start_snap.owner and dist < 1.4:
					continue
				if not end_snap.is_empty() and owner == end_snap.owner and total - dist < 1.4:
					continue
			valid = false
			reason = "blocked"
			return


func _owner_of(node: Node) -> Node:
	while node:
		if node is ConveyorLine or node is SellMachine or node is Machine:
			return node
		node = node.get_parent()
	return null


func all_sockets() -> Array:
	var out: Array = []
	for line in get_tree().get_nodes_in_group("conveyor"):
		if (line as ConveyorLine).points.size() >= 2:
			out.append_array((line as ConveyorLine).sockets())
	if main.sell_machine:
		out.append_array(main.sell_machine.intake_sockets())
	for m in get_tree().get_nodes_in_group("machine"):
		if not (m as Machine).preview:
			out.append_array((m as Machine).sockets())
	return out


func find_socket(point: Vector3, exclude_owner: Object = null, as_end := false) -> Dictionary:
	var best := {}
	var best_d := SNAP_RADIUS
	for sock in all_sockets():
		if exclude_owner != null and sock.owner == exclude_owner:
			continue
		var p: Vector3 = sock.pos
		var d := Vector2(p.x - point.x, p.z - point.z).length()
		if d < best_d:
			best_d = d
			best = sock
	if not best.is_empty():
		return best
	for line in get_tree().get_nodes_in_group("conveyor"):
		var l := line as ConveyorLine
		if l == exclude_owner or l.points.size() < 2:
			continue
		var pr := l.project(point)
		if pr.is_empty() or pr.dist > 1.0:
			continue
		var total := l.length()
		if pr.along < 0.9 or pr.along > total - 0.9:
			continue
		var side: Vector3 = pr.side
		var off := ConveyorLine.WIDTH * 0.5 + 0.55
		return {"pos": (pr.pos as Vector3) + side * off, "out": side, "owner": l, "input": as_end, "mid": true, "along": pr.along, "anchor": pr.pos}
	return {}


func _link_junctions(line: ConveyorLine) -> void:
	for info in [[start_snap, true], [end_snap, false]]:
		var snap: Dictionary = info[0]
		if snap.is_empty() or not snap.get("mid", false):
			continue
		var main_line: ConveyorLine = snap.owner
		var at_click_start: bool = info[1]
		var is_flow_start := at_click_start == _flow_forward
		if is_flow_start:
			main_line.add_split(snap.along, line)
		else:
			line.set_feed(main_line, snap.along)
	last_link = ""
	for info in [start_snap, end_snap]:
		if not info.is_empty() and info.get("mid", false):
			last_link = "junction"


func junction_kind() -> String:
	for info in [[start_snap, true], [end_snap, false]]:
		var snap: Dictionary = info[0]
		if snap.is_empty() or not snap.get("mid", false):
			continue
		return "split" if (info[1] == _flow_forward) else "merge"
	return ""


func _add_arrows(st: SurfaceTool) -> void:
	var pts := _flow_points()
	var dist := 0.0
	var next := 0.6
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		while next <= dist + seg:
			var t := (next - dist) / seg
			var c := a.lerp(b, t) + Vector3.UP * 0.06
			var f := ConveyorLine.flat_dir(a, b)
			var side := Vector3(-f.z, 0, f.x)
			var tip := c + f * 0.22
			for off in [0.0, -0.16]:
				var o: Vector3 = f * off
				MeshKit.add_tri(st, tip + o, c - f * 0.05 + side * 0.2 + o, c + f * 0.05 + o, Vector3.UP, Color.WHITE)
				MeshKit.add_tri(st, tip + o, c + f * 0.05 + o, c - f * 0.05 - side * 0.2 + o, Vector3.UP, Color.WHITE)
			next += 1.0
		dist += seg


func _flow_points() -> PackedVector3Array:
	var pts := _points.duplicate()
	if not _flow_forward:
		pts.reverse()
	return pts


func rotate_action() -> void:
	if not equipped:
		return
	if placing:
		flip = not flip
		Sfx.play_ui("holo_start", -10.0)
	elif is_instance_valid(hover_line):
		var had_links := not hover_line.splits.is_empty() or not hover_line.feeds.is_empty()
		if Net.is_client():
			main.sync.req_reverse_line.rpc_id(1, hover_line.net_id)
		else:
			reverse_line(hover_line)
		main.hud.toast("Reversed" + (" · its splitters and merges were removed" if had_links else ""), "info")
		Sfx.play_at("holo_place", hover_line.points[hover_line.points.size() / 2], -8.0)
	_emit_state()


func secondary(pressed: bool) -> void:
	if not equipped:
		return
	if placing:
		if pressed:
			cancel()
		return
	if pressed and is_instance_valid(hover_line):
		_dismantling = true
		_dismantle_t = 0.0
	elif not pressed:
		_dismantling = false
		_dismantle_t = 0.0
		dismantle_progress.emit(0.0)


func _update_hover_line() -> void:
	hover_line = null
	if placing:
		return
	var cam := player.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * HOVER_RANGE, 1)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var owner := _owner_of(hit.collider)
		if owner is ConveyorLine:
			hover_line = owner


func dismantle(line: ConveyorLine) -> void:
	if Net.is_client():
		main.sync.req_dismantle_line.rpc_id(1, line.net_id)
		main.hud.toast("Dismantled · +%d m of belt back" % line.meters, "info")
		Sfx.play_ui("holo_cancel", -8.0)
		return
	var touched := line.clear_links()
	if main.sync:
		main.sync.lines_relinked(touched)
		main.sync.line_removed(line.net_id)
	var refund := line.meters
	var at := line.points[line.points.size() / 2]
	line.queue_free()
	main.conveyor_meters += refund
	main.inventory_changed.emit()
	main.hud.toast("Dismantled · +%d m of belt back" % refund, "info")
	Sfx.play_at("holo_place", at, -4.0)
	Sfx.play_ui("holo_cancel", -8.0)


func _belongs_to_sell_machine(node: Node) -> bool:
	while node:
		if node is SellMachine:
			return true
		node = node.get_parent()
	return false


func _place() -> void:
	var need := length_meters()
	var flow_grounds := _grounds.duplicate()
	if not _flow_forward:
		flow_grounds.reverse()
	var kind := junction_kind()
	if Net.is_client():
		main.sync.req_build_line.rpc_id(1, _flow_points(), flow_grounds, need, main.sync.snap_to_net(start_snap), main.sync.snap_to_net(end_snap), _flow_forward)
	else:
		build_line_from(_flow_points(), flow_grounds, need, start_snap, end_snap, _flow_forward)
	Sfx.play_at("holo_place", _points[_points.size() / 2], -2.0)
	placing = false
	_holo.visible = false
	main.hud.toast(("Splitter built · every 2nd straw goes this way" if kind == "split" else "Merge built · this line feeds into the other" if kind == "merge" else "Built %d m of conveyor" % need), "success")


func build_line_from(pts: PackedVector3Array, gnd: PackedFloat32Array, need: int, s_snap: Dictionary, e_snap: Dictionary, forward: bool) -> ConveyorLine:
	var line := ConveyorLine.new()
	line.net_id = main.next_net_id()
	main.add_child(line)
	line.meters = need
	line.build(pts, gnd)
	var touched: Array = [line]
	for info in [[s_snap, true], [e_snap, false]]:
		var snap: Dictionary = info[0]
		if snap.is_empty() or not snap.get("mid", false) or not is_instance_valid(snap.get("owner")):
			continue
		var main_line: ConveyorLine = snap.owner
		var at_click_start: bool = info[1]
		if at_click_start == forward:
			main_line.add_split(snap.along, line)
			touched.append(main_line)
		else:
			line.set_feed(main_line, snap.along)
	main.conveyor_meters -= need
	main.belt_built += need
	main.inventory_changed.emit()
	if main.sync:
		for l in touched:
			main.sync.line_built(l)
	placed.emit(line)
	return line


func reverse_line(line: ConveyorLine) -> void:
	line.reverse()
	if main.sync:
		main.sync.line_built(line)


func _process(delta: float) -> void:
	if placing:
		_update_path(delta)
	elif equipped:
		var before := hover_line
		_update_hover_line()
		if _dismantling:
			if hover_line == null or hover_line != before:
				_dismantling = false
				_dismantle_t = 0.0
				dismantle_progress.emit(0.0)
			else:
				_dismantle_t = minf(_dismantle_t + delta / DISMANTLE_TIME, 1.0)
				dismantle_progress.emit(_dismantle_t)
				if _dismantle_t >= 1.0:
					_dismantling = false
					dismantle_progress.emit(0.0)
					dismantle(hover_line)
					hover_line = null
	_emit_state()


func _emit_state() -> void:
	var kind := ""
	if equipped:
		if not placing:
			kind = "tool_conveyor" if is_instance_valid(hover_line) else "tool_idle"
		elif valid:
			kind = "tool_valid"
		else:
			kind = "tool_" + (reason if reason != "" else "blocked")
	if kind != _kind:
		_kind = kind
		state_changed.emit(kind)


func status_text() -> String:
	return "%d m" % length_meters()
