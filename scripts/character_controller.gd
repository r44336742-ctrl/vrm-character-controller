extends CharacterBody3D

@export var move_speed: float = 3.5
@export var rotation_speed: float = 8.0
@export var acceleration: float = 4.0
@export var friction: float = 12.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var model_pivot: Node3D = $ModelPivot

var anim_player: AnimationPlayer = null
var hair_shader_material: ShaderMaterial
var dress_material: ShaderMaterial
const HAIR_MESH_NAMES: Array[String] = ["Object_2"]

func _ready() -> void:
    add_to_group("player")
    # On récupère le modèle FBX instancié
    var character_model = $ModelPivot.get_child(0)
    if character_model:
        # Corrige le 180° classique des imports
        character_model.rotation.y = PI
        
        anim_player = _find_anim_player(character_model)
        
        if anim_player:
            var lib = anim_player.get_animation_library("")
            if lib:
                var anims = anim_player.get_animation_list()
                for a in anims:
                    if not lib.has_animation("idle"):
                        # CRUCIAL : .duplicate() rend l'animation éditable en mémoire !
                        var anim = anim_player.get_animation(a).duplicate()
                        lib.add_animation("idle", anim)
                    break
            
            _load_walk_anim("res://assets/models/animations/walk.fbx")
            
            # SUPPRESSION DU ROOT MOTION (qui était multiplié par l'échelle 6.66x !)
            _strip_root_motion("walk")

    if anim_player and anim_player.has_animation("idle"):
        anim_player.play("idle")

    # --- CORRECTION DES UV (FLIP VERTICAL) + SHADERS GOTHIQUES ---
    if character_model:
        var skeleton = character_model.get_node_or_null("Skeleton3D")
        if skeleton:
            var tex_map = {
                "Object_0": "T_P003_E001_Wear_CS01_C_0.png",
                "Object_1": "T_P003_E001_Body_CS01_C_1.png",
                "Object_2": "T_P003_E001_Hair_CS01_C_2.png",
                "Object_3": "T_P003_E001_Face_CS01_C_3.png",
                "Object_4": "T_P003_E001_Iris_CS01_C_4.png"
            }
            
            var hair_shader: Shader = load("res://shaders/character_hair.gdshader")
            var skin_shader: Shader = load("res://shaders/character_skin_tint.gdshader")
            
            for child in skeleton.get_children():
                if child is MeshInstance3D:
                    # 1. Flip des UV (Y = 1.0 - Y)
                    var mesh = child.mesh
                    if mesh:
                        var arr = mesh.surface_get_arrays(0)
                        var uvs = arr[Mesh.ARRAY_TEX_UV]
                        if uvs != null:
                            for i in range(uvs.size()):
                                uvs[i].y = 1.0 - uvs[i].y
                            arr[Mesh.ARRAY_TEX_UV] = uvs
                            var new_mesh = ArrayMesh.new()
                            new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
                            child.mesh = new_mesh
                            
                    # 2. Application du Shader et de la Texture
                    var albedo_tex: Texture2D = null
                    if tex_map.has(child.name):
                        albedo_tex = load("res://assets/textures/nami/" + tex_map[child.name])
                        
                    if albedo_tex:
                        var new_mat = ShaderMaterial.new()
                        if child.name in HAIR_MESH_NAMES:
                            new_mat.shader = hair_shader
                            hair_shader_material = new_mat
                            # Couleurs originales du VRM
                            new_mat.set_shader_parameter("saturation", 1.0)
                            new_mat.set_shader_parameter("tint_color", Color(1.0, 1.0, 1.0))
                            new_mat.set_shader_parameter("darken_amount", 0.0)
                        else:
                            new_mat.shader = skin_shader
                            # Couleurs originales du VRM
                            new_mat.set_shader_parameter("saturation", 1.0)
                            new_mat.set_shader_parameter("tint_color", Color(1.0, 1.0, 1.0))
                            new_mat.set_shader_parameter("darken_amount", 0.0)
                            
                        new_mat.set_shader_parameter("albedo_texture", albedo_tex)
                        
                        # Transparence pour Cheveux(2), Visage(3 - cils), et Yeux(4 - iris)
                        if child.name in ["Object_2", "Object_3", "Object_4"]:
                            new_mat.set_shader_parameter("alpha_scissor_threshold", 0.5)
                        else:
                            new_mat.set_shader_parameter("alpha_scissor_threshold", 0.0) # Désactivé pour le reste
                            
                        child.set_surface_override_material(0, new_mat)

            _apply_lace_dress()

