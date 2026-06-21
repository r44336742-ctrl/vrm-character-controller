extends Node

# --- AUDIO MANAGER : Mer + Pas ---
var ocean_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer
var footstep_timer: float = 0.0
var is_walking: bool = false

func _ready() -> void:
	_setup_ocean_sound()
	_setup_footstep_sound()

func _process(delta: float) -> void:
	# --- Son de la mer : volume basé sur la distance à la falaise ---
	var player = get_tree().get_first_node_in_group("player")
	if player and ocean_player:
		# La falaise est à Z=-75 (dans le repère monde, manoir à Z=-22 donc falaise à Z=-97)
		var dist_to_cliff = abs(player.global_position.z - (-75.0))
		# Volume : fort près de la falaise, faible loin
		var vol = lerp(-5.0, -25.0, clamp(dist_to_cliff / 120.0, 0.0, 1.0))
		ocean_player.volume_db = vol
	
	# --- Son de pas : rythmé ---
	if is_walking:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			_play_footstep()
			footstep_timer = 0.45 # ~0.45s entre chaque pas
	else:
		footstep_timer = 0.0

func start_walking() -> void:
	is_walking = true

func stop_walking() -> void:
	is_walking = false

# --- GÉNÉRATION PROCÉDURALE : Bruit de mer ---
func _setup_ocean_sound() -> void:
	var sample_rate = 22050
	var duration = 4.0 # 4 secondes en boucle
	var num_samples = int(sample_rate * duration)
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	
	var data = PackedByteArray()
	data.resize(num_samples * 2) # 16 bits = 2 bytes per sample
	
	# Bruit blanc filtré passe-bas (simulation vagues)
	var prev_sample: float = 0.0
	var alpha: float = 0.08 # Filtre passe-bas agressif (son grave, sourd)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		# Bruit blanc
		var white = randf_range(-1.0, 1.0)
		# Filtre passe-bas (lissage exponentiel)
		prev_sample = prev_sample * (1.0 - alpha) + white * alpha
		# Modulation d'amplitude lente (vagues qui montent et descendent)
		var wave_envelope = 0.4 + 0.6 * abs(sin(t * PI / 2.5))
		var sample_val = prev_sample * wave_envelope * 0.5
		# Clamp et conversion 16 bits
		sample_val = clamp(sample_val, -1.0, 1.0)
		var int_val = int(sample_val * 32767.0)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
	
	stream.data = data
	
	ocean_player = AudioStreamPlayer.new()
	ocean_player.stream = stream
	ocean_player.volume_db = -15.0
	ocean_player.bus = "Master"
	add_child(ocean_player)
	ocean_player.play()

# --- GÉNÉRATION PROCÉDURALE : Son de pas ---
func _setup_footstep_sound() -> void:
	footstep_player = AudioStreamPlayer.new()
	footstep_player.volume_db = -8.0
	footstep_player.bus = "Master"
	add_child(footstep_player)

func _play_footstep() -> void:
	var sample_rate = 22050
	var duration = 0.12 # Très court (impact)
	var num_samples = int(sample_rate * duration)
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	
	var prev: float = 0.0
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		# Impulsion bruitée qui décroît rapidement (impact pierre)
		var envelope = exp(-t * 40.0) # Décroissance très rapide
		var noise_val = randf_range(-1.0, 1.0)
		# Filtre passe-bas léger
		prev = prev * 0.6 + noise_val * 0.4
		var sample_val = prev * envelope * 0.7
		# Légère variation de pitch aléatoire
		sample_val += sin(t * (800.0 + randf_range(-100, 100))) * envelope * 0.15
		sample_val = clamp(sample_val, -1.0, 1.0)
		var int_val = int(sample_val * 32767.0)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
	
	stream.data = data
	footstep_player.stream = stream
	footstep_player.play()
