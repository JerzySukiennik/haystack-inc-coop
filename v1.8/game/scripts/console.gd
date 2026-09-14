# Slash-command console: Minecraft-style suggestions, Tab completion and cycling, typo correction, history and a fading log.
class_name GameConsole
extends CanvasLayer

signal opened_changed(open: bool)

const MAX_SUGGESTIONS := 8
const LOG_LINES := 8
const INK := Color(1.0, 0.98, 0.93)
const DIM := Color(0.75, 0.75, 0.72)
const ACCENT := Color(0.98, 0.80, 0.36)

var main: Node
var is_open := false
var commands := {}

var _line: LineEdit
var _suggest_box: VBoxContainer
var _hint: Label
var _log_box: VBoxContainer
var _panel: PanelContainer
var _suggestions: Array[Dictionary] = []
var _selected := -1
var _history: Array[String] = []
var _history_index := -1
var _tab_base := ""
var _suppress_refresh := false


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_commands()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_log_box = VBoxContainer.new()
	_log_box.add_theme_constant_override("separation", 2)
	_log_box.alignment = BoxContainer.ALIGNMENT_END
	_place(_log_box, Control.PRESET_BOTTOM_LEFT, Vector2(20, -120 - 26 * MAX_SUGGESTIONS - 230), Vector2(760, 220))
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_log_box)

	_suggest_box = VBoxContainer.new()
	_suggest_box.add_theme_constant_override("separation", 0)
	_suggest_box.alignment = BoxContainer.ALIGNMENT_END
	_place(_suggest_box, Control.PRESET_BOTTOM_LEFT, Vector2(20, -110 - 26 * MAX_SUGGESTIONS), Vector2(560, 26 * MAX_SUGGESTIONS))
	_suggest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_suggest_box)

	_panel = PanelContainer.new()
	var ps := UI.box(Color(UI.INK, 0.9), 12, UI.HAY, 2, 0, 10)
	ps.content_margin_left = 12
	ps.content_margin_right = 12
	ps.content_margin_top = 4
	ps.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", ps)
	_place(_panel, Control.PRESET_BOTTOM_LEFT, Vector2(20, -104), Vector2(760, 40))
	_panel.visible = false
	root.add_child(_panel)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(740, 32)
	_panel.add_child(stack)
	_hint = Label.new()
	_hint.add_theme_font_override("font", UI.mono())
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.position.x = 8
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_hint)
	_line = LineEdit.new()
	_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	_line.add_theme_font_override("font", UI.mono())
	_line.add_theme_font_size_override("font_size", 18)
	_line.add_theme_color_override("font_color", INK)
	_line.add_theme_color_override("caret_color", ACCENT)
	var empty := StyleBoxEmpty.new()
	_line.add_theme_stylebox_override("normal", empty)
	_line.add_theme_stylebox_override("focus", empty)
	_line.context_menu_enabled = false
	_line.caret_blink = true
	_line.text_changed.connect(_on_text_changed)
	_line.text_submitted.connect(_on_submit)
	stack.add_child(_line)


func _place(c: Control, preset: Control.LayoutPreset, offset: Vector2, size: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


func open(initial := "/") -> void:
	if is_open:
		return
	is_open = true
	_panel.visible = true
	_line.text = initial
	_line.grab_focus()
	_line.caret_column = _line.text.length()
	_history_index = -1
	for c in _log_box.get_children():
		c.modulate.a = 1.0
	_refresh()
	opened_changed.emit(true)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	_line.release_focus()
	_clear_suggestions()
	_hint.text = ""
	for c in _log_box.get_children():
		_fade(c as Control, 4.0)
	opened_changed.emit(false)


func print_line(text: String, col := INK) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UI.mono())
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_box.add_child(l)
	while _log_box.get_child_count() > LOG_LINES:
		_log_box.get_child(0).free()
	if not is_open:
		_fade(l, 6.0)


func _fade(c: Control, delay: float) -> void:
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 0.0, 1.0)


