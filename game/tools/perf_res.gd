extends SceneTree
## 주민 물리 한 번의 값 — 상태별 µs, move_and_slide 만 따로
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await process_frame
	while not town._due.is_empty(): await process_frame
	for i in 120: await process_frame
	for r in town.residents: r.set_physics_process(false)
	var by := {}; var tot := 0.0
	for r in town.residents:
		var a := Time.get_ticks_usec()
		for i in 4: r._physics_process(1.0 / 60.0)
		var us := (Time.get_ticks_usec() - a) / 4.0
		tot += us
		var k: String = r.state
		if not by.has(k): by[k] = [0, 0.0, 0.0]
		by[k][0] += 1; by[k][1] += us; by[k][2] = maxf(by[k][2], us)
	print("PR total per tick %.0f us" % tot)
	for k in by: print("PR %s n=%d avg=%.0f max=%.0f" % [k, by[k][0], by[k][1] / by[k][0], by[k][2]])
	var r0: CharacterBody3D = town.residents[0]
	var a2 := Time.get_ticks_usec()
	for i in 50: r0.velocity = Vector3(1, 0, 0); r0.move_and_slide()
	print("PR move_and_slide %.0f us" % ((Time.get_ticks_usec() - a2) / 50.0))
	var w: Resident = null
	for r in town.residents:
		if r.state == "walk" and r.global_position.distance_to(town.body.global_position) < 30.0: w = r; break
	if w:
		var p := w.global_position
		var segs := { "in_water": func(): town.in_water(p), "teeter": func(): town.teeter(w.fig, p, true), "step_up": func(): town.step_up(w, Vector3(0.03, 0, 0)), "has_ground": func(): town.gen.has_ground(p), "is_on_floor": func(): w.is_on_floor(), "phys": func(): w._physics_process(1.0 / 60.0), "slide": func(): w.move_and_slide() }
		for k in segs:
			var a := Time.get_ticks_usec()
			for i in 50: segs[k].call()
			print("PR seg %s %.0f us" % [k, (Time.get_ticks_usec() - a) / 50.0])
	quit()
