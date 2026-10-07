extends SceneTree
## 유령 발판 팩 점검(헤드리스): 자료가 읽히나, 가장 긴 틈 하나에 판이 자라나(틈 가운데, 두 발판 높이의 중간, 양쪽 margin 을 남긴 너비), 박자의 앞 반만 단단한가, 끝 fade 초는 fading 이고 농도가 녹나,
## 단단할 때만 land 가 받고 유령일 땐 지나가나, 그림 농도·점선·종소리가 박자를 따르나, lurch 자세가 놀라 팔을 올리고 허우적거리다 착지 뒤 LAND_T 에 서나, 진짜 탑의 1..40층에서 plan 이 판을 몇 개 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var gh := ClimbGhost.new(); root.add_child(gh)
	await process_frame
	print("PACK id=", gh.pack.get("id"), " kind=", gh.kind.size() > 0, " pose=", gh.pack.get("pose"), " drop=", gh.pack.get("pose_drop"))
	var plats: Array = [
		{ "id": "2.0", "x": 100.0, "y": 1300.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "2.1", "x": 400.0, "y": 1410.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "2.2", "x": 600.0, "y": 1520.0, "w": 160.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "2.3", "x": 240.0, "y": 1630.0, "w": 120.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "2s", "x": 500.0, "y": 1458.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var planned := gh.plan(2, plats)
	var none := gh.plan(3, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	gh.build(band_root, planned)
	print("PLAN n2=", planned.size(), " (want 1: the 240 gap between 2.2 and 2.3 — x 420 w 120, y 1575; the 120 and 50 gaps lose) ids=", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + "@%.0f,%.0f w%.0f" % [float(v["x"]), float(v["y"]), float(v["w"])]), " n3=", none.size(), " nodes=", band_root.get_child_count())
	var s: Dictionary = gh.slabs[0]
	gh.t = 0.5; var a0 := gh.active(s); var f0 := gh.fading(s); var k0 := gh.solidity(s)
	gh.t = 1.75; var a1 := gh.active(s); var f1 := gh.fading(s); var k1 := gh.solidity(s)
	gh.t = 2.5; var a2 := gh.active(s); var k2 := gh.solidity(s)
	gh.t = 4.05; var k3 := gh.solidity(s)
	print("BEAT t0.5 on=%s fading=%s k=%.2f (want true false 1.00) | t1.75 on=%s fading=%s k=%.2f (want true true 0.62) | t2.5 on=%s k=%.2f (want false 0.00) | t4.05 k=%.2f (want 0.33, hardening)" % [a0, f0, k0, a1, f1, k1, a2, k2, k3])
	# 착지: 판 위 5px 에서 5px 아래로 떨어지는 틱 — 단단하면 받고(판 사전), 유령이면 비고, 옆이면 비고
	var sx := float(s["x"]) + float(s["w"]) / 2.0; var sy := float(s["y"])
	gh.t = 0.5; var l_on := gh.land(sx, sy + 5.0, sy - 5.0, float(s["z"]))
	gh.t = 2.5; var l_off := gh.land(sx, sy + 5.0, sy - 5.0, float(s["z"]))
	gh.t = 0.5; var l_side := gh.land(float(s["x"]) + float(s["w"]) + 30.0, sy + 5.0, sy - 5.0, float(s["z"]))
	var l_z := gh.land(sx, sy + 5.0, sy - 5.0, float(s["z"]) + 100.0)
	print("LAND on=%s (want 2.g0) off=%s side=%s far_z=%s (want all empty) holds_on=%s holds_off=%s" % [l_on.get("id", "-"), l_off.get("id", "-"), l_side.get("id", "-"), l_z.get("id", "-"), _holds(gh, s, 0.5), _holds(gh, s, 2.5)])
	# 그림: 단단할 때 몸통 알파 1·점선 0, 유령일 때 몸통 0·점선 1, 굳는 순간 종
	gh.t = 1.0; await process_frame
	var body_on: float = (s["mats"][0] as StandardMaterial3D).albedo_color.a; var dot_on: float = (s["dot_mat"] as StandardMaterial3D).albedo_color.a
	gh.t = 3.0; await process_frame
	var body_off: float = (s["mats"][0] as StandardMaterial3D).albedo_color.a; var dot_off: float = (s["dot_mat"] as StandardMaterial3D).albedo_color.a
	gh.t = 4.02; await process_frame
	var rang: bool = (s["chime"] as AudioStreamPlayer3D).playing or (s["chime"] as AudioStreamPlayer3D).stream != null
	print("VISUAL solid body=%.2f dots=%.2f (want 1 0) | ghost body=%.2f dots=%.2f (want 0 1) | chime=%s" % [body_on, dot_on, body_off, dot_off, rang])
	# 자세: 팔이 위로(어깨 -2.0..-3.2 — 놀람 2.6 에서 풍차로), 허벅지가 찬다(-0.1..-1.2), 허우적거림(어깨가 -2.0..-3.2 사이를 돈다), 착지 뒤 LAND_T 에 done, 골반 0.12 까지
	var f := Stick3D.new(); root.add_child(f)
	f.pose_request = "lurch"; f.airborne = true; f.vertical = -3.0
	await process_frame; await process_frame; await process_frame
	var early: float = (f.shoulders[1.0] as Node3D).rotation.x
	for i in 30: await process_frame
	var snap: float = (f.shoulders[1.0] as Node3D).rotation.x; var hip_snap: float = (f.hips[1.0] as Node3D).rotation.x
	var lo := 10.0; var hi := -10.0
	for i in 80:
		await process_frame
		var v: float = (f.shoulders[1.0] as Node3D).rotation.x
		lo = minf(lo, v); hi = maxf(hi, v)
	var done_air := LurchPoses.done(f)
	f.airborne = false; f.vertical = 0.0
	var low := 10.0
	for i in 120:
		await process_frame
		low = minf(low, f.pelvis.position.y)
	print("POSE early=%.2f (≈ -0.04, before the startle) up=%.2f (want inside -3.2..-2.0 — headless frames are ~16 ms, so 30 frames is already the windmill) hip=%.2f (want inside -1.2..-0.1, kicking) flail lo=%.2f hi=%.2f (want spread ≥ 0.6 inside -3.3..-1.9) spread_ok=%s done_air=%s done_land=%s pelvis_low=%.2f (want ≈ 0.12)" % [early, snap, hip_snap, lo, hi, hi - lo >= 0.6 and lo >= -3.3 and hi <= -1.9, done_air, LurchPoses.done(f), low])
	# 진짜 탑: 1..40층에 plan 이 찾는 판 수
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var g: Node3D = town.game_node
	var count := 0; var bands: Array = []; var ws: Array = []
	for n in range(1, 41):
		var pl := gh.plan(n, g.band(n))
		if pl.size() > 0: bands.append(n); count += pl.size()
		for v in pl: ws.append(int(float(v["w"])))
	print("TOWER floors=", bands, " slabs=", count, " widths=", ws, " (want every 4th floor from 2 — 2, 6, 10 … 38 — one each where two std hops meet, widths 44..120)")
	quit()

func _holds(gh: ClimbGhost, s: Dictionary, at: float) -> bool:
	gh.t = at
	return gh.holds(s)