func _input_event_keys(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_TAB:
			_tab(-1 if event.shift_pressed else 1)
			return true
		KEY_UP:
			if not _suggestions.is_empty():
				_move_selection(-1)
			else:
				_history_step(1)
			return true
		KEY_DOWN:
			if not _suggestions.is_empty():
				_move_selection(1)
			else:
				_history_step(-1)
			return true
		KEY_ESCAPE:
			close()
			return true
	return false


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		if _input_event_keys(event as InputEventKey):
			get_viewport().set_input_as_handled()


func _tokens(text: String) -> PackedStringArray:
	var body := text.substr(1) if text.begins_with("/") else text
	return body.split(" ", true)


func _on_text_changed(_t: String) -> void:
	if _suppress_refresh:
		return
	_tab_base = ""
	_selected = -1
	_refresh()


func _refresh() -> void:
	var text := _line.text
	if not text.begins_with("/"):
		_suppress_refresh = true
		_line.text = "/" + text
		_line.caret_column = _line.text.length()
		_suppress_refresh = false
		text = _line.text
	var tokens := _tokens(text)
	_suggestions.clear()
	var hint := ""
	if tokens.size() <= 1:
		var word := tokens[0] if tokens.size() == 1 else ""
		for name in _match(word, commands.keys()):
			_suggestions.append({"text": name, "label": "/" + name + "  " + _usage(name), "arg": 0})
		if word != "" and not commands.has(word) and _suggestions.is_empty():
			var fix := _closest(word, commands.keys())
			if fix != "":
				_suggestions.append({"text": fix, "label": "did you mean  /" + fix + " ?", "arg": 0, "fix": true})
	else:
		var cmd := tokens[0]
		if commands.has(cmd):
			var spec: Dictionary = commands[cmd]
			var arg_i := tokens.size() - 2
			var args: Array = spec.args
			if arg_i < args.size():
				var arg: Dictionary = args[arg_i]
				var word := tokens[tokens.size() - 1]
				var opts: Array = arg.get("options", [])
				if opts.is_empty() and arg.has("options_fn"):
					opts = (arg.options_fn as Callable).call(tokens)
				for o in _match(word, opts):
					_suggestions.append({"text": o, "label": o, "arg": arg_i + 1})
				if word != "" and not opts.is_empty() and _suggestions.is_empty():
					var fix := _closest(word, opts)
					if fix != "":
						_suggestions.append({"text": fix, "label": "did you mean  " + fix + " ?", "arg": arg_i + 1, "fix": true})
				var parts := PackedStringArray()
				for i in range(arg_i, args.size()):
					parts.append(("<%s>" if not args[i].get("optional", false) else "[%s]") % args[i].name)
				hint = " ".join(parts)
		else:
			var fix := _closest(cmd, commands.keys())
			if fix != "":
				_suggestions.append({"text": fix, "label": "unknown command  ·  did you mean  /" + fix + " ?", "arg": 0, "fix": true})
	if _suggestions.size() == 1 and _suggestions[0].text == tokens[tokens.size() - 1] and not _suggestions[0].get("fix", false):
		_suggestions.clear()
	_hint.text = ""
	if hint != "" and text.ends_with(" "):
		_hint.text = " ".repeat(0) + _ghost_prefix(text) + hint
	_draw_suggestions()


func _ghost_prefix(text: String) -> String:
	var font := _line.get_theme_font("font")
	var size := _line.get_theme_font_size("font_size")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var space_w := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return " ".repeat(int(ceil(w / maxf(space_w, 1.0))))


func _match(word: String, options: Array) -> Array:
	var w := word.to_lower()
	var prefix: Array = []
	var fuzzy: Array = []
	for o in options:
		var s := str(o)
		var low := s.to_lower()
		if low.begins_with(w):
			prefix.append(s)
		elif w != "" and _subsequence(w, low):
			fuzzy.append(s)
	prefix.sort()
	fuzzy.sort()
	return (prefix + fuzzy).slice(0, MAX_SUGGESTIONS)


func _subsequence(needle: String, hay: String) -> bool:
	var i := 0
	for c in hay:
		if i < needle.length() and c == needle[i]:
			i += 1
	return i == needle.length()


func _closest(word: String, options: Array) -> String:
	var best := ""
	var best_d := 99
	for o in options:
		var d := _levenshtein(word.to_lower(), str(o).to_lower())
		if d < best_d:
			best_d = d
			best = str(o)
	var limit := 1 if word.length() <= 3 else 2 if word.length() <= 6 else 3
	return best if best_d <= limit else ""


func _levenshtein(a: String, b: String) -> int:
	var prev := PackedInt32Array()
	prev.resize(b.length() + 1)
	for j in b.length() + 1:
		prev[j] = j
	for i in a.length():
		var cur := PackedInt32Array()
		cur.resize(b.length() + 1)
		cur[0] = i + 1
		for j in b.length():
			var cost := 0 if a[i] == b[j] else 1
			cur[j + 1] = mini(mini(cur[j] + 1, prev[j + 1] + 1), prev[j] + cost)
		prev = cur
	return prev[b.length()]


func _usage(name: String) -> String:
	var spec: Dictionary = commands[name]
	var parts := PackedStringArray()
	for a in spec.args:
		parts.append(("<%s>" if not a.get("optional", false) else "[%s]") % a.name)
	return " ".join(parts)


func _draw_suggestions() -> void:
	for c in _suggest_box.get_children():
		c.queue_free()
	var tokens := _tokens(_line.text)
	var typed := tokens[tokens.size() - 1].to_lower() if tokens.size() > 0 else ""
	for i in _suggestions.size():
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UI.INK_SOFT, 0.96) if i == _selected else Color(UI.INK, 0.82)
		if i == _selected:
			sb.border_color = UI.HAY
			sb.border_width_left = 4
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		row.add_theme_stylebox_override("panel", sb)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.custom_minimum_size = Vector2(520, 0)
		l.add_theme_font_override("normal_font", UI.mono())
		l.add_theme_font_override("bold_font", UI.mono())
		l.add_theme_font_size_override("normal_font_size", 16)
		l.add_theme_font_size_override("bold_font_size", 16)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var text: String = _suggestions[i].label
		var fix: bool = _suggestions[i].get("fix", false)
		var base := "#f6ecd6" if i == _selected else "#cfc2a6"
		if fix:
			l.text = "[color=#ffb4a3]%s[/color]" % text
		else:
			var name: String = _suggestions[i].text
			var start := text.to_lower().find(name.to_lower())
			if typed != "" and start >= 0 and name.to_lower().begins_with(typed):
				var hi := start + typed.length()
				l.text = "[color=%s]%s[color=#efb943]%s[/color]%s[/color]" % [base, text.substr(0, start), text.substr(start, typed.length()), text.substr(hi)]
			else:
				l.text = "[color=%s]%s[/color]" % [base, text]
		row.add_child(l)
		_suggest_box.add_child(row)


