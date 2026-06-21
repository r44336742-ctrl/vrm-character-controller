extends Node3D

@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -0.6
@export var max_pitch: float = 0.9

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var character: CollisionObject3D = get_parent()

var yaw: float = 0.0
var pitch: float = 0.15

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    
    # Exclut la capsule du joueur pour que le bras ne percute pas le personnage
    spring_arm.add_excluded_object(character.get_rid())

func _unhandled_input(event: InputEvent) -> void:
    if Input.is_action_just_pressed("quit"):
        get_tree().quit()
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * mouse_sensitivity
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity, min_pitch, max_pitch)

func _process(_delta: float) -> void:
    rotation.y = yaw
    spring_arm.rotation.x = pitch
