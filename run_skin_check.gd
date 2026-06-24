extends SceneTree
func _init():
	var scene = load("res://scenes/main.tscn")
	var inst = scene.instantiate()
	var skels = inst.find_children("*", "Skeleton3D", true)
	var mesh_nodes = inst.find_children("*Hair*", "MeshInstance3D", true)
	if not mesh_nodes.is_empty():
		var mesh_node = mesh_nodes[0]
		var skin = mesh_node.skin
		var skel = skels[0]
		if skin:
			print("[SkinDebug] Bind count: ", skin.get_bind_count())
			for i in range(skin.get_bind_count()):
				var bname = skin.get_bind_name(i)
				if "Hair" in bname:
					var bone_idx = skin.get_bind_bone(i)
					print("[SkinDebug] Bind ", i, " -> name: ", bname, " bone_idx in skin: ", bone_idx, " actual skel idx: ", skel.find_bone(bname))
	quit()
