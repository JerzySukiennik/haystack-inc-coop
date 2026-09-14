# First-person farmer: movement, mouse look, pulling hay from the stack, physics carrying and throwing.
class_name Player
extends CharacterBody3D

signal hover_changed(kind: String)
signal charge_changed(amount: float)
signal pulled_changed(total: int)

const WALK := 4.6
const SPRINT := 7.6
const JUMP := 4.8
const ACCEL := 11.0
const AIR_ACCEL := 2.5
const REACH := 3.8
const HOLD_MIN := 1.0
const HOLD_MAX := 2.8
const THROW_MIN := 3.0
const THROW_MAX := 18.0
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


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
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
	ray.collision_mask = 1 | 2
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
				if mb.pressed:
					primary_press()
				else:
					primary_release()
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					begin_charge()
				else:
					release_throw()
			MOUSE_BUTTON_WHEEL_UP:
				hold_distance = clampf(hold_distance + 0.15, HOLD_MIN, HOLD_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				hold_distance = clampf(hold_distance - 0.15, HOLD_MIN, HOLD_MAX)


func primary_press() -> void:
	if held or _pull_cooldown > 0.0:
		return
	ray.force_raycast_update()
	var hit := ray.get_collider()
	if hit is HayPiece:
		grab(hit as HayPiece)
	elif hit is Haystack:
		var piece: HayPiece = (hit as Haystack).pull_piece(ray.get_collision_point(), ray.get_collision_normal())
		if piece:
			_pull_cooldown = 0.18
			pulled += 1
			pulled_changed.emit(pulled)
			Sfx.play_at("hay_pull", ray.get_collision_point(), -2.0)
			grab(piece, true)


func primary_release() -> void:
	if held and not charging:
		drop()


func grab(piece: HayPiece, fresh := false) -> void:
	if piece.held_by != null:
		return
	held = piece
	piece.set_held(self)
	add_collision_exception_with(piece)
	hold_distance = HOLD_MIN + 0.6 if fresh else clampf(camera.global_position.distance_to(piece.global_position), HOLD_MIN, HOLD_MAX)
	if not fresh:
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
	var power := lerpf(THROW_MIN, THROW_MAX, ease(charge, 0.6))
	var forward := -camera.global_basis.z
	drop()
	piece.linear_velocity = forward * power + Vector3.UP * power * 0.08 + velocity * 0.6
	piece.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-8, 8), randf_range(-6, 6)) * clampf(power / THROW_MAX, 0.2, 1.0)
	Sfx.play_at("throw" if charge > 0.35 else "throw_soft", camera.global_position + forward, lerpf(-14.0, -4.0, charge))


func look_at_point(target: Vector3) -> void:
	var dir := (target - head.global_position).normalized()
	rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(clampf(dir.y, -1.0, 1.0))


func _physics_process(delta: float) -> void:
	_pull_cooldown = maxf(_pull_cooldown - delta, 0.0)
	var wish := Vector2.ZERO
	var sprinting := false
	if input_enabled:
		wish = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		sprinting = Input.is_action_pressed("sprint") and wish.y < 0.0
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var dir := (global_basis * Vector3(wish.x, 0, wish.y)).normalized()
	var speed := (SPRINT if sprinting else WALK) * (0.82 if held else 1.0)
	var target := dir * speed
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)
	move_and_slide()
	_push_bodies()
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
	var target := camera.global_position - camera.global_basis.z * (hold_distance - charge * 0.35)
	var offset := target - held.global_position
	if offset.length() > 2.6:
		drop()
		return
	var v := offset * 22.0
	if v.length() > 24.0:
		v = v.normalized() * 24.0
	held.linear_velocity = held.linear_velocity.lerp(v, 0.6)
	var want := Basis(Vector3.UP, rotation.y + PI * 0.5)
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


func _update_hover() -> void:
	var kind := ""
	var glow: HayPiece = null
	if held:
		kind = "charging" if charging else "holding"
		glow = held
	else:
		var hit := ray.get_collider()
		if hit is HayPiece:
			kind = "piece"
			glow = hit as HayPiece
		elif hit is Haystack:
			kind = "stack"
	if _highlighted != glow:
		if is_instance_valid(_highlighted):
			_highlighted.set_highlight(false)
		_highlighted = glow
		if glow:
			glow.set_highlight(true)
	if kind != _hover:
		_hover = kind
		hover_changed.emit(kind)
