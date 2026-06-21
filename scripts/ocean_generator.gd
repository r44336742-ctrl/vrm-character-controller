extends Node3D

func _ready() -> void:
	var mesh_instance = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(1200, 1200)
	plane.subdivide_width = 300
	plane.subdivide_depth = 300
	mesh_instance.mesh = plane
	
	var mat = ShaderMaterial.new()
	var shader = load("res://shaders/ocean.gdshader")
	if shader:
		mat.shader = shader
		# Tout est procédural dans le shader, pas besoin de textures
	
	mesh_instance.material_override = mat
	mesh_instance.position = Vector3(0, -6.0, -300)
	add_child(mesh_instance)
