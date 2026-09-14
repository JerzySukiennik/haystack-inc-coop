# First-person farmer: movement, mouse look, pulling hay from the stack, physics carrying and throwing.
class_name Player
extends CharacterBody3D

signal hover_changed(kind: String)
signal charge_changed(amount: float)
signal pulled_changed(total: int)
signal pull_progress(amount: float)

const WALK := 4.6
const SPRINT := 7.6
const JUMP := 4.8
const ACCEL := 11.0
const AIR_ACCEL := 2.5
const REACH := 3.4
const HOLD_MIN := 0.55
const HOLD_MAX := 2.2
const THROW_MIN := 2.5
const THROW_MAX := 12.0
const HOLD_POSE := Vector3(0.0, 0.6, 0.2)
const PULL_TIME := 2.0
const CHARGE_TIME := 0.85
const EYE := 1.62

var sensitivity := 0.0024
var input_enabled := true
var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var held: HayPiece
var hold_distance := 1.6
var charging := false
var charge := 0.0
var pulled := 0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bob := 0.0
var _stride := 0.0
var _hover := ""
var _pull_cooldown := 0.0
var _base_fov := 78.0
var _highlighted: HayPiece
var tool: ToolBelt
var speed_mult := 1.0
var pull_time := PULL_TIME
var reach := REACH
var throw_max := THROW_MAX
var jump_speed := JUMP
var move_mult := 1.0
var _fresh_until := 0
var fly := false
var pulling := false
var pull_t := 0.0
var _pull_stack: Haystack
var _pull_point := Vector3.ZERO
var _pull_normal := Vector3.UP
var _pull_preview: MeshInstance3D
var _pull_sound := 0.0
var _pull_info := {}
var _pull_dir := Vector3.UP


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 16
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.3
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = capsule
	cs.position.y = 0.9
	add_child(cs)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.fov = _base_fov
	camera.near = 0.05
	camera.far = 600.0
	head.add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collision_mask = 1 | HayPiece.PICK_LAYER
	ray.collide_with_areas = true
	ray.add_exception(self)
	camera.add_child(ray)
	camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * sensitivity)
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * sensitivity, deg_to_rad(-88), deg_to_rad(88))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if tool and tool.equipped:
					if mb.pressed:
						tool.primary()
					else:
						tool.primary_up()
				elif mb.pressed:
					primary_press()
				else:
					primary_release()
			MOUSE_BUTTON_RIGHT:
				if tool and tool.equipped:
					tool.secondary(mb.pressed)
				elif mb.pressed:
					begin_charge()
				else:
					release_throw()
			MOUSE_BUTTON_WHEEL_UP:
				if tool and tool.placing:
					tool.scroll(1)
				else:
					hold_distance = clampf(hold_distance + 0.1, HOLD_MIN, HOLD_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				if tool and tool.placing:
					tool.scroll(-1)
				else:
					hold_distance = clampf(hold_distance - 0.1, HOLD_MIN, HOLD_MAX)
	elif event is InputEventPanGesture and tool and tool.placing:
		tool.pan((event as InputEventPanGesture).delta.y)


func primary_press() -> void:
	if held or _pull_cooldown > 0.0:
		return
	ray.force_raycast_update()
	var hit := ray.get_collider()
	var straw := HayPiece.from_collider(hit)
	if straw:
		grab(straw)
	elif hit is Haystack:
		begin_pull(hit as Haystack, ray.get_collision_point(), ray.get_collision_normal())


func begin_pull(stack: Haystack, point: Vector3, normal: Vector3) -> void:
	var info := stack.begin_take(point)
	if info.is_empty():
		return
	pulling = true
	pull_t = 0.0
	_pull_stack = stack
	_pull_point = point
	_pull_normal = normal
	_pull_info = info
	var xf: Transform3D = info.transform
	var dir := xf.basis.y.normalized()
	var toward := normal + (camera.global_position - point).normalized() * 0.3
	_pull_dir = dir if dir.dot(toward) >= 0.0 else -dir
	_pull_preview = MeshInstance3D.new()
	_pull_preview.mesh = MeshKit.straw_mesh()
	_pull_preview.material_override = stack.take_material(info)
	get_parent().add_child(_pull_preview)
	HayPiece.highlight_mesh(_pull_preview, true)
	_pull_sound = 0.0
	_update_pull_preview()


func cancel_pull() -> void:
	if not pulling:
		return
	pulling = false
	pull_t = 0.0
	if is_instance_valid(_pull_preview):
		_pull_preview.queue_free()
	if is_instance_valid(_pull_stack):
		_pull_stack.restore_take(_pull_info)
	_pull_info = {}
	pull_progress.emit(0.0)


func _update_pull_preview() -> void:
	if not is_instance_valid(_pull_preview):
		return
	var xf: Transform3D = _pull_info.transform
	var length: float = _pull_info.length
	var side := _pull_dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	var wobble := sin(pull_t * 38.0) * 0.006 * (1.0 - pull_t)
	var out := length * 0.85 * ease(pull_t, 1.6)
	_pull_preview.global_transform = Transform3D(xf.basis, xf.origin + _pull_dir * out + side.normalized() * wobble)


func _update_pull(delta: float) -> void:
	if not pulling:
		return
	var hit := ray.get_collider()
	if not input_enabled or hit != _pull_stack or ray.get_collision_point().distance_to(_pull_point) > 0.6:
		cancel_pull()
		return
	pull_t = minf(pull_t + delta / pull_time, 1.0)
	_pull_sound -= delta
	if _pull_sound <= 0.0:
		_pull_sound = 0.7
		Sfx.play_at("hay_pull", _pull_point, -6.0, 0.2)
	_update_pull_preview()
	pull_progress.emit(pull_t)
	if pull_t >= 1.0:
		var xf := _pull_preview.global_transform
		pulling = false
		_pull_preview.queue_free()
		pull_progress.emit(0.0)
		var piece := _pull_stack.finish_take(_pull_info, xf)
		_pull_info = {}
		if piece:
			_pull_cooldown = 0.25
			pulled += 1
			pulled_changed.emit(pulled)
			Sfx.play_at("hay_grab", _pull_point, -2.0)
			grab(piece, true)


func primary_release() -> void:
	cancel_pull()
	if held and not charging:
		drop()


func grab(piece: HayPiece, fresh := false) -> void:
	if piece.held_by != null:
		return
	held = piece
	piece.set_held(self)
	add_collision_exception_with(piece)
	hold_distance = HOLD_MIN + 0.3 if fresh else clampf(camera.global_position.distance_to(piece.global_position), HOLD_MIN, HOLD_MAX)
	if fresh:
		_fresh_until = Time.get_ticks_msec() + 900
	else:
		Sfx.play_at("hay_grab", piece.global_position, -5.0)
	Sfx.play_at("cloth", camera.global_position, -18.0)


func drop() -> void:
	if not held:
		return
	var piece := held
	held = null
	charging = false
	charge = 0.0
	charge_changed.emit(0.0)
	if is_instance_valid(piece):
		piece.set_held(null)
		get_tree().create_timer(0.4).timeout.connect(func() -> void:
			if is_instance_valid(piece) and piece != held:
				remove_collision_exception_with(piece))


func begin_charge() -> void:
	if held:
		charging = true
		charge = 0.0


func release_throw() -> void:
	if not held or not charging:
		charging = false
		return
	var piece := held
	var power := lerpf(THROW_MIN, throw_max, ease(charge, 0.6))
	var forward := -camera.global_basis.z
	drop()
	var side := forward.cross(Vector3.UP).normalized()
	piece.global_basis = Basis(forward, side.cross(forward), side)
	piece.linear_velocity = forward * power + Vector3.UP * power * 0.06 + velocity * 0.6
	piece.angular_velocity = forward * randf_range(-10.0, 10.0) + side * randf_range(-1.5, 1.5)
	Sfx.play_at("throw" if charge > 0.35 else "throw_soft", camera.global_position + forward, lerpf(-14.0, -4.0, charge))


func set_base_fov(v: float) -> void:
	_base_fov = v
	if camera:
		camera.fov = v


func look_at_point(target: Vector3) -> void:
	var dir := (target - head.global_position).normalized()
	rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(clampf(dir.y, -1.0, 1.0))


func _physics_process(delta: float) -> void:
	ray.target_position = Vector3(0, 0, -reach)
	_pull_cooldown = maxf(_pull_cooldown - delta, 0.0)
	var wish := Vector2.ZERO
	var sprinting := false
	if input_enabled:
		wish = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		sprinting = Input.is_action_pressed("sprint") and wish.y < 0.0
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_speed
	if fly:
		var up := 0.0
		if input_enabled:
			up = (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_key_pressed(KEY_CTRL) else 0.0)
		velocity.y = move_toward(velocity.y, up * WALK * 1.5 * speed_mult, 30.0 * delta)
	elif not is_on_floor():
		velocity.y -= _gravity * delta
	var dir := (global_basis * Vector3(wish.x, 0, wish.y)).normalized()
	var speed := (SPRINT if sprinting else WALK) * (0.82 if held else 1.0) * speed_mult * move_mult
	var target := dir * speed
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)
	move_and_slide()
	_push_bodies()
	_update_pull(delta)
	_update_held(delta)
	_update_camera(delta, sprinting)
	_update_hover()


