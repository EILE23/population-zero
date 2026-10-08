extends SceneTree
## 프레임이 어디에 쓰이나(창 모드) — 처리·물리 스크립트 시간과 그리기 수, 5초 평균
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 120: await process_frame
	town.body.global_position = Vector3(-4, 0.05, -40)
	for i in 120: await process_frame
	var tp := 0.0; var tf := 0.0; var fr := 0.0; var n := 0
	for i in 300:
		await process_frame
		tp += Performance.get_monitor(Performance.TIME_PROCESS); tf += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS); fr += Performance.get_monitor(Performance.TIME_FPS); n += 1
	print("PERF fps=%.0f process=%.1fms physics=%.1fms draws=%d objects=%d prims=%d nodes=%d residents=%d" % [fr / n, tp / n * 1000.0, tf / n * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), town.residents.size()])
	quit()
