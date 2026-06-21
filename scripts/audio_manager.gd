extends Node

# --- AUDIO MANAGER : Mer + Pas ---
var ocean_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer
var footstep_timer: float = 0.0
var step_interval: float = 0.45
var is_walking: bool = false

# Footstep buffer pré-calculé (Array de floats)
var footstep_samples: PackedFloat32Array

func _ready() -> void:
	add_to_group("audio_manager")
	call_deferred("_deferred_setup")

func _deferred_setup() -> void:
	_setup_ocean_sound()
	_setup_footstep_sound()
	print("[AudioManager] Setup complete")

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

# --- OCÉAN : AudioStreamGenerator pour du bruit continu ---
func _setup_ocean_sound() -> void:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	
	ocean_player = AudioStreamPlayer.new()
	ocean_player.stream = gen
	ocean_player.volume_db = -20.0
	ocean_player.bus = "Master"
	add_child(ocean_player)
	ocean_player.play()
	
	# Remplir en continu via _process_ocean
	set_process(true)

var ocean_phase1: float = 0.0
var ocean_phase2: float = 0.0
var ocean_prev: float = 0.0

func _fill_ocean_buffer() -> void:
	if not ocean_player or not ocean_player.playing:
		return
	var playback = ocean_player.get_stream_playback()
	if not playback:
		return
	
	var to_fill = playback.get_frames_available()
	for i in range(to_fill):
		# Bruit blanc filtré passe-bas (vagues)
		var white = randf_range(-1.0, 1.0)
		ocean_prev = ocean_prev * 0.96 + white * 0.04
		
		# Modulation de volume lente (vagues)
		ocean_phase1 += 1.0 / 22050.0
		var env = 0.3 + 0.7 * (0.5 + 0.5 * sin(ocean_phase1 * PI / 3.0))
		
		var sample = ocean_prev * env * 0.3
		playback.push_frame(Vector2(sample, sample))

func _physics_process(_delta: float) -> void:
	_fill_ocean_buffer()
	_push_footstep_samples()

# --- PAS : Pré-générer les samples ---
func _setup_footstep_sound() -> void:
	var sample_rate = 22050
	var duration = 0.12
	var num_samples = int(sample_rate * duration)
	
	footstep_samples = PackedFloat32Array()
	footstep_samples.resize(num_samples)
	
	var prev: float = 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 45.0)
		var noise_val = randf_range(-1.0, 1.0)
		prev = prev * 0.4 + noise_val * 0.6
		var sample_val = prev * envelope * 0.7
		sample_val += sin(t * 500.0) * envelope * 0.3
		footstep_samples[i] = clampf(sample_val, -1.0, 1.0)
	
	# Créer le player avec un AudioStreamGenerator aussi
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	
	footstep_player = AudioStreamPlayer.new()
	footstep_player.stream = gen
	footstep_player.volume_db = 0.0  # Volume max
	footstep_player.bus = "Master"
	add_child(footstep_player)
	footstep_player.play()
	print("[AudioManager] Footstep ready, samples: ", num_samples)

var footstep_playback_pos: int = -1

func _play_footstep() -> void:
	footstep_playback_pos = 0 # Déclenche la lecture

func _push_footstep_samples() -> void:
	if footstep_playback_pos < 0 or not footstep_player or not footstep_player.playing:
		return
	var playback = footstep_player.get_stream_playback()
	if not playback:
		return
	
	var available = playback.get_frames_available()
	var remaining = footstep_samples.size() - footstep_playback_pos
	var to_push = mini(available, remaining)
	
	for i in range(to_push):
		var s = footstep_samples[footstep_playback_pos]
		playback.push_frame(Vector2(s, s))
		footstep_playback_pos += 1
	
	if footstep_playback_pos >= footstep_samples.size():
		# Remplir le reste avec du silence
		for i in range(available - to_push):
			playback.push_frame(Vector2.ZERO)
		footstep_playback_pos = -1
