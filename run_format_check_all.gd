extends SceneTree
func _init():
	var scene = load("res://scenes/main.tscn")
	var inst = scene.instantiate()
	
	print("\n--- CHECKING ALL MESH BIND INDICES ---")
	var meshes = inst.find_children("*", "MeshInstance3D", true)
	for mesh_node in meshes:
		var skin = mesh_node.skin
		if skin and skin.get_bind_count() > 0:
			var bname = skin.get_bind_name(0)
			var bidx = skin.get_bind_bone(0)
			print("[", mesh_node.name, "] First bind: name=", bname, " bone_idx=", bidx)
	
	quit()
