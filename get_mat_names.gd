extends SceneTree

func _init():
    print("--- FETCHING ORIGINAL MATERIAL NAMES ---")
    var scene = load("res://scenes/character.tscn")
    var inst = scene.instantiate()
    var skeleton = inst.get_node_or_null("ModelPivot/Nami/Skeleton3D")
    for child in skeleton.get_children():
        if child is MeshInstance3D:
            var mesh = child.mesh
            if mesh:
                var mat = mesh.surface_get_material(0)
                if mat:
                    var mat_name = mat.resource_name
                    if mat_name == "": mat_name = mat.resource_path.get_file()
                    print(child.name, " Original Mat: ", mat_name)
                else:
                    print(child.name, " Original Mat: NULL")
    quit()