func _clear_suggestions() -> void:
	_suggestions.clear()
	_selected = -1
	_draw_suggestions()


func _move_selection(dir: int) -> void:
	if _suggestions.is_empty():
		return
	_selected = posmod(_selected + dir, _suggestions.size()) if _selected >= 0 else (0 if dir > 0 else _suggestions.size() - 1)
	_draw_suggestions()


func _tab(dir: int) -> void:
	if _suggestions.is_empty():
		return
	if _selected < 0:
		_selected = 0 if dir > 0 else _suggestions.size() - 1
	else:
		_selected = posmod(_selected + dir, _suggestions.size())
	var s: Dictionary = _suggestions[_selected]
	var tokens := _tokens(_line.text)
	var idx: int = clampi(int(s.arg), 0, tokens.size() - 1)
	tokens[idx] = s.text
	var text := "/" + " ".join(tokens)
	var cmd := tokens[0]
	var has_more := commands.has(cmd) and tokens.size() - 1 < (commands[cmd].args as Array).size()
	var keep := _suggestions.duplicate()
	var keep_sel := _selected
	_suppress_refresh = true
	_line.text = text + (" " if has_more and _suggestions.size() == 1 else "")
	_line.caret_column = _line.text.length()
	_suppress_refresh = false
	if _suggestions.size() == 1:
		_selected = -1
		_refresh()
	else:
		_suggestions = keep
		_selected = keep_sel
		_draw_suggestions()


func _history_step(dir: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + dir, -1, _history.size() - 1)
	_suppress_refresh = true
	_line.text = "/" if _history_index < 0 else _history[_history.size() - 1 - _history_index]
	_line.caret_column = _line.text.length()
	_suppress_refresh = false
	_refresh()


func _on_submit(text: String) -> void:
	if _selected >= 0 and _selected < _suggestions.size() and _suggestions[_selected].get("fix", false):
		_tab(0)
		return
	var t := text.strip_edges()
	if t == "/" or t == "":
		close()
		return
	_history.append(t)
	execute(t)
	close()


