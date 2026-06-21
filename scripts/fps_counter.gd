extends Label

var timer: float = 0.0

func _process(delta: float) -> void:
    timer += delta
    if timer >= 1.0:
        timer = 0.0
        text = "FPS: %d" % Engine.get_frames_per_second()
