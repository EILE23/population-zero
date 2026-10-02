extends SceneTree
## 오두막 장작 패기 점검(헤드리스): 나무꾼이 있나, 사람이 두 번 패면 장작이 튀나, 들고 더미 앞 C 로 쌓이나, 나무꾼이 혼자 패고 나르나, 밤에 난로가 붙나
## godot --headless --path game -s res://tools/probe_woodcut.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var wc: Dictionary = town.woodcut
	var cutters: Array = town.residents.filter(func(r): return r.job == "woodcutter")
	print("WOODCUTTER ", cutters.map(func(r): return r.handle), " stack=", (wc["stack"] as Array).size())
	var b: Node3D = town.body
	var work: Dictionary = wc["work"]
	for r in cutters: r.global_position = Vector3(-140, 0.05, -30); r.state = "busy"; r.busy_until = 1e9   # 사람 차례에 끼어들지 않게
	b.global_position = work["pos"] + Vector3(0, 0.05, 0)
	for i in 60: await physics_frame
	town.chop_use(work, Time.get_ticks_msec() / 1000.0)
	for i in 240: await physics_frame
	var loose: Array = town.loose_logs()
	print("PLAYER CHOP loose=", loose.size(), " pose=", town.player.pose_request)
	if not loose.is_empty():
		var lg: Node3D = loose[0]; town.items.erase(lg); town.player.hold(lg)
		b.global_position = (wc["pile"] as Dictionary)["pos"] + Vector3(0, 0.05, 0)
		for i in 10: await physics_frame
		var n0: int = (wc["stack"] as Array).size()
		var ok: bool = town.stack_log(Time.get_ticks_msec() / 1000.0)
		print("STACK ok=", ok, " ", n0, " -> ", (wc["stack"] as Array).size(), " carrying=", town.player.carrying)
	if cutters.is_empty(): quit(); return
	b.global_position = Vector3(-140, 0.05, -34)   # 더미 앞에 서 있으면 나무꾼 길을 막는다
	var w: Resident = cutters[0]
	town.clock = 0.2   # 11시
	w.global_position = work["pos"] + Vector3(-2, 0.05, 1); w.state = "routine"; w.busy_until = 0.0; w._release()
	if w.fig.carrying: w.fig.release(town, w.global_position).queue_free()
	var seen := {}
	for i in 60 * 60:
		await physics_frame
		var k: String = w.spot.get("kind", "") + "/" + w.state + "/" + w.fig.pose_request
		if not seen.has(k): seen[k] = true; print("  w ", k, " at ", w.global_position, " tgt ", w.target, " route ", w.route.size(), " loose=", town.loose_logs().size(), " stack=", (wc["stack"] as Array).size())
	print("WOODCUTTER after 60s loose=", town.loose_logs().size(), " stack=", (wc["stack"] as Array).size())
	town.clock = 0.7
	for i in 10: await physics_frame
	print("NIGHT unfed stove lit=", (wc["light"] as OmniLight3D).visible, " (want false)")
	# 사람이 장작을 들고 난로 앞 C — stoke 자세, STOKE_IN 뒤 화실에 하나, 밤이면 바로 붙는다(run 92)
	w.global_position = Vector3(-140, 0.05, -30); w.state = "busy"; w.busy_until = 1e9
	var lg2: Node3D = town.make_item("log", Vector3.ZERO); town.player.hold(lg2)
	b.global_position = (wc["stove"] as Dictionary)["pos"] + Vector3(0, 0.05, 0)
	for i in 10: await physics_frame
	var sok: bool = town.stoke_log(Time.get_ticks_msec() / 1000.0)
	print("STOKE ok=", sok, " pose=", town.player.pose_request)
	for i in 90: await physics_frame
	print("STOKED fire=", wc["fire"], " carrying=", town.player.carrying, " lit=", (wc["light"] as OmniLight3D).visible, " fed=", (wc["house"] as Dictionary).get("fed"))
	town.clock = 0.2
	for i in 10: await physics_frame
	print("MORNING fire=", wc["fire"], " lit=", (wc["light"] as OmniLight3D).visible)
	# 나무꾼이 저녁(16:45)에 더미에서 하나를 내려 문으로 들어가 넣는다
	town.clock = (16.75 - 6.0) / 24.0
	w.global_position = (wc["pile"] as Dictionary)["pos"] + Vector3(-1.5, 0.05, 0.5); w.state = "routine"; w.busy_until = 0.0; w._release()
	if w.fig.carrying: w.fig.release(town, w.global_position).queue_free()
	b.global_position = Vector3(-140, 0.05, -34)
	seen = {}
	for i in 60 * 40:
		await physics_frame
		town.clock = (16.75 - 6.0) / 24.0   # 저녁에 묶어 둔다 — 밤이 와 침대로 가지 않게
		var k2: String = w.spot.get("kind", "") + "/" + w.state + "/" + w.fig.pose_request
		if not seen.has(k2): seen[k2] = true; print("  w ", k2, " at ", w.global_position, " fire=", wc["fire"], " stack=", (wc["stack"] as Array).size())
		if int(wc["fire"]) > 0: break
	print("EVENING woodcutter stoked fire=", wc["fire"], " (want 1)")
	quit()
