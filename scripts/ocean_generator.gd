extends Node3D

func _ready() -> void:
    var mesh_instance = MeshInstance3D.new()
    var plane = PlaneMesh.new()
    # Océan gigantesque pour éviter de voir les bords
    plane.size = Vector2(1200, 1200)
    plane.subdivide_width = 300
    plane.subdivide_depth = 300
    mesh_instance.mesh = plane
    
    var mat = ShaderMaterial.new()
    var shader = load("res://shaders/ocean.gdshader")
    if shader:
        mat.shader = shader
        
        # Génération procédurale des Normal Maps pour les micro-vagues (clapotis)
        var noise1 = FastNoiseLite.new()
        noise1.noise_type = FastNoiseLite.TYPE_SIMPLEX
        noise1.frequency = 0.015
        var tex1 = NoiseTexture2D.new()
        tex1.noise = noise1
        tex1.as_normal_map = true
        tex1.bump_strength = 2.0
        tex1.seamless = true
        
        var noise2 = FastNoiseLite.new()
        noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX
        noise2.frequency = 0.02
        var tex2 = NoiseTexture2D.new()
        tex2.noise = noise2
        tex2.as_normal_map = true
        tex2.bump_strength = 1.5
        tex2.seamless = true
        
        # Injection dans le shader
        mat.set_shader_parameter("normalmap_a", tex1)
        mat.set_shader_parameter("normalmap_b", tex2)
        
    mesh_instance.material_override = mat
    
    # Très bas pour être dominé par la falaise
    mesh_instance.position = Vector3(0, -18.0, -300)
    add_child(mesh_instance)
