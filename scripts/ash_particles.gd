extends GPUParticles3D

# --- PARTICULES : Poussières/Lucioles spectrales ---
var proc_mat: ParticleProcessMaterial

func _ready() -> void:
	amount = 100
	emitting = true
	lifetime = 6.0
	
	# Matériau visuel (quad lumineux bleu pâle)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.5, 0.7, 1.0, 0.4)  # Bleu pâle spectral
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.5, 0.9)
	mat.emission_energy_multiplier = 0.5
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.03, 0.03)
	mesh.material = mat
	
	# Configuration physique
	proc_mat = ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc_mat.emission_box_extents = Vector3(15, 4, 15)
	proc_mat.initial_velocity_min = 0.05
	proc_mat.initial_velocity_max = 0.2
	proc_mat.gravity = Vector3(0, 0.02, 0) # Flottent vers le haut (lucioles)
	proc_mat.scale_min = 0.3
	proc_mat.scale_max = 1.2
	
	process_material = proc_mat
	draw_pass_1 = mesh

func _physics_process(delta: float) -> void:
	# Suit le joueur
	var player = get_tree().get_first_node_in_group("player")
	if player:
		global_position = player.global_position + Vector3(0, 1, 0)
		
	# Alignement avec le vent
	if proc_mat and WindSystem:
		var wind = WindSystem.get_wind_at(global_position) * 0.3
		proc_mat.direction = wind.normalized()
		var wind_speed = wind.length()
		proc_mat.initial_velocity_min = wind_speed * 0.5
		proc_mat.initial_velocity_max = wind_speed * 0.8
