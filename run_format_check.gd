extends SceneTree
func _init():
	var scene = load("res://scenes/main.tscn")
	var inst = scene.instantiate()
	
	print("\n--- CHECKING SKIRT BIND INDEX ---")
	var skirt_nodes = inst.find_children("*Skirt*", "MeshInstance3D", true)
	if not skirt_nodes.is_empty():
		var skirt_node = skirt_nodes[0]
		var skin = skirt_node.skin
		if skin and skin.get_bind_count() > 0:
			var bname = skin.get_bind_name(0)
			var bidx = skin.get_bind_bone(0)
			print("[Skirt] First bind: name=", bname, " bone_idx=", bidx)
	
	print("\n--- CHECKING HAIR MESH FORMAT AFTER REBUILD ---")
	var mesh_nodes = inst.find_children("*Hair*", "MeshInstance3D", true)
	if not mesh_nodes.is_empty():
		var mesh_node = mesh_nodes[0]
		var mesh = mesh_node.mesh as ArrayMesh
		if mesh and mesh.get_surface_count() > 0:
			var fmt = mesh.surface_get_format(0)
			print("[Hair] Surface 0 format: ", fmt)
			print("[Hair] Has BONES flag: ", (fmt & Mesh.ARRAY_FORMAT_BONES) != 0)
			print("[Hair] Has WEIGHTS flag: ", (fmt & Mesh.ARRAY_FORMAT_WEIGHTS) != 0)
			
	quit()
