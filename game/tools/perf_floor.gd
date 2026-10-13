extends SceneTree
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 200: await physics_frame
	var s := 0.0; var f := 0.0
	for i in 300:
		await physics_frame
		s += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS); f += Performance.get_monitor(Performance.TIME_PROCESS)
	print("FL physics=%.1f process=%.1f fps=%d statics=%d" % [s / 300.0 * 1000.0, f / 300.0 * 1000.0, Engine.get_frames_per_second(), town.find_children("*", "StaticBody3D", true, false).size()])
	quit()
