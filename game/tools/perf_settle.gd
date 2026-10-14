extends SceneTree
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await process_frame
	while not town._infill_q.is_empty(): await process_frame
	print("ST infill done at %d ms" % (Time.get_ticks_msec() - t0))
	for i in 120: await process_frame
	var s := 0.0; var f := 0.0
	for i in 300:
		await process_frame
		s += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS); f += Performance.get_monitor(Performance.TIME_PROCESS)
	print("ST physics=%.1f process=%.1f fps=%d draws=%d" % [s / 300.0 * 1000.0, f / 300.0 * 1000.0, Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit()
