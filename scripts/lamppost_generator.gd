extends Node3D

@export var pairs_count: int = 5
@export var spacing: float = 18.0
@export var start_z: float = 40.0
@export var aisle_width: float = 4.0 # Distance depuis le centre de l'allée

func _ready() -> void:
    var base_mat = StandardMaterial3D.new()
    base_mat.albedo_color = Color(0.02, 0.02, 0.02) # Fer noir mat
    base_mat.metallic = 0.9
    base_mat.roughness = 0.6

    var lantern_mat = StandardMaterial3D.new()
    lantern_mat.albedo_color = Color(1.0, 0.0, 0.0)
    lantern_mat.emission_enabled = true
    lantern_mat.emission = Color(1.0, 0.0, 0.0)
    lantern_mat.emission_energy_multiplier = 4.0

    for i in range(pairs_count):
        # Un lampadaire de chaque côté
        var z = start_z - i * spacing
        _create_lamppost(Vector3(-aisle_width, 0.0, z), base_mat, lantern_mat)
        _create_lamppost(Vector3(aisle_width, 0.0, z), base_mat, lantern_mat)

func _create_lamppost(pos: Vector3, base_mat: StandardMaterial3D, lantern_mat: StandardMaterial3D) -> void:
    var post = Node3D.new()
    post.position = pos
    
    # 1. Base (Socle lourd)
    var base_mesh = BoxMesh.new()
    base_mesh.size = Vector3(0.4, 0.6, 0.4)
    var base_inst = MeshInstance3D.new()
    base_inst.mesh = base_mesh
    base_inst.material_override = base_mat
    base_inst.position.y = 0.3
    post.add_child(base_inst)
    
    # 2. Pilier
    var pillar_mesh = CylinderMesh.new()
    pillar_mesh.top_radius = 0.05
    pillar_mesh.bottom_radius = 0.08
    pillar_mesh.height = 3.5
    var pillar_inst = MeshInstance3D.new()
    pillar_inst.mesh = pillar_mesh
    pillar_inst.material_override = base_mat
    pillar_inst.position.y = 0.6 + 1.75
    post.add_child(pillar_inst)
    
    # 3. Lanterne (Verre rouge)
    var lantern_mesh = BoxMesh.new()
    lantern_mesh.size = Vector3(0.25, 0.4, 0.25)
    var lantern_inst = MeshInstance3D.new()
    lantern_inst.mesh = lantern_mesh
    lantern_inst.material_override = lantern_mat
    lantern_inst.position.y = 4.1 + 0.2
    post.add_child(lantern_inst)
    
    # 4. Toit (Chapeau pointu)
    var roof_mesh = CylinderMesh.new()
    roof_mesh.top_radius = 0.0
    roof_mesh.bottom_radius = 0.25
    roof_mesh.height = 0.3
    var roof_inst = MeshInstance3D.new()
    roof_inst.mesh = roof_mesh
    roof_inst.material_override = base_mat
    roof_inst.position.y = 4.5 + 0.15
    post.add_child(roof_inst)
    
    # 5. Lumière (OmniLight3D avec ombres)
    var light = OmniLight3D.new()
    light.light_color = Color(1.0, 0.05, 0.05) # Rouge pur
    light.light_energy = 2.0
    light.shadow_enabled = true
    light.omni_range = 12.0 # Éclaire loin
    light.position.y = 4.3
    post.add_child(light)
    
    # 6. Collision
    var body = StaticBody3D.new()
    var coll = CollisionShape3D.new()
    var shape = CylinderShape3D.new()
    shape.radius = 0.2
    shape.height = 4.0
    coll.shape = shape
    coll.position.y = 2.0
    body.add_child(coll)
    post.add_child(body)
    
    add_child(post)
