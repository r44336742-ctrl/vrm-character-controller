extends Node3D

var world_env: WorldEnvironment
var moon_light: DirectionalLight3D

func _ready() -> void:
	# --- CIEL ---
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.005, 0.01, 0.03) # Plus sombre
	sky_mat.sky_horizon_color = Color(0.02, 0.03, 0.08) # Plus sombre
	sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.01)
	sky_mat.ground_horizon_color = Color(0.01, 0.015, 0.04) # Plus sombre
	sky_mat.sky_energy_multiplier = 0.3 # Baisse de l'énergie globale du ciel
	sky_mat.sun_angle_max = 0.0 # HIDE DEFAULT SUN DISK!
	
	var sky = Sky.new()
	sky.sky_material = sky_mat
	
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	
	# --- AMBIENT : "Day for Night" ---
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.04, 0.06, 0.12) # Plus sombre
	env.ambient_light_energy = 0.3 # Baisse de la lumière ambiante
	
	# --- BROUILLARD VOLUMÉTRIQUE ---
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.002
	env.fog_light_color = Color(0.03, 0.05, 0.12)
	
	env.volumetric_fog_enabled = false
	
	# --- POST-PROCESSING ---
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.tonemap_white = 1.0
	
	# Glow : halo autour de la lune et des sources lumineuses
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.26  # Highlight blurriness
	env.glow_hdr_threshold = 0.20 # Highlight cutoff
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.40
	env.adjustment_contrast = 1.1
	
	# --- SSAO : Occlusion ambiante pour la profondeur ---
	# OPTIMIZATION: Disabled. Grass rendering is too dense and stylized doesn't need it.
	env.ssao_enabled = false
	
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	
	# --- CALCUL POSITION LUNE (HUD = 155°, Distance = 2800m) ---
	# HUD compass_deg = 180 - yaw_deg -> yaw_deg = 180 - 155 = 25
	var moon_dist = 2800.0
	var yaw_rad = deg_to_rad(25.0)
	var mx = -sin(yaw_rad) * moon_dist
	var mz = -cos(yaw_rad) * moon_dist
	var my = 350.0 # Partiellement cachée par l'océan
	var moon_pos = Vector3(mx, my, mz)
	
	# --- LUNE : Directionnelle principale (Depuis la lune) ---
	moon_light = DirectionalLight3D.new()
	moon_light.light_energy = 0.8 
	moon_light.light_color = Color(0.6, 0.75, 1.0)
	moon_light.shadow_enabled = true
	moon_light.shadow_bias = 0.02
	moon_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon_light.shadow_normal_bias = 1.0
	moon_light.shadow_opacity = 0.85
	add_child(moon_light)
	moon_light.position = moon_pos
	moon_light.look_at(Vector3.ZERO, Vector3.UP)
	
	# --- FILL LIGHT : Lumière de remplissage ---
	var fill_light = DirectionalLight3D.new()
	fill_light.light_energy = 0.15
	fill_light.light_color = Color(0.4, 0.5, 0.7)
	fill_light.shadow_enabled = false
	fill_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill_light)
	fill_light.position = -moon_pos
	fill_light.look_at(Vector3.ZERO, Vector3.UP)
	
	# --- LUNE PHYSIQUE (shader avec texture) ---
	var dummy_moon = get_parent().get_node_or_null("EnvironmentAssets/Moon")
	if dummy_moon:
		dummy_moon.visible = false 
		
	var moon_mesh_inst = MeshInstance3D.new()
	var moon_quad = QuadMesh.new()
	moon_quad.size = Vector2(1600, 1600) 
	moon_mesh_inst.mesh = moon_quad
	moon_mesh_inst.position = moon_pos
	moon_mesh_inst.look_at(Vector3(0, my, 0), Vector3.UP)
	moon_mesh_inst.rotate_object_local(Vector3.UP, PI)
	
	var moon_shader = load("res://shaders/moon.gdshader")
	if moon_shader:
		var moon_mat = ShaderMaterial.new()
		moon_mat.shader = moon_shader
		var tex = load("res://assets/textures/moon.png")
		if tex:
			moon_mat.set_shader_parameter("moon_texture", tex)
		moon_mat.set_shader_parameter("moon_color", Vector3(0.85, 0.88, 0.95))
		moon_mat.set_shader_parameter("glow_intensity", 2.0) # Moins intense car on simule le brouillard
		moon_mat.set_shader_parameter("fog_color", env.fog_light_color)
		moon_mat.set_shader_parameter("fog_blend", 0.4) # 60% immunité = 40% noyé dans le brouillard
		moon_mesh_inst.material_override = moon_mat
	
	get_parent().get_node("EnvironmentAssets").add_child(moon_mesh_inst)
	
	# --- HALO LUNAIRE (quad géant derrière la lune) ---
	var halo = MeshInstance3D.new()
	var halo_quad = QuadMesh.new()
	halo_quad.size = Vector2(4000, 4000) 
	halo.mesh = halo_quad
	var halo_mat = StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.disable_fog = true
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(0.2, 0.3, 0.5, 0.0)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(0.15, 0.2, 0.35)
	halo_mat.emission_energy_multiplier = 1.5 * 0.6 # 60% immunité = baissé de 40%
	halo.material_override = halo_mat
	var halo_pos = Vector3(mx * 1.02, my, mz * 1.02)
	halo.position = halo_pos
	halo.look_at(Vector3(0, my, 0), Vector3.UP)
	halo.rotate_object_local(Vector3.UP, PI)
	get_parent().get_node("EnvironmentAssets").add_child(halo)
	
	# --- ÉTOILES ---
	_generate_stars()
	
	# --- LAMPES DE RUE ---
	_generate_lanterns()
	
	# --- LAMPES DE RUE ---
	_generate_lanterns()

