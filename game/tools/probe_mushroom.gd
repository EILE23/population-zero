extends SceneTree
## 통통 버섯 팩 점검(헤드리스): 자료가 읽히나, 잇단 발판 사이 넓은 틈 둘에 버섯이 자라나(아래 발판보다 sink 낮게), 갓 위로 떨어진 몸이 launch 로 던져져 위 발판보다 높이 가나(순수 step_vy 시뮬레이션),
## 갓 옆·갓 아래를 지나는 몸은 그냥 떨어지나, 갓이 눌렸다 돌아오나, bounce 자세가 웅크렸다 펼치고 착지 뒤 LAND_T 에 서나, 진짜 탑의 1..40층에서 plan 이 버섯을 몇 개 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var mu := ClimbMushroom.new(); root.add_child(mu)
	await process_frame
	print("PACK id=", mu.pack.get("id"), " kind=", mu.kind.size() > 0, " pose=", mu.pack.get("pose"))
	var plats: Array = [
		{ "id": "5r", "x": 200.0, "y": 3000.0, "w": 400.0, "kind": "rest", "z": 0.0, "d": 180.0 },
		{ "id": "5.0", "x": 100.0, "y": 3100.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "5.1", "x": 400.0, "y": 3210.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "5.2", "x": 600.0, "y": 3320.0, "w": 160.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "5.3", "x": 240.0, "y": 3430.0, "w": 120.0, "kind": "std", "z": -35.0, "d": 70.0 },
	]
	var planned := mu.plan(5, plats)
	var none := mu.plan(6, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	mu.build(band_root, planned)
	print("PLAN n5=", planned.size(), " (want 2: gap 240 at x 480,3260 and 120 at x 340,3040; the 50 gap is skipped) ids=", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + "@%.0f,%.0f" % [float(v["x"]), float(v["y"])]), " n6=", none.size(), " nodes=", band_root.get_child_count())
	# 몸: 아래 발판 높이(y 3100)에서 vy 0 으로 틈에 떨어진다 — 갓 위면 던져져 위 발판(3210)보다 높이, 옆이면 그냥 떨어진다
	var c: Dictionary = mu.caps[1]   # x 340 — 아래 발판 5.0(3100)과 5.1(3210) 사이
	var sim := func(x: float, y0: float) -> Array:
		var y := y0; var vy := 0.0; var apex := -1e9; var hit := false; var when := -1.0
		for i in 240:
			var dt := 1.0 / 60.0
			vy -= C.G * dt
			vy = mu.step_vy(x, float(y), float(c["z"]), vy, dt)
			if mu.bounced and not hit: hit = true; when = y
			y += vy * dt; apex = maxf(apex, y)
			if y < float(c["y"]) - 300.0: break
		return [apex, hit, when]
	var r_on: Array = sim.call(float(c["x"]), 3100.0); var r_off: Array = sim.call(float(c["x"]) + 60.0, 3100.0)
	print("BOUNCE on apex=%.0f hit=%s at y=%.0f (want hit near top %.0f, apex %.0f..%.0f > upper 3210) | off apex=%.0f hit=%s (want 3100, false)" % [r_on[0], r_on[1], r_on[2], mu.top(c), mu.top(c) + 240.0, mu.top(c) + 270.0, r_off[0], r_off[1]])
	# 갓이 눌렸다 돌아온다 — 튕긴 직후 scale.y < 1, 0.5초 뒤 1
	mu.step_vy(float(c["x"]), mu.top(c) + 1.0, float(c["z"]), -200.0, 1.0 / 60.0)
	var cap: Node3D = c["cap"]
	var low_y := 10.0; var high_y := 0.0
	for i in 60:
		await process_frame
		low_y = minf(low_y, cap.scale.y); high_y = maxf(high_y, cap.scale.y)
	await create_timer(0.6).timeout
	print("SQUASH low=%.2f (want < 0.8 — headless frames are coarse) high=%.2f (want > 1.05) back=%.2f (want 1.00) boing=%s" % [low_y, high_y, cap.scale.y, (c["boing"] as AudioStreamPlayer3D).stream != null])
	# 자세: 오르며 웅크리고(허벅지 ≈ -2.0), 떨어지며 펼치고(허벅지 ≈ 0.05, 어깨 ≈ -2.9), 착지 뒤 LAND_T 에 done
	var f := Stick3D.new(); root.add_child(f)
	f.pose_request = "bounce"; f.airborne = true; f.vertical = 30.0
	await process_frame; await process_frame; await process_frame
	var early: float = (f.hips[1.0] as Node3D).rotation.x
	for i in 40: await process_frame
	var tucked: float = (f.hips[1.0] as Node3D).rotation.x; var sh_tuck: float = (f.shoulders[1.0] as Node3D).rotation.x
	f.vertical = -5.0
	for i in 60: await process_frame
	var opened: float = (f.hips[1.0] as Node3D).rotation.x; var sh_open: float = (f.shoulders[1.0] as Node3D).rotation.x; var done_air := BouncePoses.done(f)
	f.airborne = false; f.vertical = 0.0
	var low := 10.0
	for i in 120:
		await process_frame
		low = minf(low, f.pelvis.position.y)
	print("POSE early=%.2f tucked=%.2f (want ≈ -2.0) sh_tuck=%.2f (want ≈ -1.35) opened=%.2f (want ≈ 0.05) sh_open=%.2f (want ≈ -2.8) done_air=%s done_land=%s pelvis_low=%.2f (want ≈ 0.12)" % [early, tucked, sh_tuck, opened, sh_open, done_air, BouncePoses.done(f), low])
	# 진짜 탑: 1..40층에 plan 이 찾는 버섯 수
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var g: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 41):
		var pl := mu.plan(n, g.band(n))
		if pl.size() > 0: bands.append(n); count += pl.size()
	print("TOWER floors=", bands, " caps=", count, " (want every 4th floor from 1 — 1, 5, 9 … 37)")
	quit()
