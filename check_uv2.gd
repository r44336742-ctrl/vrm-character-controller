extends SceneTree

func _init():
    var scene = load("res://scenes/character.tscn")
    var inst = scene.instantiate()
    var skeleton = inst.get_node_or_null("ModelPivot/Nami/Skeleton3D")
    for child in skeleton.get_children():
        if child is MeshInstance3D:
            var mesh = child.mesh
            if mesh:
                var arr = mesh.surface_get_arrays(0)
                var uvs1 = arr[Mesh.ARRAY_TEX_UV] if arr.size() > Mesh.ARRAY_TEX_UV else null
                var uvs2 = arr[Mesh.ARRAY_TEX_UV2] if arr.size() > Mesh.ARRAY_TEX_UV2 else null
                print(child.name, " UV1: ", "YES" if uvs1 != null else "NO", " | UV2: ", "YES" if uvs2 != null else "NO")
    quit()
