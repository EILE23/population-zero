extends SceneTree
## 편지방 점검(헤드리스, run 99 — "Letters and notes" 1조각): 집·문·우편함이 있고 편지 일곱이 보이나, 서기가 있나(문 수가 주민 수를 넘으면 빈집),
## 사람이 종이를 꽂으면 +1·손이 비나, 빈손 C 면 −1·손에 편지가 오나, 주민이 빈손으로 닿으면 하나 꺼내 읽나, 종이를 들고 닿으면 꽂나, 서기 아침 편지 +3
## godot --headless --path game -s res://tools/probe_letters.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"
	var lw: Dictionary = town.letterwall
	var shown := (lw["shown"] as Array).filter(func(b): return (b as Node3D).visible).size()
	var scribes: Array = town.residents.filter(func(r): return r.job == "scribe")
	print("ROOM stock=", lw["stock"], " shown=", shown, " door=", lw.has("door"), " doors=", town.doors.size(), " scribes=", scribes.size(), " (want 7 7 true _ >=1)")
	var inroom: Array = town.spots.filter(func(sp): return sp.get("door") == lw["door"]).map(func(sp): return sp["kind"])
	print("ROOM spots=", inroom, " (want letters, chair, bed)")
	town.body.global_position = lw["pos"] + Vector3(0, 0.02, 0)
	town.player.hold(town.make_item("paper", Vector3.ZERO))
	var s0: int = lw["stock"]
	var ok: bool = town.letters_use(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.3).timeout
	print("PUT ok=", ok, " stock ", s0, "->", lw["stock"], " hand=", town.player.carrying, " pose='", town.player.pose_request, "' (want +1, null, '')")
	s0 = lw["stock"]
	ok = town.letters_use(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.3).timeout
	var held: String = String(town.player.carrying.get_meta("kind", "")) if town.player.carrying else ""
	print("TAKE ok=", ok, " stock ", s0, "->", lw["stock"], " hand=", held, " (want -1, letter)")
	town.player.release(town, Vector3.ZERO).queue_free()
	town.body.global_position = Vector3(0, 0.02, 4)
	var free: Array = town.residents.filter(func(x): return x.state in ["routine", "walk", "busy"] and x.fig.carrying == null and not x.fig.seated and x.riding_swing.is_empty() and x.riding_seesaw == null and not x.in_boat and not x.has_umb and x.job != "scribe")
	var r: ResidentLetters = free[0]
	r._leave(); r.weather = "clear"
	r.global_position = lw["pos"] + Vector3(0, 0.1, 0.05); r.spot = lw; r.slot = 1; r._claim(lw, 1); r.state = "busy"; r.door_ref = lw["door"]
	s0 = lw["stock"]
	r._post_arrive(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.4).timeout
	print("R TAKE stock ", s0, "->", lw["stock"], " kind=", r.carrying_kind, " pose=", r.fig.pose_request, " (want -1, letter, read)")
	r.state = "busy"; r.spot = lw; r.fig.pose_request = ""
	s0 = lw["stock"]
	r._post_arrive(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.0).timeout
	print("R PUT stock ", s0, "->", lw["stock"], " kind='", r.carrying_kind, "' (want +1, '')")
	if not scribes.is_empty():
		var sc: ResidentLetters = scribes[0]
		sc._leave(); sc.global_position = lw["pos"] + Vector3(-0.3, 0.1, 0.05); sc.spot = lw; sc.slot = 0; sc._claim(lw, 0); sc.state = "busy"; sc.door_ref = lw["door"]
		town.clock = (9.5 - 6.0) / 24.0   # 9시 반
		s0 = lw["stock"]
		sc._post_arrive(Time.get_ticks_msec() / 1000.0)
		await create_timer(3.8).timeout
		print("SCRIBE morning stock ", s0, "->", lw["stock"], " pose='", sc.fig.pose_request, "' (want +3 up to 12, '')")
	# 서기가 _pick 으로 문을 지나 우편함까지 걸어가나(낮)
	if not scribes.is_empty():
		var sc2: ResidentLetters = scribes[0]
		sc2._leave(); sc2.state = "routine"; sc2.global_position = Vector3(18, 0.05, -12.5); sc2.busy_until = 0.0
		var picked := false
		for k in 20:
			sc2._release(); if sc2._post_pick(Time.get_ticks_msec() / 1000.0): picked = true; break
		var arrived := false
		for i in 900:
			await physics_frame
			if sc2.state == "busy" and is_same(sc2.spot, lw): arrived = true; break
		print("SCRIBE walk picked=", picked, " arrived=", arrived, " at=", sc2.global_position, " (want true true)")
	quit()
