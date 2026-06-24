extends Node

var target_bone_name = "J_Sec_Hair1_01"
var skel: Skeleton3D = null
var bone_idx: int = -1
var test_frame: int = 0
var test_quat: Quaternion = Quaternion(Vector3(1, 0, 0), 0.785398) # 45 degrees
var test_transform: Transform3D

func _ready():
	call_deferred("_setup")

func _setup():
	var parent = get_parent()
	var skels = parent.find_children("*", "Skeleton3D", true)
	if skels.is_empty():
		print("[PoseDebug] No Skeleton3D found.")
		return
	skel = skels[0]
	bone_idx = skel.find_bone(target_bone_name)
	if bone_idx == -1:
		print("[PoseDebug] Bone ", target_bone_name, " not found.")
		return
		
	print("[PoseDebug] Ready. Testing bone: ", target_bone_name, " (idx: ", bone_idx, ")")
	
	# Etape 3: Verifier VRMSecondary / VRMSpringBone
	var vrm_nodes = parent.find_children("*", "VRMSecondary*", true)
	if vrm_nodes.is_empty():
		print("[PoseDebug] No VRMSecondary node found.")
	for v in vrm_nodes:
		print("[PoseDebug] Found VRMSecondary: ", v.name, " is_processing=", v.is_processing(), " process_mode=", v.process_mode)
		
	var spring_nodes = parent.find_children("*", "VRMSpringBone*", true)
	if spring_nodes.is_empty():
		print("[PoseDebug] No VRMSpringBone node found.")
	for v in spring_nodes:
		print("[PoseDebug] Found VRMSpringBone: ", v.name, " is_processing=", v.is_processing(), " process_mode=", v.process_mode)

func _process(_delta):
	if skel == null or bone_idx == -1: return
	
	var time = Time.get_ticks_msec() / 1000.0
	var angle = sin(time * 5.0) * 0.5 # Oscillate by ~30 degrees
	var q = Quaternion(Vector3(1, 0, 0), angle)
	
	var rest = skel.get_bone_global_rest(bone_idx)
	test_transform = Transform3D(Basis(q) * rest.basis, rest.origin)
	skel.set_bone_global_pose_override(bone_idx, test_transform, 1.0, true)

