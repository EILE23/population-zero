extends SceneTree
## 출근 뒤 화면 — 아침으로 돌려 100초 기다린 뒤, 공방 일터(마당에서 고치는 사람)와 가게 일터 앞을 찍는다
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 10: await process_frame
	while not town._due.is_empty(): await process_frame
	town.clock = (6.0 - 6.0) / 24.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 110000: await process_frame
	var picks: Array = []
	for e in town.commuters:
		var r: Resident = e["r"]
		if r.spot.get("kind", "") == "work" and r.state == "busy": picks.append(r)
	print("DS at_work=%d h=%.1f" % [picks.size(), fmod(town.clock * 24.0 + 6.0, 24.0)])
	var outside := picks.filter(func(r): return not r.get_meta("work", {}).get("inside", true))
	var targets: Array = []
	if not outside.is_empty(): targets.append(["fix", (outside[0] as Node3D).global_position])
	for e in town.commuters:
		if e["phase"] == "there" and String(e["dest"].get("name", "")) == "work": targets.append(["park", (e["car"] as Node3D).global_position]); break
	for tg in targets:
		var p: Vector3 = tg[1] + Vector3(0, 0, 3.0)
		p.y = town.gen.height(p.x, p.z) + 0.3
		town.body.global_position = p; town.body.velocity = Vector3.ZERO
		town.gen.fill(p); town.zoom_want = 1.6; town.zoom = 1.6
		for i in 120: await process_frame
		root.get_texture().get_image().save_png("user://shots/day-%s.png" % tg[0])
		print("DS shot %s at %s" % [tg[0], str(p.snapped(Vector3.ONE))])
	quit()
