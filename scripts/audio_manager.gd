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
		var dist_to_cliff = abs(player.global_position.z - (-75.0))
		# Coupure agressive : inaudible au-delà de 50m, fort uniquement très près
		var normalized = clamp(dist_to_cliff / 50.0, 0.0, 1.0)
		# Courbe quadratique : chute très rapide
		var vol = lerp(float(-8.0), float(-60.0), normalized * normalized)
		ocean_player.volume_db = vol
	
	# --- Son de pas : rythmé ---
	if is_walking:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			_play_footstep()
			footstep_timer = 0.45
	else:
		footstep_timer = 0.0

func start_walking() -> void:
	is_walking = true

func stop_walking() -> void:
	is_walking = false

# --- GÉNÉRATION PROCÉDURALE : Bruit de mer ---
func _setup_ocean_sound() -> void:
	var sample_rate = 22050
	var duration = 6.0 # Plus long pour moins de répétition
	var num_samples = int(sample_rate * duration)
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	
	# Double filtre passe-bas pour un son plus doux et profond
	var prev1: float = 0.0
	var prev2: float = 0.0
	var alpha: float = 0.04 # Filtre très agressif (grave pur)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var white = randf_range(-1.0, 1.0)
		# Double filtre passe-bas en cascade (son beaucoup plus doux)
		prev1 = prev1 * (1.0 - alpha) + white * alpha
		prev2 = prev2 * (1.0 - alpha * 0.7) + prev1 * (alpha * 0.7)
		# Enveloppe de vague lente et douce
		var wave_env = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * PI / 3.5))
		var sample_val = prev2 * wave_env * 0.35
		sample_val = clamp(sample_val, -1.0, 1.0)
		var int_val = int(sample_val * 32767.0)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
	
	stream.data = data
	
	ocean_player = AudioStreamPlayer.new()
	ocean_player.stream = stream
	ocean_player.volume_db = -20.0
	ocean_player.bus = "Master"
	add_child(ocean_player)
	ocean_player.play()

# --- GÉNÉRATION PROCÉDURALE : Son de pas ---
func _setup_footstep_sound() -> void:
	footstep_player = AudioStreamPlayer.new()
	footstep_player.volume_db = -10.0
	footstep_player.bus = "Master"
	add_child(footstep_player)

func _play_footstep() -> void:
	var sample_rate = 22050
	var duration = 0.08 # Encore plus court (claquement sec)
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
		# Impact sec qui décroît immédiatement
		var envelope = exp(-t * 60.0)
		var noise_val = randf_range(-1.0, 1.0)
		# Filtre passe-bas fort (son mat, pas de grésillement)
		prev = prev * 0.5 + noise_val * 0.5
		var sample_val = prev * envelope * 0.5
		sample_val = clamp(sample_val, -1.0, 1.0)
		var int_val = int(sample_val * 32767.0)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
	
	stream.data = data
	footstep_player.stream = stream
	footstep_player.play()
