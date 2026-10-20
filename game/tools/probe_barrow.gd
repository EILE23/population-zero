extends SceneTree
## 반납 손수레 팩 점검(헤드리스): 자료가 읽히나, 서재 층의 140 px 넘는 std 발판 가운데 다음 발판이 가장 높이 오르는 것(11.1, 오름 95)의 틈 반대쪽 끝에만 수레가 서나(목록함이 선 발판·위에 지름길 판이 든 발판·얼음 발판은 비켜 가 11.0 으로, 다른 테마 층(9·15)은 없다),
## 손잡이 뒤의 C 가 수레를 잡고(busy, bar_t 0, pushes 1) C 없는 몸·먼 x·먼 z·다른 발판·통 위는 아무것도 아니나(평이 100%), 0.4 s 에 밀기로 넘어가나(push, bar_t 1), 밀며 걸으면 수레가 손 앞 35 px 를 따라오고 bar_v 가 속도를 읽고 바퀴가 삐걱이나,
## C 를 떼면 내려놓나(0.3 s, bar_t 1 → 0, clunk, 메타가 걷힌다) 그 통 윗면이 디딤인가(land 820), 바퀴가 발판 끝(400)에 서고 몸이 8 px 더 가면 손을 놓나(drop 0.3 s, bar_x, 수레는 422 그대로), 밀며 선 채 C 를 0.5 s 누르면 엎나(tip 0.6 s, bar_k, up) — 끝에서는 책 넷이 틈으로(lost, 0.5 s 뒤 숨는다) 손잡이 끝이 디딤인가(land 841, 오늘을 센다),
## 세운 수레 곁의 C 가 바로 세우나(0.5 s, bar_k 1 → 0, clunk) 그 8 s 뒤 책이 통으로 돌아오나(slither, 넷 — 숨겼던 같은 책), 발판 안에서 엎으면 책 더미가 서고(heap 456, 디딤 804 — 오늘을 안 센다) 세운 뒤 곁에 선 동안은 안 돌아오고 떠난 1 s 뒤 돌아오나, 미는 몸이 사라지면(step 끊김 0.25 s) 손을 놓나(엎던 중이면 엎어진다),
## 다음 날 다른 몸(tally 거짓)의 밀기는 판의 수를 안 바꾸나, 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 세나, 자국·수레 몸(틀 일곱 조각·바퀴·책 넷)·소리 셋이 그려지나, 노드 자리,
## barrow 자세가 잡고(t 1·v 0) 골반 0.39..0.41·상체 0.09·어깨 −0.35±0.02/z ∓0.12·팔꿈치 −0.05·무릎 0.10±0.03 이고, 숙여(t 0.5) 골반 0.32·상체 0.225·엉덩이 −0.60·무릎 0.90·어깨 −0.45/z ∓0.08·팔꿈치 −0.10 이고, 밀며(v 1) 엉덩이가 움직이고, 엎어(k 1) 어깨 −1.50·왼 엉덩이 0.30·오른 무릎 0.50·상체 0.2475 이고, 놓으며(x 0.5) 어깨 −0.475±0.02·상체 0 이고, 메타 없이 3.3 에 done 인가,
## 진짜 탑의 1..70층에서 plan 이 서재 층(10..14, 45..49)에만 수레를 찾나
const C = preload("res://scripts/games/climb.gd")
const DT := 1.0 / 60.0

