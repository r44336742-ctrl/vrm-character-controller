extends CharacterBody3D

@export var move_speed: float = 3.5
@export var sprint_speed: float = 7.0
@export var rotation_speed: float = 8.0
@export var acceleration: float = 4.0
@export var friction: float = 12.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var model_pivot: Node3D = $ModelPivot

var anim_player: AnimationPlayer = null
var character_model: Node = null

# Références pour la physique custom des cheveux
var _hair_skeleton: Skeleton3D = null
var _hair_bone_indices: Array[int] = []
var _hair_bone_tails: Array[Vector3] = []  # position tail courante (world space)
var _hair_bone_prev_tails: Array[Vector3] = []  # position tail precedente
var _hair_initialized: bool = false
const HAIR_STIFFNESS: float = 0.08
const HAIR_DRAG: float = 0.10
const HAIR_GRAVITY: float = 1.5
const HAIR_LENGTH: float = 0.12  # Pendule plus court = déformation naturelle

func _ready() -> void:
    add_to_group("player") # Requis pour Atmosphere et Particules
    character_model = $ModelPivot.get_child(0)
    if character_model:
        character_model.rotation.y = PI
        
        anim_player = _find_anim_player(character_model)
        if not anim_player:
            anim_player = AnimationPlayer.new()
            character_model.add_child(anim_player)
        
        var skeletons = character_model.find_children("*", "Skeleton3D", true)
        var skeleton = skeletons[0] if skeletons.size() > 0 else null
        
        # Charger les 3 animations
        _load_mixamo_anim("res://assets/models/animations/idle.fbx", "idle", skeleton)
        _load_mixamo_anim("res://assets/models/animations/walk.fbx", "walk", skeleton)
        _load_mixamo_anim("res://assets/models/animations/run.fbx", "run", skeleton)

        _strip_root_motion("idle")
        _strip_root_motion("walk")
        _strip_root_motion("run")

        if skeleton:
            _init_hair_physics(skeleton)

    # Lancer l'animation Idle par défaut
    if anim_player and anim_player.has_animation("idle"):
        anim_player.play("idle")

func _physics_process(delta: float) -> void:
    if Input.is_action_just_pressed("quit"):
        get_tree().quit()
        return

    if is_on_floor():
        velocity.y = 0.0
    else:
        velocity.y -= gravity * delta

    var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

    var cam_basis = camera.global_transform.basis
    var forward: Vector3 = -cam_basis.z
    var right: Vector3 = cam_basis.x
    forward.y = 0.0
    right.y = 0.0
    forward = forward.normalized()
    right = right.normalized()

    var direction: Vector3 = (forward * -input_dir.y + right * input_dir.x).normalized()

    # --- LOGIQUE DE VITESSE ET ANIMATION ---
    var is_sprinting = Input.is_action_pressed("sprint") and direction != Vector3.ZERO
    var current_speed = sprint_speed if is_sprinting else move_speed
    
    var target_anim = "idle"
    if direction != Vector3.ZERO:
        target_anim = "run" if is_sprinting else "walk"
    
    # Changement d'animation avec crossfade
    if anim_player and anim_player.has_animation(target_anim):
        if anim_player.current_animation != target_anim:
            anim_player.play(target_anim, 0.2)

    if direction != Vector3.ZERO:
        velocity.x = lerp(velocity.x, direction.x * current_speed, acceleration * delta)
        velocity.z = lerp(velocity.z, direction.z * current_speed, acceleration * delta)
        
        var target_rotation: float = atan2(-direction.x, -direction.z)
        model_pivot.rotation.y = lerp_angle(model_pivot.rotation.y, target_rotation, delta * rotation_speed)
    else:
        velocity.x = lerp(velocity.x, 0.0, friction * delta)
        velocity.z = lerp(velocity.z, 0.0, friction * delta)

    move_and_slide()
    _update_hair_physics(delta)

func _init_hair_physics(skeleton: Skeleton3D) -> void:
    _hair_skeleton = skeleton
    _hair_bone_indices.clear()
    _hair_bone_tails.clear()
    _hair_bone_prev_tails.clear()
    for i in range(skeleton.get_bone_count()):
        var bname = skeleton.get_bone_name(i)
        if "Hair" in bname or "Skirt" in bname:
            _hair_bone_indices.append(i)
            # Calculer la direction de repos REELLE de l'os (depuis sa rest pose globale)
            var rest = _get_bone_global_rest(skeleton, i)
            var world_origin = skeleton.global_transform * rest.origin
            # La direction de repos = depuis l'os vers le bas naturel (sa rest direction)
            var rest_dir_local = skeleton.get_bone_rest(i).origin.normalized()
            if rest_dir_local.length() < 0.01:
                rest_dir_local = Vector3(0, -1, 0)
            var world_tail = world_origin + skeleton.global_transform.basis * (rest_dir_local * HAIR_LENGTH)
            _hair_bone_tails.append(world_tail)
            _hair_bone_prev_tails.append(world_tail)
    _hair_initialized = true
    print("[HairPhysics] Initialized with ", _hair_bone_indices.size(), " bones")

