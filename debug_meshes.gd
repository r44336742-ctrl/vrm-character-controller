extends SceneTree

func _init():
    var scene = load("res://scenes/character.tscn")
    var inst = scene.instantiate()
    var skeleton = inst.get_node_or_null("ModelPivot/Nami/Skeleton3D")
    for child in skeleton.get_children():
        if child is MeshInstance3D:
            var mesh = child.mesh
            var arr = mesh.surface_get_arrays(0)
            var verts = arr[Mesh.ARRAY_VERTEX]
            var uvs = arr[Mesh.ARRAY_TEX_UV] if arr.size() > Mesh.ARRAY_TEX_UV else null
            print(child.name, " Verts: ", verts.size(), " UVs: ", "YES" if uvs != null else "NO")
    quit()
