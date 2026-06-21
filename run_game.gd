extends SceneTree

func _init():
    print("--- RUNNING GAME TEST ---")
    var scene = load("res://scenes/character.tscn")
    var inst = scene.instantiate()
    get_root().add_child(inst)
    
    for i in range(10):
        await self.process_frame
        
    print("--- GAME TEST FINISHED ---")
    quit()
