extends SceneTree
## 광장 게시판 점검(헤드리스, run 100 — "Letters and notes" 2조각): 판에 쪽지 둘, 사람이 종이를 꽂으면 +1·손이 비나, 빈손 C 면 가장 새 것을 떼나,
## 주민이 종이를 들고 닿으면 꽂나, 빈손으로 닿으면 scan 으로 읽나, 서기가 하루 넘은 쪽지를 떼어 다발로 우편함에 넣나(재고 +장수)
## godot --headless --path game -s res://tools/probe_notice.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"; town.clock = (12.0 - 6.0) / 24.0
	var nb: Dictionary = town.notice
	var notes: Array = nb["notes"]
	print("BOARD notes=", notes.size(), " slot=", town.note_slot(), " (want 2, 0)")
	town.body.global_position = nb["pos"] + Vector3(0, 0.02, 0)
	town.player.hold(town.make_item("letter", Vector3.ZERO))
	var ok: bool = town.notice_use(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.0).timeout
	print("PIN ok=", ok, " notes=", notes.size(), " hand=", town.player.carrying, " pose='", town.player.pose_request, "' (want true 3 null '')")
	ok = town.notice_use(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.0).timeout
	var held: String = String(town.player.carrying.get_meta("kind", "")) if town.player.carrying else ""
	print("TAKE ok=", ok, " notes=", notes.size(), " hand=", held, " (want true 2 letter)")
	town.player.release(town, Vector3.ZERO).queue_free()
	town.body.global_position = Vector3(0, 0.02, 4)
	var free: Array = town.residents.filter(func(x): return x.state in ["routine", "walk", "busy"] and x.fig.carrying == null and not x.fig.seated and x.riding_swing.is_empty() and x.riding_seesaw == null and not x.in_boat and not x.has_umb and x.job != "scribe")
	var r: ResidentLetters = free[0]
	r._leave(); r.weather = "clear"
	r.fig.hold(town.make_item("paper", Vector3.ZERO)); r.carrying_kind = "paper"
	r.global_position = nb["pos"] + Vector3(0.35, 0.1, 0.05); r.spot = nb; r.slot = 1; r._claim(nb, 1); r.state = "busy"
	r._post_arrive(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.0).timeout
	print("R PIN notes=", notes.size(), " kind='", r.carrying_kind, "' (want 3 '')")
	r.state = "busy"; r.spot = nb; r.fig.pose_request = ""
	r._post_arrive(Time.get_ticks_msec() / 1000.0)
	await physics_frame
	print("R READ pose=", r.fig.pose_request, " busy=", r.state, " (want scan busy)")
	var scribes: Array = town.residents.filter(func(x): return x.job == "scribe")
	if not scribes.is_empty():
		var sc: ResidentLetters = scribes[0]
		sc._leave(); sc.weather = "clear"
		for n: Node3D in notes: n.set_meta("at", -1000.0)   # 모두 하루 넘게 묵었다
		town.clock = (16.3 - 6.0) / 24.0
		var picked := false
		sc.global_position = nb["pos"] + Vector3(-3, 0.05, 2)
		for k in 5:
			sc._release(); sc.state = "routine"
			if sc._post_pick(Time.get_ticks_msec() / 1000.0) and is_same(sc.spot, nb): picked = true; break
		var arrived := false
		for i in 600:
			await physics_frame
			if sc.state == "busy" and is_same(sc.spot, nb): arrived = true; break
		var n0 := notes.size()
		await create_timer(PostPoses.PIN_T * n0 + 0.3).timeout
		var cnt: int = int(sc.fig.carrying.get_meta("count", 0)) if sc.fig.carrying else 0
		print("SCRIBE picked=", picked, " arrived=", arrived, " notes ", n0, "->", notes.size(), " bundle=", cnt, " (want true true 3->0 3)")
		var lw: Dictionary = town.letterwall
		sc._leave(); sc.global_position = lw["pos"] + Vector3(-0.3, 0.1, 0.05); sc.spot = lw; sc.slot = 0; sc._claim(lw, 0); sc.state = "busy"; sc.door_ref = lw["door"]
		lw["stock"] = 5; town._show_stock(lw)
		sc._post_arrive(Time.get_ticks_msec() / 1000.0)
		await create_timer(1.5).timeout
		print("SCRIBE file stock 5->", lw["stock"], " hand=", sc.fig.carrying, " (want 8 null)")
		# run 101: 떼는 도중 넘어지면 이미 뗀 쪽지가 다발로 바닥에 떨어진다(전엔 셈만 하다 통째로 사라졌다)
		town.clock = (16.3 - 6.0) / 24.0
		for i in 3: town._add_note(town.note_slot(), -1000.0, "paper")
		sc._leave(); sc.global_position = nb["pos"] + Vector3(-0.35, 0.1, 0.05); sc.spot = nb; sc.slot = 0; sc._claim(nb, 0); sc.state = "busy"
		sc._post_arrive(Time.get_ticks_msec() / 1000.0)
		await create_timer(PostPoses.PIN_T + PostPoses.PIN_IN + 0.1).timeout
		var left := notes.size()
		sc.hit(Vector3(0, 0, 1), town.body, true)
		var dropped: Array = town.items.filter(func(it: Node3D) -> bool: return is_instance_valid(it) and it.has_meta("count"))
		var dc: int = int(dropped[0].get_meta("count")) if not dropped.is_empty() else 0
		print("KNOCK notes 3->", left, " dropped bundle=", dc, " (want 1, 2: nothing vanishes)")
		# 다발은 판에 못 꽂는다 — 들고 C 면 false(읽기로 넘어간다)
		town.body.global_position = nb["pos"] + Vector3(0, 0.02, 0)
		var b: Node3D = town.make_item("paper", Vector3.ZERO); b.set_meta("count", 2); town.player.hold(b)
		var n1 := notes.size()
		print("BUNDLE pin=", town.notice_use(Time.get_ticks_msec() / 1000.0), " notes ", n1, "->", notes.size(), " (want false, same)")
	quit()
