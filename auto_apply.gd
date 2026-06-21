extends SceneTree

func _init():
	var scene_path = "res://scenes/character.tscn"
	var packed = load(scene_path)
	var root = packed.instantiate()
	
	var nami = root.get_node("ModelPivot/Nami")
	var skeleton = nami.get_node("Skeleton3D")
	
	if skeleton:
		var wear = load("res://assets/textures/nami/mat_Wear.tres")
		var body = load("res://assets/textures/nami/mat_Body.tres")
		var hair = load("res://assets/textures/nami/mat_Hair.tres")
		var face = load("res://assets/textures/nami/mat_Face.tres")
		var iris = load("res://assets/textures/nami/mat_Iris.tres")
		
		# Best guess mapping based on vertex counts
		# Object_0: 9792 -> Wear
		# Object_1: 4956 -> Face
		# Object_2: 9731 -> Hair
		# Object_3: 4885 -> Body
		# Object_4: 172 -> Iris
		# Object_5: 379 -> None
		
		var obj0 = skeleton.get_node("Object_0")
		if obj0: obj0.set_surface_override_material(0, wear)
		
		var obj1 = skeleton.get_node("Object_1")
		if obj1: obj1.set_surface_override_material(0, face)
		
		var obj2 = skeleton.get_node("Object_2")
		if obj2: obj2.set_surface_override_material(0, hair)
		
		var obj3 = skeleton.get_node("Object_3")
		if obj3: obj3.set_surface_override_material(0, body)
		
		var obj4 = skeleton.get_node("Object_4")
		if obj4: obj4.set_surface_override_material(0, iris)
		
	var new_packed = PackedScene.new()
	new_packed.pack(root)
	ResourceSaver.save(new_packed, scene_path)
	print("Auto-applied materials to character.tscn")
	quit()
