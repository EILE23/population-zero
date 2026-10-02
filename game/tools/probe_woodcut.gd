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
	print("NIGHT stove lit=", (wc["light"] as OmniLight3D).visible)
	town.clock = 0.2
	for i in 10: await physics_frame
	print("MORNING stack=", (wc["stack"] as Array).size())
	quit()
