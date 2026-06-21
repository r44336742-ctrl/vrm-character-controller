extends Node3D

func _ready() -> void:
    var mesh_instance = MeshInstance3D.new()
    var plane = PlaneMesh.new()
    # Très grande surface pour l'océan
    plane.size = Vector2(800, 400)
    # Résolution moyenne : assez pour voir les vagues de Gerstner
    plane.subdivide_width = 250
    plane.subdivide_depth = 150
    mesh_instance.mesh = plane
    
    var mat = ShaderMaterial.new()
    var shader = load("res://shaders/ocean.gdshader")
    if shader:
        mat.shader = shader
    mesh_instance.material_override = mat
    
    # Positionner l'océan en contrebas de la falaise
    # La falaise chute à Z < -75. L'océan sera centré plus loin.
    mesh_instance.position = Vector3(0, -16.0, -150)
    
    add_child(mesh_instance)