func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Sprint (Shift)
	var current_speed = move_speed
	if Input.is_action_pressed("sprint"):
		current_speed = 7.0

	var cam_basis = camera.global_transform.basis
	var forward: Vector3 = -cam_basis.z
	var right: Vector3 = cam_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var direction: Vector3 = (forward * -input_dir.y + right * input_dir.x).normalized()

	if direction != Vector3.ZERO:
		velocity.x = lerp(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, acceleration * delta)
		
		var target_rotation: float = atan2(-direction.x, -direction.z)
		model_pivot.rotation.y = lerp_angle(model_pivot.rotation.y, target_rotation, delta * rotation_speed)
		
		if anim_player and anim_player.has_animation("walk"):
			if anim_player.current_animation != "walk":
				anim_player.play("walk", 0.2)
			# Vitesse d'animation proportionnelle au sprint
			anim_player.speed_scale = current_speed / move_speed
		
		# Son de pas (timer plus rapide en sprint)
		var audio_mgr = get_tree().root.get_node_or_null("Main/AudioManager")
		if audio_mgr:
			audio_mgr.start_walking()
			audio_mgr.set_step_interval(0.45 * (move_speed / current_speed))
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * delta)
		
		if anim_player and anim_player.has_animation("idle"):
			if anim_player.current_animation != "idle":
				anim_player.play("idle", 0.2)
			anim_player.speed_scale = 1.0
		
		var audio_mgr = get_tree().root.get_node_or_null("Main/AudioManager")
		if audio_mgr:
			audio_mgr.stop_walking()

	move_and_slide()
    
    # --- ANIMATION CHEVEUX ---
    _update_hair_animation()

# --- CORRECTION DU ROOT MOTION PAR CODE ---
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
                        # On force X et Z à la position de départ (annule l'avancée)
                        # et on garde Y pour le rebond de la marche !
                        var fixed_pos = Vector3(first_pos.x, pos.y, first_pos.z)
                        anim.track_set_key_value(i, k, fixed_pos)

# --- INJECTION MIXAMO ---
func _load_walk_anim(fbx_path: String) -> void:
    if not ResourceLoader.exists(fbx_path): return
    var packed = load(fbx_path) as PackedScene
    if not packed: return
    
    var instance = packed.instantiate()
    var ap = _find_anim_player(instance)
    
    if ap and anim_player:
        var lib = anim_player.get_animation_library("")
        if not lib:
            lib = AnimationLibrary.new()
            anim_player.add_animation_library("", lib)
            
        var anim_list = ap.get_animation_list()
        for a_name in anim_list:
            # CRUCIAL : .duplicate() rend l'animation éditable !
            var anim = ap.get_animation(a_name).duplicate()
            if not lib.has_animation("walk"):
                lib.add_animation("walk", anim)
            break
            
    instance.queue_free()

func _find_anim_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer: return node
    for child in node.get_children():
        var res = _find_anim_player(child)
        if res: return res
    return null

func _update_hair_animation() -> void:
    var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
    var intensity: float = clamp(horizontal_speed / move_speed, 0.0, 1.0)
    
    if hair_shader_material:
        hair_shader_material.set_shader_parameter("movement_intensity", intensity)
        
    if dress_material:
        dress_material.set_shader_parameter("movement_intensity", intensity)

func _apply_lace_dress() -> void:
    var lace_shader: Shader = load("res://shaders/lace_dress.gdshader")
    var character_model = $ModelPivot.get_child(0)
    if not character_model: return
    
    var skeleton = character_model.get_node_or_null("Skeleton3D")
    if not skeleton:
        print("ERREUR: Pas de Skeleton3D trouvé pour la robe.")
        return

    var body_mesh_node = skeleton.get_node_or_null("Object_1")
    if not body_mesh_node or not body_mesh_node is MeshInstance3D:
        return

    # On clone le mesh du corps
    var dress_mesh_inst = MeshInstance3D.new()
    dress_mesh_inst.mesh = body_mesh_node.mesh
    dress_mesh_inst.skin = body_mesh_node.skin # Hérite du skinning (animations)
    dress_mesh_inst.name = "LaceDress"
    
    # Attacher et lier au squelette
    skeleton.add_child(dress_mesh_inst)
    dress_mesh_inst.skeleton = NodePath("..")
    
    # Crée le matériel de la robe
    var mat = ShaderMaterial.new()
    mat.shader = lace_shader
    
    mat.set_shader_parameter("albedo_texture", load("res://assets/textures/nami/T_P003_E001_Body_CS01_C_1.png"))
        
    # Réglages de la robe
    mat.set_shader_parameter("dress_color", Color(0.01, 0.01, 0.03, 1.0)) # Noir profond
    mat.set_shader_parameter("flare_amount", 0.08) # Gonflement
    mat.set_shader_parameter("top_cutoff", 0.3) # L'origine est aux hanches (0.0). 0.3 = sous la poitrine.
    mat.set_shader_parameter("bottom_cutoff", -1.2) # S'arrête aux mollets (négatif)
    mat.set_shader_parameter("lace_scale", 80.0) # Échelle de la dentelle (beaucoup plus fin)
    mat.set_shader_parameter("lace_thickness", 0.08)
    mat.set_shader_parameter("movement_intensity", 0.0)
    mat.set_shader_parameter("alpha_scissor_threshold", 0.5)
    
    dress_mesh_inst.set_surface_override_material(0, mat)
    dress_material = mat
