# Builds the play space: sky, sun and a flat grid baseplate that everything stands on.
class_name World
extends RefCounted

const YARD_HALF := 19.0
const PLATE_HALF := 48.0
const SHOP_POS := Vector3(25.0, 0.0, -25.0)
const OFF_PLATE := -60.0


static func on_plate(x: float, z: float) -> bool:
	return absf(x) <= PLATE_HALF and absf(z) <= PLATE_HALF


static func ground_height(x: float, z: float) -> float:
	return 0.0 if on_plate(x, z) else OFF_PLATE


static func build(root: Node3D) -> void:
	_environment(root)
	_baseplate(root)


static func _environment(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_blur = 1.0
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	root.add_child(sun)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.26, 0.48, 0.84)
	sky_mat.sky_horizon_color = Color(0.74, 0.82, 0.90)
	sky_mat.ground_horizon_color = Color(0.74, 0.82, 0.90)
	sky_mat.ground_bottom_color = Color(0.46, 0.58, 0.72)
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.7
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.82, 0.90)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)


static func _baseplate(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	var thickness := 2.0
	var size := Vector3(PLATE_HALF * 2.0, thickness, PLATE_HALF * 2.0)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/prototype/grid_dark.png")
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.25
	mat.roughness = 0.9
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = -thickness * 0.5
	body.add_child(mi)
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = -thickness * 0.5
	body.add_child(cs)
	var trim := StandardMaterial3D.new()
	trim.albedo_texture = load("res://assets/textures/prototype/grid_orange.png")
	trim.uv1_triplanar = true
	trim.uv1_world_triplanar = true
	trim.uv1_scale = Vector3.ONE * 0.5
	trim.roughness = 0.8
	for side in 4:
		var edge := MeshInstance3D.new()
		var em := BoxMesh.new()
		var along := PLATE_HALF * 2.0 + 0.6
		em.size = Vector3(along, 0.3, 0.3) if side < 2 else Vector3(0.3, 0.3, along)
		em.material = trim
		edge.mesh = em
		var s := -1.0 if side % 2 == 0 else 1.0
		edge.position = Vector3(0, 0.15, s * (PLATE_HALF + 0.15)) if side < 2 else Vector3(s * (PLATE_HALF + 0.15), 0.15, 0)
		body.add_child(edge)
		var es := BoxShape3D.new()
		es.size = em.size
		var ecs := CollisionShape3D.new()
		ecs.shape = es
		ecs.position = edge.position
		body.add_child(ecs)
	root.add_child(body)
