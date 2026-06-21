extends SceneTree

func _init():
	var scene = load("res://assets/models/nami_idle.fbx")
	if not scene:
		print("Failed to load nami_idle.fbx")
		quit()
		return
	var node = scene.instantiate()
	print("--- FBX STRUCTURE ---")
	_print_tree(node, "")
	print("---------------------")
	quit()

func _print_tree(node: Node, indent: String):
	var info = indent + node.name + " (" + node.get_class() + ")"
	if node is ImporterMeshInstance3D:
		var mesh = node.mesh
		if mesh:
			info += " - " + str(mesh.get_surface_count()) + " surfaces: "
			for i in range(mesh.get_surface_count()):
				var mat_name = mesh.get_surface_material_name(i)
				info += str(i) + ":" + str(mat_name) + " "
	elif node is MeshInstance3D:
		var mesh = node.mesh
		if mesh:
			info += " - " + str(mesh.get_surface_count()) + " surfaces: "
			for i in range(mesh.get_surface_count()):
				var mat = mesh.surface_get_material(i)
				var mat_name = mat.resource_name if mat else "null"
				info += str(i) + ":" + str(mat_name) + " "
	print(info)
	for child in node.get_children():
		_print_tree(child, indent + "  ")
