extends SceneTree
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await process_frame
	while not town._due.is_empty(): await process_frame
	print("ST houses done at %d ms" % (Time.get_ticks_msec() - t0))
	for i in 120: await process_frame
	var s := 0.0; var f := 0.0
	for i in 300:
		await process_frame
		s += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS); f += Performance.get_monitor(Performance.TIME_PROCESS)
	print("ST physics=%.1f process=%.1f fps=%d draws=%d" % [s / 300.0 * 1000.0, f / 300.0 * 1000.0, Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	for z in [5.0, 12.0]:
		town.zoom_want = z; town.zoom = z
		for i in 120: await process_frame
		var a := Time.get_ticks_usec()
		for i in 120: await process_frame
		print("ST zoom %.0f frame=%.1f ms draws=%d prims=%d" % [z, (Time.get_ticks_usec() - a) / 120000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	quit()
