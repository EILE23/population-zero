extends SceneTree
## 처리 시간이 어디서 나나 — 주민 졸라맨 _process 를 켠 채/끈 채, 주민 _physics_process 를 끈 채 견준다(창 모드)
func _avg(town: Node3D, label: String) -> void:
	var tp := 0.0; var tf := 0.0; var fr := 0.0
	for i in 240:
		await process_frame
		tp += Performance.get_monitor(Performance.TIME_PROCESS); tf += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS); fr += Performance.get_monitor(Performance.TIME_FPS)
	print("AB %-14s fps=%.0f process=%.1fms physics=%.1fms" % [label, fr / 240.0, tp / 240.0 * 1000.0, tf / 240.0 * 1000.0])

func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 120: await process_frame
	town.body.global_position = Vector3(-4, 0.05, -40)
	for i in 60: await process_frame
	await _avg(town, "all on")
	for c in town.find_children("*", "Car3D", true, false): c.set_physics_process(false); c.set_process(false)
	await _avg(town, "cars off")
	for c in town.find_children("*", "Car3D", true, false): c.set_physics_process(true); c.set_process(true)
	var us := {}
	for name in ["_tick", "_stream", "_cutaway", "_hud", "_seesaws", "_swings"]:
		if not town.has_method(name): continue
		var t0 := Time.get_ticks_usec()
		for k in 30:
			if name == "_tick": town.call(name, 1.0 / 60.0, Time.get_ticks_msec() / 1000.0)
			elif name in ["_seesaws", "_swings"]: town.call(name, 1.0 / 60.0)
			elif name == "_hud": town.call(name, Time.get_ticks_msec() / 1000.0)
			else: town.call(name)
		us[name] = (Time.get_ticks_usec() - t0) / 30.0
	print("AB calls(us) ", str(us))
	quit()
