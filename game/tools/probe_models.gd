extends SceneTree
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	await process_frame; await physics_frame
	var space := (town as Node3D).get_world_3d().direct_space_state
	for x in [44.0, 45.0, 45.5, 46.0, 46.5, 47.0, 48.0]:
		var q := PhysicsShapeQueryParameters3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(0.5, 2.0, 2.4); q.shape = sh
		q.transform = Transform3D(Basis(), Vector3(x, 1.0, 2.6)); q.collision_mask = 0xFFFF
		for h in space.intersect_shape(q, 4):
			var o: Node = h["collider"]; var cs: CollisionShape3D = o.get_child(0) if o.get_child_count() > 0 else null
			print("PROBE x=", x, " ", o.name, " pos=", (o as Node3D).global_position, " shape=", cs.shape if cs else null, " size=", (cs.shape as BoxShape3D).size if cs and cs.shape is BoxShape3D else "", " parent=", o.get_parent().name)
	quit()
