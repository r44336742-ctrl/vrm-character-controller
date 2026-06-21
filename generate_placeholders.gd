extends SceneTree

func _init():
    # Character GLB (Capsule)
    var char_mesh = MeshInstance3D.new()
    var capsule = CapsuleMesh.new()
    capsule.radius = 0.25
    capsule.height = 1.6
    char_mesh.mesh = capsule
    
    var char_mat = StandardMaterial3D.new()
    char_mat.albedo_color = Color(0.1, 0.1, 0.1) # Dark clothes
    capsule.material = char_mat
    
    var char_node = Node3D.new()
    char_node.name = "character"
    char_mesh.position.y = 0.8
    char_node.add_child(char_mesh)
    
    var gltf = GLTFDocument.new()
    var state = GLTFState.new()
    gltf.append_from_scene(char_node, state)
    gltf.write_to_filesystem(state, "res://assets/models/character.glb")
    print("Generated placeholder character.glb")
    
    # Ruins GLB (Box structures)
    var ruins_node = Node3D.new()
    ruins_node.name = "ruins"
    for i in range(5):
        var pillar = MeshInstance3D.new()
        var box = BoxMesh.new()
        box.size = Vector3(1.5, 6.0, 1.5)
        pillar.mesh = box
        pillar.position = Vector3(randf_range(-15, 15), 3, randf_range(-15, 15))
        ruins_node.add_child(pillar)
        
    var state2 = GLTFState.new()
    gltf.append_from_scene(ruins_node, state2)
    gltf.write_to_filesystem(state2, "res://assets/models/ruins.glb")
    print("Generated placeholder ruins.glb")
    
    quit()
