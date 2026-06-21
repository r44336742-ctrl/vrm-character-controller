extends Node

# --- SYSTÈME DE VENT GLOBAL ---
var base_wind_vector: Vector3 = Vector3(1, 0, 0.3) * 2.0
var wind_vector: Vector3 = Vector3.ZERO
var current_gust_multiplier: float = 1.0

var noise: FastNoiseLite
var time: float = 0.0
var gust_timer: Timer

func _ready() -> void:
    noise = FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_PERLIN
    noise.frequency = 0.05
    
    gust_timer = Timer.new()
    gust_timer.wait_time = randf_range(4.0, 8.0)
    gust_timer.one_shot = true
    gust_timer.timeout.connect(_on_gust_timer_timeout)
    add_child(gust_timer)
    gust_timer.start()

func _on_gust_timer_timeout() -> void:
    var gust_strength = randf_range(3.0, 5.0)
    var tween = create_tween()
    tween.tween_property(self, "current_gust_multiplier", gust_strength, 0.5).set_trans(Tween.TRANS_SINE)
    tween.tween_interval(1.5)
    tween.tween_property(self, "current_gust_multiplier", 1.0, 1.5)
    
    gust_timer.wait_time = randf_range(4.0, 8.0)
    gust_timer.start()

func _process(delta: float) -> void:
    time += delta
    # Turbulence procédurale
    var turbulence = Vector3(
        noise.get_noise_2d(time, 0.0),
        noise.get_noise_2d(time, 100.0) * 0.2,
        noise.get_noise_2d(time, 200.0)
    ) * 1.5
    
    wind_vector = (base_wind_vector + turbulence) * current_gust_multiplier

func get_wind_at(position: Vector3) -> Vector3:
    # Ajoute une variance spatiale pour que le vent ne soit pas uniforme
    var spatial_noise = Vector3(
        noise.get_noise_3d(position.x, position.y, position.z),
        noise.get_noise_3d(position.x + 10, position.y, position.z) * 0.2,
        noise.get_noise_3d(position.x, position.y, position.z + 10)
    ) * 0.5
    return wind_vector + spatial_noise
