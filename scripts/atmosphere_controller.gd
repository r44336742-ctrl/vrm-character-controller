extends Node3D

var world_env: WorldEnvironment
var moon_light: DirectionalLight3D
var ghost_light: OmniLight3D

func _ready() -> void:
    # --- 1. CIEL & ESPACE ---
    var sky_mat = ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.005, 0.01, 0.02)       # Nuit très sombre
    sky_mat.sky_horizon_color = Color(0.01, 0.02, 0.04)    # Bleu nuit
    sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.0)
    sky_mat.ground_horizon_color = Color(0.0, 0.0, 0.0)
    
    var sky = Sky.new()
    sky.sky_material = sky_mat
    
    var env = Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    
    # --- 2. BROUILLARD GLOBAL ---
    env.fog_enabled = true
    env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
    env.fog_density = 0.001  # Très dégagé
    env.fog_light_color = Color(0.01, 0.02, 0.04) # Bleu abysse
    
    env.volumetric_fog_enabled = true
    env.volumetric_fog_density = 0.002 # Presque transparent
    env.volumetric_fog_albedo = Color(0.5, 0.7, 1.0) # Bleu lune
    env.volumetric_fog_emission = Color(0.0, 0.0, 0.0) 
    env.volumetric_fog_length = 400.0
    
    # --- 3. POST-PROCESSING ---
    env.tonemap_mode = Environment.TONEMAP_ACES
    env.tonemap_exposure = 0.8
    env.tonemap_white = 1.0
    
    env.glow_enabled = true
    env.glow_intensity = 0.8
    env.glow_bloom = 0.1
    env.glow_hdr_threshold = 0.95
    
    env.adjustment_enabled = true
    env.adjustment_saturation = 0.7 # Un peu désaturé
    env.adjustment_contrast = 1.6 # Contraste +10 (Massif, ombres noires pures)
    
    world_env = WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)
    
    # --- 4. LA LUNE ---
    moon_light = DirectionalLight3D.new()
    moon_light.light_energy = 1.5
    moon_light.light_color = Color(0.6, 0.8, 1.0) # Bleu lune froid
    moon_light.shadow_enabled = true
    moon_light.shadow_bias = 0.02
    moon_light.shadow_opacity = 1.0   # Ombres 100% noires
    moon_light.rotation_degrees = Vector3(-15, 180, 0) # Face au joueur
    add_child(moon_light)
    
    var dummy_moon = get_parent().get_node_or_null("EnvironmentAssets/Moon")
    if dummy_moon:
        dummy_moon.position = Vector3(0, 80, -350)
        dummy_moon.scale = Vector3(25, 25, 25)
        var m_mat = dummy_moon.material_override as StandardMaterial3D
        if m_mat:
            m_mat.emission_energy_multiplier = 4.0
            m_mat.emission = Color(0.6, 0.8, 1.0)
            m_mat.albedo_color = Color(0.6, 0.8, 1.0)
    
    # --- 6. LUMIÈRE FANTÔME (JOUEUR) ---
    var player = get_tree().get_first_node_in_group("player")
    if player:
        ghost_light = OmniLight3D.new()
        ghost_light.light_color = Color(0.4, 0.6, 0.9) # Bleu pâle pour éclairer le perso
        ghost_light.light_energy = 0.8
        ghost_light.omni_range = 8.0
        ghost_light.shadow_enabled = true
        ghost_light.position = Vector3(0, 1.5, 0)
        player.add_child(ghost_light)

func _process(delta: float) -> void:
    if ghost_light:
        var t = Time.get_ticks_msec() / 1000.0
        ghost_light.light_energy = 0.8 + sin(t * (2 * PI / 3.0)) * 0.2
