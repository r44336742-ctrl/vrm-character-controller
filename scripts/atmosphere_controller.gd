extends Node3D

var world_env: WorldEnvironment
var moon_light: DirectionalLight3D

func _ready() -> void:
	# --- CIEL ---
	var sky_shader = load("res://shaders/sky.gdshader")
	var sky_mat = ShaderMaterial.new()
	if sky_shader:
		sky_mat.shader = sky_shader
	
	var sky = Sky.new()
	sky.sky_material = sky_mat
	
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	
	# --- AMBIENT : "Day for Night" ---
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.12, 0.25)
	env.ambient_light_energy = 0.5
	
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
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.5
	
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	
	# --- LUNE : Directionnelle principale (NW) ---
	moon_light = DirectionalLight3D.new()
	moon_light.light_energy = 1.2
	moon_light.light_color = Color(0.6, 0.75, 1.0)
	moon_light.shadow_enabled = true
	moon_light.shadow_bias = 0.02
	moon_light.shadow_normal_bias = 1.0
	moon_light.shadow_opacity = 0.85
	moon_light.rotation_degrees = Vector3(-35, -30, 0) # NW → SE
	add_child(moon_light)
	
	# --- FILL LIGHT : Lumière de remplissage côté SE ---
	# Technique "day for night" : une 2e directionnelle faible dans la direction opposée
	# garantit que les normales de l'océan sont lisibles de TOUS les côtés
	var fill_light = DirectionalLight3D.new()
	fill_light.light_energy = 0.35 # Assez pour révéler les bumps, pas pour blanchir
	fill_light.light_color = Color(0.3, 0.45, 0.8) # Bleu plus foncé (lumière réfléchie du ciel)
	fill_light.shadow_enabled = false # Pas d'ombre = pas de performance
	fill_light.rotation_degrees = Vector3(-25, 150, 0) # SE → NW (opposé à la lune)
	# (La lune et les étoiles sont désormais gérées par le shader de ciel)
	var dummy_moon = get_parent().get_node_or_null("EnvironmentAssets/Moon")
	if dummy_moon:
		dummy_moon.visible = false # Cacher l'ancienne lune sphérique
	
	# --- LAMPES DE RUE ---
	_generate_lanterns()
	
	# --- LAMPES DE RUE ---
	_generate_lanterns()

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
