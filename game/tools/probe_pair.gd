extends SceneTree
## 둘이 함께 걷기 점검(헤드리스, run 95): 친구 사이 둘 중 하나가 바깥 자리로 나서면 다른 하나가 그 목적지로 따라붙어 0.6m 옆에서 나란히 걷나,
## 앞사람이 닿으면 곁에 서나, 걷던 중 하나를 때리면 짝이 깨지고 둘 다 bicker 를 하나(맞은 쪽은 움찔이 끝난 뒤), 90초 안엔 다시 짝을 안 맺나
## godot --headless --path game -s res://tools/probe_pair.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"
	var free: Array = town.residents.filter(func(x): return x.state in ["routine", "walk", "busy"] and not x.fig.seated and x.riding_swing.is_empty() and x.riding_seesaw == null and not x.in_boat and not x.has_umb)
	var a: ResidentPair = free[0]; var b: ResidentPair = free[1]
	for r: ResidentPair in [a, b]:
		r._leave(); r.weather = "clear"; r.global_position = Vector3(-6.0 if r == a else -4.0, 0.1, 12.0)
	a.mind.friends[b.uid] = 0.7; b.mind.friends[a.uid] = 0.7
	var dest: Dictionary = {}
	for sp in town.spots:
		var d: float = (sp["pos"] as Vector3).distance_to(b.global_position)
		if sp["kind"] in ["lamp", "tree"] and d > 12.0 and d < 30.0 and b._free_slot(sp) >= 0: dest = sp; break
	print("DEST ", dest.get("kind"), " ", dest.get("pos"))
	for i in 5: await physics_frame
	var now := Time.get_ticks_msec() / 1000.0
	b.spot = dest; b.slot = 0; b._claim(dest, 0); b.route = town.via_bridge(b.global_position, [{ "pos": dest["pos"] + Vector3(0, 0, 0.5), "act": "" }])
	b.target = b.route[0]["pos"]; b.state = "walk"
	a.state = "routine"
	print("PICK paired=", a._pair_pick(now, 1.0), " follow=", a.pair_follow, " lead pace=", b.pace, " a spot=", a.spot.get("kind"))
	var near := 0; var walked := 0; var looked := false
	for i in 900:
		await physics_frame
		if a.state == "walk" and b.state == "walk":
			walked += 1
			if a.global_position.distance_to(b.global_position) < 1.0: near += 1
			if absf(a.fig.look_yaw) > 0.2: looked = true
		if b.state == "busy" and a.state == "busy": break
	print("WALK frames=", walked, " side-by-side(<1m)=", near, " looked=", looked, " a=", a.state, "/", a.spot.get("kind"), " b=", b.state, "/", b.spot.get("kind"), " gap=", snappedf(a.global_position.distance_to(b.global_position), 0.01), " still paired=", a.pair == b)
	# 다시 걷게 하고 걷는 중에 앞사람을 때린다
	for r: ResidentPair in [a, b]: r._leave(); r._pair_cool = 0.0
	b.global_position = Vector3(-4.0, 0.1, 12.0); a.global_position = Vector3(-6.0, 0.1, 12.0)
	b.spot = dest; b._claim(dest, 0); b.route = town.via_bridge(b.global_position, [{ "pos": dest["pos"] + Vector3(0, 0, 0.5), "act": "" }]); b.target = b.route[0]["pos"]; b.state = "walk"
	a.state = "routine"; a._pair_pick(Time.get_ticks_msec() / 1000.0, 1.0)
	for i in 90: await physics_frame
	b.hit(Vector3(1, 0, 0), town.body, false)
	await physics_frame
	print("HIT pair a=", a.pair, " b=", b.pair, " a pose=", a.fig.pose_request, " (want bicker) a said='", a.say_label.text, "'")
	var b_bicker := false
	for i in 120:
		await physics_frame
		if b.fig.pose_request == "bicker": b_bicker = true
	print("AFTER b bicker=", b_bicker, " b state=", b.state, " a state=", a.state, " a pose='", a.fig.pose_request, "' repair=", a._pair_pick(Time.get_ticks_msec() / 1000.0, 1.0), " (want false: 90s cool)")
	quit()
