# Sound effects autoload: named cue groups mapped to asset files, random variant and pitch per play.
extends Node

const AUDIO_DIR := "res://assets/audio"
const CUES := {
	"hay_pull": ["hay_rustle_long_"],
	"hay_grab": ["hay_grab_"],
	"hay_thud": ["hay_land_1", "hay_land_2", "hay_land_3", "hay_land_4"],
	"hay_thud_heavy": ["hay_land_heavy_"],
	"throw": ["throw_whoosh_1", "throw_whoosh_2", "throw_whoosh_3"],
	"throw_soft": ["throw_whoosh_soft"],
	"step_dirt": ["footstep_dirt_"],
	"step_grass": ["footstep_grass_"],
	"cloth": ["cloth_"],
	"ui": ["ui_click"],
	"sell": ["sell_coin_"],
	"ui_tap": ["holo_start"],
	"pitchfork_stab": ["pitchfork_stab_"],
	"basket_collect": ["basket_collect_"],
	"machine_arm": ["machine_arm_"],
	"hopper_drop": ["hopper_drop_"],
	"machine_place": ["machine_place_", "holo_place"],
	"machine_pickup": ["machine_pickup_", "holo_cancel"],
	"upgrade": ["upgrade_", "purchase_"],
	"equip": ["equip_"],
	"purchase": ["purchase_"],
	"deny": ["deny_"],
	"slide": ["carousel_slide_"],
	"holo_start": ["holo_start"],
	"holo_place": ["holo_place"],
	"holo_cancel": ["holo_cancel"],
	"door_bell": ["shop_door_bell"],
}
const AMBIENCE := {"ambience_morning_birds_loop": -15.0, "ambience_wind_loop": -21.0}

var _streams := {}
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var files := _list_audio()
	for cue in CUES:
		var list: Array[AudioStream] = []
		for prefix in CUES[cue]:
			for f in files:
				if f.get_file().begins_with(prefix):
					var s := load(f) as AudioStream
					if s:
						list.append(s)
		_streams[cue] = list
	for f in files:
		var base := f.get_file().get_basename()
		if AMBIENCE.has(base):
			var s := load(f) as AudioStream
			if s:
				if "loop" in s:
					s.set("loop", true)
				var amb := AudioStreamPlayer.new()
				amb.stream = s
				amb.volume_db = AMBIENCE[base]
				add_child(amb)
				amb.play()


func _list_audio() -> Array[String]:
	var out: Array[String] = []
	_walk(AUDIO_DIR, out)
	out.sort()
	return out


func _walk(dir: String, out: Array[String]) -> void:
	for entry in ResourceLoader.list_directory(dir):
		var path := dir.path_join(entry)
		if entry.ends_with("/"):
			_walk(path.trim_suffix("/"), out)
		elif entry.get_extension() in ["ogg", "wav", "mp3"]:
			out.append(path)


func play_ui(cue: String, volume_db := 0.0, pitch_spread := 0.05) -> void:
	var list: Array = _streams.get(cue, [])
	if list.is_empty():
		return
	var p := AudioStreamPlayer.new()
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_spread, 1.0 + pitch_spread)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func play_music(base: String, volume_db := -12.0) -> void:
	stop_music()
	for f in _list_audio():
		if f.get_file().get_basename() == base:
			var s := load(f) as AudioStream
			if s == null:
				return
			if "loop" in s:
				s.set("loop", true)
			_music = AudioStreamPlayer.new()
			_music.stream = s
			_music.volume_db = -40.0
			add_child(_music)
			_music.play()
			create_tween().tween_property(_music, "volume_db", volume_db, 0.8)
			return


func loop_at(base: String, parent: Node3D, volume_db := -10.0) -> AudioStreamPlayer3D:
	if parent == null or not parent.is_inside_tree():
		return null
	for f in _list_audio():
		if f.get_file().get_basename() == base:
			var s := load(f) as AudioStream
			if s == null:
				return null
			s = s.duplicate()
			if "loop" in s:
				s.set("loop", true)
			elif "loop_mode" in s:
				s.set("loop_mode", 1)
			var p := AudioStreamPlayer3D.new()
			p.stream = s
			p.volume_db = volume_db
			p.unit_size = 3.0
			p.max_distance = 30.0
			parent.add_child(p)
			p.play()
			return p
	return null


func stop_loop(p: AudioStreamPlayer3D) -> void:
	if is_instance_valid(p):
		var tw := p.create_tween()
		tw.tween_property(p, "volume_db", -40.0, 0.15)
		tw.tween_callback(p.queue_free)


func stop_music() -> void:
	if is_instance_valid(_music):
		var m := _music
		_music = null
		var tw := create_tween()
		tw.tween_property(m, "volume_db", -40.0, 0.4)
		tw.tween_callback(m.queue_free)


func play_at(cue: String, pos: Vector3, volume_db := 0.0, pitch_spread := 0.12) -> void:
	var list: Array = _streams.get(cue, [])
	if list.is_empty():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_spread, 1.0 + pitch_spread)
	p.unit_size = 4.0
	p.max_distance = 60.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