func _push_bodies() -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider()
		if body is RigidBody3D and body != held:
			var push := -c.get_normal()
			push.y = 0.0
			(body as RigidBody3D).apply_central_impulse(push.normalized() * (0.05 + hspeed * 0.06))


func _update_held(delta: float) -> void:
	if held and not is_instance_valid(held):
		held = null
	if not held:
		return
	if charging:
		charge = minf(charge + delta / CHARGE_TIME, 1.0)
		charge_changed.emit(charge)
	var reach := hold_distance - charge * 0.35
	var forward := -camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + forward * (reach + 0.3), 1 | 16)
	q.exclude = [get_rid()]
	var blocked := get_world_3d().direct_space_state.intersect_ray(q)
	if not blocked.is_empty():
		reach = minf(reach, camera.global_position.distance_to(blocked.position) - 0.3)
	var target := camera.global_position + forward * maxf(reach, 0.3)
	var offset := target - held.global_position
	if offset.length() > reach + 0.6 and Time.get_ticks_msec() > _fresh_until:
		drop()
		return
	var v := offset * 22.0
	if v.length() > 24.0:
		v = v.normalized() * 24.0
	held.linear_velocity = held.linear_velocity.lerp(v, 0.6)
	var want := camera.global_basis * Basis.from_euler(HOLD_POSE)
	var diff := (want * held.global_basis.inverse()).get_rotation_quaternion()
	var axis := diff.get_axis()
	var angle := diff.get_angle()
	if angle > PI:
		angle -= TAU
	if axis.is_finite():
		held.angular_velocity = axis * angle * 6.0


