extends SceneTree
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	await process_frame
	var k := 0
	for w in town.wreckables: if (w["at"] as Vector3).distance_to(Vector3(-4, 0, 4.2)) < 0.5: k += 1
	var names := {}
	for mi in town.find_children("*", "MeshInstance3D", true, false):
		var gp: Vector3 = (mi as Node3D).global_position
		if Vector2(gp.x + 4.0, gp.z - 4.2).length() < 1.0 and gp.y > 0.1 and gp.y < 1.0:
			var key := "%s/%s" % [mi.get_parent().name, (mi as MeshInstance3D).mesh.get_class()]
			names[key] = names.get(key, 0) + 1
	print("PROBE bench-wreckables-here ", k, " meshes ", names)
	quit()
