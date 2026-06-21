extends SceneTree

func _init():
    print("Initializing test render...")
    
    # Create rendering server
    var root = get_root()
    
    var scene = load("res://scenes/character.tscn")
    var inst = scene.instantiate()
    root.add_child(inst)
    
    var cam = Camera3D.new()
    root.add_child(cam)
    cam.global_transform.origin = Vector3(0, 1.5, 3)
    cam.look_at(Vector3(0, 1, 0))
    cam.current = true
    
    var light = DirectionalLight3D.new()
    root.add_child(light)
    light.rotation_degrees = Vector3(-45, 45, 0)
    
    # Let Godot process a few frames
    for i in range(5):
        await self.process_frame
    
    var img = get_root().get_viewport().get_texture().get_image()
    img.save_png("res://test_render.png")
    print("Saved test_render.png")
    quit()
