extends Node

func _ready():
	call_deferred("_run_debug")

func _run_debug():
	var parent = get_parent()
	var mesh_node : MeshInstance3D = null
	for mn in parent.find_children("*", "MeshInstance3D", true):
		if "Hair" in mn.name:
			mesh_node = mn
			break
			
	if not mesh_node:
		print("[Debug] No hair mesh found.")
		return
		
	var mesh = mesh_node.mesh as ArrayMesh
	if not mesh:
		print("[Debug] Hair mesh is not ArrayMesh.")
		return
		
	var skin = mesh_node.skin
	var target_bind = -1
	var target_bone_name = ""
	if skin:
		for i in range(skin.get_bind_count()):
			var bname = skin.get_bind_name(i)
			if "J_Sec_Hair" in bname:
				target_bind = i
				target_bone_name = bname
				break
				
	print("[Debug] Target bone: ", target_bone_name, " bind_idx: ", target_bind)
	
	var new_mesh = ArrayMesh.new()
	for surf_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surf_idx)
		var verts = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		
		var colors = PackedColorArray()
		colors.resize(verts.size())
		
		var max_weight = 0.0
		
		if bones != null and weights != null:
			for v in range(verts.size()):
				var w = 0.0
				for i in range(4):
					if bones[v*4 + i] == target_bind:
						w = weights[v*4 + i]
				colors[v] = Color(w, 0.0, 1.0 - w, 1.0) # Red if 1, Blue if 0
				max_weight = max(max_weight, w)
		else:
			for v in range(verts.size()):
				colors[v] = Color(0, 0, 1, 1) # All blue
				
		print("[Debug] Surface ", surf_idx, " max weight for ", target_bone_name, ": ", max_weight)
		
		arrays[Mesh.ARRAY_COLOR] = colors
		var fmt = mesh.surface_get_format(surf_idx)
		# Ensure format includes color
		fmt |= Mesh.ARRAY_FORMAT_COLOR
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
		
		var mat = StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		new_mesh.surface_set_material(surf_idx, mat)
		
	mesh_node.mesh = new_mesh
	print("[Debug] Applied debug color material to hair.")
