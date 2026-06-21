extends Node3D

var world_env: WorldEnvironment
var moon_light: DirectionalLight3D

func _ready() -> void:
	# --- CIEL ---
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.01, 0.02, 0.06)       # Bleu nuit visible
	sky_mat.sky_horizon_color = Color(0.04, 0.06, 0.14)    # Horizon bleu plus clair
	sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.01)
	sky_mat.ground_horizon_color = Color(0.02, 0.03, 0.08)
	sky_mat.sky_energy_multiplier = 0.5
	
	var sky = Sky.new()
	sky.sky_material = sky_mat
	
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	
	# --- AMBIENT : "Day for Night" (clé de toute la visibilité) ---
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.12, 0.25) # Bleu nuit cinéma
	env.ambient_light_energy = 0.5 # Assez fort pour tout voir
	
	# --- BROUILLARD ---
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.003
	env.fog_light_color = Color(0.03, 0.05, 0.12) # Bleu nuit
	
	env.volumetric_fog_enabled = false
	
	# --- POST-PROCESSING ---
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.tonemap_white = 1.0
	
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.1
	
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	
	# --- LUNE : Directionnelle forte ---
	moon_light = DirectionalLight3D.new()
	moon_light.light_energy = 1.2 # Plus forte pour éclairer le terrain/manoir
	moon_light.light_color = Color(0.6, 0.75, 1.0) # Bleu lune
	moon_light.shadow_enabled = true
	moon_light.shadow_bias = 0.02
	moon_light.shadow_normal_bias = 1.0
	moon_light.shadow_opacity = 0.85
	moon_light.rotation_degrees = Vector3(-35, -30, 0)
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
