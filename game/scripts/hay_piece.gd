# A single physical hay clump that can be pulled, carried, dropped and thrown.
class_name HayPiece
extends RigidBody3D

const SIZE := Vector3(0.52, 0.16, 0.24)
const RIM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform float strength = 0.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = vec3(1.0, 0.85, 0.45) * (rim * 0.8 + 0.12) * strength;
}
"""

static var _rim_material: ShaderMaterial

var held_by: Node = null
var _mesh_instance: MeshInstance3D
var _last_thud := 0.0
var _despawning := false


func setup(mesh: Mesh, material: Material) -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	mass = 0.45
	linear_damp = 0.25
	angular_damp = 0.9
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 2
	var pm := PhysicsMaterial.new()
	pm.friction = 0.95
	pm.bounce = 0.02
	physics_material_override = pm
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material
	add_child(_mesh_instance)
	var shape := BoxShape3D.new()
	shape.size = SIZE
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)
	add_to_group("hay_piece")
	body_entered.connect(_on_body_entered)


func set_highlight(on: bool) -> void:
	if _rim_material == null:
		var sh := Shader.new()
		sh.code = RIM_SHADER
		_rim_material = ShaderMaterial.new()
		_rim_material.shader = sh
		_rim_material.set_shader_parameter("strength", 1.0)
	if is_instance_valid(_mesh_instance):
		_mesh_instance.material_overlay = _rim_material if on else null


func set_held(holder: Node) -> void:
	held_by = holder
	gravity_scale = 0.0 if holder else 1.0
	angular_damp = 6.0 if holder else 0.9
	sleeping = false


func _on_body_entered(_body: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var speed := linear_velocity.length()
	if held_by == null and speed > 1.6 and now - _last_thud > 0.2:
		_last_thud = now
		Sfx.play_at("hay_thud_heavy" if speed > 9.0 else "hay_thud", global_position, clampf(remap(speed, 1.6, 12.0, -16.0, -2.0), -16.0, -2.0))


func despawn() -> void:
	if _despawning:
		return
	_despawning = true
	freeze = true
	collision_layer = 0
	collision_mask = 0
	var tw := create_tween()
	tw.tween_property(_mesh_instance, "scale", Vector3.ONE * 0.01, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
