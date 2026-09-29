extends SceneTree
func _init() -> void:
	var n: Node3D = (load("res://assets/models/animals/quaternius/ShibaInu.gltf") as PackedScene).instantiate(); root.add_child(n)
	var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ap.get_animation_list(): print("PROBE anim ", a, " len=", ap.get_animation(a).length, " loop=", ap.get_animation(a).loop_mode)
	var s: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var names: Array = []
	for i in s.get_bone_count(): names.append(s.get_bone_name(i))
	print("PROBE bones ", names)
	quit()
