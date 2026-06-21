extends Node3D

@export var bat_texture: Texture2D
var spawn_timer: Timer

func _ready() -> void:
    spawn_timer = Timer.new()
    spawn_timer.wait_time = randf_range(10.0, 20.0)
    spawn_timer.one_shot = true
    spawn_timer.timeout.connect(_spawn_bat)
    add_child(spawn_timer)
    spawn_timer.start()

func _spawn_bat() -> void:
    var bat = Sprite3D.new()
    # Utilise l'icône par défaut si pas de texture (placeholder)
    bat.texture = bat_texture if bat_texture else load("res://icon.svg") 
    bat.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    
    # Matériau simple et sombre
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(0, 0, 0)
    bat.material_override = mat
    
    # Positionner loin, près de la lune
    bat.global_position = global_position + Vector3(randf_range(-50, 50), randf_range(10, 30), -80)
    bat.scale = Vector3(0.5, 0.5, 0.5)
    add_child(bat)
    
    # Animer la traversée
    var tween = create_tween().set_loops()
    # Faire battre des ailes (scale Y)
    tween.tween_property(bat, "scale:y", 0.3, 0.1).set_trans(Tween.TRANS_SINE)
    tween.tween_property(bat, "scale:y", 0.5, 0.1).set_trans(Tween.TRANS_SINE)
    
    # Déplacer et détruire
    var move_tween = create_tween()
    move_tween.tween_property(bat, "global_position:x", bat.global_position.x + 100, 5.0)
    move_tween.tween_callback(bat.queue_free)
    
    spawn_timer.wait_time = randf_range(8.0, 15.0)
    spawn_timer.start()