func execute(text: String) -> void:
	var tokens := Array(_tokens(text.strip_edges()))
	tokens = tokens.filter(func(x: String) -> bool: return x != "")
	if tokens.is_empty():
		return
	var cmd: String = tokens[0].to_lower()
	print_line(text, DIM)
	if not commands.has(cmd):
		var fix := _closest(cmd, commands.keys())
		print_line("Unknown command /%s%s" % [cmd, ("  ·  did you mean /%s ?" % fix) if fix != "" else ""], Color(1.0, 0.55, 0.45))
		return
	var spec: Dictionary = commands[cmd]
	var args: Array = tokens.slice(1)
	var required := 0
	for a in spec.args:
		if not a.get("optional", false):
			required += 1
	if args.size() < required:
		print_line("Usage: /%s %s" % [cmd, _usage(cmd)], Color(1.0, 0.8, 0.5))
		return
	var result: String = (spec.run as Callable).call(args)
	if result != "":
		print_line(result, Color(0.7, 1.0, 0.6) if not result.begins_with("!") else Color(1.0, 0.55, 0.45))


func _reg(name: String, args: Array, help: String, run: Callable) -> void:
	commands[name] = {"args": args, "help": help, "run": run}


func _num(s: String, fallback := -1.0) -> float:
	return float(s) if s.is_valid_float() else fallback


