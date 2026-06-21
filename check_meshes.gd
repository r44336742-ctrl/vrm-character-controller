extends SceneTree

func _init():
	var scene = load("res://assets/models/nami_idle.fbx")
	var node = scene.instantiate()
	print("--- MESH STATS ---")
	_print_tree(node)
	quit()

func _print_tree(node: Node):
	if node is ImporterMeshInstance3D:
		var mesh = node.mesh
		if mesh:
			var arrays = mesh.get_surface_arrays(0)
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			print(node.name, " - Vertices: ", vertices.size())
	elif node is MeshInstance3D:
		var mesh = node.mesh
		if mesh:
			var arrays = mesh.surface_get_arrays(0)
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			print(node.name, " - Vertices: ", vertices.size())
			
	for child in node.get_children():
		_print_tree(child)
