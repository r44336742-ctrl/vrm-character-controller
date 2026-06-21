extends SceneTree

func _init():
    print("=== DÉBUT DU SCAN DES OS ===")
    
    var glb = load("res://assets/models/nico_robin.glb") as PackedScene
    if glb:
        var instance = glb.instantiate()
        var skel = _find_skeleton(instance)
        if skel:
            print("--- OS DE NICO ROBIN ---")
            for i in range(min(skel.get_bone_count(), 10)): # 10 premiers pour voir le style
                print(skel.get_bone_name(i))
        else:
            print("PAS DE SQUELETTE TROUVE DANS NICO ROBIN")
    else:
        print("IMPOSSIBLE DE CHARGER NICO ROBIN GLB")
        
    var fbx = load("res://assets/models/animations/idle.fbx") as PackedScene
    if fbx:
        var instance = fbx.instantiate()
        var skel = _find_skeleton(instance)
        if skel:
            print("--- OS DE MIXAMO IDLE ---")
            for i in range(min(skel.get_bone_count(), 10)):
                print(skel.get_bone_name(i))
            
            # Affichons aussi les pistes d'animation de Mixamo
            var ap = _find_anim_player(instance)
            if ap:
                print("--- PISTES D'ANIMATION MIXAMO ---")
                var anim = ap.get_animation(ap.get_animation_list()[0])
                for i in range(min(anim.get_track_count(), 5)):
                    print(anim.track_get_path(i))
        else:
            print("PAS DE SQUELETTE DANS IDLE FBX")
    else:
        print("IMPOSSIBLE DE CHARGER IDLE FBX")
        
    print("=== FIN DU SCAN ===")
    quit()

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D: return node
    for child in node.get_children():
        var res = _find_skeleton(child)
        if res: return res
    return null

func _find_anim_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer: return node
    for child in node.get_children():
        var res = _find_anim_player(child)
        if res: return res
    return null
