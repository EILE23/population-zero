extends SceneTree
func _init() -> void:
	var ps: PackedScene = load("res://assets/models/people/AnimationLibrary_Godot_Standard.gltf")
	if ps == null: print("PROBE UAL LOAD FAILED"); quit(); return
	var n: Node3D = ps.instantiate(); root.add_child(n)
	for c in n.find_children("*", "", true, false): print("PROBE node ", c.name, " ", c.get_class())
	for sk in n.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D; var names: Array = []
		for i in s.get_bone_count(): names.append(s.get_bone_name(i))
		print("PROBE bones ", s.get_bone_count(), " ", names)
		var hips := s.find_bone("Hips"); if hips >= 0: print("PROBE hips rest y=", s.get_bone_global_rest(hips).origin.y)
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		var l: Array = (ap as AnimationPlayer).get_animation_list(); print("PROBE anims ", l.size(), " ", l)
	quit()
