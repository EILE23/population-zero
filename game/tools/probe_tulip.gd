extends SceneTree
## 튤립 승강기 팩 점검(헤드리스): 자료가 읽히나, 공중정원 층(바람구멍 층은 빼고)의 잇단 still 발판 짝(84..200 px 틈, 위 발판이 150 px 안; 위 발판은 crumble·spring 도 된다) 중 가장 넓은 틈에만 튤립이 서나(좁은 틈은 지고, 상자에 드는 발판·진폭째 드는 움직이는 발판·taken 조각이 든 틈은 비켜 가며, 다른 테마 층은 아니다, 거울 층은 반대로),
## lift 가 dy − 40 을 60..90 에 가둔 값인가(120 → 80), 아래 발판에서 가장자리 24 안·쉬는 꽃에서만 C 가 들어서나(안 누름·멀리·가장자리를 지난 몸·위 발판·앞·이미 든 꽃은 아니다), 1/16 틱으로 감싸기 0.4 → 늘어나기 1.2(smoothstep) → 피기 0.3 → 핌이 이어지며 x 가 봉오리 가운데에 묶이고 curl_k·curl_v 가 적히나,
## 핀 뒤 바닥과 잎 턱 위를 걷고 어느 끝이든 넘으면 off 인가, 몸이 떠난 1.5초 뒤 시들기(sigh)가 6초에 걸쳐 내려오고 닫기 0.4 뒤 쉬나, 핀 채 5초를 서 있으면 발밑이 같이 내려오고 다 내려온 뒤 벌어진 채(spent) 기다리다 떠나면 닫히나,
## 벌어진 바닥을 지나는 몸·catch 안에서 내려서는 몸·바닥 밑 catch 안의 몸만 land 가 받나(멀리 위·밑·오르는 몸·옆·앞·닫힌 봉오리는 아니다), 받침 팔·화분·줄기·잎 둘·머리·소리 넷이 그려지고 머리에 바닥·꽃잎 여섯·잎 턱·잎맥인가, 줄기가 늘어난 만큼 길어지고 머리가 오르며 꽃잎이 벌어진 만큼 눕나,
## curl 자세가 무릎을 가슴으로 올리고 골반을 내리며 팔이 무릎을 안고 고개를 묻나, 진짜 탑의 1..60층에서 plan 이 공중정원 층에만 튤립을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var ct := ClimbTulip.new(); root.add_child(ct)
	var cp := ClimbPlanter.new(); root.add_child(cp)
	var cv := ClimbVine.new(); root.add_child(cv)
	var ch := ClimbHammock.new(); root.add_child(ch)
	var cz := ClimbZip.new(); root.add_child(cz)
	var cb := ClimbBridge.new(); root.add_child(cb)
	await process_frame
	print("PACK id=", ct.pack.get("id"), " kind=", ct.kind.size() > 0, " pose=", ct.pack.get("pose"), " themes=", ct.pack.get("themes"), " bud_w=%.0f bud_h=%.0f leaf_w=%.0f lift=%.0f/%.0f top_short=%.0f root_d=%.0f reach=%.0f fold=%.1f rise=%.1f bloom=%.1f stay=%.1f hold=%.1f wilt=%.1f close=%.1f catch=%.0f deck_d=%.0f lift_of(120)=%.0f lift_of(60)=%.0f lift_of(150)=%.0f (want 40 44 36 60/90 40 40 24 0.4 1.2 0.3 5.0 1.5 6.0 0.4 16 28 80 60 90)" % [ct.bud_w(), ct.bud_h(), ct.leaf_w(), ct.min_lift(), ct.max_lift(), ct.top_short(), ct.root_d(), ct.reach(), ct.fold_s(), ct.rise_s(), ct.bloom_s(), ct.stay_s(), ct.hold_s(), ct.wilt_s(), ct.close_s(), ct.catch_px(), ct.deck_d(), ct.lift_of(120.0), ct.lift_of(60.0), ct.lift_of(150.0)])
	var plats: Array = [
		{ "id": "5.0", "x": 100.0, "y": 3100.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5.1", "x": 420.0, "y": 3220.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5.2", "x": 150.0, "y": 3330.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "5.3", "x": 435.0, "y": 3450.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5.4", "x": 620.0, "y": 3470.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5s", "x": 560.0, "y": 3480.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := ct.plan(5, plats)
	var netted := ct.plan(5, plats, [{ "id": "5.H0", "kind": "hammock", "x": 272.0, "w": 40.0, "y": 3065.0 }])   # 조각(262..322, 3055..3285)이 5.0↔5.1 의 상자(276..360, 3061..3274)만 가른다 — 5.2↔5.3 (125) 이 남는다
	var moved := plats.duplicate(true); moved.append({ "id": "5m", "x": 330.0, "y": 3150.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째(240..480, 3150) 5.0↔5.1 의 상자에 든다
	var movep := ct.plan(5, moved)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := ct.plan(5, mirror)
	var f4 := ct.plan(4, plats); var f6 := ct.plan(6, plats); var f7 := ct.plan(7, plats); var f8 := ct.plan(8, plats); var f9 := ct.plan(9, plats); var f10 := ct.plan(10, plats); var f40 := ct.plan(40, plats); var f43 := ct.plan(43, plats); var f44 := ct.plan(44, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	ct.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s a_edge %.0f b_edge %.0f lift %.0f bx %.0f x_in %.0f x_out %.0f y_top %.0f x %.0f w %.0f y %.0f z %.0f d %.0f" % [float(v["dir"]), float(v["gap"]), String(v["a_id"]), String(v["b_id"]), float(v["a_edge"]), float(v["b_edge"]), float(v["lift"]), float(v["bx"]), float(v["x_in"]), float(v["x_out"]), float(v["y_top"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["z"]), float(v["d"])]
	print("PLAN free=", free.map(show), " (want 1: 5.T0 dir 1 gap 140 5.0→5.1 wins over 5.2↔5.3 gap 125 and 5.1↔5.2 gap 110, 5.3↔5.4 gap 65 out: a_edge 280 b_edge 420 lift 80 bx 300 x_in 280 x_out 356 y_top 3224 x 280 w 76 y 3100 z −48 d 28)")
	print("PLAN netted=", netted.map(show), " (want 5.T0 dir 1 gap 125 5.2→5.3 a_edge 310 b_edge 435 lift 80 bx 330 x_in 310 x_out 386 y_top 3454 x 310) moved=", movep.map(func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f a_edge %.0f" % [float(v["gap"]), float(v["a_edge"])]), " (want 5.T0 gap 125 a_edge 310) right=", right.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f a_edge %.0f b_edge %.0f bx %.0f x_out %.0f x %.0f" % [float(v["dir"]), float(v["gap"]), float(v["a_edge"]), float(v["b_edge"]), float(v["bx"]), float(v["x_out"]), float(v["x"])]), " (want 5.T0 dir −1 gap 140 a_edge 680 b_edge 540 bx 660 x_out 604 x 604) f4=", f4.size(), " f6=", f6.size(), " f7=", f7.size(), " f8=", f8.size(), " f9=", f9.size(), " f10=", f10.size(), " f40=", f40.size(), " f43=", f43.size(), " f44=", f44.size(), " (want 0 1 0 1 1 0 1 0 1)")
	var s: Dictionary = ct.lifts[0]
	var on_a: Dictionary = plats[0]
	var z := C.PLAYER_Z
	var fig := Stick3D.new(); root.add_child(fig)
	var dt := 0.0625
	var rustle: AudioStreamPlayer3D = s["rustle"]; var creak: AudioStreamPlayer3D = s["creak"]; var pop: AudioStreamPlayer3D = s["pop"]; var sigh: AudioStreamPlayer3D = s["sigh"]
	# 들어서기(0.0): 안 누름·x 250(30 멀다)·x 286(가장자리를 6 지났다)·위 발판·앞(z −20)·닫힌 봉오리의 land 는 아니다; x 270 은 든다(rustle, fold) — 든 뒤 다시는 아니다
	ct.sync(0.0)
	var no_press := ct.enter(on_a, 270.0, z, false); var far := ct.enter(on_a, 250.0, z, true); var past := ct.enter(on_a, 286.0, z, true); var upper := ct.enter(plats[1], 430.0, z, true); var front := ct.enter(on_a, 270.0, -20.0, true)
	var shut := ct.land(300.0, 3105.0, 3095.0, z)
	var got_in := ct.enter(on_a, 270.0, z, true); var rustle_in := rustle.playing; var ph_in := String(s["phase"])
	var again := ct.enter(on_a, 270.0, z, true)
	print("ENTER refused: no_press=%s far=%s past=%s upper=%s front=%s shut=%s (want empty ×6) | in: kind=%s id=%s x=%.0f y=%.0f w=%.0f bx=%.0f z=%.0f d=%.0f rustle=%s phase=%s (want tulip 5.T0 280 3100 76 300 −48 28 true fold) | again=%s (want empty)" % [no_press.is_empty(), far.is_empty(), past.is_empty(), upper.is_empty(), front.is_empty(), shut.is_empty(), String(got_in.get("kind", "-")), String(got_in.get("id", "-")), float(got_in.get("x", 0.0)), float(got_in.get("y", 0.0)), float(got_in.get("w", 0.0)), float(got_in.get("bx", 0.0)), float(got_in.get("z", 0.0)), float(got_in.get("d", 0.0)), rustle_in, ph_in, again.is_empty()])
	# 시계(1/16 틱, x 310 으로 stand): 1틱 fold x 300 y 3100 curl_k 0.15625 curl_v 0; 7틱 rise(creak) y 3100 curl_k 1 curl_v 1; 20틱 rise y 3163.5532 curl_v 1; 26틱 bloom(pop) y 3180; 29틱 bloom curl_k 0.2917 curl 참; 31틱 open curl 거짓; 40틱 open
	var got: Dictionary = {}
	for i in 40:
		var now := float(i + 1) * dt
		rustle.stop(); creak.stop(); pop.stop(); sigh.stop()
		ct.sync(now)
		var r := ct.stand(got_in, 310.0, dt, fig)
		if (i + 1) in [1, 7, 20, 26, 29, 31, 40]: got[i + 1] = { "r": r, "ck": float(fig.get_meta("curl_k", 9.0)), "cv": float(fig.get_meta("curl_v", 9.0)), "ok": float(s["open_k"]), "creak": creak.playing, "pop": pop.playing }
	var showt := func(k: int) -> String: var e: Dictionary = got[k]; var r: Dictionary = e["r"]; return "%d: x=%.1f y=%.4f off=%s curl=%s phase=%s ck=%.4f cv=%.1f open=%.4f creak=%s pop=%s" % [k, float(r["x"]), float(r["y"]), r["off"], r["curl"], String(r["phase"]), float(e["ck"]), float(e["cv"]), float(e["ok"]), e["creak"], e["pop"]]
	print("CLOCK ", showt.call(1), " (want 300.0 3100.0000 false true fold 0.1562 0.0 0.2953 false false) | ", showt.call(7), " (want 300.0 3100.0000 … rise 1.0000 1.0 0.0000 creak=true) | ", showt.call(20), " (want 3163.5532 … rise 1.0000 1.0) | ", showt.call(26), " (want 3180.0000 … bloom 1.0000 0.0 0.0000 pop=true) | ", showt.call(29), " (want 3180.0000 false true bloom 0.2917 0.0 0.7083) | ", showt.call(31), " (want 3180.0000 false false open 0.0000 0.0 1.0000) | ", showt.call(40), " (want open)")
	# 핀 바닥(2.5, 3180): x 340 은 잎 턱 위(on), x 360 은 잎 끝을 넘어 off, x 276 은 발판 쪽을 넘어 off, 모르는 꽃은 off
	var on_leaf := ct.stand(got_in, 340.0, dt, fig); var off_far := ct.stand(got_in, 360.0, dt, fig); var off_in := ct.stand(got_in, 276.0, dt, fig)
	var lost := ct.stand({ "id": "nope", "x": 5.0, "y": 7.0 }, 50.0, dt)
	# 착지(바닥 3180, x 330): 지나는 몸(3185→3175) 받는다; 10 위에서 내려서는 몸 step; 밑 10 의 몸 ramp; 20 위·30 밑·오르는 몸·옆(x 250)·앞(z −20)은 아니다
	rustle.stop()
	var cross := ct.land(330.0, 3185.0, 3175.0, z); var rustle_land := rustle.playing; var step := ct.land(330.0, 3190.0, 3189.0, z); var ramp := ct.land(330.0, 3170.0, 3169.9, z)
	var high := ct.land(330.0, 3200.0, 3199.0, z); var low := ct.land(330.0, 3150.0, 3149.0, z); var rising := ct.land(330.0, 3175.0, 3176.0, z); var side := ct.land(250.0, 3185.0, 3175.0, z); var fr := ct.land(330.0, 3185.0, 3175.0, -20.0)
	print("FLOOR leaf: x=%.0f y=%.0f off=%s curl=%s (want 340 3180 false false) | far: off=%s (want true) in: off=%s (want true) | unknown: off=%s x=%.0f y=%.0f (want true 50 7) | LAND cross=%s y=%.0f x=%.0f w=%.0f z=%.0f d=%.0f step=%s ramp=%s rustle=%s (want tulip 3180 280 76 −48 28 false false true) | step: y=%.0f step=%s (want 3180 true) ramp: y=%.0f ramp=%s (want 3180 true) | high=%s low=%s rising=%s side=%s front=%s (want empty ×5)" % [float(on_leaf["x"]), float(on_leaf["y"]), on_leaf["off"], on_leaf["curl"], off_far["off"], off_in["off"], lost["off"], float(lost["x"]), float(lost["y"]), String(cross.get("kind", "-")), float(cross.get("y", 0.0)), float(cross.get("x", 0.0)), float(cross.get("w", 0.0)), float(cross.get("z", 0.0)), float(cross.get("d", 0.0)), cross.get("step", "-"), cross.get("ramp", "-"), rustle_land, float(step.get("y", 0.0)), step.get("step", "-"), float(ramp.get("y", 0.0)), ramp.get("ramp", "-"), high.is_empty(), low.is_empty(), rising.is_empty(), side.is_empty(), fr.is_empty()])
	# 시들기(마지막 stand 2.5): 4.0 에 wilt(sigh) 가 시작, 7.0 은 반(k_stem 0.5 → y 3140, droop 0.5), 10.0 에 다 내려와 close, 10.2 open_k 0.675, 10.5 rest open_k 0.35 — 그때 다시 든다
	sigh.stop()
	ct.sync(4.0); var ph4 := String(s["phase"]); var sigh4 := sigh.playing
	ct.sync(7.0); var y7 := ct.floor_of(s); var dr7 := float(s["droop"]); var ph7 := String(s["phase"])
	ct.sync(10.0); var ph10 := String(s["phase"]); var y10 := ct.floor_of(s)
	ct.sync(10.2); var ok102 := float(s["open_k"])
	ct.sync(10.5); var ph105 := String(s["phase"]); var ok105 := float(s["open_k"])
	var in2 := ct.enter(on_a, 270.0, z, true)
	print("WILT 4.0: phase=%s sigh=%s (want wilt true) 7.0: y=%.4f droop=%.4f phase=%s (want 3140.0000 0.5000 wilt) 10.0: phase=%s y=%.0f (want close 3100) 10.2: open=%.4f (want 0.6750) 10.5: phase=%s open=%.4f (want rest 0.3500) | enter again: %s (want tulip)" % [ph4, sigh4, y7, dr7, ph7, ph10, y10, ok102, ph105, ok105, String(in2.get("kind", "-"))])
	# 서서 버티기(10.5 에 들었다, 핌 12.4): 18.0 까지 매 틱 stand — 17.4 에 선 채 시들기, 18.0 y 3177.76 off 거짓; 24.0 까지 계속 서면 23.4 에 다 내려와 spent(벌어진 채 기다린다), y 3100, C 는 아니다, 걸어 올라서는 land 는 받는다; 떠나면 24.3 close, 24.8 rest
	for i in 120: ct.sync(10.5 + float(i + 1) * dt); ct.stand(in2, 330.0, dt, fig)
	var r18 := ct.stand(in2, 330.0, dt, fig); var ph18 := String(s["phase"])
	for i in 96: ct.sync(18.0 + float(i + 1) * dt); ct.stand(in2, 330.0, dt, fig)
	var r24 := ct.stand(in2, 330.0, dt, fig); var ph24 := String(s["phase"]); var ok24 := float(s["open_k"])
	var spent_c := ct.enter(on_a, 270.0, z, true); var spent_l := ct.land(330.0, 3100.0, 3099.9, z)
	ct.sync(24.3); var ph243 := String(s["phase"])
	ct.sync(24.8); var ph248 := String(s["phase"])
	print("STAY 18.0: y=%.4f off=%s phase=%s (want 3177.7600 false wilt) 24.0: y=%.0f off=%s phase=%s open=%.2f (want 3100 false spent 1.00) C=%s (want empty) land=%s y=%.0f (want tulip 3100) | 24.3: %s (want close) 24.8: %s (want rest)" % [float(r18["y"]), r18["off"], ph18, float(r24["y"]), r24["off"], ph24, ok24, spent_c.is_empty(), String(spent_l.get("kind", "-")), float(spent_l.get("y", 0.0)), ph243, ph248])
	# 그림: 노드 아이 10(받침 팔·화분·줄기·잎 둘·머리·소리 넷), 줄기 아이 1, 머리 아이 9(바닥·꽃잎 여섯·잎 턱·잎맥), 꽃잎 축 아이 1; 노드 자리 −5 86.1111 −1.3333;
	# 쉼: 줄기 scale 1.1111 머리 y 0 꽃잎 −0.2925; 핌(k_stem 1, open 1): 줄기 3.3333 머리 2.2222 꽃잎 −1.3; spent(droop 1): 꽃잎 −1.7
	var node: Node3D = s["node"]; var stem: Node3D = s["stem"]; var head: Node3D = s["head"]; var p0: Node3D = (s["petals"] as Array)[0]
	ct._place(s); var sc_r := stem.scale.y; var hy_r := head.position.y; var pz_r := p0.rotation.z
	s["k_stem"] = 1.0; s["open_k"] = 1.0; s["droop"] = 0.0; ct._place(s); var sc_o := stem.scale.y; var hy_o := head.position.y; var pz_o := p0.rotation.z
	s["k_stem"] = 0.0; s["droop"] = 1.0; ct._place(s); var pz_s := p0.rotation.z
	print("VISUAL node children=%d (want 10) stem children=%d (want 1) head children=%d (want 9) petal children=%d (want 1) node pos=%.4f %.4f %.4f (want −5.0000 86.1111 −1.3333) | rest: stem=%.4f head y=%.4f petal=%.4f (want 1.1111 0.0000 −0.2925) | open: stem=%.4f head y=%.4f petal=%.4f (want 3.3333 2.2222 −1.3000) | spent petal=%.4f (want −1.7000)" % [node.get_child_count(), stem.get_child_count(), head.get_child_count(), p0.get_child_count(), node.position.x, node.position.y, node.position.z, sc_r, hy_r, pz_r, sc_o, hy_o, pz_o, pz_s])
	# 자세: 반 접힘(curl_k 0.5, v 0): 골반 0.310 몸통 0.2475 엉덩이 −0.925/−0.975 무릎 1.150 어깨 −0.725 어깨 z ∓0.070 팔꿈치 −1.050; 다 접혀 늘어나는 중(curl_k 1, v 1): 골반 0.17..0.20 앞 엉덩이 −1.97..−1.85 앞 무릎 2.30..2.42 몸통 0.495..0.5625
	fig.pose_request = "curl"
	fig.set_meta("curl_k", 0.5); fig.set_meta("curl_v", 0.0)
	await process_frame; await process_frame; await process_frame
	var early_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	while fig.pose_t < 1.2: await process_frame   # 헤드리스는 프레임이 빠르다 — 시간으로 기다린다
	var pel_h := fig.pelvis.position.y; var torso_h := fig.torso.rotation.x; var hip_h: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_hb: float = (fig.hips[-1.0] as Node3D).rotation.x; var knee_h: float = (fig.knees[1.0] as Node3D).rotation.x
	var sh_h: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz_h: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shz_hb: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var el_h: float = (fig.elbows[1.0] as Node3D).rotation.x
	fig.set_meta("curl_k", 1.0); fig.set_meta("curl_v", 1.0)
	var pel_lo := 9.0; var pel_hi := 0.0; var hip_lo := 0.0; var hip_hi := -9.0; var knee_lo := 9.0; var knee_hi := 0.0; var tor_lo := 9.0; var tor_hi := 0.0
	while fig.pose_t < 1.8: await process_frame   # 블렌딩이 새 curl_k 에 닿을 시간
	var t1 := fig.pose_t
	while fig.pose_t < t1 + 0.9:   # 1.6Hz 한 주기(0.625초)보다 길게
		await process_frame
		pel_lo = minf(pel_lo, fig.pelvis.position.y); pel_hi = maxf(pel_hi, fig.pelvis.position.y)
		hip_lo = minf(hip_lo, (fig.hips[1.0] as Node3D).rotation.x); hip_hi = maxf(hip_hi, (fig.hips[1.0] as Node3D).rotation.x)
		knee_lo = minf(knee_lo, (fig.knees[1.0] as Node3D).rotation.x); knee_hi = maxf(knee_hi, (fig.knees[1.0] as Node3D).rotation.x)
		tor_lo = minf(tor_lo, fig.torso.rotation.x); tor_hi = maxf(tor_hi, fig.torso.rotation.x)
	print("POSE early shoulder=%.2f (want > −0.4: the arms have only begun to wrap) half: pelvis=%.3f (want 0.310) torso=%.4f (want 0.2475) hips=%.3f %.3f (want −0.925 −0.975) knee=%.3f (want 1.150) shoulder=%.3f (want −0.725) z=%.3f %.3f (want −0.070 0.070) elbow=%.3f (want −1.050) | squeezing: pelvis %.3f..%.3f (want 0.170..0.200) hip %.3f..%.3f (want −1.970..−1.850) knee %.3f..%.3f (want 2.300..2.420) torso %.4f..%.4f (want 0.4950..0.5625) pose_t=%.2f" % [early_sh, pel_h, torso_h, hip_h, hip_hb, knee_h, sh_h, shz_h, shz_hb, el_h, pel_lo, pel_hi, hip_lo, hip_hi, knee_lo, knee_hi, tor_lo, tor_hi, fig.pose_t])
	# 진짜 탑: 1..60층에 plan 이 찾는 튤립 — 공중정원 층 5, 6, 8, 9, 40, 41, 42, 44 중 덩굴·다리·그물·집라인·화분(taken)이 안 든 84..200 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var vp: Array = cv.plan(n, pl); var bp: Array = cb.plan(n, pl); var hp: Array = ch.plan(n, pl, gm.wind_of(n), bp); var zp: Array = cz.plan(n, pl, hp + bp); var pp: Array = cp.plan(n, pl, vp + bp + hp + zp)
		var out2 := ct.plan(n, pl, vp + bp + hp + zp + pp)
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f dy %.0f lift %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["b_y"]) - float(v["a_y"]), float(v["lift"])])]); count += out2.size()
	print("TOWER floors=", bands, " tulips=", count, " (want a subset of 5, 6, 8, 9, 40, 41, 42, 44 — one each, never 7 or 43, never another theme; lift = dy − 40 in 60..90; the upper hop may be crumble or spring)")
	quit()
