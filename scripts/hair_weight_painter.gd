extends Node
## Runtime Hair Weight Painter
## Réassigne les vertex weights du mesh Hair aux os J_Sec_Hair* au démarrage.
## Ceci corrige les modèles VRoid exportés sans bone weights sur les cheveux.

@export var hair_mesh_name: String = "Hair"
@export var head_bone_name: String = "Head"

# Contrôle du gradient de poids
@export var root_radius: float = 0.06  # Distance au-dessous de laquelle le vertex reste 100% Head
@export var max_influence_distance: float = 0.35  # Distance max pour le hair bone le plus proche

var _painted: bool = false

func _ready() -> void:
	# Attendre une frame pour que le VRM soit complètement chargé
	call_deferred("_paint_weights")

func _paint_weights() -> void:
	if _painted:
		return
	_painted = true
	
	var parent = get_parent()
	if parent == null:
		return
	
	# Trouver le skeleton
	var skels = parent.find_children("*", "Skeleton3D", true)
	if skels.is_empty():
		push_warning("HairWeightPainter: Skeleton3D not found")
		return
	var skel: Skeleton3D = skels[0]
	
	# Trouver le mesh Hair
	var mesh_node: MeshInstance3D = null
	var mesh_nodes = parent.find_children("*", "MeshInstance3D", true)
	for mn in mesh_nodes:
		if mn.name == hair_mesh_name or hair_mesh_name in mn.name:
			mesh_node = mn
			break
	if mesh_node == null:
		push_warning("HairWeightPainter: Hair mesh not found")
		return
	
	var mesh: ArrayMesh = mesh_node.mesh as ArrayMesh
	if mesh == null:
		push_warning("HairWeightPainter: Mesh is not ArrayMesh")
		return
	
	# Identifier les os Hair et leur position world
	var head_idx: int = skel.find_bone(head_bone_name)
	if head_idx == -1:
		push_warning("HairWeightPainter: Head bone not found")
		return
	
	var head_pos: Vector3 = skel.get_bone_global_pose(head_idx).origin
	
	var hair_bones: Array[int] = []
	var hair_bone_positions: Array[Vector3] = []
	for i in range(skel.get_bone_count()):
		if "Hair" in skel.get_bone_name(i):
			hair_bones.append(i)
			hair_bone_positions.append(skel.get_bone_global_pose(i).origin)
	
	if hair_bones.is_empty():
		push_warning("HairWeightPainter: No hair bones found")
		return
	
	print("[HairWeightPainter] Painting ", mesh.get_surface_count(), " surfaces, ", hair_bones.size(), " hair bones")
	
	# Recréer le mesh complet avec les nouveaux weights
	var new_mesh = ArrayMesh.new()
	var painted_total: int = 0
	
	for surf_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surf_idx)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones_arr = arrays[Mesh.ARRAY_BONES]
		var weights_arr = arrays[Mesh.ARRAY_WEIGHTS]
		
		if bones_arr == null or weights_arr == null:
			new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			new_mesh.surface_set_material(new_mesh.get_surface_count() - 1, mesh.surface_get_material(surf_idx))
			continue
		
		var vert_count = len(vertices)
		var new_bones = bones_arr.duplicate()
		var new_weights = weights_arr.duplicate()
		var painted_count: int = 0
		
		for v in range(vert_count):
			var vert_pos: Vector3 = vertices[v]
			
			# Trouver l'os Hair le plus proche
			var closest_bone_idx: int = -1
			var closest_dist: float = INF
			for bi in range(hair_bones.size()):
				var dist = vert_pos.distance_to(hair_bone_positions[bi])
				if dist < closest_dist:
					closest_dist = dist
					closest_bone_idx = hair_bones[bi]
			
			# Distance à la tête (racine des cheveux)
			var head_dist = vert_pos.distance_to(head_pos)
			
			# Calculer le poids : plus le vertex est loin de la tête, plus il suit le hair bone
			var hair_weight: float = 0.0
			if head_dist > root_radius:
				hair_weight = clampf((head_dist - root_radius) / (max_influence_distance - root_radius), 0.0, 0.85)
			
			if hair_weight > 0.01 and closest_bone_idx >= 0:
				var head_weight: float = 1.0 - hair_weight
				new_bones[v * 4 + 0] = head_idx
				new_weights[v * 4 + 0] = head_weight
				new_bones[v * 4 + 1] = closest_bone_idx
				new_weights[v * 4 + 1] = hair_weight
				new_bones[v * 4 + 2] = 0
				new_weights[v * 4 + 2] = 0.0
				new_bones[v * 4 + 3] = 0
				new_weights[v * 4 + 3] = 0.0
				painted_count += 1
		
		arrays[Mesh.ARRAY_BONES] = new_bones
		arrays[Mesh.ARRAY_WEIGHTS] = new_weights
		var fmt = mesh.surface_get_format(surf_idx)
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
		new_mesh.surface_set_material(new_mesh.get_surface_count() - 1, mesh.surface_get_material(surf_idx))
		painted_total += painted_count
		print("[HairWeightPainter] Surface ", surf_idx, ": painted ", painted_count, "/", vert_count, " vertices")
	
	# Remplacer le mesh
	mesh_node.mesh = new_mesh
	print("[HairWeightPainter] Done! Total painted: ", painted_total)
