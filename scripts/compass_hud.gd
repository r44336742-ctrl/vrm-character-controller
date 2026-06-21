extends Label

# --- BOUSSOLE HUD 360° ---

func _ready() -> void:
	# Positionnement en haut-centre
	anchors_preset = 5 # CENTER_TOP
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	offset_left = -120.0
	offset_right = 120.0
	offset_top = 8.0
	offset_bottom = 40.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Style
	add_theme_color_override("font_color", Color(0.7, 0.8, 1.0, 0.8))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_theme_constant_override("outline_size", 3)
	add_theme_font_size_override("font_size", 18)

func _process(_delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	# Récupérer la rotation Y de la caméra (yaw)
	var yaw_rad = camera.global_rotation.y
	var yaw_deg = rad_to_deg(yaw_rad)
	# Normaliser à 0-360 (0=Sud, 90=Ouest, 180=Nord, 270=Est dans Godot)
	# On veut : 0=Nord, 90=Est, 180=Sud, 270=Ouest
	var compass_deg = fmod(180.0 - yaw_deg, 360.0)
	if compass_deg < 0:
		compass_deg += 360.0
	
	var cardinal = _get_cardinal(compass_deg)
	var left_card = _get_cardinal(fmod(compass_deg - 45.0 + 360.0, 360.0))
	var right_card = _get_cardinal(fmod(compass_deg + 45.0, 360.0))
	
	text = "%s  ←  %s %d°  →  %s" % [left_card, cardinal, int(compass_deg), right_card]

func _get_cardinal(deg: float) -> String:
	# 8 directions
	if deg >= 337.5 or deg < 22.5:
		return "N"
	elif deg < 67.5:
		return "NE"
	elif deg < 112.5:
		return "E"
	elif deg < 157.5:
		return "SE"
	elif deg < 202.5:
		return "S"
	elif deg < 247.5:
		return "SW"
	elif deg < 292.5:
		return "W"
	else:
		return "NW"
