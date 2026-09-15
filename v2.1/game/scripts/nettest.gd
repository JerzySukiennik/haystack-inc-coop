# Headless networking smoke test: host prints a room code, joiner connects by code, both exchange pings over RPC.
extends Node

var _pings := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Net.state_changed.connect(func(s: String, d: String) -> void: print("[net] state ", s, " ", d))
	Net.peer_joined.connect(func(id: int) -> void:
		print("[net] peer joined ", id)
		if Net.is_host():
			ping.rpc_id(id, "hello from host"))
	if "host" in args:
		Net.my_name = "Host"
		var code := Net.host()
		print("[net] CODE ", code)
		var f := FileAccess.open(args[args.find("host") + 1] if args.size() > args.find("host") + 1 else "user://code.txt", FileAccess.WRITE)
		if f:
			f.store_string(code)
			f.close()
	elif "join" in args:
		Net.my_name = "Joiner"
		Net.join(args[args.find("join") + 1])
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		print("[net] timeout, pings=", _pings)
		get_tree().quit())


@rpc("any_peer", "reliable")
func ping(text: String) -> void:
	_pings += 1
	print("[net] got ping from ", multiplayer.get_remote_sender_id(), ": ", text)
	if Net.is_client():
		ping.rpc_id(1, "hello back from client")
		await get_tree().create_timer(1.0).timeout
		print("[net] RESULT OK")
		get_tree().quit()
	else:
		print("[net] RESULT OK")
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()
