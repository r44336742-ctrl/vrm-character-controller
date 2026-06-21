extends Node3D

var world_env: WorldEnvironment
var moon_light: DirectionalLight3D

func _ready() -> void:
	# --- CIEL : Noir absolu avec un dégradé bleu très foncé à l'horizon ---
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.0, 0.0, 0.02)        # Noir quasi-pur en haut
	sky_mat.sky_horizon_color = Color(0.02, 0.03, 0.08)   # Bleu nuit très foncé à l'horizon
	sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.0)    # Noir absolu en bas
	sky_mat.ground_horizon_color = Color(0.01, 0.015, 0.04)
	sky_mat.sky_energy_multiplier = 0.3  # Réduire l'énergie globale du ciel
	
	var sky = Sky.new()
	sky.sky_material = sky_mat
	
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.03, 0.04, 0.08) # Ambient bleu nuit très subtil
	env.ambient_light_energy = 0.15
	
	# --- BROUILLARD : Très léger, bleu nuit ---
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.002
	env.fog_light_color = Color(0.02, 0.03, 0.06) # Bleu nuit profond
	
	# Pas de volumetric fog (c'est lui qui grisait tout)
	env.volumetric_fog_enabled = false
	
	# --- POST-PROCESSING ---
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0
	
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.15  # Contraste léger et propre, pas un écrasement
	
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	
	# --- LUNE : Lumière directionnelle bleu froid ---
	moon_light = DirectionalLight3D.new()
	moon_light.light_energy = 0.6
	moon_light.light_color = Color(0.55, 0.7, 1.0) # Bleu lune froid
	moon_light.shadow_enabled = true
	moon_light.shadow_bias = 0.02
	moon_light.shadow_normal_bias = 1.0
	moon_light.shadow_opacity = 0.95
	moon_light.rotation_degrees = Vector3(-30, -30, 0) # Éclaire en diagonale
	add_child(moon_light)
	
	# --- LUNE PHYSIQUE ---
	var dummy_moon = get_parent().get_node_or_null("EnvironmentAssets/Moon")
	if dummy_moon:
		dummy_moon.position = Vector3(-120, 90, -500)
		dummy_moon.scale = Vector3(3, 3, 3)
		var m_mat = dummy_moon.material_override as StandardMaterial3D
		if m_mat:
			m_mat.emission_energy_multiplier = 3.0
			m_mat.emission = Color(0.7, 0.8, 1.0)
			m_mat.albedo_color = Color(0.85, 0.9, 1.0)
