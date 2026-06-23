extends Node3D

@export var terrain_size: float = 200.0
@export var resolution: float = 1.0 # 1 vertex per meter
@export var cliff_z_start: float = -75.0 # Z position where cliff starts

var noise: FastNoiseLite

func _ready() -> void:
	print("TerrainGenerator: Generating terrain...")
	
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = 12345
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.015

	var verts_count = int(terrain_size / resolution) + 1
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var height_data = PackedFloat32Array()
	height_data.resize(verts_count * verts_count)
	
	# 1. Generate vertices
	for z in range(verts_count):
		for x in range(verts_count):
			var px = x * resolution - terrain_size / 2.0
			var pz = z * resolution - terrain_size / 2.0
			
			var y = get_height(px, pz)
			height_data[z * verts_count + x] = y
			
			st.set_uv(Vector2(x / float(verts_count), z / float(verts_count)))
			st.add_vertex(Vector3(px, y, pz))
			
	# 2. Generate indices
	for z in range(verts_count - 1):
		for x in range(verts_count - 1):
			var i = z * verts_count + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + verts_count)
			
			st.add_index(i + 1)
			st.add_index(i + verts_count + 1)
			st.add_index(i + verts_count)
			
	st.generate_normals()
	st.generate_tangents()
	
	var mesh = st.commit()
	
	# 3. Create MeshInstance
	var mesh_instance = MeshInstance3D.new()
	
	var mat = ShaderMaterial.new()
	var shader = load("res://shaders/terrain.gdshader")
	if shader:
		mat.shader = shader
	mesh_instance.mesh = mesh
	
	# --- TERRAIN MATERIAL ---
	# Paint the ground with the exact same dark color as the grass roots.
	# This completely hides any gaps between the grass, creating the illusion of infinite density.
	var terrain_mat = StandardMaterial3D.new()
	terrain_mat.albedo_color = Color(0.01, 0.02, 0.05) # Same as grass color_bottom
	terrain_mat.roughness = 0.9
	mesh_instance.material_override = terrain_mat
	
	add_child(mesh_instance)
	
	# 4. Create optimized collision (HeightMapShape3D)
	var static_body = StaticBody3D.new()
	var coll_shape = CollisionShape3D.new()
	var height_shape = HeightMapShape3D.new()
	height_shape.map_width = verts_count
	height_shape.map_depth = verts_count
	height_shape.map_data = height_data
	coll_shape.shape = height_shape
	static_body.add_child(coll_shape)
	add_child(static_body)
	
	print("TerrainGenerator: Done.")
	
	# 5. Generate Grass
	generate_grass()

var grass_material: ShaderMaterial

func generate_grass() -> void:
	print("TerrainGenerator: Generating grass...")
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var blades_per_clump = 18
	var max_height = 0.9
	var min_height = 0.5
	var segments = 2
	var base_width = 0.12
	var v_count = 0
	
	# Generate a single clump of grass at origin (0,0,0)
	for b in range(blades_per_clump):
		var angle = (float(b) / blades_per_clump) * PI * 2.0 + randf_range(-0.3, 0.3)
		var h = randf_range(min_height, max_height)
		var curve_amount = randf_range(0.3, 0.7) # Leans out much more
		
		var dir_x = cos(angle)
		var dir_z = sin(angle)
		
		var right_x = cos(angle + PI/2.0)
		var right_z = sin(angle + PI/2.0)
		
		var v_start = v_count
		
		for i in range(segments + 1):
			var t = float(i) / segments
			var t_curve = t * t 
			
			var y = t * h
			var x_offset = dir_x * t_curve * curve_amount
			var z_offset = dir_z * t_curve * curve_amount
			
			var current_width = lerp(base_width, 0.0, t) 
			
			var left_x = x_offset - right_x * current_width * 0.5
			var left_z = z_offset - right_z * current_width * 0.5
			var right_x_pos = x_offset + right_x * current_width * 0.5
			var right_z_pos = z_offset + right_z * current_width * 0.5
			
			st.set_uv(Vector2(0.0, t))
			st.add_vertex(Vector3(left_x, y, left_z))
			
			st.set_uv(Vector2(1.0, t))
			st.add_vertex(Vector3(right_x_pos, y, right_z_pos))
			
			v_count += 2
			
		for i in range(segments):
			var base = v_start + i * 2
			# Front face only! cull_disabled in shader handles back face
			st.add_index(base)
			st.add_index(base + 1)
			st.add_index(base + 2)
			
			st.add_index(base + 1)
			st.add_index(base + 3)
			st.add_index(base + 2)
			
	st.generate_normals()
	var grass_mesh = st.commit()
	
	var instances = 150000
	var valid_positions = []
	
	for i in range(350000):
		var px = randf_range(-terrain_size / 2.0, terrain_size / 2.0)
		var pz = randf_range(-terrain_size / 2.0, terrain_size / 2.0)
		
		if pz < cliff_z_start + 5.0:
			continue
			
		var closest_z = clamp(pz, -30.0, 50.0)
		var dist_to_estate = Vector2(px, pz - closest_z).length()
		
		if dist_to_estate < 25.0:
			continue
			
		var y = get_height(px, pz)
		if y > -2.0:
			valid_positions.append(Vector3(px, y, pz))
			
		if valid_positions.size() >= instances:
			break
			
	# CHUNKING SYSTEM FOR FRUSTUM CULLING
	var chunk_size = 80.0
	var chunks = {}
	
	for i in range(valid_positions.size()):
		var pos = valid_positions[i]
		var cx = floor(pos.x / chunk_size)
		var cz = floor(pos.z / chunk_size)
		var cpos = Vector2(cx, cz)
		
		if not chunks.has(cpos):
			chunks[cpos] = []
			
		var transform = Transform3D()
		transform = transform.rotated_local(Vector3.UP, randf() * PI * 2.0)
		var scale = randf_range(0.7, 1.4)
		transform = transform.scaled_local(Vector3(scale, scale, scale))
		transform.origin = pos
		chunks[cpos].append(transform)
		
	grass_material = ShaderMaterial.new()
	grass_material.shader = load("res://shaders/grass.gdshader")
	
	var grass_parent = Node3D.new()
	grass_parent.name = "GrassChunks"
	add_child(grass_parent)
	
	for cpos in chunks:
		var arr = chunks[cpos]
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = grass_mesh
		mm.instance_count = arr.size()
		
		for i in range(arr.size()):
			mm.set_instance_transform(i, arr[i])
			
		var mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = grass_material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		# Optimization: Distance fade
		mmi.visibility_range_end = 130.0
		mmi.visibility_range_end_margin = 20.0
		
		grass_parent.add_child(mmi)
		
	print("TerrainGenerator: Grass generated with %d chunks and %d instances." % [chunks.size(), valid_positions.size()])

func _process(delta: float) -> void:
	if grass_material:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			grass_material.set_shader_parameter("player_position", player.global_position)

func get_height(px: float, pz: float) -> float:
	var h = noise.get_noise_2d(px, pz) * 6.0 
	
	var closest_z = clamp(pz, -30.0, 50.0)
	var dist_to_estate = Vector2(px, pz - closest_z).length()
	
	if dist_to_estate < 40.0:
		var blend = smoothstep(20.0, 40.0, dist_to_estate)
		h = lerp(0.0, h, blend)
	
	if pz < cliff_z_start:
		var drop = (cliff_z_start - pz) * 1.0 
		var cliff_noise = noise.get_noise_2d(px * 3.0, pz * 3.0) * 2.0
		h -= drop + cliff_noise
		
	return h
