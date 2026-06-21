extends SceneTree
func _init():
    var cfg = ConfigFile.new()
    var err = cfg.load("res://project.godot")
    if err == OK:
        cfg.set_value("autoload", "WindSystem", "*res://scripts/wind_system.gd")
        cfg.save("res://project.godot")
    
    var p = load("res://scenes/main.tscn")
    var scene = p.instantiate()
    
    var env_node = scene.get_node_or_null("WorldEnvironment")
    if env_node:
        scene.remove_child(env_node)
        env_node.free()
        
    var moon_node = scene.get_node_or_null("MoonLight")
    if moon_node:
        scene.remove_child(moon_node)
        moon_node.free()

    var atm = Node3D.new()
    atm.name = "AtmosphereController"
    atm.set_script(load("res://scripts/atmosphere_controller.gd"))
    scene.add_child(atm)
    atm.owner = scene

    var ash = GPUParticles3D.new()
    ash.name = "AshParticles"
    ash.set_script(load("res://scripts/ash_particles.gd"))
    scene.add_child(ash)
    ash.owner = scene

    var p2 = PackedScene.new()
    p2.pack(scene)
    ResourceSaver.save(p2, "res://scenes/main.tscn")
    
    print("GLM integration applied successfully!")
    quit()
