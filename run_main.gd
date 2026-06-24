extends SceneTree
func _init():
	var scene = load("res://scenes/main.tscn")
	var inst = scene.instantiate()
	get_root().add_child(inst)
	
	var debug_script = load("res://scripts/debug_pose_override.gd")
	var debug_node = Node.new()
	debug_node.set_script(debug_script)
	inst.add_child(debug_node)
	
	# Laisser tourner un peu plus pour laisser le temps au script de s'exécuter
	for i in range(20):
		await self.process_frame
	quit()
