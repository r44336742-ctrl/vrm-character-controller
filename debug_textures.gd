extends SceneTree

func _init():
    print("--- DEBUG TEXTURES ---")
    var tex = load("res://assets/textures/nami/T_P003_E001_Wear_CS01_C_0.png")
    if tex:
        print("Texture WEAR loaded! Type: ", tex.get_class())
    else:
        print("FAILED to load Texture WEAR!")

    var scene = load("res://scenes/character.tscn")
    if scene:
        var inst = scene.instantiate()
        var skeleton = inst.get_node_or_null("ModelPivot/Nami/Skeleton3D")
        if skeleton:
            print("Skeleton3D found!")
            for child in skeleton.get_children():
                print("- Child: ", child.name, " Type: ", child.get_class())
                if child is MeshInstance3D:
                    var mesh = child.mesh
                    if mesh:
                        print("  Surface count: ", mesh.get_surface_count())
                        var mat = child.get_surface_override_material(0)
                        if mat:
                            print("  Has override material: YES")
                        else:
                            print("  Has override material: NO")
        else:
            print("Skeleton3D NOT FOUND! Nodes:")
            _print_tree(inst, "")
    quit()

func _print_tree(node, indent):
    print(indent + node.name)
    for c in node.get_children():
        _print_tree(c, indent + "  ")
