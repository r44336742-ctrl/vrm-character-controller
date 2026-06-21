extends SceneTree

func _init():
    print("Démarrage de la conversion vers OBJ...")
    var packed = load("res://assets/models/nico_robin.glb") as PackedScene
    if not packed:
        print("Erreur: Impossible de charger nico_robin.glb")
        quit()
        return
        
    var scene = packed.instantiate()
    get_root().add_child(scene)
    var meshes = []
    _collect_meshes(scene, meshes)
    
    if meshes.is_empty():
        print("Erreur: Aucun mesh trouvé dans le modèle.")
        quit()
        return
        
    var path = "res://nico_robin_pure.obj"
    var file = FileAccess.open(path, FileAccess.WRITE)
    if not file:
        print("Erreur ouverture fichier OBJ")
        quit()
        return
        
    var vertex_offset = 1
    for mi in meshes:
        var mesh = mi.mesh as ArrayMesh
        # Certains importateurs utilisent un ImporterMesh, on le convertit si besoin
        if not mesh and mi.mesh is ImporterMesh:
            mesh = mi.mesh.get_mesh()
            
        if not mesh: continue
        
        var transform = mi.global_transform
        file.store_line("o " + mi.name)
        
        for surf_idx in range(mesh.get_surface_count()):
            var arrays = mesh.surface_get_arrays(surf_idx)
            var vertices = arrays[Mesh.ARRAY_VERTEX]
            var normals = arrays[Mesh.ARRAY_NORMAL]
            var uvs = arrays[Mesh.ARRAY_TEX_UV]
            var indices = arrays[Mesh.ARRAY_INDEX]
            
            if not vertices: continue
            
            for v in vertices:
                var glob_v = transform * v
                file.store_line("v %f %f %f" % [glob_v.x, glob_v.y, glob_v.z])
                
            if uvs:
                for uv in uvs:
                    # OBJ UVs are often flipped vertically
                    file.store_line("vt %f %f" % [uv.x, 1.0 - uv.y])
            
            if normals:
                for n in normals:
                    var glob_n = transform.basis * n
                    file.store_line("vn %f %f %f" % [glob_n.x, glob_n.y, glob_n.z])
                    
            if indices:
                for i in range(0, indices.size(), 3):
                    var i1 = indices[i] + vertex_offset
                    var i2 = indices[i+1] + vertex_offset
                    var i3 = indices[i+2] + vertex_offset
                    if uvs and normals:
                        file.store_line("f %d/%d/%d %d/%d/%d %d/%d/%d" % [i1, i1, i1, i2, i2, i2, i3, i3, i3])
                    elif uvs:
                        file.store_line("f %d/%d %d/%d %d/%d" % [i1, i1, i2, i2, i3, i3])
                    elif normals:
                        file.store_line("f %d//%d %d//%d %d//%d" % [i1, i1, i2, i2, i3, i3])
                    else:
                        file.store_line("f %d %d %d" % [i1, i2, i3])
            
            vertex_offset += vertices.size()
            
    file.close()
    print("Conversion terminée : nico_robin_pure.obj a ete cree avec succes.")
    quit()

func _collect_meshes(node: Node, arr: Array):
    if node is MeshInstance3D:
        arr.append(node)
    for c in node.get_children():
        _collect_meshes(c, arr)
