extends SceneTree
func _init():
	var scene = load("res://scenes/main.tscn")
	var packed = scene.instantiate()
	
	# Find the CharacterBody3D (VRoid character)
	var character = null
	var queue = [packed]
	while queue.size() > 0:
		var node = queue.pop_front()
		if node is CharacterBody3D:
			character = node
			break
		for child in node.get_children():
			queue.push_back(child)
	
	if character == null:
		print("ERROR: CharacterBody3D not found")
		quit()
		return
	
	print("Found character: ", character.name)
	
	# Check if HairWeightPainter already exists
	var existing = character.find_children("HairWeightPainter", "", false)
	if existing.size() > 0:
		print("HairWeightPainter already exists, skipping")
	else:
		# Add the HairWeightPainter node
		var painter = Node.new()
		painter.name = "HairWeightPainter"
		painter.set_script(load("res://scripts/hair_weight_painter.gd"))
		character.add_child(painter, true)
		painter.owner = packed
		print("Added HairWeightPainter to ", character.name)
	
	# Save the scene
	var ps = PackedScene.new()
	ps.pack(packed)
	ResourceSaver.save(ps, "res://scenes/main.tscn")
	print("Scene saved!")
	quit()
