extends SceneTree
## 물리 스크립트 비용을 스크립트별로 — 같은 스크립트의 _physics_process 를 다 끄고 줄어든 만큼
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await process_frame
	while not town._infill_q.is_empty(): await process_frame
	for i in 60: await process_frame
	print("PH spots=%d crowns=%d wreck=%d" % [town.spots.size(), town.crowns.size(), town.wreckables.size()])
	var m := func() -> float:
		var s := 0.0; var steps := 0
		for i in 120:
			await physics_frame
			s += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		return s / 120.0 * 1000.0
	var groups := {}
	for n in town.find_children("*", "", true, false) + [town]:
		if n.is_physics_processing():
			var k: String = n.get_script().resource_path.get_file() if n.get_script() else n.get_class()
			if not groups.has(k): groups[k] = []
			groups[k].append(n)
	var base: float = await m.call()
	print("PH base per step=%.1f ms groups=%d" % [base, groups.size()])
	for k in groups:
		for n in groups[k]: n.set_physics_process(false)
		var t: float = await m.call()
		for n in groups[k]: n.set_physics_process(true)
		print("PH %s n=%d saves %.1f ms" % [k, groups[k].size(), base - t])
	for k in groups:
		for n in groups[k]: n.set_physics_process(false)
	print("PH all scripts off=%.1f" % (await m.call()))
	for b in town.find_children("*", "CollisionObject3D", true, false): (b as Node).process_mode = Node.PROCESS_MODE_DISABLED
	print("PH all bodies off too=%.1f" % (await m.call()))
	quit()
