extends SceneTree
func _init():
    print("=== DEBUT DU DIAGNOSTIC ===")
    var fbx = load("res://assets/models/nami_idle.fbx") as PackedScene
    if fbx:
        var inst = fbx.instantiate()
        var meshes = 0
        for child in inst.find_children("*", "MeshInstance3D", true, false): 
            meshes += 1
        for child in inst.find_children("*", "ImporterMeshInstance3D", true, false): 
            meshes += 1
        
        var skel_count = 0
        for child in inst.find_children("*", "Skeleton3D", true, false):
            skel_count += 1
            print("Skeleton trouve avec ", child.get_bone_count(), " os.")
            
        print("RESULTAT FBX : ", meshes, " MeshInstance trouves.")
    else:
        print("ERREUR : Impossible de charger nami_idle.fbx")
    print("=== FIN DU DIAGNOSTIC ===")
    quit()
