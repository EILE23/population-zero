extends SceneTree
## 물리 비용 나누기 — 정적 몸·모양 수, 그리고 무리별로 끈 뒤의 물리 시간
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 120: await process_frame
	var m := func() -> float:
		var s := 0.0
		for i in 150:
			await process_frame
			s += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		return s / 150.0 * 1000.0
	var bodies := town.find_children("*", "StaticBody3D", true, false)
	var shapes := 0; var world_b := 0; var town_b := 0
	for b in bodies:
		shapes += (b as CollisionObject3D).get_shape_owners().size()
		var p: Node = b
		var in_world := false
		while p and p != town:
			if p.name == "World": in_world = true
			p = p.get_parent()
		if in_world: world_b += 1
		else: town_b += 1
	print("PP static=%d shapes=%d world=%d town=%d active=%d" % [bodies.size(), shapes, world_b, town_b, Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
	print("PP base physics=%.1f fps=%d" % [await m.call(), Engine.get_frames_per_second()])
	print("PP pairs=%d islands=%d" % [Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)])
	for b in bodies:
		if (b as Node).get_parent() and not ("World" in str((b as Node).get_path())): (b as CollisionObject3D).process_mode = Node.PROCESS_MODE_DISABLED
	print("PP town statics off physics=%.1f" % (await m.call()))
	quit()
