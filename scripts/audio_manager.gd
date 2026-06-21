extends Node

# --- AUDIO MANAGER : Mer + Pas ---
var ocean_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer
var footstep_timer: float = 0.0
var step_interval: float = 0.45
var is_walking: bool = false
var footstep_stream: AudioStreamWAV  # Pré-généré une seule fois

func _ready() -> void:
	_setup_ocean_sound()
	_setup_footstep_sound()

func _process(delta: float) -> void:
	# --- Son de la mer ---
	var player = get_tree().get_first_node_in_group("player")
	if player and ocean_player:
		var dist_to_cliff = abs(player.global_position.z - (-75.0))
		var normalized = clamp(dist_to_cliff / 50.0, 0.0, 1.0)
		var vol = lerp(float(-8.0), float(-60.0), normalized * normalized)
		ocean_player.volume_db = vol
	
	# --- Son de pas ---
	if is_walking:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			_play_footstep()
			footstep_timer = step_interval
	else:
		footstep_timer = 0.0

func start_walking() -> void:
	is_walking = true

func stop_walking() -> void:
	is_walking = false

func set_step_interval(interval: float) -> void:
	step_interval = interval

# --- OCÉAN ---
func _setup_ocean_sound() -> void:
	var sample_rate = 22050
	var duration = 6.0
	var num_samples = int(sample_rate * duration)
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	
	var prev1: float = 0.0
	var prev2: float = 0.0
	var alpha: float = 0.04
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var white = randf_range(-1.0, 1.0)
		prev1 = prev1 * (1.0 - alpha) + white * alpha
		prev2 = prev2 * (1.0 - alpha * 0.7) + prev1 * (alpha * 0.7)
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

# --- PAS : Pré-génère le son une seule fois ---
func _setup_footstep_sound() -> void:
	var sample_rate = 22050
	var duration = 0.1
	var num_samples = int(sample_rate * duration)
	
	footstep_stream = AudioStreamWAV.new()
	footstep_stream.format = AudioStreamWAV.FORMAT_16_BITS
	footstep_stream.mix_rate = sample_rate
	footstep_stream.stereo = false
	
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	
	var prev: float = 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 50.0)
		var noise_val = randf_range(-1.0, 1.0)
		prev = prev * 0.5 + noise_val * 0.5
		var sample_val = prev * envelope * 0.6
		# Tonalité basse pour l'impact pierre
		sample_val += sin(t * 600.0) * envelope * 0.2
		sample_val = clamp(sample_val, -1.0, 1.0)
		var int_val = int(sample_val * 32767.0)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
	
	footstep_stream.data = data
	
	footstep_player = AudioStreamPlayer.new()
	footstep_player.volume_db = -6.0
	footstep_player.bus = "Master"
	add_child(footstep_player)

func _play_footstep() -> void:
	footstep_player.stream = footstep_stream
	footstep_player.play()
