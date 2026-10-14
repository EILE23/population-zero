extends SceneTree
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 40: await physics_frame
	for at in [Vector3(-11, 0.9, -30.5), Vector3(114.4, 0.9, 46.5)]:
		town.body.global_position = at + Vector3(0, 5, 0); town.gen.fill(at)
		for i in 10: await physics_frame
		var q := PhysicsShapeQueryParameters3D.new(); var sh := SphereShape3D.new(); sh.radius = 0.6; q.shape = sh; q.transform = Transform3D(Basis(), at); q.collision_mask = 7
		for h in town.get_world_3d().direct_space_state.intersect_shape(q, 8):
			var n: Node = h["collider"]; var chain := ""
			var m: Node = n
			for k in 5:
				if m == null: break
				var extra := ""
				for c in m.get_children(): if c is MeshInstance3D and (c as MeshInstance3D).mesh: extra = (c as MeshInstance3D).mesh.get_class() + str((c as MeshInstance3D).mesh.get("size") if (c as MeshInstance3D).mesh is BoxMesh else "")
				chain += "%s(%s %s) < " % [m.name, m.get_class(), extra]; m = m.get_parent()
			print("AT %s: %s" % [str(at), chain])
		print("AT road near=", Valley.near(Vector2(at.x, at.z)))
	quit()
