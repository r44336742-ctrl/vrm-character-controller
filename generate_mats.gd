extends SceneTree

func _init():
	var tex_map = {
		"Body": "T_P003_E001_Body_CS01_C_1.png",
		"Face": "T_P003_E001_Face_CS01_C_3.png",
		"Hair": "T_P003_E001_Hair_CS01_C_2.png",
		"Iris": "T_P003_E001_Iris_CS01_C_4.png",
		"Wear": "T_P003_E001_Wear_CS01_C_0.png"
	}
	
	var base_path = "res://assets/textures/nami/"
	for mat_name in tex_map.keys():
		var mat = StandardMaterial3D.new()
		
		var tex = load("res://assets/textures/nami/" + tex_map[mat_name])
		if tex:
			mat.albedo_texture = tex
		else:
			print("Error loading image: ", tex_map[mat_name])

		mat.roughness = 1.0
		mat.metallic = 0.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		
		if mat_name == "Hair" or mat_name == "Face":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.5
		else:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			
		ResourceSaver.save(mat, base_path + "mat_" + mat_name + ".tres")
		
	print("MATERIALS GENERATED!")
	quit()
