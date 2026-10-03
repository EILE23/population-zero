extends SceneTree
## 둘이 함께 걷기 점검(헤드리스, run 95): 친구 사이 둘 중 하나가 바깥 자리로 나서면 다른 하나가 그 목적지로 따라붙어 0.6m 옆에서 나란히 걷나,
## 앞사람이 닿으면 곁에 서나, 걷던 중 하나를 때리면 짝이 깨지고 둘 다 bicker 를 하나(맞은 쪽은 움찔이 끝난 뒤), 90초 안엔 다시 짝을 안 맺나
## 2조각(run 96): 다툰 둘이 토라져 있나, 하나가 벤치에 앉으면 다른 하나가 와서 옆 칸에 앉고 둘 다 makeup 을 하나, 사람의 C 가 한쪽을 보내 화해시키나(성미 급한 상대는 거절)
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
	var now2 := Time.get_ticks_msec() / 1000.0
	print("SULK a=", a._sulking(now2), " b=", b._sulking(now2), " (want true true)")
	# 벤치: b 를 앉히고 a 는 4m 떨어져 서 있게
	for i in 60: await physics_frame
	var bench: Dictionary = {}
	for sp in town.spots:
		if sp["kind"] == "bench" and (sp["pos"] as Vector3).y < 0.5 and absf((sp["pos"] as Vector3).x) < 60.0 and b._free_slot(sp) == 0 and b._free_slot(sp) >= 0 and (sp.get("taken", []) as Array).all(func(x): return x == null): bench = sp; break
	for r: ResidentPair in [a, b]: r._leave(); r._mending = null
	now2 = Time.get_ticks_msec() / 1000.0
	for r: ResidentPair in [a, b]: r.sulk_until = now2 + 90.0
	a.sulk_with = b; b.sulk_with = a
	b.spot = bench; b.slot = 0; b._claim(bench, 0); b.global_position = bench["pos"] + Vector3(-0.45, 0.05, 0.02); b.fig.seated = true; b.state = "busy"; b.busy_until = now2 + 30.0; b.collision_layer = 0; b.collision_mask = 0
	a.global_position = bench["pos"] + Vector3(3.0, 0.1, 2.0); a.state = "routine"; a.busy_until = now2 + 60.0
	var made := false
	for i in 600:
		await physics_frame
		if a.fig.pose_request == "makeup" and b.fig.pose_request == "makeup": made = true; break
	print("BENCH made_up=", made, " a seated=", a.fig.seated, " a slot=", a.slot, " b look_yaw=", snappedf(b.fig.look_yaw, 0.01), " sulk a=", a.sulk_with, " said='", a.say_label.text, "'")
	# 사람의 C: 토라진 a 에게 인사 → a 가 b 에게 간다
	for r: ResidentPair in [a, b]: r._leave()
	now2 = Time.get_ticks_msec() / 1000.0
	for r: ResidentPair in [a, b]: r.sulk_until = now2 + 90.0
	a.sulk_with = b; b.sulk_with = a; b.mind.temper = 0.3
	a.global_position = Vector3(-6.0, 0.1, 12.0); b.global_position = Vector3(-1.0, 0.1, 12.0)
	for r: ResidentPair in [a, b]: r.state = "routine"; r.busy_until = now2 + 60.0
	a.greet(town.body)
	print("NUDGE a mending=", a._mending == b, " a said='", a.say_label.text, "'")
	made = false
	for i in 400:
		await physics_frame
		if a.fig.pose_request == "makeup" and b.fig.pose_request == "makeup": made = true; break
	print("NUDGE made_up=", made, " gap=", snappedf(a.global_position.distance_to(b.global_position), 0.01), " sulk=", a.sulk_with, "/", b.sulk_with)
	# 성미 급한 상대는 거절
	for r: ResidentPair in [a, b]: r._leave()
	now2 = Time.get_ticks_msec() / 1000.0
	for r: ResidentPair in [a, b]: r.sulk_until = now2 + 90.0; r.state = "routine"; r.busy_until = now2 + 60.0
	a.sulk_with = b; b.sulk_with = a; b.mind.temper = 0.9
	a.global_position = Vector3(-6.0, 0.1, 12.0); b.global_position = Vector3(-1.0, 0.1, 12.0)
	a.greet(town.body)
	for i in 400:
		await physics_frame
		if a._mending == null: break
	print("REFUSE still sulking=", a._sulking(Time.get_ticks_msec() / 1000.0), " b said='", b.say_label.text, "' (want true + a sulk line)")
	quit()
