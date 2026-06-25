extends SceneTree
func _init():
    var mixamo = load("res://assets/models/animations/idle.fbx").instantiate()
    var mix_skel = mixamo.find_children("*", "Skeleton3D", true)[0]
    for i in range(mix_skel.get_bone_count()):
        var bname = mix_skel.get_bone_name(i)
        if "UpLeg" in bname:
            print(bname, " Rest: ", mix_skel.get_bone_rest(i).basis.get_euler())
            print(bname, " Local Basis: ", mix_skel.get_bone_rest(i).basis)
    quit()