func _generate_stars() -> void:
	# 3 types de couleur d'étoiles
	var star_colors = [
		Color(0.9, 0.92, 1.0),    # Blanc-bleu (courantes)
		Color(0.6, 0.75, 1.0),    # Bleu vif (chaudes B)
		Color(1.0, 0.9, 0.75),    # Blanc-chaud (type G/K)
	]
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	
	var star_mesh = SphereMesh.new()
	star_mesh.radius = 0.15
	star_mesh.height = 0.3
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	
	for i in range(200): # Plus d'étoiles
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = star_mesh
		
		# Matériau individuel pour variation de couleur/intensité
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		
		# Couleur aléatoire parmi les 3 types
		var color_idx = rng.randi_range(0, 2)
		var star_col = star_colors[color_idx]
		mat.emission = star_col
		mat.albedo_color = star_col
		
		# 3 tiers de luminosité (quelques brillantes, beaucoup de faibles)
		var brightness_roll = rng.randf()
		if brightness_roll < 0.05:
			mat.emission_energy_multiplier = rng.randf_range(4.0, 6.0) # Très brillante
			var bs = rng.randf_range(2.0, 3.0)
			mesh_inst.scale = Vector3(bs, bs, bs)
		elif brightness_roll < 0.25:
			mat.emission_energy_multiplier = rng.randf_range(2.0, 3.5) # Moyenne
			var ms = rng.randf_range(1.0, 2.0)
			mesh_inst.scale = Vector3(ms, ms, ms)
		else:
			mat.emission_energy_multiplier = rng.randf_range(0.8, 1.5) # Faible
			var ss = rng.randf_range(0.3, 0.8)
			mesh_inst.scale = Vector3(ss, ss, ss)
		
		mesh_inst.material_override = mat
		
		var theta = rng.randf_range(0, TAU)
		var phi = rng.randf_range(0.05, 0.75)
		var r = 800.0
		mesh_inst.position = Vector3(
			r * sin(phi) * cos(theta),
			r * cos(phi),
			r * sin(phi) * sin(theta)
		)
		
		add_child(mesh_inst)

func _generate_lanterns() -> void:
	# Lanternes le long de l'allée (Z=20 à Z=55, de chaque côté)
	var lantern_positions = [
		Vector3(-4.5, 0, 25), Vector3(4.5, 0, 25),
		Vector3(-4.5, 0, 35), Vector3(4.5, 0, 35),
		Vector3(-4.5, 0, 45), Vector3(4.5, 0, 45),
	]
	
	var pole_mat = StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.04, 0.04, 0.05)
	pole_mat.metallic = 0.8
	pole_mat.roughness = 0.4
	
	for pos in lantern_positions:
		# Poteau
		var pole = CSGCylinder3D.new()
		pole.radius = 0.08
		pole.height = 3.5
		pole.position = pos + Vector3(0, 1.75, 0)
		pole.material = pole_mat
		pole.use_collision = true
		get_parent().get_node("EnvironmentAssets").add_child(pole)
		
		# Globe lumineux
		var globe = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.2
		sphere.height = 0.4
		globe.mesh = sphere
		
		var glow_mat = StandardMaterial3D.new()
		glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_mat.emission_enabled = true
		glow_mat.emission = Color(0.3, 0.5, 0.9) # Bleu pâle
		glow_mat.emission_energy_multiplier = 3.0
		glow_mat.albedo_color = Color(0.4, 0.6, 1.0)
		globe.material_override = glow_mat
		globe.position = pos + Vector3(0, 3.7, 0)
		get_parent().get_node("EnvironmentAssets").add_child(globe)
		
		# Lumière ponctuelle
		var light = OmniLight3D.new()
		light.light_color = Color(0.3, 0.5, 0.9)
		light.light_energy = 0.6
		light.omni_range = 8.0
		light.shadow_enabled = false # Économie de perf
		light.position = pos + Vector3(0, 3.7, 0)
		get_parent().get_node("EnvironmentAssets").add_child(light)
