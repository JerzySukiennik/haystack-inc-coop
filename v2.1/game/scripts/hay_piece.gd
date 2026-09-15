# A single physical straw of hay (needle-shaped) that can be pulled, carried, dropped and thrown.
class_name HayPiece
extends RigidBody3D

const RADIUS := 0.016
const PICK_RADIUS := 0.075
const LAYER := 2
const PICK_LAYER := 8
const RIM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float strength = 0.0;
void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	ALBEDO = vec3(1.0, 0.86, 0.5) * (rim * 0.7 + 0.45) * strength;
}
"""

static var _rim_material: ShaderMaterial

var held_by: Node = null
var selling := false
var net_id := 0
var replica := false
var net_color := Color(0.85, 0.7, 0.35)
var _target_xf := Transform3D()
var _has_target := false
var local_driven := false
var is_needle := false
var length := 0.42
var _mesh_instance: MeshInstance3D
var _last_tick := 0.0
var _despawning := false


func make_replica() -> void:
	replica = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	contact_monitor = false


func set_net_target(xf: Transform3D) -> void:
	_target_xf = xf
	if not _has_target:
		global_transform = xf
	_has_target = true


func _physics_process(delta: float) -> void:
	if not replica or not _has_target or local_driven:
		return
	var k := 1.0 - exp(-delta * 16.0)
	var o := global_position.lerp(_target_xf.origin, k)
	var q := global_basis.get_rotation_quaternion().slerp(_target_xf.basis.get_rotation_quaternion(), k)
	global_transform = Transform3D(Basis(q), o)


func setup(mesh: Mesh, material: Material, straw_length: float) -> void:
	length = straw_length
	collision_layer = LAYER
	collision_mask = 1 | 2 | 4 | 16
	mass = 0.06
	linear_damp = 0.55
	angular_damp = 1.4
	can_sleep = true
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 1
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.05
	physics_material_override = pm
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material
	_mesh_instance.transform = local_mesh_transform(length)
	add_child(_mesh_instance)
	var bar := BoxShape3D.new()
	bar.size = Vector3(length, RADIUS * 2.0, RADIUS * 2.0)
	var cs := CollisionShape3D.new()
	cs.shape = bar
	add_child(cs)
	var pick := Area3D.new()
	pick.collision_layer = PICK_LAYER
	pick.collision_mask = 0
	pick.monitoring = false
	pick.monitorable = true
	var pick_shape := CapsuleShape3D.new()
	pick_shape.radius = PICK_RADIUS
	pick_shape.height = length + PICK_RADIUS
	var pcs := CollisionShape3D.new()
	pcs.shape = pick_shape
	pcs.rotation.z = PI * 0.5
	pick.add_child(pcs)
	add_child(pick)
	add_to_group("hay_piece")
	body_entered.connect(_on_body_entered)


func make_needle(material: Material) -> void:
	if is_needle:
		return
	is_needle = true
	if Net.is_online() and Net.is_host():
		var sync := get_tree().root.get_node_or_null("Main/NetSync") if is_inside_tree() else null
		if sync:
			sync.piece_needled.call_deferred(self)
	add_to_group("needle")
	_mesh_instance.material_override = material
	_mesh_instance.scale = Vector3(0.55, 1.0, 0.55)


static func local_mesh_transform(straw_length: float) -> Transform3D:
	return Transform3D(Basis(Vector3(0, -1, 0), Vector3(straw_length, 0, 0), Vector3(0, 0, 1)), Vector3(-straw_length * 0.5, 0, 0))


static func from_collider(hit: Object) -> HayPiece:
	if hit is HayPiece:
		return hit as HayPiece
	if hit is Area3D and (hit as Area3D).get_parent() is HayPiece:
		return (hit as Area3D).get_parent() as HayPiece
	return null


static func highlight_mesh(mi: MeshInstance3D, on: bool) -> void:
	if _rim_material == null:
		var sh := Shader.new()
		sh.code = RIM_SHADER
		_rim_material = ShaderMaterial.new()
		_rim_material.shader = sh
		_rim_material.set_shader_parameter("strength", 1.0)
	if is_instance_valid(mi):
		mi.material_overlay = _rim_material if on else null


func set_highlight(on: bool) -> void:
	highlight_mesh(_mesh_instance, on)


func set_held(holder: Node) -> void:
	held_by = holder
	gravity_scale = 0.0 if holder else 1.0
	angular_damp = 8.0 if holder else 1.4
	sleeping = false


func _on_body_entered(_body: Node) -> void:
	if replica:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var speed := linear_velocity.length()
	if held_by == null and speed > 2.0 and now - _last_tick > 0.25:
		_last_tick = now
		Sfx.play_at("hay_thud", global_position, clampf(remap(speed, 2.0, 12.0, -26.0, -12.0), -26.0, -12.0), 0.25)


func despawn() -> void:
	if _despawning:
		return
	_despawning = true
	freeze = true
	collision_layer = 0
	collision_mask = 0
	var tw := create_tween()
	tw.tween_property(_mesh_instance, "scale", Vector3.ONE * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
