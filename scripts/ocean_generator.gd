extends Node3D

func _ready() -> void:
	var mesh_instance = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	plane.subdivide_width = 800
	plane.subdivide_depth = 800
	mesh_instance.mesh = plane
	
	var mat = ShaderMaterial.new()
	var shader = load("res://shaders/ocean.gdshader")
	if shader:
		mat.shader = shader
		
		# Normal map A (vagues moyennes)
		var noise1 = FastNoiseLite.new()
		noise1.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise1.frequency = 0.015
		var tex1 = NoiseTexture2D.new()
		tex1.width = 512
		tex1.height = 512
		tex1.noise = noise1
		tex1.as_normal_map = true
		tex1.bump_strength = 3.0
		tex1.seamless = true
		
		# Normal map B (clapotis fin)
		var noise2 = FastNoiseLite.new()
		noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise2.frequency = 0.025
		var tex2 = NoiseTexture2D.new()
		tex2.width = 512
		tex2.height = 512
		tex2.noise = noise2
		tex2.as_normal_map = true
		tex2.bump_strength = 2.0
		tex2.seamless = true
		
		# Attendre que les textures soient générées (elles sont asynchrones)
		await tex1.changed
		await tex2.changed
		
		mat.set_shader_parameter("normalmap_a", tex1)
		mat.set_shader_parameter("normalmap_b", tex2)
		
	mesh_instance.material_override = mat
	mesh_instance.position = Vector3(0, -6.0, -300)
	add_child(mesh_instance)
