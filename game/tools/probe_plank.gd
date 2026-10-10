extends SceneTree
## 다이빙 판 팩 점검(헤드리스): 자료가 읽히나, 구름바다 층의 잇단 두 발판 사이 틈(90..240, 높이차 160 안) 중 널의 상자를 다른 판이 가르지 않고 taken 조각(뗏목)이 닿지 않는 가장 넓은 하나에만 널이 서나(통풍구 층·다른 테마 층은 아니다, 지름길 판이 틈에 있으면 진다, 움직이는 발판 옆은 아니다),
## 널 위로 떨어지는 몸만 land 가 받나(집게 쪽·끝 너머·이미 밑·앞뒤 밖은 아니다), 끝에 선 몸의 무게로 끝이 18 처지고(bend_s 0.25) 반쯤에선 제곱으로 덜 처지나, 끝 24 안에서만 poised 인가, 끝을 지나면 off 인가,
## 탭 셋이 쌓이고 넷째가 던지나(vx 300 vy 980, twang), 0.6초를 넘긴 탭은 처음부터인가, 탭의 눌림과 튀어오름(2.0875 → −30.15, 2.2625 → −13.95), 던진 뒤 널이 12 가까이 튀어 올랐다(2.9417 → 10.16) 1초 뒤 멎나, 끝 밖의 SPACE 는 안 받나,
## 집게·볼트 둘·스프링·널 노드·creak·twang 과 널 안의 판·먹줄 셋·미끄럼막이가 그려지나, 널이 처짐만큼 도나, bound 자세가 널 위에서 팔을 앞으로 젓고 무릎을 접다 날면 팔을 머리 위로 뻗고 꼭대기를 지나 접고 착지에 무릎이 받치나, 진짜 탑의 1..60층에서 plan 이 구름바다 층(25, 26, 28, 29, 60, 61, 62, 64)에만 널을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cp := ClimbPlank.new(); root.add_child(cp)
	var cr := ClimbRaft.new(); root.add_child(cr)
	var mu := ClimbMushroom.new(); root.add_child(mu)
	await process_frame
	print("PACK id=", cp.pack.get("id"), " kind=", cp.kind.size() > 0, " pose=", cp.pack.get("pose"), " themes=", cp.pack.get("themes"), " length=%.0f sag=%.0f tip_zone=%.0f loads=%d tap=%.2f gap=%.2f bend=%.2f quiver=%.2f (want 70 18 24 3 0.35 0.60 0.25 1.00)" % [cp.length(), cp.sag(), cp.tip_zone(), cp.loads(), cp.tap_s(), cp.gap_s(), cp.bend_s(), cp.quiver_s()])
	var plats: Array = [
		{ "id": "25r", "x": 250.0, "y": 14900.0, "w": 400.0, "kind": "rest", "z": 0.0, "d": 180.0 },
		{ "id": "25.0", "x": 100.0, "y": 15100.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "25.1", "x": 400.0, "y": 15200.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "25.2", "x": 700.0, "y": 15300.0, "w": 200.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "25.3", "x": 420.0, "y": 15420.0, "w": 160.0, "kind": "ice", "z": -35.0, "d": 70.0 },
		{ "id": "25.4", "x": 200.0, "y": 15540.0, "w": 170.0, "kind": "move", "z": -35.0, "d": 70.0 },
		{ "id": "25.5", "x": 25.0, "y": 15650.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "25s", "x": 680.0, "y": 15468.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var free := cp.plan(25, plats)
	var rafted := cp.plan(25, plats, [{ "id": "25.c0", "kind": "raft", "x": 600.0, "w": 60.0, "y": 15250.0 }])
	var cut := plats.duplicate(true); cut.append({ "id": "25c", "x": 590.0, "y": 15230.0, "w": 50.0, "kind": "short", "z": -35.0, "d": 60.0 })   # 가장 넓은 틈에 지름길 판 — 널이 걸린다
	var cutp := cp.plan(25, cut)
	var ghost := cp.plan(26, plats); var vent := cp.plan(27, plats); var bridge := cp.plan(28, plats); var wind := cp.plan(24, plats); var high := cp.plan(60, plats); var star := cp.plan(30, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cp.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " %s-%s gap %.0f edge %.0f tip %.0f dir %.0f a_y %.0f b_y %.0f x %.0f w %.0f z %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"]), float(v["edge"]), float(v["tip"]), float(v["dir"]), float(v["a_y"]), float(v["b_y"]), float(v["x"]), float(v["w"]), float(v["z"])]
	print("PLAN free=", free.map(show), " (want 1: 25.P0 25.1-25.2 gap 150 edge 550 tip 620 dir 1 a_y 15200 b_y 15300 x 550 w 70 z −35 — 25.0-25.1 and 25.2-25.3 are 120, 25.4 moves → out)")
	print("PLAN rafted=", rafted.map(show), " (want 25.0-25.1 gap 120 edge 280 tip 350: the raft takes the widest gap, the lower 120 wins the tie) cut=", cutp.map(show), " (want 25.0-25.1: a shortcut slab in the widest gap) ghost=", ghost.size(), " vent=", vent.size(), " bridge=", bridge.size(), " wind=", wind.size(), " high=", high.size(), " star=", star.size(), " (want 1 0 1 0 1 0)")
	var s: Dictionary = cp.planks[0]
	var z := C.PLAYER_Z
	# 착지(t 1): 널 위(600, 15205 → 15195)는 받는다; 집게 쪽 530·끝 너머 630·이미 밑 15195→15185·앞 z 20 은 아니다
	cp.sync(1.0)
	var l_ok := cp.land(600.0, 15205.0, 15195.0, z)
	var l_root := cp.land(530.0, 15205.0, 15195.0, z); var l_past := cp.land(630.0, 15205.0, 15195.0, z); var l_under := cp.land(600.0, 15195.0, 15185.0, z); var l_front := cp.land(600.0, 15205.0, 15195.0, 20.0)
	print("LAND ok kind=%s x=%.0f y=%.0f w=%.0f (want plank 550 15200 70) | root=%s past=%s under=%s front=%s (want true ×4: empty)" % [l_ok.get("kind", "-"), float(l_ok.get("x", 0.0)), float(l_ok.get("y", 0.0)), float(l_ok.get("w", 0.0)), l_root.is_empty(), l_past.is_empty(), l_under.is_empty(), l_front.is_empty()])
	# 서기: 1.0 끝(620)에 0.25초 → 무게 1, y 15182, poise; 1.1 반쯤(585)에 0.1초 → 무게 0.6, y 15197.30, poise 아님; 1.2 끝 너머(626) → off
	var fig := Stick3D.new(); root.add_child(fig)
	var r1 := cp.stand(l_ok, 620.0, 0.25, fig); var d1 := float(fig.get_meta("bound_dip", 9.0)); var k1 := float(fig.get_meta("bound_k", 9.0))
	cp.sync(1.1); var r2 := cp.stand(l_ok, 585.0, 0.1, fig)
	cp.sync(1.2); var r3 := cp.stand(l_ok, 626.0, 0.1, fig)
	var p_in := cp.poised(l_ok, 600.0); var p_out := cp.poised(l_ok, 580.0)
	print("STAND 1.0 tip: y=%.2f off=%s poise=%s dip=%.2f k=%.2f (want 15182.00 false true −1.00 0.00) | 1.1 half: y=%.2f poise=%s (want 15197.30 false) | 1.2 past: off=%s (want true) | poised 600=%s 580=%s (want true false)" % [float(r1["y"]), r1["off"], r1["poise"], d1, k1, float(r2["y"]), r2["poise"], r3["off"], p_in, p_out])
	# 탭: 1.9 끝에 서서(무게 1) 2.0·2.3·2.6 탭 → 1·2·3 쌓이고(creak), 2.9 넷째 → 던진다(vx 300 vy 980, twang); 눌림 2.0875 → −30.15, 튀어오름 2.2625 → −13.95; 던진 뒤 2.9417 → 10.16, 3.95 → 0; 4.0 탭 → 1, 4.8 탭(0.8 뒤) → 다시 1; 끝 밖(580)의 탭은 안 받는다
	cp.sync(1.9); cp.stand(l_ok, 620.0, 0.25, fig)
	cp.sync(2.0); var t1 := cp.tap(l_ok, 620.0); var creak: AudioStreamPlayer3D = s["creak"]; var creak_on := creak.playing
	var dy_press := cp.tip_dy(s, 2.0875); var dy_spring := cp.tip_dy(s, 2.2625)
	cp.sync(2.3); var t2 := cp.tap(l_ok, 620.0); cp.sync(2.6); var t3 := cp.tap(l_ok, 620.0)
	cp.sync(2.9); var t4 := cp.tap(l_ok, 620.0); var twang: AudioStreamPlayer3D = s["twang"]; var twang_on := twang.playing
	var dy_snap := cp.tip_dy(s, 2.9417); var dy_still := cp.tip_dy(s, 3.95)
	cp.sync(4.0); var t5 := cp.tap(l_ok, 620.0); cp.sync(4.8); var t6 := cp.tap(l_ok, 620.0); var t_out := cp.tap(l_ok, 580.0)
	print("TAP loads=%d %d %d (want 1 2 3) creak=%s | fourth: took=%s fling=%s vx=%.0f vy=%.0f twang=%s (want true true 300 980 true) | press=%.2f spring=%.2f (want −30.15 −13.95) | snap=%.2f still=%.2f (want 10.16 0.00) | 4.0 → %d, 4.8 → %d (want 1 1: settled) | outside took=%s (want false)" % [int(t1["load"]), int(t2["load"]), int(t3["load"]), creak_on, t4["took"], t4["fling"], float(t4["vx"]), float(t4["vy"]), twang_on, dy_press, dy_spring, dy_snap, dy_still, int(t5["load"]), int(t6["load"]), t_out["took"]])
	# 그림: 노드 아이 7(집게·볼트 둘·스프링·널·creak·twang), 널 아이 5(판·먹줄 셋·미끄럼막이); 노드 자리 1.944 422.222 −0.972; 빈 널은 0, 끝에 몸이 서면 −0.2515
	var node: Node3D = s["node"]; var board: Node3D = s["board"]
	s["load"] = 0; s["last_tap"] = -9.0; s["tap_t"] = -9.0; s["fling_t"] = -9.0; s["weight"] = 0.0; s["stood"] = -9.0
	cp.sync(9.0); cp._process(0.0); var rot_empty := board.rotation.z
	s["weight"] = 1.0; s["stood"] = 9.0; cp._process(0.0); var rot_full := board.rotation.z
	print("VISUAL node children=", node.get_child_count(), " (want 7) board children=", board.get_child_count(), " (want 5) node pos=%.3f %.3f %.3f (want 1.944 422.222 −0.972) | empty rot=%.4f (want 0.0000) full rot=%.4f (want −0.2515)" % [node.position.x, node.position.y, node.position.z, rot_empty, rot_full])
	# 자세: 준비(k 1, dip −1): 엉덩이 −0.70, 무릎 1.15, 어깨 +0.40(팔이 아래로 쓸린다), 골반 0.220; 뻗기(airborne, 오름): 엉덩이 +0.10, 무릎 0.05, 어깨 −2.95, 팔꿈치 0; 접기(내림): 엉덩이 −1.30, 무릎 0.15, 어깨 −1.40; 착지: 무릎 1.6 가까이 받치고, 0.3 뒤 done
	fig.pose_request = "bound"
	fig.set_meta("bound_k", 1.0); fig.set_meta("bound_dip", -1.0)
	for i in 90: await process_frame
	var hip_g: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_g: float = (fig.knees[1.0] as Node3D).rotation.x; var sh_g: float = (fig.shoulders[1.0] as Node3D).rotation.x; var pel_g := fig.pelvis.position.y
	fig.airborne = true; fig.vertical = 6.0
	for i in 90: await process_frame   # 헤드리스 프레임은 짧다 — 30 프레임으론 0.15/0.2 블렌드가 다 차지 않아 뻗기·접기가 섞여 읽혔다
	var hip_u: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_u: float = (fig.knees[1.0] as Node3D).rotation.x; var sh_u: float = (fig.shoulders[1.0] as Node3D).rotation.x; var el_u: float = (fig.elbows[1.0] as Node3D).rotation.x
	fig.vertical = -1.0
	for i in 90: await process_frame
	var hip_p: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_p: float = (fig.knees[1.0] as Node3D).rotation.x; var sh_p: float = (fig.shoulders[1.0] as Node3D).rotation.x
	fig.airborne = false; fig.vertical = 0.0
	await process_frame
	var done_early := BoundPoses.done(fig); var knee_b := 0.0
	for i in 20:   # 받침의 꼭대기(착지 0.15초 뒤)를 프레임 수에 기대지 않고 가장 깊은 무릎으로 읽는다
		await process_frame
		knee_b = maxf(knee_b, (fig.knees[1.0] as Node3D).rotation.x)
	for i in 30: await process_frame
	var done_late := BoundPoses.done(fig)
	print("POSE poise: hip=%.2f knee=%.2f shoulder=%.2f pelvis=%.3f (want −0.70 1.15 0.40 0.220) | stretch: hip=%.2f knee=%.2f shoulder=%.2f elbow=%.2f (want 0.10 0.05 −2.95 ±0.00) | pike: hip=%.2f knee=%.2f shoulder=%.2f (want −1.30 0.15 −1.40) | land: knee=%.2f (want > 1.4: the brace near its peak) done=%s then %s (want false true)" % [hip_g, knee_g, sh_g, pel_g, hip_u, knee_u, sh_u, el_u, hip_p, knee_p, sh_p, knee_b, done_early, done_late])
	# 진짜 탑: 1..60층에 plan 이 찾는 널 — 구름바다 층 25, 26, 28, 29, 60, 61, 62, 64 중 뗏목·버섯이 안 가져간 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var out := cp.plan(n, pl, cr.plan(n, pl) + mu.plan(n, pl))
		if out.size() > 0: bands.append("%d:%s" % [n, out.map(func(v: Dictionary) -> String: return "%s-%s gap %.0f dy %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"]), float(v["b_y"]) - float(v["a_y"])])]); count += out.size()
	print("TOWER floors=", bands, " planks=", count, " (want a subset of 25, 26, 28, 29, 60, 61, 62, 64 — one each)")
	quit()
