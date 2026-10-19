extends SceneTree
## 프레임 시간 나누기 — 기준, 주민 물리 끔, 차 끔, 구역 숨김(그리기), 그림자 끔
func _ms(n: int) -> float:
	var t := Time.get_ticks_usec()
	for i in n: await process_frame
	return (Time.get_ticks_usec() - t) / 1000.0 / n
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await process_frame
	while not town._due.is_empty(): await process_frame
	for i in 120: await process_frame
	print("PS base %.1f ms draws=%d prims=%d objs=%d" % [await _ms(200), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	print("PS bodies static=%d active=%d nodes=%d" % [Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	var near := 0
	for r in town.residents: if r.global_position.distance_squared_to(town.body.global_position) < 1225.0: near += 1
	print("PS residents=%d near35=%d" % [town.residents.size(), near])
	for r in town.residents:
		for n in r.find_children("*", "", true, false): n.set_process(false)
	print("PS no_res_anim %.1f" % await _ms(200))
	for r in town.residents: r.set_process(false)
	print("PS no_res_process %.1f" % await _ms(200))
	for r in town.residents: r.set_physics_process(false)
	print("PS no_residents %.1f" % await _ms(200))
	for c in town.cars: c.set_physics_process(false); c.set_process(false)
	print("PS no_cars %.1f" % await _ms(200))
	town.set_process(false); town.set_physics_process(false)
	print("PS no_town_tick %.1f" % await _ms(200))
	for d in town.districts: (d["node"] as Node3D).visible = false
	print("PS no_districts %.1f draws=%d" % [await _ms(200), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	var sun: DirectionalLight3D = null
	for n in town.find_children("*", "DirectionalLight3D", true, false): n.shadow_enabled = false
	print("PS no_shadow %.1f draws=%d" % [await _ms(200), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit()
