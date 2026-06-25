extends SceneTree
func _init():
    var mixamo = load("res://assets/models/animations/idle.fbx").instantiate()
    var mix_skel = mixamo.find_children("*", "Skeleton3D", true)[0]
    var mix_ul = mix_skel.find_bone("mixamorig:RightUpLeg")
    if mix_ul == -1: mix_ul = mix_skel.find_bone("RightUpLeg")
    print("Mixamo Leg Rest: ", mix_skel.get_bone_rest(mix_ul).basis.get_euler())
    var mix_arm = mix_skel.find_bone("mixamorig:RightArm")
    if mix_arm == -1: mix_arm = mix_skel.find_bone("RightArm")
    print("Mixamo Arm Rest: ", mix_skel.get_bone_rest(mix_arm).basis.get_euler())
    quit()