func _update_camera(delta: float, sprinting: bool) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.5:
		_bob += delta * hspeed * 1.9
		_stride += hspeed * delta
		if _stride > (2.2 if sprinting else 1.75):
			_stride = 0.0
			var on_dirt := Vector2(global_position.x, global_position.z).length() < 11.0
			Sfx.play_at("step_dirt" if on_dirt else "step_grass", global_position, -16.0 if not sprinting else -11.0)
	else:
		_bob = lerpf(_bob, round(_bob / PI) * PI, delta * 6.0)
	camera.position.y = sin(_bob) * 0.03
	camera.position.x = cos(_bob * 0.5) * 0.02
	camera.fov = lerpf(camera.fov, _base_fov + (6.0 if sprinting and hspeed > 5.0 else 0.0), delta * 6.0)


func hover_kind() -> String:
	return _hover


func _update_hover() -> void:
	var kind := ""
	var glow: HayPiece = null
	if tool and tool.equipped:
		kind = "tool"
	elif pulling:
		kind = "pulling"
	elif held:
		kind = "charging" if charging else "holding"
		glow = held
	else:
		var hit := ray.get_collider()
		var straw := HayPiece.from_collider(hit)
		if straw:
			kind = "piece"
			glow = straw
		elif hit is Haystack:
			kind = "stack"
		elif hit is ShopBooth or (hit is Area3D and (hit as Area3D).get_parent() is ShopBooth):
			kind = "shop"
	if _highlighted != glow:
		if is_instance_valid(_highlighted):
			_highlighted.set_highlight(false)
		_highlighted = glow
		if glow:
			glow.set_highlight(true)
	if kind != _hover:
		_hover = kind
		hover_changed.emit(kind)
