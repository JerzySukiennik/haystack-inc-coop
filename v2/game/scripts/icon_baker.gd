# Renders item meshes into small transparent icons once, using an offscreen viewport with its own world.
class_name IconBaker
extends Node

signal baked(id: String, texture: Texture2D)

var _cache := {}
var _queue: Array[String] = []
var _busy := false
var _viewport: SubViewport
var _holder: Node3D
var _camera: Camera3D


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(160, 160)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.78, 0.74)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.3
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_holder = Node3D.new()
	_viewport.add_child(_holder)


func get_icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	if DisplayServer.get_name() == "headless":
		return null
	if not id in _queue:
		_queue.append(id)
		_run.call_deferred()
	return null


func _run() -> void:
	if _busy:
		return
	_busy = true
	while not _queue.is_empty():
		var id: String = _queue.pop_front()
		for c in _holder.get_children():
			c.free()
		var mi := MeshInstance3D.new()
		mi.mesh = Items.mesh_for(id)
		mi.material_override = MeshKit.vertex_material(0.6)
		_holder.add_child(mi)
		var aabb := mi.get_aabb()
		var radius := maxf(aabb.size.length() * 0.5, 0.05)
		var center := aabb.get_center()
		_holder.rotation = Vector3(0.0, 0.75, 0.0)
		var target := _holder.global_transform * center
		_camera.position = target + Vector3(0.0, radius * 1.1, radius * 3.4)
		_camera.look_at(target)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _viewport.get_texture().get_image()
		var tex := ImageTexture.create_from_image(img)
		_cache[id] = tex
		baked.emit(id, tex)
	_busy = false