func _init() -> void:
	var cw := ClimbBarrow.new(); root.add_child(cw)
	var cl := ClimbLadder.new(); root.add_child(cl)
	var cd := ClimbDumbwaiter.new(); root.add_child(cd)
	var cs := ClimbBookcase.new(); root.add_child(cs)
	var pn := ClimbPaternoster.new(); root.add_child(pn)
	var sc := ClimbScroll.new(); root.add_child(sc)
	var cc := ClimbCatalogue.new(); root.add_child(cc)
	await process_frame
	print("PACK id=", cw.pack.get("id"), " kind=", cw.kind.size() > 0, " pose=", cw.pack.get("pose"), " themes=", cw.pack.get("themes"), " min_w=%.0f park_in=%.0f reach=%.0f len=%.0f tray=%.0f×%.0f×%.0f wheel=%.0f books=%d step_w=%.0f heap=%.0f/%.0f/%.0f grip=%.2f set=%.2f tip=%.2f swing=%.2f drop=%.2f right=%.2f back=%.0f slow=%.2f/%.2f day=%.0f up_h=%.0f (want barrow true barrow [Library] 140 30 14 44 24×30×20 7 4 20 22/30/14 0.40 0.30 0.50 0.60 0.30 0.50 8 0.60/0.85 600 51)" % [cw.min_w(), cw.park_in(), cw.reach(), cw.length(), cw.tray_w(), cw.tray_h(), cw.tray_d(), cw.wheel_r(), cw.books(), cw.step_w(), cw.heap_dx(), cw.heap_w(), cw.heap_h(), cw.grip_s(), cw.set_s(), cw.tip_s(), cw.swing_s(), cw.drop_s(), cw.right_s(), cw.back_s(), cw.slow(), cw.slow_empty(), cw.day_s(), cw.up_h()])
	var plats: Array = [
		{ "id": "11.0", "x": 100.0, "y": 700.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "11.1", "x": 400.0, "y": 790.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "11.2", "x": 150.0, "y": 885.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "11.3", "x": 420.0, "y": 1010.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "11.4", "x": 600.0, "y": 1100.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "11s", "x": 560.0, "y": 1028.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cw.plan(11, plats)
	var taken := cw.plan(11, plats, [{ "id": "11.C0", "kind": "cabinet", "x": 380.0, "w": 48.0, "y": 790.0, "y_top": 880.0 }])   # 목록함이 11.1 의 띠에 — 11.0 으로
	var cut := plats.duplicate(true); cut.append({ "id": "11c", "x": 470.0, "y": 830.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 })   # 11.1 위에 지름길 판 — 11.0 으로
	var cutp := cw.plan(11, cut)
	var icy := plats.duplicate(true); (icy[1] as Dictionary)["kind"] = "ice"   # 얼음 — 11.0 으로
	var icyp := cw.plan(11, icy)
	var f9 := cw.plan(9, plats); var f10 := cw.plan(10, plats); var f14 := cw.plan(14, plats); var f15 := cw.plan(15, plats); var f45 := cw.plan(45, plats)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " a %s b %s dy %.0f dir %.0f px %.0f x %.0f w %.0f y %.0f y_top %.0f z %.0f d %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dy"]), float(v["dir"]), float(v["px"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	var brief := func(v: Dictionary) -> String: return "%s dy %.0f px %.0f" % [String(v["a_id"]), float(v["dy"]), float(v["px"])]
	print("PLAN free=", free.map(show), " (want 1: 11.W0 a 11.1 b 11.2 dy 95 dir −1 px 520 x 488 w 64 y 790 y_top 841 z −48 d 20)")
	print("PLAN taken=", taken.map(brief), " cut=", cutp.map(brief), " ice=", icyp.map(brief), " (want [11.0 dy 90 px 130] ×3) floors 9/10/14/15/45=", [f9.size(), f10.size(), f14.size(), f15.size(), f45.size()], " (want 0 1 1 0 1)")
	var band_root := Node3D.new(); root.add_child(band_root)
	cw.build(band_root, free)
	var s: Dictionary = cw.barrows[0]
	var node: Node3D = s["node"]; var piv: Node3D = s["piv"]; var tray: Node3D = s["tray"]
	var frame := piv.get_child(0) as Node3D
	print("VISUAL node=%s (want %s) children=%d (want 6: mark + stencil + body + 3 sounds) piv x=%.3f (want −0.611: the wheel 22 px toward the gap) frame parts=%d (want 7: tray + 2 legs + 2 handles + 2 grips) tray parts=%d (want 5: the tray + 4 books) book 0 y=%.3f (want 0.694) bx=%.0f up=%s (want 520 false)" % [node.position, C.to3(520.0, 790.0, C.PLAYER_Z * C.K), node.get_child_count(), piv.position.x, frame.get_child_count(), tray.get_child_count(), (tray.get_child(1) as Node3D).position.y, float(s["bx"]), s["up"]])
	var fig := Stick3D.new(); root.add_child(fig)
	var fig2 := Stick3D.new(); root.add_child(fig2)
	await process_frame
	var on: Dictionary = plats[1]; var z := C.PLAYER_Z
	var squeak: AudioStreamPlayer3D = s["squeak"]; var clunk: AudioStreamPlayer3D = s["clunk"]; var slither: AudioStreamPlayer3D = s["slither"]
	var none := func(r: Dictionary) -> bool: return not bool(r["busy"]) and not bool(r["push"])
	# 잡기(t 10, 몸 545 — 손잡이 끝 542 곁 3 ≤ 24): busy, grip, bar_t 0, pushes 1; C 없음·먼 x·먼 z·다른 발판·통 위는 아무것도 아니다
	cw.sync(10.0)
	var r0 := cw.step(on, 545.0, z, -1.0, true, true, DT, fig)
	var l0 := "busy=%s push=%s sw=%s t=%.1f holder=%s pushing=%s pushes=%d day_pushes=%d" % [r0["busy"], r0["push"], String(s["sw"]), float(fig.get_meta("bar_t", 9.0)), s["holder"] == fig, cw.pushing(fig), int(s["pushes"]), int(s["day_pushes"])]
	var no_c := cw.step(on, 545.0, z, -1.0, false, false, DT, fig2); var far_x := cw.step(on, 580.0, z, -1.0, true, true, DT, fig2); var far_z := cw.step(on, 545.0, z + 40.0, -1.0, true, true, DT, fig2); var other := cw.step(plats[0], 545.0, z, -1.0, true, true, DT, fig2)
	var on_tray := cw.step({ "kind": "barrow", "id": "11.W0.t", "x": 512.0, "y": 820.0, "w": 24.0, "z": z, "d": 20.0 }, 545.0, z, -1.0, true, true, DT, fig2)
	print("GRIP ", l0, " (want true false grip 0.0 true true 1 1) | no C=%s far x=%s far z=%s other hop=%s on the tray=%s pushing fig2=%s (want true ×5 false)" % [none.call(no_c), none.call(far_x), none.call(far_z), none.call(other), none.call(on_tray), cw.pushing(fig2)])
	cw.sync(10.2); var r1 := cw.step(on, 545.0, z, -1.0, false, false, DT, fig); var p1 := "busy=%s t=%.2f" % [r1["busy"], float(fig.get_meta("bar_t", 9.0))]
	cw.sync(10.42); var r2 := cw.step(on, 545.0, z, -1.0, false, false, DT, fig); var p2 := "busy=%s push=%s sw=%s t=%.1f" % [r2["busy"], r2["push"], String(s["sw"]), float(fig.get_meta("bar_t", 9.0))]
	# 밀며 걷기: 틱마다 2.6 px(156 px/s = 0.6 × 260) 왼쪽으로 스무 틱 → bar_v 1.0, 493 에 선다, 수레 458(손 앞 35), 바퀴 삐걱
	var xw := 545.0; var vmax := 0.0; var sq := false
	for i in 20:
		xw -= 2.6; cw.sync(cw.t + DT); cw.step(on, xw, z, -1.0, false, false, DT, fig); vmax = maxf(vmax, float(fig.get_meta("bar_v", 0.0))); sq = sq or squeak.playing
	var p3 := "v_max=%.2f bx=%.0f body x=%.3f squeak=%s" % [vmax, float(s["bx"]), (s["body"] as Node3D).position.x, sq]
	# 내려놓기: C 를 한 틱 눌렀다 떼면 set(0.3 s, bar_t 1 → 0, clunk) — 통 윗면이 디딤(442..466, 820)
	cw.sync(cw.t + DT); cw.step(on, 493.0, z, -1.0, true, true, DT, fig)
	cw.sync(cw.t + DT); var r4 := cw.step(on, 493.0, z, -1.0, false, false, DT, fig); var p4 := "busy=%s sw=%s" % [r4["busy"], String(s["sw"])]
	cw.sync(cw.t + 0.15); var r5 := cw.step(on, 493.0, z, -1.0, false, false, DT, fig); var p5 := "busy=%s t=%.2f" % [r5["busy"], float(fig.get_meta("bar_t", 9.0))]
	cw.sync(cw.t + 0.16); var r6 := cw.step(on, 493.0, z, -1.0, false, false, DT, fig)
	var st := cw.steps_of(s); var ld1 := cw.land(450.0, 830.0, 815.0, z); var ldz := cw.land(450.0, 830.0, 815.0, z + 30.0); var ldx := cw.land(500.0, 830.0, 815.0, z)
	var p6 := "busy=%s push=%s sw='%s' holder null=%s metas=%s clunk=%s steps=%s" % [r6["busy"], r6["push"], String(s["sw"]), s["holder"] == null, fig.has_meta("bar_t"), clunk.playing, st.map(func(k: Dictionary) -> String: return "%s x %.0f y %.0f w %.0f" % [String(k["id"]), float(k["x"]), float(k["y"]), float(k["w"])])]
	print("PUSH 0.2 s: %s (want busy=true t=0.50) | 0.42 s: %s (want busy=false push=true sw=push t=1.0) | walk: %s (want 1.00 458 −1.722 true) | tap: %s (want busy=true sw=set) | 0.15 s: %s (want busy=true t=0.50) | 0.31 s: %s (want false false '' true false true [11.W0.t x 442 y 820 w 24])" % [p1, p2, p3, p4, p5, p6])
	print("LAND tray=%s %s x=%.0f y=%.0f w=%.0f d=%.0f (want barrow 11.W0.t 442 820 24 20) far z=%s beside=%s (want true true — empty) stands=%d day=%d (want 1 0)" % [String(ld1.get("kind", "-")), String(ld1.get("id", "-")), float(ld1.get("x", 0.0)), float(ld1.get("y", 0.0)), float(ld1.get("w", 0.0)), float(ld1.get("d", 0.0)), ldz.is_empty(), ldx.is_empty(), int(s["stands"]), int(s["day"])])
	# 끝에 서기(t 20): 손잡이 480 곁 483 에서 잡아 밀면 바퀴가 400(발판 끝)에 서고(수레 422), 몸이 8 px 더 가면 손을 놓는다(drop 0.3 s, bar_x) — 수레는 422 그대로
	cw.sync(20.0); _grip(cw, on, 483.0, -1.0, fig)
	var at_edge := ""; var dropped := ""; var x_mid := -1.0; var t_drop := -1.0
	xw = 483.0
	for i in 20:
		xw -= 2.6; cw.sync(cw.t + DT); var rr := cw.step(on, xw, z, -1.0, false, false, DT, fig)
		if at_edge == "" and float(s["bx"]) <= 422.0: at_edge = "x=%.1f bx=%.0f wheel=%.0f sw=%s" % [xw, float(s["bx"]), cw._wheel_x(s), String(s["sw"])]
		if String(s["sw"]) == "drop": dropped = "x=%.1f push=%s bx=%.0f" % [xw, rr["push"], float(s["bx"])]; t_drop = cw.t; break
	cw.sync(cw.t + 0.15); cw.step(on, 440.0, z, -1.0, false, false, DT, fig); x_mid = float(fig.get_meta("bar_x", 9.0))
	cw.sync(t_drop + 0.31); var r7 := cw.step(on, 440.0, z, -1.0, false, false, DT, fig)
	print("EDGE at: %s (want x=457.0 bx=422 wheel=400 sw=push) | let go: %s (want x=446.6 push=true bx=422: 11 px past the slack) | bar_x at 0.15 s=%.2f (want 0.50..0.56) | 0.31 s: busy=%s push=%s sw='%s' metas=%s bx=%.0f (want false false '' false 422)" % [at_edge, dropped, x_mid, r7["busy"], r7["push"], String(s["sw"]), fig.has_meta("bar_x"), float(s["bx"])])
	# 엎기(t 30; 손잡이 444 곁 450 — 447 은 끝에 선 수레의 여유 8 px 를 2 px 넘어 손을 놓는 자리): 밀며 선 채 C 를 0.5 s 누르면 tip — 0.6 s 에 세워진다(up, swing 1), 책 넷은 바퀴 앞 378 이 발판 밖이라 틈으로(lost 4, 통 비고, 0.5 s 뒤 사라진다), 손잡이 끝(397..417, 841)이 디딤 — 오늘을 센다
	cw.sync(30.0); _grip(cw, on, 450.0, -1.0, fig)
	var tip_at := -1.0; var k_mid := -1.0; var up_at := -1.0; var t0 := cw.t
	while cw.t - t0 < 1.5:
		cw.sync(cw.t + DT); cw.step(on, 450.0, z, -1.0, false, cw.t - t0 < 0.7, DT, fig)
		if tip_at < 0.0 and String(s["sw"]) == "tip": tip_at = cw.t - t0
		if tip_at >= 0.0 and k_mid < 0.0 and cw.t - t0 >= tip_at + 0.3: k_mid = float(fig.get_meta("bar_k", 9.0))
		if up_at < 0.0 and bool(s["up"]): up_at = cw.t - t0
	var st2 := cw.steps_of(s); var ld2 := cw.land(400.0, 850.0, 835.0, z)
	var p8 := "tip at=%.2f (want 0.50..0.52) k at +0.3=%.2f (want 0.50) up at=%.2f (want tip + 0.60..0.62) swing=%.1f up=%s piv rot=%.3f sw='%s' (want 1.0 true 1.571 '') books=%d heap=%d lost=%d tips=%d slither=%s (want 0 0 4 1 true)" % [tip_at, k_mid, up_at, float(s["swing"]), s["up"], piv.rotation.z, String(s["sw"]), (s["books"] as Array).size(), (s["heap"] as Array).size(), int(s["lost_n"]), int(s["tips"]), slither.playing]
	for i in 40: cw._process(DT)
	print("TIP ", p8, " | steps=%s (want [11.W0.h x 397 y 841 w 20]) land=%s y=%.0f (want 11.W0.h 841) stands=%d (want 2) | lost books hidden=%s tray parts=%d node children=%d (want true 1 10: 6 + the 4 hidden books, kept for the return)" % [st2.map(func(k: Dictionary) -> String: return "%s x %.0f y %.0f w %.0f" % [String(k["id"]), float(k["x"]), float(k["y"]), float(k["w"])]), String(ld2.get("id", "-")), float(ld2.get("y", 0.0)), int(s["stands"]), (s["lost"] as Array).all(func(l: Dictionary) -> bool: return not (l["node"] as Node3D).visible), tray.get_child_count(), node.get_child_count()])
	# 세우기(t 40): 바퀴(400) 곁 410 의 C — right 0.5 s(bar_k 1 → 0), clunk, 통 윗면이 다시 디딤; 손잡이 쪽(447)·안 누름은 아무것도 아니다; 8 s 뒤 책 넷이 통으로(slither)
	cw.sync(40.0)
	var r9 := cw.step(on, 447.0, z, -1.0, true, true, DT, fig2); var r9b := cw.step(on, 410.0, z, -1.0, false, false, DT, fig2)
	var r10 := cw.step(on, 410.0, z, -1.0, true, true, DT, fig); var p10 := "busy=%s sw=%s k=%.1f" % [r10["busy"], String(s["sw"]), float(fig.get_meta("bar_k", 9.0))]
	cw.sync(40.25); cw.step(on, 410.0, z, -1.0, false, false, DT, fig); var k_half := float(fig.get_meta("bar_k", 9.0))
	cw.sync(40.52); var r11 := cw.step(on, 410.0, z, -1.0, false, false, DT, fig)
	var p11 := "busy=%s sw='%s' up=%s swing=%.1f righted=%.1f clunk=%s steps=%s" % [r11["busy"], String(s["sw"]), s["up"], float(s["swing"]), float(s["righted_t"]), clunk.playing, cw.steps_of(s).map(func(k: Dictionary) -> String: return String(k["id"]))]
	var back_at := -1.0; var t1 := cw.t; var rt := float(s["righted_t"])
	while cw.t - t1 < 9.0:
		cw._process(DT)
		if back_at < 0.0 and (s["books"] as Array).size() == 4: back_at = cw.t - rt
	print("RIGHT far side=%s no C=%s (want true true — nothing) | C: %s (want busy=true sw=right k=1.0) | 0.25 s: k=%.2f (want 0.50) | 0.52 s: %s (want false '' false 0.0 40.5 true [11.W0.t]) | books back at=%.2f s after the righting (want 8.00..8.02) tray parts=%d node children=%d visible=%s slither=%s (want 5 6 true true)" % [none.call(r9), none.call(r9b), p10, k_half, p11, back_at, tray.get_child_count(), node.get_child_count(), (tray.get_child(1) as Node3D).visible, slither.playing])
	# 발판 안에서 엎기(t 60; 수레를 500 에): 손잡이 522 곁 535 에서(손 앞 35 — 수레가 안 움직인다) 잡아 C 를 누르면 바퀴 478 앞 456 에 더미(441..471, 804 — 디딤, 오늘을 안 센다); 세운 뒤 더미 곁에 선 동안(near_t)은 안 돌아오고, 떠난 1 s 뒤 돌아온다
	cw.sync(60.0); s["bx"] = 500.0; cw._place(s)
	_grip(cw, on, 535.0, -1.0, fig)
	for i in 70: cw.sync(cw.t + DT); cw.step(on, 535.0, z, -1.0, false, true, DT, fig)
	for i in 20: cw.sync(cw.t + DT); cw.step(on, 535.0, z, -1.0, false, false, DT, fig)
	var heap_s := "up=%s heap=%d heap_x=%.0f lost=%d steps=%s" % [s["up"], (s["heap"] as Array).size(), float(s["heap_x"]), int(s["lost_n"]), cw.steps_of(s).map(func(k: Dictionary) -> String: return "%s x %.0f y %.0f w %.0f" % [String(k["id"]), float(k["x"]), float(k["y"]), float(k["w"])])]
	var stands0 := int(s["stands"]); var ld3 := cw.land(456.0, 810.0, 800.0, z); var heap_land := "%s y=%.0f stands same=%s" % [String(ld3.get("id", "-")), float(ld3.get("y", 0.0)), int(s["stands"]) == stands0]
	cw.sync(cw.t + DT); cw.step(on, 488.0, z, -1.0, true, true, DT, fig)   # 바퀴 478 곁 — 세운다
	for i in 32: cw.sync(cw.t + DT); cw.step(on, 488.0, z, -1.0, false, false, DT, fig)
	var righted := String(s["sw"]) == "" and not bool(s["up"])
	var t2 := cw.t; var kept := true
	while cw.t - t2 < 9.0:
		cw._process(DT); cw.step(on, 456.0, z, -1.0, false, false, DT, fig)   # 더미 위에 선 채
		kept = kept and (s["heap"] as Array).size() == 4
	var t3 := cw.t; var back2 := -1.0
	while cw.t - t3 < 2.0:
		cw._process(DT)
		if back2 < 0.0 and (s["heap"] as Array).is_empty(): back2 = cw.t - t3
	print("HEAP ", heap_s, " (want true 4 456 4 [11.W0.h x 475 y 841 w 20, 11.W0.b x 441 y 804 w 30]) land=%s (want 11.W0.b 804 true) | righted=%s (want true) kept while you stand on it 9 s=%s (want true) | back %.2f s after you leave (want 1.00..1.03) tray parts=%d (want 5)" % [heap_land, righted, kept, back2, tray.get_child_count()])
	# 사라진 몸(t 80): 잡은 채 step 이 끊기면 0.25 s 에 손을 놓는다(sw 비고 메타 걷힘, 수레 그대로); 엎던 중이면 엎어진다(up)
	cw.sync(80.0); s["bx"] = 500.0; cw._place(s); _grip(cw, on, 535.0, -1.0, fig)
	var t4 := cw.t; var lost_at := -1.0
	while cw.t - t4 < 1.0:
		cw._process(DT)
		if lost_at < 0.0 and String(s["sw"]) == "": lost_at = cw.t - t4
	var g1 := "released at=%.2f s (want 0.27..0.29) pushing=%s metas=%s bx=%.0f up=%s (want false false 500 false)" % [lost_at, cw.pushing(fig), fig.has_meta("bar_t"), float(s["bx"]), s["up"]]
	_grip(cw, on, 535.0, -1.0, fig)
	for i in 35: cw.sync(cw.t + DT); cw.step(on, 535.0, z, -1.0, false, true, DT, fig)
	var mid_tip := String(s["sw"])
	for i in 30: cw._process(DT)
	print("GONE ", g1, " | mid-tip=%s → sw='%s' up=%s swing=%.1f heap=%d (want tip '' true 1.0 4)" % [mid_tip, String(s["sw"]), s["up"], float(s["swing"]), (s["heap"] as Array).size()])
	# 다음 날(t 610) 다른 몸(tally 거짓)의 밀기 — 판의 수는 그대로(day_pushes 0): 판은 '0 of 1 stood on today, 0 tipped out today, 0 pushes today'
	cw.sync(610.0); s["bx"] = 500.0; s["up"] = false; s["swing"] = 0.0; cw._place(s); _grip(cw, on, 535.0, -1.0, fig2, false)
	for i in 10: cw.sync(cw.t + DT); cw.step(on, 535.0, z, -1.0, false, false, DT, fig2, false)
	cw.sync(cw.t + DT); cw.step(on, 535.0, z, -1.0, true, true, DT, fig2, false)
	for i in 25: cw.sync(cw.t + DT); cw.step(on, 535.0, z, -1.0, false, false, DT, fig2, false)
	print("OTHER next day: pushes=%d day_pushes=%d push_day=%d (want 7 6 0 — the other body's grip counts in pushes, not on the board) note 11=\"%s\" (want 'Returns barrows, floors 11–15: 0 of 1 stood on today, 0 tipped out today, 0 pushes today.') | note 10=\"%s\" 16=\"%s\" 30=\"%s\" (want 'floors 10–14: …' / 'floors 11–15: …' / '')" % [int(s["pushes"]), int(s["day_pushes"]), int(s["push_day"]), cw.note(11), cw.note(10), cw.note(16), cw.note(30)])
	cw.sync(90.0)
	print("NOTE day 0: \"%s\" (want 'Returns barrows, floors 11–15: 1 of 1 stood on today, 3 tipped out today, 6 pushes today.')" % cw.note(11))
	await _pose(fig)
	# 진짜 탑: 1..70층에 plan 이 찾는 수레 — 서재 층 10..14, 45..49 중 사다리·덤웨이터·서가·파터노스터·두루마리 선반·목록함이 안 쓴 넓은 std 발판이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var lp: Array = cl.plan(n, pl); var dp: Array = cd.plan(n, pl); var bp: Array = cs.plan(n, pl, lp + dp); var np: Array = pn.plan(n, pl, lp + dp + bp); var sp: Array = sc.plan(n, pl, lp + dp + bp + np)
		var out2 := cw.plan(n, pl, lp + dp + bp + np + sp + cc.plan(n, pl, lp + dp + bp + np + sp))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s dy %.0f px %.0f" % [String(v["a_id"]), float(v["dy"]), float(v["px"])])])
	print("TOWER floors=", bands, " (want a subset of 10..14 and 45..49 — one barrow each on the free std hop under the biggest rise, never another theme)")
	quit()

## 손잡이 곁 x 에서 C 한 틱(잡는다) 뒤 0.45 s 기다린다 — 미는 채
func _grip(cw: ClimbBarrow, on: Dictionary, x: float, face: float, fig: Stick3D, tally := true) -> void:
	cw.step(on, x, C.PLAYER_Z, face, true, true, DT, fig, tally)
	var t0 := cw.t
	while cw.t - t0 < 0.45:
		cw.sync(cw.t + DT); cw.step(on, x, C.PLAYER_Z, face, false, false, DT, fig, tally)

## barrow 자세(메타로 세운다) — 잡고(t 1·v 0), 숙여(t 0.5), 밀며(v 1, 두 틱 떨어져 엉덩이가 움직이나), 엎어(k 1), 놓으며(x 0.5); 메타 없이 3.3 에 done
func _pose(fig: Stick3D) -> void:
	fig.pose_request = "barrow"; fig.set_meta("bar_t", 1.0); fig.set_meta("bar_v", 0.0); fig.set_meta("bar_k", 0.0); fig.set_meta("bar_x", 0.0)
	for i in 45: await process_frame
	var r_sh: Node3D = fig.shoulders[1.0]; var l_sh: Node3D = fig.shoulders[-1.0]; var r_el: Node3D = fig.elbows[1.0]
	var r_hip: Node3D = fig.hips[1.0]; var l_hip: Node3D = fig.hips[-1.0]; var r_knee: Node3D = fig.knees[1.0]; var l_knee: Node3D = fig.knees[-1.0]
	var a := "pelvis=%.3f torso=%.3f shoulder=%.2f z=%.2f/%.2f elbow=%.2f hip=%.2f knee=%.2f neck=%.2f" % [fig.pelvis.position.y, fig.torso.rotation.x, r_sh.rotation.x, r_sh.rotation.z, l_sh.rotation.z, r_el.rotation.x, r_hip.rotation.x, r_knee.rotation.x, fig.neck.rotation.x]
	fig.set_meta("bar_t", 0.5)
	for i in 45: await process_frame
	var b := "pelvis=%.2f torso=%.3f hip=%.2f knee=%.2f shoulder=%.2f z=%.2f/%.2f elbow=%.2f neck=%.2f" % [fig.pelvis.position.y, fig.torso.rotation.x, r_hip.rotation.x, r_knee.rotation.x, r_sh.rotation.x, r_sh.rotation.z, l_sh.rotation.z, r_el.rotation.x, fig.neck.rotation.x]
	fig.set_meta("bar_t", 1.0); fig.set_meta("bar_v", 1.0)
	for i in 45: await process_frame
	var h1 := r_hip.rotation.x
	for i in 3: await process_frame
	var c := "hip=%.2f→%.2f moves=%s torso=%.3f" % [h1, r_hip.rotation.x, absf(r_hip.rotation.x - h1) > 0.01, fig.torso.rotation.x]
	fig.set_meta("bar_v", 0.0); fig.set_meta("bar_k", 1.0)
	for i in 45: await process_frame
	var d := "shoulder=%.2f left hip=%.2f right knee=%.2f left knee=%.2f torso=%.4f pelvis=%.2f elbow=%.2f neck=%.2f" % [r_sh.rotation.x, l_hip.rotation.x, r_knee.rotation.x, l_knee.rotation.x, fig.torso.rotation.x, fig.pelvis.position.y, r_el.rotation.x, fig.neck.rotation.x]
	fig.set_meta("bar_k", 0.0); fig.set_meta("bar_x", 0.5)
	for i in 45: await process_frame
	var e := "shoulder=%.3f torso=%.3f pelvis=%.3f" % [r_sh.rotation.x, fig.torso.rotation.x, fig.pelvis.position.y]
	for key: String in ["bar_t", "bar_v", "bar_k", "bar_x"]: fig.remove_meta(key)
	fig.pose_t = BarrowPoses.LAP - 0.01; var before := BarrowPoses.done(fig)
	fig.pose_t = BarrowPoses.LAP + 0.001; var after := BarrowPoses.done(fig)
	print("BARROW pose hold: ", a, " (want 0.39..0.41 0.090 −0.35±0.02 −0.12/0.12 −0.05 0.00 0.10±0.03 ≈−0.14: the base −0.7 × lean) | bend: ", b, " (want 0.32 0.225 −0.60 0.90 −0.45 −0.08/0.08 −0.10 ≈0.10: 0.45 over the base −0.7 × lean) | push: ", c, " (want true, torso 0.144) | tip: ", d, " (want −1.50 0.30 0.50 0.20 0.2475 0.35±0.01 −0.15 ≈0.01: 0.40 over the base) | drop 0.5: ", e, " (want −0.475±0.02 0.000 0.400..0.420) | done(3.29 → 3.301)=%s LAP=%.1f (want true 3.3)" % [(not before) and after, BarrowPoses.LAP])
	fig.pose_request = ""
