extends SceneTree
## 고드름 팩 점검(헤드리스): 자료가 읽히나, 테마 층에만 앞 발판을 향한 턱 밑에 고드름이 달리나(밑에 발판이 있는 턱부터 둘, 턱마다 둘), 시계가 자람 → 떨림 → 낙하(탑의 G) → 빈 턱 → 다시 자람으로 도나,
## 떠는·떨어지는 고드름 밑의 몸만 near 인가, 떨어지는 고드름이 몸에 닿으면 깨지며 공중의 몸은 아래로·선 몸은 hurt 를 받나(옆은 비고 두 번은 안 맞나), 그림이 자라고 떨고 사라지며 저절로 깨질 때 조각이 나나,
## duck 자세가 팔로 머리를 덮고 내려앉았다가 done 을 묻기 시작한 뒤 OUT_T 에 풀리나(hold 가 풀림을 지우나), 진짜 탑의 1..40층에서 plan 이 테마 층(20..24, 30..34)에만 고드름을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var ic := ClimbIcicle.new(); root.add_child(ic)
	await process_frame
	print("PACK id=", ic.pack.get("id"), " kind=", ic.kind.size() > 0, " pose=", ic.pack.get("pose"), " drop=", ic.pack.get("pose_drop"), " themes=", ic.pack.get("themes"))
	var plats: Array = [
		{ "id": "20.0", "x": 100.0, "y": 12100.0, "w": 200.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "20.1", "x": 400.0, "y": 12210.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "20.2", "x": 150.0, "y": 12320.0, "w": 160.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "20.3", "x": 500.0, "y": 12430.0, "w": 140.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "20.4", "x": 200.0, "y": 12540.0, "w": 120.0, "kind": "ice", "z": -35.0, "d": 70.0 },
		{ "id": "20s", "x": 700.0, "y": 12468.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var planned := ic.plan(20, plats)
	var none := ic.plan(25, plats)
	var star := ic.plan(30, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	ic.build(band_root, planned)
	print("PLAN n20=", planned.size(), " (want 4: lips 2 and 3 — the ones with a hop below — two icicles each; lip 1 hangs over nothing and lip 4 is third in line) ", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + "@%.0f,%.0f f%.0f p%.2f" % [float(v["x"]), float(v["y"]), float(v["floor"]), float(v["phase"])]), " n25=", none.size(), " (want 0, Cloud sea) n30=", star.size(), " (want 4, Starlit) nodes=", band_root.get_child_count())
	var s: Dictionary = ic.pins[0]
	var ft := ic.fall_t(s); var cyc := ic.cycle(s)
	ic.t = 3.0; var st0 := ic.state(s); var l0 := ic.length(s)
	ic.t = 6.2; var st1 := ic.state(s); var tip1 := ic.tip_y(s)
	ic.t = 6.6; var st2 := ic.state(s); var tip2 := ic.tip_y(s)
	ic.t = 6.95; var st3 := ic.state(s)
	ic.t = cyc + 0.3; var st4 := ic.state(s); var l4 := ic.length(s)
	print("CLOCK fall_t=%.3f (want 0.394 for a 186 px drop) cycle=%.3f (want 7.894) | t3 %s len=%.0f (want grow 17) | t6.2 %s tip=%.0f (want tremble 12286) | t6.6 %s tip=%.0f (want fall 12274) | t6.95 %s (want gone) | t%.1f %s len=%.1f (want grow, ≈ 1.7)" % [ft, cyc, st0, l0, st1, tip1, st2, tip2, st3, cyc + 0.3, st4, l4])
	# 경고: 20.0 위(293, 12100)에 선 몸 — 떨 때 true, 자랄 때 false, 옆(350)은 false
	ic.t = 6.2; var n_on := ic.near(293.0, 12100.0, -35.0); var n_side := ic.near(350.0, 12100.0, -35.0)
	ic.t = 3.0; var n_grow := ic.near(293.0, 12100.0, -35.0)
	print("NEAR tremble=%s (want true) side=%s grow=%s (want false false)" % [n_on, n_side, n_grow])
	# 맞음: 공중의 몸(300, 12250 — 상자 12250..12290, 끝 12274)이 떨어지는 고드름에 → 아래로 밀리고 lurch, 그 고드름은 깨져 gone; 옆(560)은 빈 사전; 두 번째 고드름(s2, 20.i3.0)은 선 몸(517, 12210)이 맞을 때 hurt 0.6 duck
	ic.t = 6.6; var h_side := ic.strike(560.0, 12250.0, -35.0, true)
	var h_air := ic.strike(300.0, 12250.0, -35.0, true); var st_hit := ic.state(s); var again := ic.strike(300.0, 12250.0, -35.0, true)
	var s2: Dictionary = ic.pins[2]
	var tau := sqrt(2.0 * (float(s2["y"]) - ic.len_px() - 12240.0) / C.G)   # 끝이 선 몸의 머리(발 + 30) 에 오는 때
	ic.t = float(s2["t0"]) + ic.grow_t() + ic.tremble_t() + tau
	var st_s2 := ic.state(s2); var h_ground := ic.strike(517.0, 12210.0, -35.0, false)
	print("STRIKE side=%s (want empty) air=%s (want vy -320 hurt 0.4 lurch) after=%s (want gone) again=%s (want empty) | s2 %s ground=%s (want fall; vy 0 hurt 0.6 duck)" % [h_side, h_air, st_hit, again, st_s2, h_ground])
	# 그림: 자랄 때 stem 이 반쯤, 떨 때 x 가 흔들리고, 빈 턱이면 안 보인다; 저절로 깨질 때 조각 넷이 층 노드에 붙는다
	var s3: Dictionary = ic.pins[3]
	ic.t = float(s3["t0"]) + 3.0; await process_frame
	var sc_grow: float = (s3["stem"] as Node3D).scale.y; var x_grow: float = (s3["node"] as Node3D).position.x
	ic.t = float(s3["t0"]) + ic.grow_t() + 0.21; await process_frame
	var x_trem: float = (s3["node"] as Node3D).position.x
	var before := band_root.get_child_count()
	ic.t = float(s3["t0"]) + ic.grow_t() + ic.tremble_t() + ic.fall_t(s3) - 0.005; await process_frame   # 낙하 끝 직전 — 다음 틱에 저절로 깨진다
	await process_frame
	var vis_gone: bool = (s3["stem"] as Node3D).visible; var after := band_root.get_child_count()
	var rang: bool = (s3["glass"] as AudioStreamPlayer3D).stream != null
	print("VISUAL grow scale=%.2f (want ≈ 0.5) tremble dx=%.3f (want ≠ 0, |dx| ≤ 0.017) gone visible=%s (want false) shards=%d (want 4) glass=%s" % [sc_grow, x_trem - x_grow, vis_gone, after - before, rang])
	# 자세: 팔이 머리 위로(어깨 ≈ -2.5), 팔꿈치 접힘(≈ -1.9), 무릎 접힘(≈ +0.95), 골반 0.28, 고개 앞으로; done 을 묻기 시작하면 OUT_T 뒤 true 이고 팔이 내려온다; 도중 hold 면 다시 감싼다
	var f := Stick3D.new(); root.add_child(f)
	f.pose_request = "duck"
	for i in 40: await process_frame   # 헤드리스 프레임은 ~7 ms — 40 프레임이 IN_T 의 두 배
	var sh_in: float = (f.shoulders[1.0] as Node3D).rotation.x; var el_in: float = (f.elbows[1.0] as Node3D).rotation.x; var kn_in: float = (f.knees[1.0] as Node3D).rotation.x; var pel_in: float = f.pelvis.position.y
	var d0 := DuckPoses.done(f)
	for i in 6: await process_frame
	DuckPoses.hold(f)
	for i in 10: await process_frame
	var sh_held: float = (f.shoulders[1.0] as Node3D).rotation.x
	var d1 := DuckPoses.done(f)
	var d_mid := false
	for i in 60:
		await process_frame
		if i == 8: d_mid = DuckPoses.done(f)
	var d2 := DuckPoses.done(f); var pt_out := f.pose_t; var off_out := float(f.get_meta("duck_off", -1.0)); var sh_out: float = (f.shoulders[1.0] as Node3D).rotation.x; var pel_out: float = f.pelvis.position.y
	print("POSE in sh=%.2f el=%.2f knee=%.2f pelvis=%.2f (want ≈ -2.5 -1.9 0.95 0.28) | done0=%s (want false, starts the release) held sh=%.2f (want ≈ -2.5 again after hold) done1=%s mid=%s (want false false) done2=%s (want true after 0.3 s; pose_t %.2f off %.2f) out sh=%.2f pelvis=%.2f (want ≈ 0 and 0.42)" % [sh_in, el_in, kn_in, pel_in, d0, sh_held, d1, d_mid, d2, pt_out, off_out, sh_out, pel_out])
	# 진짜 탑: 1..40층에 plan 이 찾는 고드름 수
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var g: Node3D = town.game_node
	var count := 0; var bands: Array = []; var below := 0
	for n in range(1, 41):
		var pl := ic.plan(n, g.band(n))
		if pl.size() > 0: bands.append(n); count += pl.size()
		for v in pl:
			if float((v as Dictionary)["floor"]) > float((v as Dictionary)["y"]) - 280.0: below += 1
	print("TOWER floors=", bands, " icicles=", count, " over_a_hop=", below, " (want only Wind cliffs 20..24 and Starlit 30..34, up to 4 each; most over a hop two steps down)")
	quit()
