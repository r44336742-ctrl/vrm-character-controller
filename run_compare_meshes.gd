extends SceneTree
func _init():
	var scene = load("res://scenes/main.tscn")
	var inst = scene.instantiate()
	
	var hair_mesh = inst.find_children("*Hair*", "MeshInstance3D", true)[0]
	var body_mesh = inst.find_children("*Body*", "MeshInstance3D", true)[0]
	
	print("--- COMPARING HAIR AND BODY ---")
	print("[Hair]  Skeleton path: ", hair_mesh.skeleton)
	print("[Body]  Skeleton path: ", body_mesh.skeleton)
	print("[Hair]  Skin object: ", hair_mesh.skin)
	print("[Body]  Skin object: ", body_mesh.skin)
	
	if hair_mesh.skin and body_mesh.skin:
		print("[Hair]  Skin bind count: ", hair_mesh.skin.get_bind_count())
		print("[Body]  Skin bind count: ", body_mesh.skin.get_bind_count())
	
	quit()
