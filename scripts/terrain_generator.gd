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
    mesh_instance.mesh = mesh
    
    var mat = ShaderMaterial.new()
    var shader = load("res://shaders/terrain.gdshader")
    if shader:
        mat.shader = shader
    mesh_instance.material_override = mat
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

func get_height(px: float, pz: float) -> float:
    # Bruit de base (collines légères)
    var h = noise.get_noise_2d(px, pz) * 6.0 
    
    # Zone plate pour le manoir et le jardin (autour de Z = -20 à Z = 20)
    var dist_to_center = Vector2(px, pz + 10.0).length()
    if dist_to_center < 50.0:
        var blend = smoothstep(30.0, 50.0, dist_to_center)
        h = lerp(0.0, h, blend) # Aplanir vers 0
    
    # Falaise plongeante vers l'océan
    if pz < cliff_z_start:
        var drop = (cliff_z_start - pz) * 1.8 # Pente raide
        # Ajouter du bruit sur la falaise pour qu'elle ne soit pas parfaitement lisse
        var cliff_noise = noise.get_noise_2d(px * 3.0, pz * 3.0) * 2.0
        h -= drop + cliff_noise
        
    return h
