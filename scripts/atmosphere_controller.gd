extends Node3D

var world_env: WorldEnvironment
var moon_light: DirectionalLight3D
var ghost_light: OmniLight3D

func _ready() -> void:
    # --- 1. CIEL & ESPACE ---
    var sky_mat = ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.0, 0.0, 0.0)       # Noir pur
    sky_mat.sky_horizon_color = Color(0.01, 0.0, 0.0)  # Très légère teinte écarlate à l'horizon
    sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.0)
    sky_mat.ground_horizon_color = Color(0.01, 0.0, 0.0)
    
    var sky = Sky.new()
    sky.sky_material = sky_mat
    
    var env = Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    
    # --- 2. BROUILLARD GLOBAL ---
    env.fog_enabled = true
    env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
    env.fog_density = 0.001  # Très dégagé pour voir au loin
    env.fog_light_color = Color(0.02, 0.0, 0.0) # Ombre rouge très sombre
    
    env.volumetric_fog_enabled = true
    env.volumetric_fog_density = 0.003 # Très léger
    env.volumetric_fog_albedo = Color(0.8, 0.8, 0.8) # Blanc/Gris pour capter le rouge
    env.volumetric_fog_emission = Color(0.02, 0.0, 0.0) # Emission rouge sang subtile
    env.volumetric_fog_length = 400.0
    
    # --- 3. POST-PROCESSING ---
    env.tonemap_mode = Environment.TONEMAP_ACES
    env.tonemap_exposure = 0.9
    env.tonemap_white = 1.0
    
    env.glow_enabled = true
    env.glow_intensity = 1.2
    env.glow_bloom = 0.1
    env.glow_hdr_threshold = 0.9 # Seules les lumières fortes (lune/rouge) bavent
    
    env.adjustment_enabled = true
    env.adjustment_saturation = 0.7 # Désaturé pour faire ressortir le rouge et le blanc
    env.adjustment_contrast = 1.3 # Contraste agressif (Noir profond, Blanc pur)
    
    world_env = WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)
    
    # --- 4. LA LUNE ---
    moon_light = DirectionalLight3D.new()
    moon_light.light_energy = 2.0      # Très violente (Blanc pur)
    moon_light.light_color = Color(1.0, 1.0, 1.0)
    moon_light.shadow_enabled = true
    moon_light.shadow_bias = 0.02
    moon_light.shadow_opacity = 0.95   # Ombres presque noires
    moon_light.rotation_degrees = Vector3(-15, 180, 0) # Face au joueur (depuis l'océan)
    add_child(moon_light)
    
    var dummy_moon = get_parent().get_node_or_null("EnvironmentAssets/Moon")
    if dummy_moon:
        dummy_moon.position = Vector3(0, 80, -350)
        dummy_moon.scale = Vector3(25, 25, 25) # Gigantesque
        var m_mat = dummy_moon.material_override as StandardMaterial3D
        if m_mat:
            m_mat.emission_energy_multiplier = 10.0 # Blanc éblouissant
            m_mat.emission = Color(1.0, 1.0, 1.0)
            m_mat.albedo_color = Color(1.0, 1.0, 1.0)
    
    # --- 5. BROUILLARD RAMPANT (FOG VOLUME) ---
    var fog_vol = FogVolume.new()
    fog_vol.size = Vector3(1000, 30, 1000)
    fog_vol.position = Vector3(0, -10, -50) # Couvre la mer et lèche le terrain
    var fog_mat = FogMaterial.new()
    fog_mat.density = 0.08 # Dense
    fog_mat.albedo = Color(0.8, 0.8, 0.8) # Brouillard spectral (Blanc/Gris)
    fog_mat.emission = Color(0.0, 0.0, 0.0)
    fog_mat.height_falloff = 2.0 # Colle bien au sol
    fog_mat.edge_fade = 0.5
    fog_vol.material = fog_mat
    add_child(fog_vol)
    
    # --- 6. LUMIÈRE FANTÔME (JOUEUR) ---
    var player = get_tree().get_first_node_in_group("player")
    if player:
        ghost_light = OmniLight3D.new()
        ghost_light.light_color = Color(0.9, 0.05, 0.05) # ROUGE SANG VIF
        ghost_light.light_energy = 1.0
        ghost_light.omni_range = 8.0
        ghost_light.shadow_enabled = true
        ghost_light.position = Vector3(0, 1.5, 0)
        player.add_child(ghost_light)

func _process(delta: float) -> void:
    if ghost_light:
        var t = Time.get_ticks_msec() / 1000.0
        ghost_light.light_energy = 1.0 + sin(t * (2 * PI / 3.0)) * 0.3
