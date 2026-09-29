extends SceneTree
func _init() -> void:
	for p in ["CommonTree_1", "CommonTree_3", "CommonTree_5", "Pine_1", "TwistedTree_1", "Bush_Common", "Grass_Common_Short", "Flower_3_Group", "Flower_4_Single", "Rock_Medium_1", "Clover_1"]:
		var ps: PackedScene = load("res://assets/models/nature/quaternius/%s.gltf" % p)
		if ps == null: print("PROBE ", p, " LOAD FAILED"); continue
		var n: Node3D = ps.instantiate(); root.add_child(n)
		var aabb := AABB(); var first := true; var mats: Array = []
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var b: AABB = m.global_transform * m.get_aabb(); aabb = b if first else aabb.merge(b); first = false
			for i in m.mesh.get_surface_count(): mats.append(m.mesh.surface_get_material(i).resource_name if m.mesh.surface_get_material(i) else "none")
		print("PROBE ", p, " size=", aabb.size, " miny=", aabb.position.y, " meshes=", n.find_children("*", "MeshInstance3D", true, false).size(), " mats=", mats)
		n.queue_free()
	quit()
