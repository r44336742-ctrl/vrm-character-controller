extends SceneTree
func _init():
    var vrm = load("res://assets/models/runner.vrm").instantiate()
    var vrm_skel = vrm.find_children("*", "Skeleton3D", true)[0]
    var mixamo = load("res://assets/models/animations/idle.fbx").instantiate()
    var mix_skel = mixamo.find_children("*", "Skeleton3D", true)[0]
    
    var vrm_hips = vrm_skel.find_bone("Hips")
    var mix_hips = mix_skel.find_bone("mixamorig_Hips")
    
    print("VRM Hips Local Basis: ", vrm_skel.get_bone_rest(vrm_hips).basis)
    print("Mixamo Hips Local Basis: ", mix_skel.get_bone_rest(mix_hips).basis)
    quit()
