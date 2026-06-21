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
	
	# ── Construire le mapping nom_os → bind_index depuis le Skin ──
	var skin: Skin = mesh_node.skin
	var bone_name_to_bind: Dictionary = {}
	if skin:
		for b in range(skin.get_bind_count()):
			var bname = skin.get_bind_name(b)
			if bname != "":
				bone_name_to_bind[bname] = b
	
	# Résoudre Head en bind index
	var head_bind: int = bone_name_to_bind.get(head_bone_name, -1)
	if head_bind == -1:
		# Fallback : chercher dans les arrays originaux quel bind est le plus utilisé
		var test_arrays = mesh.surface_get_arrays(0)
		if test_arrays[Mesh.ARRAY_BONES]:
			head_bind = test_arrays[Mesh.ARRAY_BONES][0]  # Le plus commun
		else:
			return
	
	print("[HairWeightPainter v2] Head bind index: ", head_bind)
	
	var head_idx: int = skel.find_bone(head_bone_name)
	if head_idx == -1:
		return
	
	# Collecter les os Hair avec positions ET bind indices
	var hair_bones: Array[int] = []         # skeleton bone indices (pour positions)
	var hair_bone_binds: Array[int] = []    # bind indices (pour ARRAY_BONES)
	var hair_bone_positions: Array[Vector3] = []
	for i in range(skel.get_bone_count()):
		var bname = skel.get_bone_name(i)
		if "Hair" in bname:
			var bind_idx = bone_name_to_bind.get(bname, -1)
			if bind_idx >= 0:
				hair_bones.append(i)
				hair_bone_binds.append(bind_idx)
				hair_bone_positions.append(_get_bone_global_rest(skel, i).origin)
	
	if hair_bones.is_empty():
		print("[HairWeightPainter v2] No hair bones found in skin binds!")
		return
	
	print("[HairWeightPainter v2] Found ", hair_bones.size(), " hair bones with valid bind indices")
	
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
	var root_y = y_max - hair_height * 0.20
	
	print("[HairWeightPainter v2] Hair Y range: ", y_min, " to ", y_max, " height=", hair_height)
	print("[HairWeightPainter v2] Root threshold Y: ", root_y, " (top 20% stays on Head)")
	
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
			
			# Trouver les 2 os Hair les plus proches (blend pour éviter blocs rigides)
			var best_bind: Array[int] = [-1, -1]
			var best_dist: Array[float] = [INF, INF]
			for bi in range(hair_bones.size()):
				var bone_pos = hair_bone_positions[bi]
				var dx = vert_pos.x - bone_pos.x
				var dz = vert_pos.z - bone_pos.z
				var dy = vert_pos.y - bone_pos.y
				var dist = sqrt(dx*dx + dz*dz + dy*dy*0.3)
				if dist < best_dist[0]:
					best_dist[1] = best_dist[0]; best_bind[1] = best_bind[0]
					best_dist[0] = dist;          best_bind[0] = hair_bone_binds[bi]
				elif dist < best_dist[1]:
					best_dist[1] = dist;          best_bind[1] = hair_bone_binds[bi]
			
			# Gradient basé sur la hauteur Y (max 35% aux pointes)
			var hair_weight: float = 0.0
			if vert_pos.y < root_y:
				var progress = (root_y - vert_pos.y) / (root_y - y_min)
				hair_weight = clampf(pow(progress, 0.9) * 0.35, 0.0, 0.35)
			
			if hair_weight > 0.01 and best_bind[0] >= 0:
				var head_weight: float = 1.0 - hair_weight
				
				if best_bind[1] >= 0 and best_dist[1] < INF:
					# Blend 2 os : répartir hair_weight selon distance inverse
					var w0 = 1.0 / (best_dist[0] + 0.001)
					var w1 = 1.0 / (best_dist[1] + 0.001)
					var total_w = w0 + w1
					var share0 = (w0 / total_w) * hair_weight
					var share1 = (w1 / total_w) * hair_weight
					new_bones[v * 4 + 0]   = head_bind;      new_weights[v * 4 + 0] = head_weight
					new_bones[v * 4 + 1]   = best_bind[0];   new_weights[v * 4 + 1] = share0
					new_bones[v * 4 + 2]   = best_bind[1];   new_weights[v * 4 + 2] = share1
					new_bones[v * 4 + 3]   = 0;              new_weights[v * 4 + 3] = 0.0
				else:
					# Fallback : 1 seul os Hair
					new_bones[v * 4 + 0]   = head_bind;      new_weights[v * 4 + 0] = head_weight
					new_bones[v * 4 + 1]   = best_bind[0];   new_weights[v * 4 + 1] = hair_weight
					new_bones[v * 4 + 2]   = 0;              new_weights[v * 4 + 2] = 0.0
					new_bones[v * 4 + 3]   = 0;              new_weights[v * 4 + 3] = 0.0
				painted_count += 1
		
		arrays[Mesh.ARRAY_BONES] = new_bones
		arrays[Mesh.ARRAY_WEIGHTS] = new_weights
		var fmt = mesh.surface_get_format(surf_idx)
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
		new_mesh.surface_set_material(new_mesh.get_surface_count() - 1, mesh.surface_get_material(surf_idx))
		painted_total += painted_count
	
	mesh_node.mesh = new_mesh
	print("[HairWeightPainter v2] Done! Painted ", painted_total, "/", mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), " vertices using BIND indices")

	# ── Appliquer le vertex shader vent par-dessus le matériau original ──
	_apply_wind_shader(mesh_node, new_mesh, y_min, y_max)

