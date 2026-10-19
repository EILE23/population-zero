extends SceneTree
## GPU 시간(뷰포트 측정) — 기준, 작은 소품 그림자 끔, 해 그림자 끔. 줌 1·5·12
func _gpu(n: int) -> Array:
	var vp := root.get_viewport_rid()
	var g := 0.0; var c := 0.0
	for i in n:
		await process_frame
		g += RenderingServer.viewport_get_measured_render_time_gpu(vp); c += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	return [g / n, c / n, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
func _init() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await process_frame
	while not town._due.is_empty(): await process_frame
	for i in 120: await process_frame
	for z in [1.0, 5.0, 12.0]:
		town.zoom_want = z; town.zoom = z
		for i in 90: await process_frame
		var r: Array = await _gpu(60)
		var sun: DirectionalLight3D = town.get_node("Sun")
		sun.shadow_enabled = false
		var r2: Array = await _gpu(60)
		sun.shadow_enabled = true
		print("PG zoom %.0f gpu=%.1f ms cpu_render=%.1f draws=%d | no_shadow gpu=%.1f draws=%d" % [z, r[0], r[1], r[2], r2[0], r2[2]])
	quit()
