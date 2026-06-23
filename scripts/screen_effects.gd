extends Node

func _ready() -> void:
	# CanvasLayer au-dessus de tout (layer 100)
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	# ColorRect plein écran
	var rect = ColorRect.new()
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE # Ne bloque pas les clics
	
	var mat = ShaderMaterial.new()
	var shader = load("res://shaders/screen_effects.gdshader")
	if shader:
		mat.shader = shader
		mat.set_shader_parameter("grain_intensity", 0.04)
		mat.set_shader_parameter("vignette_inner_radius", 28.0)
		mat.set_shader_parameter("vignette_outer_radius", 100.0)
		mat.set_shader_parameter("vignette_intensity", 1.0)
	
	rect.material = mat
	rect.color = Color(1, 1, 1, 1) # Blanc = neutre (le shader fait le travail)
	canvas.add_child(rect)