func _update_hair_physics(delta: float) -> void:
    if not _hair_initialized or _hair_skeleton == null:
        return
    var wind = WindSystem.get_wind_at(global_position)
    for idx in range(_hair_bone_indices.size()):
        var bone_idx = _hair_bone_indices[idx]
        var gp = _hair_skeleton.get_bone_global_pose(bone_idx)
        var bone_world = _hair_skeleton.global_transform * gp.origin
        # Verlet integration
        var cur = _hair_bone_tails[idx]
        var prv = _hair_bone_prev_tails[idx]
        var velocity = (cur - prv) * (1.0 - HAIR_DRAG)
        var gravity_force = Vector3(0, -HAIR_GRAVITY, 0) * delta * delta
        var wind_force = wind * delta * delta * 0.5
        # Direction de repos REELLE de cet os
        var rest_local = _hair_skeleton.get_bone_rest(bone_idx).origin.normalized()
        if rest_local.length() < 0.01:
            rest_local = Vector3(0, -1, 0)
        var rest_world_dir = _hair_skeleton.global_transform.basis * rest_local
        var rest_pos = bone_world + rest_world_dir * HAIR_LENGTH
        var stiffness_force = (rest_pos - cur) * HAIR_STIFFNESS
        var next = cur + velocity + gravity_force + wind_force + stiffness_force
        # Contrainte longueur fixe
        var dir = (next - bone_world).normalized()
        next = bone_world + dir * HAIR_LENGTH
        _hair_bone_prev_tails[idx] = cur
        _hair_bone_tails[idx] = next
        # Rotation: amener rest_local_dir vers la direction cible en local
        var local_next = _hair_skeleton.global_transform.affine_inverse() * next
        var local_bone = gp.origin
        var target_local_dir = (local_next - local_bone).normalized()
        # rest_local = direction de repos locale de l'os
        if rest_local.length() > 0.01 and target_local_dir.length() > 0.01:
            var rot = Quaternion(rest_local, target_local_dir)
            var new_pose = gp
            new_pose.basis = Basis(rot) * Basis(gp.basis.get_rotation_quaternion())
            _hair_skeleton.set_bone_global_pose_override(bone_idx, new_pose, 1.0, true)

func _get_bone_global_rest(skel: Skeleton3D, bone_idx: int) -> Transform3D:
    var result = skel.get_bone_rest(bone_idx)
    var parent_idx = skel.get_bone_parent(bone_idx)
    while parent_idx >= 0:
        result = skel.get_bone_rest(parent_idx) * result
        parent_idx = skel.get_bone_parent(parent_idx)
    return result

# --- FONCTIONS DE RETARGETING (Robustesse Absolue) ---

func _strip_root_motion(anim_name: String) -> void:
    if not anim_player: return
    var lib = anim_player.get_animation_library("")
    if not lib or not lib.has_animation(anim_name): return
    
    var anim: Animation = lib.get_animation(anim_name)
    for i in range(anim.get_track_count()):
        if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
            var path_str = str(anim.track_get_path(i)).to_lower()
            if "hips" in path_str or "root" in path_str or "mixamorig" in path_str:
                var key_count = anim.track_get_key_count(i)
                if key_count > 0:
                    var first_pos: Vector3 = anim.track_get_key_value(i, 0)
                    for k in range(key_count):
                        var pos: Vector3 = anim.track_get_key_value(i, k)
                        var fixed_pos = Vector3(first_pos.x, pos.y, first_pos.z)
                        anim.track_set_key_value(i, k, fixed_pos)

