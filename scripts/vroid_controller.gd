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

# ============================================================
# PHYSIQUE DES CHEVEUX – Verlet Integration + Local Pose Override
# Architecture : chaque os de cheveux est un pendule dont :
#   - La RACINE suit l'os parent animé (Head)
#   - La POINTE est simulée en verlet (gravité + vent + stiffness)
#   - La ROTATION en local-space du parent est recalculée chaque frame
# ============================================================
var _hair_skeleton: Skeleton3D = null

# Par os simulé :
var _hair_bone_indices:    Array[int]     = []  # indice os dans le squelette
var _hair_parent_indices:  Array[int]     = []  # indice de l'os parent
var _hair_rest_origins:    Array[Vector3] = []  # position rest en local du parent
var _hair_rest_dirs:       Array[Vector3] = []  # direction normalisée rest en local du parent
var _hair_bone_lengths:    Array[float]   = []  # longueur physique du brin (m)
var _hair_tail_cur:        Array[Vector3] = []  # position pointe courante (world)
var _hair_tail_prv:        Array[Vector3] = []  # position pointe précédente (world)
var _hair_initialized: bool = false
var _debug_frame: int = 0

# Constantes physiques
const H_DRAG:      float = 0.06   # Très faible = oscille longtemps
const H_STIFF:     float = 0.03   # Très souple = peu de rappel
const H_GRAVITY:   float = 3.0    # Gravité forte = mèches tombent
const H_WIND_MUL:  float = 5.0    # Vent très fort = mouvement visible
const H_INERTIA:   float = 0.25

func _init_hair_physics(skeleton: Skeleton3D) -> void:
    _hair_skeleton = skeleton
    _hair_bone_indices.clear(); _hair_parent_indices.clear()
    _hair_rest_origins.clear(); _hair_rest_dirs.clear()
    _hair_bone_lengths.clear(); _hair_tail_cur.clear(); _hair_tail_prv.clear()

    for i in range(skeleton.get_bone_count()):
        var bname = skeleton.get_bone_name(i)
        if not ("Hair" in bname or "Skirt" in bname):
            continue

        var parent_idx = skeleton.get_bone_parent(i)
        if parent_idx < 0:
            continue

        var rest_local = skeleton.get_bone_rest(i)           # Transform en local du parent
        var rest_origin = rest_local.origin                  # Position de l'os en local du parent
        var bone_len = rest_origin.length()                  # Longueur physique du brin
        if bone_len < 0.001:
            continue
        var rest_dir = rest_origin / bone_len                # Direction unitaire en local du parent

        _hair_bone_indices.append(i)
        _hair_parent_indices.append(parent_idx)
        _hair_rest_origins.append(rest_origin)
        _hair_rest_dirs.append(rest_dir)
        _hair_bone_lengths.append(bone_len)

        # Position initiale de la pointe = rest pose globale de l'os
        var parent_global_rest = _get_bone_global_rest(skeleton, parent_idx)
        var bone_global_rest = parent_global_rest * rest_local
        # Pointe = origine de l'os + direction vers l'enfant (ou rest_dir * length pour os terminal)
        var tail_skel = bone_global_rest.origin + bone_global_rest.basis * (rest_dir * bone_len)
        var tail_world = skeleton.global_transform * tail_skel
        _hair_tail_cur.append(tail_world)
        _hair_tail_prv.append(tail_world)

    _hair_initialized = true
    print("[HairPhysics] Ready: ", _hair_bone_indices.size(), " bones simulated")

