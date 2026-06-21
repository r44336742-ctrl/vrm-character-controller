extends Node3D

# --- CONTRÔLEUR D'ATMOSPHÈRE ---
var world_env: WorldEnvironment
var moon_light: DirectionalLight3D
var ghost_light: OmniLight3D

func _ready() -> void:
    # 1. Configuration du WorldEnvironment
    var env = Environment.new()
    env.fog_enabled = true
    env.fog_mode = Environment.FOG_MODE_DEPTH
    env.fog_density = 0.015
    env.fog_color = Color(0.05, 0.07, 0.12)
    
    env.volumetric_fog_enabled = true
    env.volumetric_fog_density = 0.04
    env.volumetric_fog_gi_inject = 1.0
    
    env.glow_enabled = true
    env.glow_intensity = 0.4
    env.glow_bloom = 0.15
    env.adjustment_enabled = true
    env.adjustment_saturation = 0.5
    
    world_env = WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)
    
    # 2. Lumière de la Lune
    moon_light = DirectionalLight3D.new()
    moon_light.energy = 0.4
    moon_light.color = Color(0.6, 0.75, 1.0)
    moon_light.shadow_enabled = true
    moon_light.rotation_degrees = Vector3(-25, -40, 0)
    add_child(moon_light)
    
    # 3. Lumière fantôme attachée au joueur
    var player = get_tree().get_first_node_in_group("player")
    if player:
        ghost_light = OmniLight3D.new()
        ghost_light.color = Color(0.3, 0.4, 0.7)
        ghost_light.energy = 0.6
        ghost_light.range = 4.0
        player.add_child(ghost_light)

func _process(delta: float) -> void:
    # Animation de l'énergie de la lumière fantôme (respiration)
    if ghost_light:
        var t = Time.get_ticks_msec() / 1000.0
        # Période 6s, amplitude 0.15 autour de 0.6
        ghost_light.energy = 0.6 + sin(t * (2 * PI / 6.0)) * 0.15
