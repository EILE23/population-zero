extends SceneTree
## 풀무 승강기 팩 점검(헤드리스): 자료가 읽히나, 태엽 층(바람구멍 층은 빼고)의 잇단 발판 짝(100..220 px 틈, 위 발판이 40..140 px 높이; 위 발판은 crumble·spring 도 된다) 중 가장 넓은 틈에만 풀무가 서나(띠 깔린 발판·뻐꾸기 집·움직이는 발판의 틈은 비켜 가나, 거울상, 층 15/17/18/19/20/50/51/52),
## 윗판 위에서만 SPACE 가 풀무의 것인가(발판 위·윗판 끝 너머·다른 발판은 아니다), 구름마다 24 오르고 꼭대기(126 = 90 + 60 − 24)에서 clank, 0.6 뒤 10 px/s 로 가라앉아 바닥에 sigh, 1초 걸음의 꾸준한 구름이 끝까지 오르나(8번), 윗판이 0.12 에 6 눌렸다 0.25 에 돌아오나,
## 올라온 판과 윗판을 지나는 몸·catch 안에서 내려서는 몸·밑 catch 안의 몸만 land 가 받나(옆·앞·오르는 몸·멀리 위·밑은 아니다), 선 몸 밑에서 판이 가라앉고 제 부분의 어느 끝이든 넘으면 off 인가, 받침 팔·판 둘·가죽·관 둘·실린더·레일 둘·막대·판·압력계·소리 셋이 그려지나,
## stomp 자세가 준비에서 무릎을 풀고 팔을 앞으로 들며, 구름에 한 무릎이 올라오고 팔이 휘두르며 뒤로 젖혀지고, 내리꽂힐 때 앞으로 쏠리나, 진짜 탑의 1..60층에서 plan 이 태엽 층에만 풀무를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cl := ClimbBellows.new(); root.add_child(cl)
	var cg := ClimbGears.new(); root.add_child(cg)
	var pk := ClimbPerch.new(); root.add_child(pk)
	var cpn := ClimbPendulum.new(); root.add_child(cpn)
	var gh := ClimbGhost.new(); root.add_child(gh)
	var cb := ClimbBridge.new(); root.add_child(cb)
	var cm := ClimbMushroom.new(); root.add_child(cm)
	await process_frame
	print("PACK id=", cl.pack.get("id"), " kind=", cl.kind.size() > 0, " pose=", cl.pack.get("pose"), " themes=", cl.pack.get("themes"), " board_w=%.0f piston_w=%.0f step=%.0f rest_d=%.0f top_short=%.0f stamp=%.0f hold=%.1f sink=%.0f give=%.0f press=%.2f back=%.2f catch=%.0f deck_d=%.0f (want bellows true stomp [Clockwork] 32 36 16 60 24 24 0.6 10 6 0.12 0.25 16 28)" % [cl.board_w(), cl.piston_w(), cl.step_px(), cl.rest_d(), cl.top_short(), cl.stamp_px(), cl.hold_s(), cl.sink_v(), cl.give(), cl.press_s(), cl.back_s(), cl.catch_px(), cl.deck_d()])
	var plats: Array = [
		{ "id": "16.0", "x": 100.0, "y": 9600.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.1", "x": 440.0, "y": 9690.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.2", "x": 150.0, "y": 9800.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "16.3", "x": 450.0, "y": 9900.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.4", "x": 640.0, "y": 9930.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16s", "x": 560.0, "y": 9960.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cl.plan(16, plats)
	var belted := cl.plan(16, plats, [{ "id": "16.g0", "kind": "gears", "x": 100.0, "w": 180.0, "y": 9600.0 }])   # 띠가 16.0 에 — 그 가장자리의 윗판은 안 된다; 16.2→16.3 (140) 이 16.1→16.2 (130) 을 이긴다
	var housed := cl.plan(16, plats, [{ "id": "16.H0", "kind": "perch", "x": 200.0, "w": 72.0, "y": 9645.0, "len": 86.0 }])   # 집(190..282, 9635..9741)이 16.0↔16.1 의 상자(276..382, 9471..9716)만 가른다
	var moved := plats.duplicate(true); moved.append({ "id": "16m", "x": 330.0, "y": 9650.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째(230..490, 9650) 16.0↔16.1 과 16.1↔16.2 의 상자에 든다
	var movep := cl.plan(16, moved)
	var flat := plats.duplicate(true); (flat[1] as Dictionary)["y"] = 9630.0   # 16.0→16.1 dy 30 (너무 낮다), 16.1→16.2 dy 170 (너무 높다) — 16.2→16.3 만 남는다
	var flatp := cl.plan(16, flat)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := cl.plan(16, mirror)
	var f15 := cl.plan(15, plats); var f17 := cl.plan(17, plats); var f18 := cl.plan(18, plats); var f19 := cl.plan(19, plats); var f20 := cl.plan(20, plats); var f50 := cl.plan(50, plats); var f51 := cl.plan(51, plats); var f52 := cl.plan(52, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cl.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f dy %.0f %s→%s a_edge %.0f b_edge %.0f px %.0f max_lift %.0f x_in %.0f x_out %.0f x %.0f w %.0f y %.0f z %.0f d %.0f part %s" % [float(v["dir"]), float(v["gap"]), float(v["dy"]), String(v["a_id"]), String(v["b_id"]), float(v["a_edge"]), float(v["b_edge"]), float(v["px"]), float(v["max_lift"]), float(v["x_in"]), float(v["x_out"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["z"]), float(v["d"]), String(v["part"])]
	print("PLAN free=", free.map(show), " (want 1: 16.B0 dir 1 gap 160 dy 90 16.0→16.1 wins over 16.2→16.3 gap 140 and 16.1→16.2 gap 130, 16.3→16.4 gap 70 out: a_edge 280 b_edge 440 px 360 max_lift 126 x_in 280 x_out 312 x 280 w 32 y 9600 z −48 d 28 board)")
	var brief := func(v: Dictionary) -> String: return String(v["id"]) + " %s→%s dir %.0f gap %.0f px %.0f max_lift %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["px"]), float(v["max_lift"])]
	print("PLAN belted=", belted.map(brief), " (want 16.B0 16.2→16.3 dir 1 gap 140 px 380 max_lift 136) housed=", housed.map(brief), " (want the same) moved=", movep.map(brief), " (want the same) flat=", flatp.map(brief), " (want the same) mirror=", right.map(brief), " (want 16.B0 16.0→16.1 dir −1 gap 160 px 600 max_lift 126)")
	print("FLOORS 15=%d 17=%d 18=%d 19=%d 20=%d 50=%d 51=%d 52=%d (want 0 1 1 0 0 1 0 1 — vent floors 15, 19, 51 and the Wind cliffs floor 20 get none)" % [f15.size(), f17.size(), f18.size(), f19.size(), f20.size(), f50.size(), f51.size(), f52.size()])
	var s: Dictionary = cl.lifts[0]
	var z := C.PLAYER_Z
	var fig := Stick3D.new(); root.add_child(fig)
	var dt := 0.0625
	var wheeze: AudioStreamPlayer3D = s["wheeze"]; var clank: AudioStreamPlayer3D = s["clank"]; var sigh: AudioStreamPlayer3D = s["sigh"]
	var got: Dictionary = { "kind": "bellows", "id": "16.B0", "part": "board", "x": 280.0, "y": 9600.0, "w": 32.0, "z": z, "d": 28.0 }
	# 구름(0.0): x 290 은 윗판(poised), 270 은 발판·320 은 끝 너머·다른 발판 사전은 아니다; 거기선 stamp 가 took 거짓. x 290 의 stamp: lift 24, count 1, top 거짓, wheeze, 발 +1, 메타
	cl.sync(0.0)
	var p_on := cl.poised(got, 290.0); var p_hop := cl.poised(got, 270.0); var p_past := cl.poised(got, 320.0); var p_other := cl.poised(plats[0], 290.0)
	var no := cl.stamp(got, 320.0, fig)
	var st := cl.stamp(got, 290.0, fig); var wh := wheeze.playing; var ck := clank.playing
	var r0 := cl.stand(got, 290.0, dt, fig)
	print("STAMP poised on=%s hop=%s past=%s other=%s (want true false false false) | refused took=%s (want false) | took=%s lift=%.0f count=%d top=%s wheeze=%s clank=%s (want true 24 1 false true false) | metas s=%.1f f=%.0f k=%.4f dip=%.1f (want 0.0 1 0.1905 0.0) | stand y=%.0f off=%s poised=%s lift=%.0f part=%s (want 9600 false true 24 board)" % [p_on, p_hop, p_past, p_other, no["took"], st["took"], float(st["lift"]), int(st["count"]), st["top"], wh, ck, float(fig.get_meta("stomp_s")), float(fig.get_meta("stomp_f")), float(fig.get_meta("stomp_k")), float(fig.get_meta("stomp_dip")), float(r0["y"]), r0["off"], r0["poised"], float(r0["lift"]), String(r0["part"])])
	# 윗판의 눌림: 0.06 → 9597, 0.12 → 9594, 0.245 → 9597, 0.37 → 9600 (메타 dip 0.5 1.0 0.5 0.0); 피스톤: 0.6 → 24 (아직 hold), 1.6 → 14, 3.0 → 0 에 sigh, 판 9540
	cl.sync(0.06); var y06 := float(cl.stand(got, 290.0, dt, fig)["y"]); var d06 := float(fig.get_meta("stomp_dip"))
	cl.sync(0.12); var y12 := float(cl.stand(got, 290.0, dt, fig)["y"]); var d12 := float(fig.get_meta("stomp_dip"))
	cl.sync(0.245); var y245 := float(cl.stand(got, 290.0, dt, fig)["y"])
	cl.sync(0.37); var y37 := float(cl.stand(got, 290.0, dt, fig)["y"]); var d37 := float(fig.get_meta("stomp_dip"))
	cl.sync(0.6); var l06 := cl.lift_of(s)
	cl.sync(1.6); var l16 := cl.lift_of(s)
	sigh.stop()
	cl.sync(3.0); var l30 := cl.lift_of(s); var sg := sigh.playing; var py30 := cl.plate_y(s); var up30 := bool(s["up"])
	print("GIVE 0.06 y=%.1f dip=%.2f (want 9597.0 0.50) 0.12 y=%.1f dip=%.2f (want 9594.0 1.00) 0.245 y=%.1f (want 9597.0) 0.37 y=%.1f dip=%.2f (want 9600.0 0.00) | SINK 0.6 lift=%.1f (want 24.0) 1.6 lift=%.1f (want 14.0) 3.0 lift=%.1f sigh=%s plate=%.0f up=%s (want 0.0 true 9540 false)" % [y06, d06, y12, d12, y245, y37, d37, l06, l16, l30, sg, py30, up30])
	# 꾸준한 구름(3.0 부터 1초마다): 24 44 64 84 104 124, 9.0 에 126 (꼭대기, clank), 9.3 에 다시 눌러도 126 (clank 없음); count 9; 판 9666 (= 9690 − 24)
	var lifts: Array = []
	var top_at := -1.0; var clank_at := -1.0
	for i in 7:
		var now := 3.0 + float(i)
		cl.sync(now); clank.stop()
		var r := cl.stamp(got, 290.0, fig)
		lifts.append(float(r["lift"]))
		if bool(r["top"]) and top_at < 0.0: top_at = now
		if clank.playing and clank_at < 0.0: clank_at = now
	cl.sync(9.3); clank.stop()
	var again := cl.stamp(got, 290.0, fig); var ck93 := clank.playing
	print("STEADY lifts=", lifts, " (want [24, 44, 64, 84, 104, 124, 126]) top_at=%.1f clank_at=%.1f (want 9.0 9.0) | 9.3: lift=%.0f top=%s clank=%s count=%d (want 126 true false 9) plate=%.0f (want 9666)" % [top_at, clank_at, float(again["lift"]), again["top"], ck93, int(again["count"]), cl.plate_y(s)])
	# 착지(9.3, 판 9666 at 342..378, 윗판 9600 at 280..312): 판을 지나는 몸·10 위 step·11 밑 ramp 는 받는다(piston); x 330 은 둘 다 아니다; 윗판을 지나는 몸(board); 오르는 몸·앞(z −20)·34 위·26 밑은 아니다
	var cross := cl.land(360.0, 9670.0, 9660.0, z); var step := cl.land(360.0, 9676.0, 9675.0, z); var ramp := cl.land(360.0, 9655.0, 9654.9, z); var between := cl.land(330.0, 9670.0, 9660.0, z)
	var board := cl.land(300.0, 9602.0, 9598.0, z); var rising := cl.land(360.0, 9670.0, 9671.0, z); var front := cl.land(360.0, 9670.0, 9660.0, -20.0); var high := cl.land(360.0, 9700.0, 9699.0, z); var low := cl.land(360.0, 9640.0, 9639.0, z)
	print("LAND cross=%s part=%s y=%.0f x=%.0f w=%.0f z=%.0f d=%.0f step=%s ramp=%s (want bellows piston 9666 342 36 −48 28 false false) | step=%s %s (want piston true) ramp=%s %s (want piston true) | between=%s board=%s y=%.0f (want empty, board 9600) | rising=%s front=%s high=%s low=%s (want empty ×4)" % [String(cross.get("kind", "")), String(cross.get("part", "")), float(cross.get("y", 0.0)), float(cross.get("x", 0.0)), float(cross.get("w", 0.0)), float(cross.get("z", 0.0)), float(cross.get("d", 0.0)), cross.get("step", false), cross.get("ramp", false), String(step.get("part", "")), step.get("step", false), String(ramp.get("part", "")), ramp.get("ramp", false), between.is_empty(), String(board.get("part", "")), float(board.get("y", 0.0)), rising.is_empty(), front.is_empty(), high.is_empty(), low.is_empty()])
	# 판 위(10.9: 9.3 + 0.6 + 1.0 → lift 116, 판 9656): x 360 은 선다(poised 거짓), 385 는 끝을 넘어 off; 윗판에서 320·276 은 off; 모르는 풀무는 off
	cl.sync(10.9)
	var on_p := cl.stand(cross, 360.0, dt, fig); var off_p := cl.stand(cross, 385.0, dt, fig); var off_b1 := cl.stand(got, 320.0, dt, fig); var off_b0 := cl.stand(got, 276.0, dt, fig); var lost := cl.stand({ "id": "nope", "y": 7.0 }, 50.0, dt)
	print("STAND plate: y=%.0f off=%s poised=%s lift=%.0f part=%s (want 9656 false false 116 piston) | plate far: off=%s (want true) | board past=%s in=%s (want true true) | unknown off=%s y=%.0f (want true 7)" % [float(on_p["y"]), on_p["off"], on_p["poised"], float(on_p["lift"]), String(on_p["part"]), off_p["off"], off_b1["off"], off_b0["off"], lost["off"], float(lost["y"])])
	# 그림: 노드 아이 15(받침 팔·아랫판·가죽·윗판·관 둘·실린더·레일 둘·막대·판·압력계·소리 셋), 가죽 4, 윗판 2, 막대 1, 판 2, 압력계 2, 바늘 1; 노드 자리 −5.5556 266.6667 −1.3333
	# 쉼: 윗판 y 0, 가죽 scale 0.8333, 막대 0.05, 판 y −1.6667, 바늘 0; 꼭대기(126): 막대 3.5, 판 1.8333, 바늘 −2.4; 눌림(0.06 뒤): 윗판 −0.0833, 가죽 0.75
	var node: Node3D = s["node"]; var leather: Node3D = s["leather"]; var bd: Node3D = s["board"]; var rod: Node3D = s["rod"]; var plate: Node3D = s["plate"]; var needle: Node3D = s["needle"]; var gauge: Node3D = needle.get_parent()
	s["last"] = -99.0; s["lift0"] = 0.0; cl._place(s); var by_r := bd.position.y; var ls_r := leather.scale.y; var rs_r := rod.scale.y; var py_r := plate.position.y; var nz_r := needle.rotation.z
	s["last"] = cl.t; s["lift0"] = 126.0; cl._place(s); var rs_t := rod.scale.y; var py_t := plate.position.y; var nz_t := needle.rotation.z
	s["last"] = cl.t - 0.06; cl._place(s); var by_d := bd.position.y; var ls_d := leather.scale.y
	print("VISUAL node children=%d (want 15) leather=%d (want 4) board=%d (want 2) rod=%d (want 1) plate=%d (want 2) gauge=%d (want 2) needle=%d (want 1) node pos=%.4f %.4f %.4f (want −5.5556 266.6667 −1.3333) | rest: board y=%.4f leather=%.4f rod=%.2f plate y=%.4f needle=%.1f (want 0.0000 0.8333 0.05 −1.6667 0.0) | top: rod=%.4f plate y=%.4f needle=%.1f (want 3.5000 1.8333 −2.4) | dip: board y=%.4f leather=%.4f (want −0.0833 0.7500)" % [node.get_child_count(), leather.get_child_count(), bd.get_child_count(), rod.get_child_count(), plate.get_child_count(), gauge.get_child_count(), needle.get_child_count(), node.position.x, node.position.y, node.position.z, by_r, ls_r, rs_r, py_r, nz_r, rs_t, py_t, nz_t, by_d, ls_d])
	# 자세: 준비(s 99, k 0, dip 0): 골반 0.34..0.36 엉덩이 −0.20 무릎 0.29..0.35 어깨 −0.50 어깨 z ∓0.25 팔꿈치 −0.50 몸통 0.045±0.005; 구름 0.10(발 +1): 앞 엉덩이 −1.589 앞 무릎 2.14..2.20 뒤 엉덩이 −0.107 어깨 −1.704 몸통 −0.06..−0.05;
	# 내리꽂힘 0.22: 엉덩이 −0.35 무릎 0.53..0.59 어깨 −1.73..−1.66 골반 0.29..0.31 몸통 0.155..0.165
	fig.pose_request = "stomp"
	fig.set_meta("stomp_s", 99.0); fig.set_meta("stomp_f", 1.0); fig.set_meta("stomp_k", 0.0); fig.set_meta("stomp_dip", 0.0)
	await process_frame; await process_frame; await process_frame
	var early_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	while fig.pose_t < 1.2: await process_frame   # 헤드리스는 프레임이 빠르다 — 시간으로 기다린다
	var pel_r := fig.pelvis.position.y; var hip_r: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_r: float = (fig.knees[1.0] as Node3D).rotation.x; var sh_r: float = (fig.shoulders[1.0] as Node3D).rotation.x
	var shz_r: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shz_rb: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var el_r: float = (fig.elbows[1.0] as Node3D).rotation.x; var tor_r := fig.torso.rotation.x
	fig.set_meta("stomp_s", 0.1)
	var t1 := fig.pose_t
	while fig.pose_t < t1 + 0.8: await process_frame   # 블렌딩이 새 박자에 닿을 시간
	var hip_u: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_u: float = (fig.knees[1.0] as Node3D).rotation.x; var hip_ub: float = (fig.hips[-1.0] as Node3D).rotation.x; var sh_u: float = (fig.shoulders[1.0] as Node3D).rotation.x; var tor_u := fig.torso.rotation.x
	fig.set_meta("stomp_s", 0.22)
	t1 = fig.pose_t
	while fig.pose_t < t1 + 0.8: await process_frame
	var hip_d: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_d: float = (fig.knees[1.0] as Node3D).rotation.x; var sh_d: float = (fig.shoulders[1.0] as Node3D).rotation.x; var pel_d := fig.pelvis.position.y; var tor_d := fig.torso.rotation.x
	print("POSE early shoulder=%.2f (want > −0.4: the arms have only begun to lift) ready: pelvis=%.3f (want 0.34..0.36) hip=%.3f (want −0.200) knee=%.3f (want 0.29..0.35) shoulder=%.3f (want −0.500) z=%.3f %.3f (want −0.250 0.250) elbow=%.3f (want −0.500) torso=%.4f (want 0.045±0.005) | up: hip=%.3f (want −1.589) knee=%.3f (want 2.14..2.20) back hip=%.3f (want −0.107) shoulder=%.3f (want −1.704) torso=%.4f (want −0.06..−0.05) | drive: hip=%.3f (want −0.350) knee=%.3f (want 0.53..0.59) shoulder=%.3f (want −1.73..−1.66, the arms still coming down) pelvis=%.3f (want 0.29..0.31) torso=%.4f (want 0.155..0.165)" % [early_sh, pel_r, hip_r, knee_r, sh_r, shz_r, shz_rb, el_r, tor_r, hip_u, knee_u, hip_ub, sh_u, tor_u, hip_d, knee_d, sh_d, pel_d, tor_d])
	# 진짜 탑: 1..60층에 plan 이 찾는 풀무 — 태엽 층 16, 17, 18, 50, 52, 53, 54 중 띠·뻐꾸기 집(taken)이 안 든 120..220 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var gp: Array = cg.plan(n, pl); var hp: Array = pk.plan(n, pl, cpn.plan(n, pl) + gh.plan(n, pl) + cb.plan(n, pl) + cm.plan(n, pl))
		var out2 := cl.plan(n, pl, gp + hp)
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f dy %.0f max_lift %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["dy"]), float(v["max_lift"])])])
		count += out2.size()
	print("TOWER floors=", bands, " bellows=", count, " (want a subset of 16, 17, 18, 50, 52, 53, 54 — one each, never 15, 19 or 51, never another theme; max_lift = dy + 36 in 76..176; the upper hop may be crumble or spring)")
	quit()
