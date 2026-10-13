extends SceneTree
## 물리 시간 나누기 — 차 수, 세운 차 물리를 끈 뒤의 물리 시간
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 120: await process_frame
	var m := func() -> float:
		var s := 0.0
		for i in 120:
			await process_frame
			s += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		return s / 120.0 * 1000.0
	print("PC cars=%d bodies? physics=%.1f" % [town.cars.size(), await m.call()])
	for c in town.cars: c.set_physics_process(false)
	print("PC cars off physics=%.1f" % (await m.call()))
	for c in town.cars: c.set_physics_process(true)
	for r in town.residents: r.set_physics_process(false)
	print("PC residents off physics=%.1f" % (await m.call()))
	for r in town.residents: r.set_physics_process(true)
	town.set_physics_process(false)
	print("PC town off physics=%.1f spots=%d wreck=%d" % [await m.call(), town.spots.size(), town.wreckables.size()])
	town.set_physics_process(true)
	town.set_meta("no_streets", true)
	quit()