func _update_hair_physics(delta: float) -> void:
    if not _hair_initialized or _hair_skeleton == null or delta <= 0.0:
        return

    var skel = _hair_skeleton
    var skel_xf = skel.global_transform
    var skel_xf_inv = skel_xf.affine_inverse()
    var wind_world = WindSystem.get_wind_at(global_position)
    var dt2 = delta * delta
    var t = Time.get_ticks_msec() * 0.001  # temps en secondes

    _debug_frame += 1
    var _diag_logged_this_frame = false

    for idx in range(_hair_bone_indices.size()):
        var bone_idx   = _hair_bone_indices[idx]
        var parent_idx = _hair_parent_indices[idx]
        var rest_dir   = _hair_rest_dirs[idx]
        var bname      = skel.get_bone_name(bone_idx)
        var is_hair    = "Hair" in bname

        var parent_gp = skel.get_bone_global_pose(parent_idx)
        var gp        = skel.get_bone_global_pose(bone_idx)
        var rest_dir_skel = (parent_gp.basis * rest_dir).normalized()

        # DIAGNOSTIC: pour le 1er os Hair, log toutes les 30 frames
        var do_log = (is_hair and not _diag_logged_this_frame and (_debug_frame == 5 or _debug_frame == 35 or _debug_frame == 65))
        if do_log:
            var pre_rot = gp.basis.get_rotation_quaternion()
            print("[DIAG frame ", _debug_frame, "] BEFORE override: bone=", bname, " rot=", pre_rot)

        # Paramètres physiques différenciés
        var stiffness = H_STIFF
        var drag = H_DRAG
        var gravity_force = H_GRAVITY
        var wind_force = wind_world * H_WIND_MUL
        var length_limit = 0.18
        
        if is_hair:
            # Les cheveux sont plus légers et plus réactifs au vent
            stiffness = 0.05
            drag = 0.08
            gravity_force = 2.0
            wind_force = wind_world * (H_WIND_MUL * 1.5)
            length_limit = 0.30

        var bone_len = minf(_hair_bone_lengths[idx], length_limit)
        var root_world = skel_xf * gp.origin
        var rest_dir_world = (skel_xf.basis * rest_dir_skel).normalized()
        var rest_tail_world = root_world + rest_dir_world * bone_len

        var cur = _hair_tail_cur[idx]
        var prv = _hair_tail_prv[idx]
        
        # Application de l'inertie du personnage
        var vel = (cur - prv) * (1.0 - drag)
        
        # Intégration Verlet
        var next = cur + vel + Vector3(0, -gravity_force, 0)*dt2 + wind_force*dt2 + (rest_tail_world - cur)*stiffness
        var to_next = next - root_world
        
        # Contrainte de longueur
        if to_next.length() > 0.001:
            next = root_world + to_next.normalized() * bone_len
            
        _hair_tail_prv[idx] = cur
        _hair_tail_cur[idx] = next

        # Calcul de la rotation pour pointer vers la nouvelle position
        var desired_dir_skel = (skel_xf_inv.basis * (next - root_world)).normalized()
        var d = rest_dir_skel.dot(desired_dir_skel)
        var target_rot: Quaternion
        
        if d < -0.9999:
            var perp = rest_dir_skel.cross(Vector3.UP)
            if perp.length() < 0.001: perp = rest_dir_skel.cross(Vector3.RIGHT)
            target_rot = Quaternion(perp.normalized(), PI)
        else:
            target_rot = Quaternion(rest_dir_skel, desired_dir_skel)
            
        var bone_rest = skel.get_bone_rest(bone_idx)
        var rest_global_basis = parent_gp.basis * bone_rest.basis
        var new_basis = rest_global_basis * Basis(target_rot)
        
        skel.set_bone_global_pose_override(bone_idx, Transform3D(new_basis, gp.origin), 1.0, true)

        # DIAGNOSTIC
        if do_log:
            var post_gp = skel.get_bone_global_pose(bone_idx)
            var post_rot = post_gp.basis.get_rotation_quaternion()
            var pre_rot2 = gp.basis.get_rotation_quaternion()
            print("[DIAG frame ", _debug_frame, "] BEFORE=", pre_rot2, " AFTER=", post_rot, " SAME=", pre_rot2.is_equal_approx(post_rot))
            _diag_logged_this_frame = true

func _get_bone_global_rest(skel: Skeleton3D, bone_idx: int) -> Transform3D:
    var result = skel.get_bone_rest(bone_idx)
    var parent_idx = skel.get_bone_parent(bone_idx)
    while parent_idx >= 0:
        result = skel.get_bone_rest(parent_idx) * result
        parent_idx = skel.get_bone_parent(parent_idx)
    return result


func _ready() -> void:
    add_to_group("player") # Requis pour Atmosphere et Particules
    # Enregistrer le paramètre global pour le shader hair
    RenderingServer.global_shader_parameter_add("player_velocity", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
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
    var is_super_sprinting = Input.is_key_pressed(KEY_A) and direction != Vector3.ZERO
    
    var current_speed = move_speed
    if is_super_sprinting:
        current_speed = 20.0
    elif is_sprinting:
        current_speed = sprint_speed
    
    var target_anim = "idle"
    if direction != Vector3.ZERO:
        target_anim = "run" if (is_sprinting or is_super_sprinting) else "walk"
    
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

func _process(delta: float) -> void:
    # Passer la vélocité au shader Hair (inclinaison au mouvement)
    RenderingServer.global_shader_parameter_set("player_velocity", velocity)
    # Hair physics DOIT tourner dans _process, APRÈS l'AnimationPlayer
    _update_hair_physics(delta)



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


