extends GPUParticles3D

func _ready() -> void:
    amount = 15
    emitting = true
    
    # Matériau doux et transparent pour la brume
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.4, 0.5, 0.7, 0.15)
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    
    var mesh = QuadMesh.new()
    mesh.size = Vector2(20, 5)
    mesh.material = mat
    
    var proc_mat = ParticleProcessMaterial.new()
    proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    proc_mat.emission_box_extents = Vector3(30, 0.5, 30)
    proc_mat.initial_velocity_min = 0.5
    proc_mat.initial_velocity_max = 1.5
    proc_mat.direction = Vector3(1, 0, 0.3) # Dérive avec le vent
    proc_mat.gravity = Vector3.ZERO
    proc_mat.scale_min = 2.0
    proc_mat.scale_max = 5.0
    
    process_material = proc_mat
    draw_pass_1 = mesh
    
    # Positionner juste au-dessus de l'eau
    global_position.y = 0.5
