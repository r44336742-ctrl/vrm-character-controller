extends SceneTree
func _init():
    var vrm = load("res://assets/models/runner.vrm").instantiate()
    var vrm_skel = vrm.find_children("*", "Skeleton3D", true)[0]
    var mixamo = load("res://assets/models/animations/idle.fbx").instantiate()
    var mix_skel = mixamo.find_children("*", "Skeleton3D", true)[0]
    
    var vrm_ll = vrm_skel.find_bone("RightLowerLeg")
    var mix_ll = mix_skel.find_bone("mixamorig_RightLeg")
    
    print("VRM LowerLeg Local: ", vrm_skel.get_bone_rest(vrm_ll).basis)
    print("Mixamo LowerLeg Local: ", mix_skel.get_bone_rest(mix_ll).basis)
    quit()
