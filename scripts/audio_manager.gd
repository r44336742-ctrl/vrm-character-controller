extends Node

# --- AUDIO MANAGER ---
var ocean_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer
var footstep_timer: float = 0.0
var step_interval: float = 0.45
var is_walking: bool = false

var footstep_samples: PackedFloat32Array
var footstep_playback_pos: int = -1

var ocean_prev: float = 0.0
var ocean_time: float = 0.0

func _ready() -> void:
	add_to_group("audio_manager")
	_setup_ocean()
	_setup_footstep()
	print("[AudioManager] Initialized OK")

func _process(delta: float) -> void:
	# Volume mer
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and ocean_player:
		var dist = abs(player_node.global_position.z + 75.0)
		var t = clamp(dist / 50.0, 0.0, 1.0)
		ocean_player.volume_db = lerp(-8.0, -60.0, t * t)
	
	# Timer pas
	if is_walking:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_playback_pos = 0
			footstep_timer = step_interval
	else:
		footstep_timer = 0.0

func _physics_process(_delta: float) -> void:
	_fill_ocean()
	_fill_footstep()

func start_walking() -> void:
	is_walking = true

func stop_walking() -> void:
	is_walking = false

func set_step_interval(i: float) -> void:
	step_interval = i

# --- OCÉAN ---
func _setup_ocean() -> void:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	ocean_player = AudioStreamPlayer.new()
	ocean_player.stream = gen
	ocean_player.volume_db = -20.0
	add_child(ocean_player)
	ocean_player.play()

func _fill_ocean() -> void:
	if not ocean_player or not ocean_player.playing:
		return
	var pb = ocean_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not pb:
		return
	var n = pb.get_frames_available()
	ocean_time += float(n) / 22050.0
	for _i in range(n):
		var white = randf_range(-1.0, 1.0)
		ocean_prev = ocean_prev * 0.96 + white * 0.04
		var env = 0.3 + 0.7 * abs(sin(ocean_time * PI / 3.0))
		pb.push_frame(Vector2(ocean_prev * env * 0.3, ocean_prev * env * 0.3))

# --- PAS ---
func _setup_footstep() -> void:
	# Génère 0.12s d'impact sur pierre
	var sr = 22050
	var n = int(sr * 0.12)
	footstep_samples.resize(n)
	var prev: float = 0.0
	for i in range(n):
		var t = float(i) / sr
		var env = exp(-t * 45.0)
		prev = prev * 0.4 + randf_range(-1.0, 1.0) * 0.6
		footstep_samples[i] = clampf(prev * env * 0.7 + sin(t * 500.0) * env * 0.3, -1.0, 1.0)
	
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = float(sr)
	gen.buffer_length = 0.3
	footstep_player = AudioStreamPlayer.new()
	footstep_player.stream = gen
	footstep_player.volume_db = 2.0  # Fort et audible
	add_child(footstep_player)
	footstep_player.play()
	print("[AudioManager] Footstep ready, samples=", n)

func _fill_footstep() -> void:
	if not footstep_player or not footstep_player.playing:
		return
	var pb = footstep_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not pb:
		return
	var avail = pb.get_frames_available()
	
	if footstep_playback_pos >= 0:
		# Jouer les samples du pas
		var remaining = footstep_samples.size() - footstep_playback_pos
		var to_push = mini(avail, remaining)
		for i in range(to_push):
			var s = footstep_samples[footstep_playback_pos]
			pb.push_frame(Vector2(s, s))
			footstep_playback_pos += 1
		if footstep_playback_pos >= footstep_samples.size():
			footstep_playback_pos = -1
		# Silence pour le reste de l'espace disponible
		var pushed = to_push
		for _i in range(avail - pushed):
			pb.push_frame(Vector2.ZERO)
	else:
		# Silence continu (garde le générateur en vie)
		for _i in range(avail):
			pb.push_frame(Vector2.ZERO)
