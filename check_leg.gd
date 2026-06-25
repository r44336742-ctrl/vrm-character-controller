extends SceneTree
func _init():
    var vrm = load("res://assets/models/runner.vrm").instantiate()
    var vrm_skel = vrm.find_children("*", "Skeleton3D", true)[0]
    var mixamo = load("res://assets/models/animations/idle.fbx").instantiate()
    var mix_skel = mixamo.find_children("*", "Skeleton3D", true)[0]
    
    var vrm_ul = vrm_skel.find_bone("RightUpperLeg")
    var mix_ul = mix_skel.find_bone("mixamorig:RightUpLeg")
    
    print("VRM Leg Rest: ", vrm_skel.get_bone_rest(vrm_ul).basis.get_euler())
    print("Mixamo Leg Rest: ", mix_skel.get_bone_rest(mix_ul).basis.get_euler())
    
    print("VRM Leg Local Basis: ", vrm_skel.get_bone_rest(vrm_ul).basis)
    print("Mixamo Leg Local Basis: ", mix_skel.get_bone_rest(mix_ul).basis)
    
    var mix_forearm = mix_skel.find_bone("mixamorig:RightForeArm")
    var vrm_forearm = vrm_skel.find_bone("RightLowerArm")
    print("VRM ForeArm Rest: ", vrm_skel.get_bone_rest(vrm_forearm).basis.get_euler())
    print("Mixamo ForeArm Rest: ", mix_skel.get_bone_rest(mix_forearm).basis.get_euler())
    quit()
