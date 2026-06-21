extends Node
## Runtime Hair Weight Painter v2
## Réassigne les vertex weights du mesh Hair aux os J_Sec_Hair* au démarrage.
## Utilise les REST poses (même espace de coordonnées que les vertices).

@export var hair_mesh_name: String = "Hair"
@export var head_bone_name: String = "Head"

var _painted: bool = false

func _ready() -> void:
	call_deferred("_paint_weights")

func _paint_weights() -> void:
	if _painted:
		return
	_painted = true
	
	var parent = get_parent()
	if parent == null:
		return
	
	var skels = parent.find_children("*", "Skeleton3D", true)
	if skels.is_empty():
		return
	var skel: Skeleton3D = skels[0]
	
	var mesh_node: MeshInstance3D = null
	var mesh_nodes = parent.find_children("*", "MeshInstance3D", true)
	for mn in mesh_nodes:
		if hair_mesh_name in mn.name:
			mesh_node = mn
			break
	if mesh_node == null:
		return
	
	var mesh: ArrayMesh = mesh_node.mesh as ArrayMesh
	if mesh == null:
		return
	
	var head_idx: int = skel.find_bone(head_bone_name)
	if head_idx == -1:
		return
	
	# Récupérer la position du sommet du crâne en skeleton space
	# La position HEAD rest est l'ancre supérieure
	var head_global_rest = _get_bone_global_rest(skel, head_idx)
	var head_pos: Vector3 = head_global_rest.origin
	
	# Collecter les os Hair avec leurs positions en skeleton-space
	var hair_bones: Array[int] = []
	var hair_bone_positions: Array[Vector3] = []
	for i in range(skel.get_bone_count()):
		if "Hair" in skel.get_bone_name(i):
			hair_bones.append(i)
			hair_bone_positions.append(_get_bone_global_rest(skel, i).origin)
	
	if hair_bones.is_empty():
		return
	
	# Trouver la hauteur Y max et min des cheveux pour calibrer le gradient
	var y_max: float = -INF
	var y_min: float = INF
	for surf_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surf_idx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in range(len(verts)):
			y_max = maxf(y_max, verts[v].y)
			y_min = minf(y_min, verts[v].y)
	
	var hair_height = y_max - y_min
	# Le seuil de racine : les 8% supérieurs restent sur Head (racines serrées)
	var root_y = y_max - hair_height * 0.08
	
	print("[HairWeightPainter v2] Hair Y range: ", y_min, " to ", y_max, " height=", hair_height)
	print("[HairWeightPainter v2] Root threshold Y: ", root_y, " (top 15% stays on Head)")
	
	# Recréer le mesh avec les nouveaux weights
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
			
			# Trouver l'os Hair le plus proche (distance horizontale XZ prioritaire)
			var closest_bone_idx: int = -1
			var closest_dist: float = INF
			for bi in range(hair_bones.size()):
				var bone_pos = hair_bone_positions[bi]
				# Distance 3D mais avec poids sur XZ pour mieux cibler les mèches
				var dx = vert_pos.x - bone_pos.x
				var dz = vert_pos.z - bone_pos.z
				var dy = vert_pos.y - bone_pos.y
				var dist = sqrt(dx*dx + dz*dz + dy*dy*0.3)
				if dist < closest_dist:
					closest_dist = dist
					closest_bone_idx = hair_bones[bi]
			
			# Gradient basé sur la hauteur Y : 
			# - Au dessus de root_y → 100% Head (racines)
			# - En dessous de root_y → gradient vers Hair bone (pointes)
			var hair_weight: float = 0.0
			if vert_pos.y < root_y:
				# Progression exponentielle: les pointes ont ~85% d'influence
				var progress = (root_y - vert_pos.y) / (root_y - y_min)
				hair_weight = clampf(pow(progress, 0.6) * 0.85, 0.0, 0.85)
			
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
	
	mesh_node.mesh = new_mesh
	print("[HairWeightPainter v2] Done! Painted ", painted_total, "/", mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), " vertices")

# Calcule la rest pose globale d'un os (en remontant la chaîne parentale)
func _get_bone_global_rest(skel: Skeleton3D, bone_idx: int) -> Transform3D:
	var result = skel.get_bone_rest(bone_idx)
	var parent_idx = skel.get_bone_parent(bone_idx)
	while parent_idx >= 0:
		result = skel.get_bone_rest(parent_idx) * result
		parent_idx = skel.get_bone_parent(parent_idx)
	return result