func _register_commands() -> void:
	_reg("help", [{"name": "command", "optional": true, "options_fn": func(_t: PackedStringArray) -> Array: return commands.keys()}], "List commands or show one command.", func(a: Array) -> String:
		if a.is_empty():
			var names := commands.keys()
			names.sort()
			return "Commands: /" + ", /".join(PackedStringArray(names))
		var n: String = a[0]
		if not commands.has(n):
			return "!No command /" + n
		return "/%s %s  —  %s" % [n, _usage(n), commands[n].help])

	_reg("give", [
		{"name": "item", "options": ["money", "meters", "conveyor_remote"]},
		{"name": "amount", "optional": true, "options": ["10", "50", "100", "1000"]},
	], "Give money, conveyor meters or the conveyor remote.", func(a: Array) -> String:
		var amount := int(_num(a[1], 1)) if a.size() > 1 else 1
		match a[0]:
			"money":
				main.money += amount
			"meters":
				main.conveyor_meters += amount
			"conveyor_remote":
				main.has_conveyor_remote = true
			_:
				return "!Unknown item " + str(a[0])
		main.inventory_changed.emit()
		return "Gave %s %s" % [str(amount) if a[0] != "conveyor_remote" else "", a[0]])

	_reg("money", [{"name": "amount", "options": ["0", "100", "1000"]}], "Set your money.", func(a: Array) -> String:
		if not str(a[0]).is_valid_int():
			return "!Amount must be a number"
		main.money = int(a[0])
		main.inventory_changed.emit()
		return "Money set to $%d" % main.money)

	_reg("tp", [
		{"name": "place|x", "options": ["spawn", "stack", "machine", "shop"]},
		{"name": "y", "optional": true},
		{"name": "z", "optional": true},
	], "Teleport to a place or to x y z.", func(a: Array) -> String:
		var target := Vector3.ZERO
		match a[0]:
			"spawn":
				target = Vector3(0, 0.2, 13)
			"stack":
				target = Vector3(0, 0.2, 7.5)
			"machine":
				target = main.sell_machine.global_position + Vector3(4.5, 0.2, -4.5)
			"shop":
				target = main.shop_booth.global_transform * Vector3(0, 0.3, 3.0)
			_:
				if a.size() < 3 or not (str(a[0]).is_valid_float() and str(a[1]).is_valid_float() and str(a[2]).is_valid_float()):
					return "!Use /tp <spawn|stack|machine|shop> or /tp x y z"
				target = Vector3(float(a[0]), float(a[1]), float(a[2]))
		main.player.global_position = target
		main.player.velocity = Vector3.ZERO
		return "Teleported to %s" % str(target.snappedf(0.1)))

	_reg("speed", [{"name": "multiplier", "options": ["1", "2", "4"]}], "Walk speed multiplier.", func(a: Array) -> String:
		var m := clampf(_num(a[0], 1.0), 0.1, 20.0)
		main.player.speed_mult = m
		return "Speed x%s" % str(m))

	_reg("fly", [], "Toggle flying (Space up, Ctrl down).", func(_a: Array) -> String:
		main.player.fly = not main.player.fly
		return "Fly " + ("on" if main.player.fly else "off"))

	_reg("spawn", [
		{"name": "what", "options": ["straws"]},
		{"name": "count", "optional": true, "options": ["1", "10", "50"]},
	], "Spawn straws in front of you.", func(a: Array) -> String:
		var n := clampi(int(_num(a[1], 10)) if a.size() > 1 else 10, 1, 300)
		var p: Player = main.player
		var f := -p.camera.global_basis.z
		for i in n:
			var pos := p.camera.global_position + f * 1.6 + Vector3(randf_range(-0.4, 0.4), 0.3 + i * 0.03, randf_range(-0.4, 0.4))
			main.haystack.spawn_piece(pos, Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, 0)), MeshKit.hay_color(RandomNumberGenerator.new()), randf_range(0.32, 0.55))
		return "Spawned %d straws" % n)

	_reg("clear", [{"name": "what", "options": ["straws", "conveyors", "log"]}], "Remove loose straws, placed conveyors or the log.", func(a: Array) -> String:
		match a[0]:
			"straws":
				var n := 0
				for piece in main.haystack.pieces.duplicate():
					if piece.held_by == null:
						piece.despawn()
						n += 1
				return "Cleared %d straws" % n
			"conveyors":
				var lines := get_tree().get_nodes_in_group("conveyor")
				var refund := 0
				for line in lines:
					refund += (line as ConveyorLine).meters
					line.queue_free()
				main.conveyor_meters += refund
				main.inventory_changed.emit()
				return "Removed %d conveyors, refunded %d m" % [lines.size(), refund]
			"log":
				for c in _log_box.get_children():
					c.queue_free()
				return ""
		return "!Unknown target " + str(a[0]))

	_reg("dig", [{"name": "count", "options": ["10", "100", "500"]}], "Instantly remove straws from the stack where you aim.", func(a: Array) -> String:
		var n := clampi(int(_num(a[0], 10)), 1, 5000)
		var p: Player = main.player
		var from := p.camera.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from - p.camera.global_basis.z * 30.0, 1)
		q.exclude = [p.get_rid()]
		var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or not (hit.collider is Haystack):
			return "!Aim at the haystack"
		var done := 0
		for i in n:
			if main.haystack.begin_take(hit.position).is_empty():
				break
			main.haystack.remaining -= 1
			done += 1
		main.haystack.count_changed.emit(main.haystack.remaining)
		return "Dug %d straws" % done)

	_reg("needle", [{"name": "action", "options": ["find", "reveal", "where"]}], "Debug the needle: teleport to it, dig it free or print its position.", func(a: Array) -> String:
		var h: Haystack = main.haystack
		if h.needle_taken:
			return "!The needle is already out of the stack"
		var n := h.surface_normal(h.needle_pos.x, h.needle_pos.z)
		match a[0]:
			"where":
				return "Needle at %s, %d straws on top" % [str(h.needle_pos.snappedf(0.1)), h.needle_cover]
			"find", "reveal":
				var flat := Vector3(n.x, 0, n.z).normalized()
				main.player.global_position = Vector3(h.needle_pos.x, 0.1, h.needle_pos.z) + flat * 2.2
				main.player.velocity = Vector3.ZERO
				main.player.look_at_point(h.needle_pos)
				if a[0] == "reveal":
					var guard := 0
					while not h.needle_exposed() and guard < 3000:
						if h.begin_take(h.needle_pos + n * 0.05).is_empty():
							break
						guard += 1
				return "Teleported to the needle" + (" and dug it free" if h.needle_exposed() else "")
		return "!Use /needle find|reveal|where")

	_reg("shop", [], "Open the shop from anywhere.", func(_a: Array) -> String:
		main.open_shop.call_deferred()
		return "")

	_reg("fov", [{"name": "degrees", "options": ["70", "78", "90", "100"]}], "Camera field of view.", func(a: Array) -> String:
		var v := clampf(_num(a[0], 78.0), 50.0, 120.0)
		main.base_fov = v
		main.player.set_base_fov(v)
		main._save_settings()
		return "FOV %d" % int(v))

	_reg("sensitivity", [{"name": "value", "options": ["0.003", "0.0045", "0.006"]}], "Mouse sensitivity.", func(a: Array) -> String:
		var v := clampf(_num(a[0], 0.0045), 0.0005, 0.02)
		main.player.sensitivity = v
		main._save_settings()
		return "Sensitivity %s" % str(v))

	_reg("reload", [], "Restart the farm.", func(_a: Array) -> String:
		main.get_tree().reload_current_scene.call_deferred()
		return "")