func _load_mixamo_anim(fbx_path: String, target_anim_name: String, skeleton: Skeleton3D) -> void:
    if not ResourceLoader.exists(fbx_path): 
        print("Animation non trouvée: ", fbx_path)
        return
    var packed = load(fbx_path) as PackedScene
    if not packed: return
    
    var instance = packed.instantiate()
    var ap = _find_anim_player(instance)
    
    var bone_map = {
        "Hips": "Hips", "Spine": "Spine", "Spine1": "Chest", "Spine2": "UpperChest",
        "Neck": "Neck", "Head": "Head", "LeftShoulder": "LeftShoulder",
        "LeftArm": "LeftUpperArm", "LeftForeArm": "LeftLowerArm", "LeftHand": "LeftHand",
        "RightShoulder": "RightShoulder", "RightArm": "RightUpperArm",
        "RightForeArm": "RightLowerArm", "RightHand": "RightHand",
        "LeftUpLeg": "LeftUpperLeg", "LeftLeg": "LeftLowerLeg", "LeftFoot": "LeftFoot",
        "LeftToeBase": "LeftToes", "RightUpLeg": "RightUpperLeg", "RightLeg": "RightLowerLeg",
        "RightFoot": "RightFoot", "RightToeBase": "RightToes"
    }
    
    if ap and anim_player:
        anim_player.root_node = anim_player.get_path_to(character_model)
        
        var lib = anim_player.get_animation_library("")
        if not lib:
            lib = AnimationLibrary.new()
            anim_player.add_animation_library("", lib)
            
        var anim_list = ap.get_animation_list()
        for a_name in anim_list:
            if a_name == "RESET": continue
            var anim = ap.get_animation(a_name).duplicate()
            anim.loop_mode = Animation.LOOP_LINEAR # Fix Godot 4
            
            var root_node_ref = anim_player.get_node(anim_player.root_node)
            if not root_node_ref or not skeleton:
                instance.queue_free()
                return
                
            var skel_relative_path = root_node_ref.get_path_to(skeleton)
            
            for i in range(anim.get_track_count() - 1, -1, -1):
                var type = anim.track_get_type(i)
                
                # Garder UNIQUEMENT la piste de position des Hanches (Hips) pour conserver la posture,
                # mais l'ajuster à la hauteur des jambes du modèle VRM pour l'empêcher de s'enfoncer !
                if type == Animation.TYPE_POSITION_3D:
                    var path = anim.track_get_path(i)
                    var bone_name = path.get_concatenated_subnames().replace("mixamorig:", "").replace("mixamorig_", "")
                    
                    if bone_name == "Hips":
                        var hips_idx = skeleton.find_bone("Hips")
                        if hips_idx != -1:
                            var vrm_height = skeleton.get_bone_rest(hips_idx).origin.y
                            var mixamo_height = anim.track_get_key_value(i, 0).y
                            var diff = vrm_height - mixamo_height
                            
                            for k in range(anim.track_get_key_count(i)):
                                var pos = anim.track_get_key_value(i, k)
                                pos.y += diff # Ajuste la hauteur
                                anim.track_set_key_value(i, k, pos)
                                
                            var new_path = NodePath(str(skel_relative_path) + ":Hips")
                            anim.track_set_path(i, new_path)
                    else:
                        anim.remove_track(i)
                    continue
                    
                if type == Animation.TYPE_ROTATION_3D or type == Animation.TYPE_SCALE_3D:
                    var path = anim.track_get_path(i)
                    var bone_name = path.get_concatenated_subnames().replace("mixamorig:", "").replace("mixamorig_", "")
                    
                    var vrm_bone = ""
                    if bone_map.has(bone_name):
                        vrm_bone = bone_map[bone_name]
                    elif skeleton.find_bone(bone_name) != -1:
                        vrm_bone = bone_name
                    
                    if vrm_bone != "":
                        var vrm_idx = skeleton.find_bone(vrm_bone)
                        
                        # Fix posture only for the spine/head. Limbs use raw rotations because their axes differ.
                        var is_spine = vrm_bone in ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]
                        
                        if type == Animation.TYPE_ROTATION_3D and vrm_idx != -1 and is_spine:
                            # Rechercher l'os Mixamo dans le fichier FBX pour calculer le delta
                            var mixamo_skel = instance.find_children("*", "Skeleton3D", true)[0]
                            var mix_idx = mixamo_skel.find_bone(path.get_concatenated_subnames())
                            if mix_idx == -1:
                                mix_idx = mixamo_skel.find_bone("mixamorig:" + bone_name)
                                
                            if mix_idx != -1:
                                var rest_m = mixamo_skel.get_bone_rest(mix_idx).basis.get_rotation_quaternion()
                                var rest_v = skeleton.get_bone_rest(vrm_idx).basis.get_rotation_quaternion()
                                
                                for k in range(anim.track_get_key_count(i)):
                                    var r_anim = anim.track_get_key_value(i, k)
                                    # Calcul de la rotation relative (Delta) par rapport à la pose de base Mixamo
                                    var delta = rest_m.inverse() * r_anim
                                    # Application du Delta sur la pose de base VRM
                                    var r_vrm = rest_v * delta
                                    anim.track_set_key_value(i, k, r_vrm)
                        
                        var new_path = NodePath(str(skel_relative_path) + ":" + vrm_bone)
                        anim.track_set_path(i, new_path)
                    else:
                        anim.remove_track(i)
            
            if not lib.has_animation(target_anim_name):
                lib.add_animation(target_anim_name, anim)
            break
            
    instance.queue_free()

func _find_anim_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer: return node
    for child in node.get_children():
        var res = _find_anim_player(child)
        if res: return res
    return null