func _apply_wind_shader(mesh_node: MeshInstance3D, new_mesh: ArrayMesh, y_min: float, y_max: float) -> void:
	var wind_shader = load("res://shaders/hair_wind.gdshader") as Shader
	if wind_shader == null:
		push_warning("[HairWeightPainter] Impossible de charger res://shaders/hair_wind.gdshader")
		return

	for surf_idx in range(new_mesh.get_surface_count()):
		var orig_mat = new_mesh.surface_get_material(surf_idx)
		var std_mat = orig_mat as StandardMaterial3D
		
		var smat = ShaderMaterial.new()
		smat.shader = wind_shader

		# Copier les propriétés du matériau VRM original
		if std_mat:
			if std_mat.albedo_texture:
				smat.set_shader_parameter("albedo_tex", std_mat.albedo_texture)
			smat.set_shader_parameter("albedo_color",  std_mat.albedo_color)
			smat.set_shader_parameter("roughness",     std_mat.roughness)
			smat.set_shader_parameter("metallic",      std_mat.metallic)
			# Alpha scissor
			if std_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				smat.set_shader_parameter("alpha_scissor", std_mat.alpha_scissor_threshold)
			else:
				smat.set_shader_parameter("alpha_scissor", 0.1)
		else:
			# Fallback : texture blanche, ciseaux conservateurs
			smat.set_shader_parameter("albedo_color",  Color(1.0, 1.0, 1.0, 1.0))
			smat.set_shader_parameter("alpha_scissor", 0.1)

		# Paramètres géométriques du vent (calibrés sur les Y mesurés)
		smat.set_shader_parameter("hair_root_y",     y_min)
		smat.set_shader_parameter("hair_tip_y",      y_max)
		smat.set_shader_parameter("wind_strength",   0.022)
		smat.set_shader_parameter("wind_speed_slow", 0.75)
		smat.set_shader_parameter("wind_speed_fast", 2.20)
		smat.set_shader_parameter("wind_freq_y",     18.0)
		smat.set_shader_parameter("wind_freq_x",     12.0)

		new_mesh.surface_set_material(surf_idx, smat)

	print("[HairWeightPainter v2] Wind shader applied to ", new_mesh.get_surface_count(), " surfaces")

# Calcule la rest pose globale d'un os (en remontant la chaîne parentale)
func _get_bone_global_rest(skel: Skeleton3D, bone_idx: int) -> Transform3D:
	var result = skel.get_bone_rest(bone_idx)
	var parent_idx = skel.get_bone_parent(bone_idx)
	while parent_idx >= 0:
		result = skel.get_bone_rest(parent_idx) * result
		parent_idx = skel.get_bone_parent(parent_idx)
	return result

