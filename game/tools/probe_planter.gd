extends SceneTree
## 시소 화분 팩 점검(헤드리스): 자료가 읽히나, 공중정원 층의 잇단 still 발판 짝(80..200 px 틈, 위 발판이 150 px 안) 중 가장 넓은 틈에만 화분이 놓이나(좁은 틈은 지고, 들린 끝 위의 상자에 드는 발판·진폭째 드는 움직이는 발판·taken 조각(덩굴·집라인)이 든 틈은 비켜 가며 먼 밑의 조각은 안 닿고, 다른 테마 층·바람구멍 층은 아니다, 거울 층은 반대로),
## 받침이 아래 윗면 위 반틈(45°)에 서고 가까운 끝이 overlap 16 만큼 발판 위에, 먼 끝이 위 발판 4 앞에 닿나, 화분 위에서 C 를 누르면 덩굴이 끊기고(snap) 0.25초 뒤 먼 끝에 떨어져(thud, creak) 1/16 틱으로 0.6초에 반대로 기울며 몸이 틈 높이 120 까지 오르나(clunk, 메타 balance_k·balance_v), 2초 뒤 미끄러져 떨어지며 몸 쪽으로 돌아오나, 8초 뒤 덩굴에 새 화분이 맺히나, 그 사이 C 는 안 듣나,
## 화분이 없으면 선 몸 쪽으로 기우나(받침 ±12 는 수평, 받침 위 높이는 늘 y_piv), 아무도 없으면 가까운 끝으로 돌아가나, 끝을 지나면 off 인가,
## 바닥을 지나는 몸·catch 안에서 내려서는 몸·비탈 밑 catch 안의 몸만 land 가 받나(멀리 위·밑·오르는 몸·옆·앞은 아니다), 들린 끝은 120 높이에서 받나, 모르는 화분은 off 인가,
## 받침 팔·핀·화분(바닥·흙·앞뒤 턱·양끝·꽃 다섯)·덩굴·항아리·소리 넷이 그려지고 화분이 기울기대로 도나(±0.7854 / 0), 항아리가 덩굴에서 먼 끝으로 내려앉고 맺히는 동안은 안 보이나, 꽃이 기우는 동안 젖고 서면 서나, balance 자세가 팔을 벌리고 무릎을 느슨히 하고 오르막 쪽으로 기울며 기울 땐 더 접고 잔걸음을 치나, 진짜 탑의 1..60층에서 plan 이 공중정원 층에만 화분을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cp := ClimbPlanter.new(); root.add_child(cp)
	var cv := ClimbVine.new(); root.add_child(cv)
	var ch := ClimbHammock.new(); root.add_child(ch)
	var cz := ClimbZip.new(); root.add_child(cz)
	var cb := ClimbBridge.new(); root.add_child(cb)
	await process_frame
	print("PACK id=", cp.pack.get("id"), " kind=", cp.kind.size() > 0, " pose=", cp.pack.get("pose"), " themes=", cp.pack.get("themes"), " overlap=%.0f clear=%.0f slope=%.2f tip=%.2f mid_w=%.0f hang=%.0f fall=%.2f hold=%.1f slide=%.1f regrow=%.1f catch=%.0f deck_d=%.0f th=%.0f (want 16 4 1.00 0.60 24 30 0.25 2.0 0.6 8.0 16 28 10)" % [cp.overlap(), cp.clear_px(), cp.slope(), cp.tip_s(), cp.mid_w(), cp.hang(), cp.fall_s(), cp.hold_s(), cp.slide_s(), cp.regrow_s(), cp.catch_px(), cp.deck_d(), cp.th()])
	var plats: Array = [
		{ "id": "5.0", "x": 100.0, "y": 3000.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5.1", "x": 400.0, "y": 3020.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5.2", "x": 150.0, "y": 3220.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "5.3", "x": 425.0, "y": 3250.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5.4", "x": 600.0, "y": 3280.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5s", "x": 560.0, "y": 3270.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cp.plan(5, plats)
	var vined := cp.plan(5, plats, [{ "id": "5.v0", "kind": "vine", "x": 255.0, "w": 20.0, "y": 3000.0 }])   # 덩굴(245..285, 2990..3220)이 5.0↔5.1 의 상자(260..400, 3001..3200)만 가른다 — 5.2↔5.3 (115, 상자 290..425, 3221..) 이 남는다
	var zipped := cp.plan(5, plats, [{ "id": "5.Z0", "kind": "zip", "x": 300.0, "w": 100.0, "y": 3020.0 }])   # 집라인(290..410, 3010..3240)이 두 상자를 다 가른다
	var lowered := cp.plan(5, plats, [{ "id": "5.H0", "kind": "hammock", "x": 300.0, "w": 60.0, "y": 2700.0 }])   # 먼 밑의 그물(..2920)은 어느 상자에도 안 닿는다
	var moved := plats.duplicate(true); moved.append({ "id": "5m", "x": 330.0, "y": 3060.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째(240..480, 3060) 5.0↔5.1 의 상자(3001..3200)에 든다 — 5.2↔5.3 의 상자(3221..)엔 아니다
	var movep := cp.plan(5, moved)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := cp.plan(5, mirror)
	var lib := cp.plan(10, plats); var vent := cp.plan(7, plats); var f8 := cp.plan(8, plats); var f9 := cp.plan(9, plats); var f40 := cp.plan(40, plats); var f43 := cp.plan(43, plats); var f44 := cp.plan(44, plats); var f6 := cp.plan(6, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cp.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s a_edge %.0f b_edge %.0f xm %.1f half %.1f y_piv %.1f y_top %.0f x %.0f w %.0f y %.1f z %.0f d %.0f" % [float(v["dir"]), float(v["gap"]), String(v["a_id"]), String(v["b_id"]), float(v["a_edge"]), float(v["b_edge"]), float(v["xm"]), float(v["half"]), float(v["y_piv"]), float(v["y_top"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["z"]), float(v["d"])]
	print("PLAN free=", free.map(show), " (want 1: 5.P0 dir 1 gap 120 5.0→5.1 wins over 5.2↔5.3 gap 115; 5.1↔5.2 gap 90 cut by 5.3 over its raised end, 5.3↔5.4 gap 55 out: a_edge 280 b_edge 400 xm 340.0 half 60.0 y_piv 3060.0 y_top 3120 x 264 w 132 y 3060.0 z −48 d 28)")
	print("PLAN vined=", vined.map(show), " (want 5.P0 dir 1 gap 115 5.2→5.3 a_edge 310 b_edge 425 xm 367.5 half 57.5 y_piv 3277.5 y_top 3335 x 294 w 127) zipped=", zipped.size(), " lowered=", lowered.size(), " (want 0 1) moved=", movep.map(func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f xm %.1f" % [float(v["gap"]), float(v["xm"])]), " (want 5.P0 gap 115 xm 367.5) right=", right.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f a_edge %.0f b_edge %.0f xm %.1f x %.0f" % [float(v["dir"]), float(v["gap"]), float(v["a_edge"]), float(v["b_edge"]), float(v["xm"]), float(v["x"])]), " (want 5.P0 dir −1 gap 120 a_edge 680 b_edge 560 xm 620.0 x 564) lib=", lib.size(), " vent7=", vent.size(), " f8=", f8.size(), " f9=", f9.size(), " f40=", f40.size(), " vent43=", f43.size(), " f44=", f44.size(), " f6=", f6.size(), " (want 0 0 1 1 1 0 1 1)")
	var s: Dictionary = cp.troughs[0]
	var on: Dictionary = free[0]
	var z := C.PLAYER_Z
	var fig := Stick3D.new(); root.add_child(fig)
	var dt := 0.0625
	var snap: AudioStreamPlayer3D = s["snap"]; var thud: AudioStreamPlayer3D = s["thud"]; var clunk: AudioStreamPlayer3D = s["clunk"]; var creak: AudioStreamPlayer3D = s["creak"]
	# 들어올리기(1/16 틱): 몸이 x 280(u −60, 가까운 끝)에 서서 1틱에 C — snap, y 3000, v 0; 5틱(0.3125) 화분 on: thud·creak, k −1, v 1; 6틱 k −0.7917 y 3012.5 bk 0.7917; 10틱 k 0.0417 y 3062.5; 15틱 k 1 y 3120 clunk, bk −1, v 0; 20틱 C 는 안 듣는다;
	# 37틱(2.3125) 미끄러짐: creak, k 1; 38틱 k 0.7917 y 3107.5; 47틱(2.9375) k −1 y 3000 clunk, 항아리 regrow; 10.9 regrow, 11.0 hung
	var got: Dictionary = {}
	var dropped := false; var late := true
	for i in 47:
		var now := float(i + 1) * dt
		snap.stop(); thud.stop(); clunk.stop(); creak.stop()
		cp.sync(now)
		if i == 0: dropped = cp.drop(on, true)
		if i == 19: late = cp.drop(on, true)
		var r := cp.stand(on, 280.0, dt, fig)
		if (i + 1) in [1, 5, 6, 10, 15, 37, 38, 47]: got[i + 1] = { "r": r, "bk": float(fig.get_meta("balance_k", 9.0)), "bv": float(fig.get_meta("balance_v", 9.0)), "snap": snap.playing, "thud": thud.playing, "clunk": clunk.playing, "creak": creak.playing, "pot": String(s["pot_st"]) }
	var showt := func(k: int) -> String: var e: Dictionary = got[k]; var r: Dictionary = e["r"]; return "%d: k=%.4f y=%.4f bk=%.4f bv=%.1f snap=%s thud=%s clunk=%s creak=%s pot=%s" % [k, float(r["k"]), float(r["y"]), float(e["bk"]), float(e["bv"]), e["snap"], e["thud"], e["clunk"], e["creak"], String(e["pot"])]
	print("LIFT dropped=%s late=%s (want true false) | " % [dropped, late], showt.call(1), " (want −1.0000 3000.0000 … 0.0 true false false false falling) | ", showt.call(5), " (want −1.0000 3000.0000 … 1.0 false true false true on) | ", showt.call(6), " (want −0.7917 3012.5000 0.7917 1.0 … on) | ", showt.call(10), " (want 0.0417 3062.5000) | ", showt.call(15), " (want 1.0000 3120.0000 −1.0000 0.0 false false true false on) | ", showt.call(37), " (want 1.0000 3120.0000 … 1.0 … creak=true sliding) | ", showt.call(38), " (want 0.7917 3107.5000) | ", showt.call(47), " (want −1.0000 3000.0000 … clunk=true regrow)")
	cp.sync(10.9); var ph109 := cp.pot_phase(s, 10.9); cp.sync(11.0); var ph110 := cp.pot_phase(s, 11.0); var vis110: bool = (s["pot"] as Node3D).visible
	# 무게(화분은 덩굴에, 20.0 에 쉬고 있다): x 360(u 20)에 서면 creak 하고 +1 로 — 20.0625 k −0.7917 y 3075.8333, 21.0 k 1 y 3040; 21.0625 x 328(u −12)은 수평으로 — 21.5 k 0 y 3060; 21.5625 x 327(u −13)은 −1 로 — 21.625 k −0.2083;
	# 떠남(23.0 x 360, 23.0625; 24.0 에 아무도 없다): 24.0 에 목표 −1, 24.6 k −1; x 397 은 off, x 396 은 아니다(y 3004 at k 1)
	creak.stop()
	cp.sync(20.0); cp.stand(on, 360.0, dt, fig); var creak_w := creak.playing
	cp.sync(20.0625); var w1 := cp.stand(on, 360.0, dt, fig)
	cp.sync(21.0); var w2 := cp.stand(on, 360.0, dt, fig)
	cp.sync(21.0625); cp.stand(on, 328.0, dt, fig)
	cp.sync(21.5); var lvl := cp.stand(on, 328.0, dt, fig)
	cp.sync(21.5625); cp.stand(on, 327.0, dt, fig)
	cp.sync(21.625); var tipa := cp.stand(on, 327.0, dt, fig)
	cp.sync(23.0); cp.stand(on, 360.0, dt, fig); cp.sync(23.0625); cp.stand(on, 360.0, dt, fig)
	cp.sync(24.0); var tgt24 := float(s["target"]); cp.sync(24.6); var k246 := cp.k_at(s, 24.6)
	s["target"] = 1.0; s["k_from"] = 1.0
	var past := cp.stand(on, 397.0, dt, fig); var over := cp.stand(on, 396.0, dt, fig)
	print("POT regrow@10.9=%s hung@11.0=%s visible=%s (want regrow hung true) | WEIGHT creak=%s (want true) 20.0625: k=%.4f y=%.4f (want −0.7917 3075.8333) 21.0: k=%.4f y=%.0f (want 1.0000 3040) level@21.5: k=%.4f y=%.0f (want 0.0000 3060) tip(u −13)@21.625: k=%.4f (want −0.2083) | LEFT target@24=%.0f k@24.6=%.4f (want −1 −1.0000) | past: off=%s (want true) over: off=%s y=%.0f (want false 3004)" % [ph109, ph110, vis110, creak_w, float(w1["k"]), float(w1["y"]), float(w2["k"]), float(w2["y"]), float(lvl["k"]), float(lvl["y"]), float(tipa["k"]), tgt24, k246, past["off"], over["off"], float(over["y"])])
	# 착지(쉼, x 310 = u −30, 바닥 3030): 지나는 몸(3035→3025) 받는다; 10 위에서 내려서는 몸 step; 비탈 밑 8 의 몸 ramp; 28 위·22 밑·오르는 몸·옆(x 250)·앞(z −20)은 아니다; 끝(x 264, u −76)은 a 높이 3000; 들린 끝(k +1, x 280)은 3120 에서 받는다; 모르는 화분은 off
	s["target"] = -1.0; s["k_from"] = -1.0; s["t_tip"] = 0.0
	var cross := cp.land(310.0, 3035.0, 3025.0, z); var step := cp.land(310.0, 3040.0, 3039.0, z); var ramp := cp.land(310.0, 3022.0, 3021.9, z)
	var high := cp.land(310.0, 3058.0, 3057.0, z); var low := cp.land(310.0, 3008.0, 3007.0, z); var rising := cp.land(310.0, 3022.0, 3023.0, z); var side := cp.land(250.0, 3000.0, 2999.0, z); var front := cp.land(310.0, 3035.0, 3025.0, -20.0)
	var endl := cp.land(264.0, 3000.0, 2999.0, z)
	s["target"] = 1.0; s["k_from"] = 1.0
	var raised := cp.land(280.0, 3122.0, 3118.0, z)
	var lost := cp.stand({ "id": "nope", "x": 5.0, "y": 7.0 }, 50.0, dt)
	print("LAND cross=%s y=%.0f x=%.0f w=%.0f z=%.0f d=%.0f step=%s ramp=%s (want planter 3030 264 132 −48 28 false false) | step: y=%.0f step=%s (want 3030 true) ramp: y=%.0f ramp=%s (want 3030 true) | high=%s low=%s rising=%s side=%s front=%s (want empty ×5) | end: y=%.0f (want 3000) raised: y=%.0f (want 3120) | unknown: off=%s x=%.0f y=%.0f (want true 50 7)" % [String(cross.get("kind", "-")), float(cross.get("y", 0.0)), float(cross.get("x", 0.0)), float(cross.get("w", 0.0)), float(cross.get("z", 0.0)), float(cross.get("d", 0.0)), cross.get("step", "-"), cross.get("ramp", "-"), float(step.get("y", 0.0)), step.get("step", "-"), float(ramp.get("y", 0.0)), ramp.get("ramp", "-"), high.is_empty(), low.is_empty(), rising.is_empty(), side.is_empty(), front.is_empty(), float(endl.get("y", 0.0)), float(raised.get("y", 0.0)), lost["off"], float(lost["x"]), float(lost["y"])])
	# 그림: 노드 아이 9(팔·핀·화분·덩굴·항아리·소리 넷), 화분 아이 11(바닥·흙·턱 둘·끝 둘·꽃 다섯), 꽃 아이 2; 노드 자리 −3.8889 85.0000 −1.3333; k −1 회전 0.7854, +1 −0.7854, 0 0;
	# 항아리: 매달림 (1.5556 2.7500 −0.2333), 먼 끝에 앉음(k 1) y −1.3056, 맺히는 동안 안 보임; 꽃: 기우는 동안 −0.35 로 젖어 가고(0.4초에 −0.3363), 서면 0
	var node: Node3D = s["node"]; var deck: Node3D = s["deck"]; var stem0: Node3D = (s["stems"] as Array)[0]; var pot: Node3D = s["pot"]
	s["target"] = -1.0; s["k_from"] = -1.0; s["pot_st"] = "hung"; cp.sync(29.0); cp._place(s); var rot_a := deck.rotation.z; var hung_p := pot.position
	s["target"] = 1.0; s["k_from"] = 1.0; s["pot_st"] = "on"; s["t_pot"] = 29.0; cp._place(s); var rot_b := deck.rotation.z; var on_y := pot.position.y
	s["target"] = 0.0; s["k_from"] = 0.0; s["pot_st"] = "regrow"; cp._place(s); var rot_0 := deck.rotation.z; var regrow_vis := pot.visible
	s["pot_st"] = "hung"; s["target"] = -1.0; s["k_from"] = -1.0; s["t_tip"] = 29.0
	cp.sync(30.0)
	for i in 8: cp.stand(on, 360.0, dt, fig); cp._process(0.05)   # 몸이 선 채로 0.4초 — 꽃이 NOD_T 0.15 로 젖어 간다(1 − (2/3)^8 = 0.961)
	var nod_tip := stem0.rotation.z
	cp.sync(31.0); cp._process(1.0); var nod_rest := stem0.rotation.z; var k32 := cp.k_at(s, 32.0)
	print("VISUAL node children=%d (want 9) deck children=%d (want 11) stem children=%d (want 2) node pos=%.4f %.4f %.4f (want −3.8889 85.0000 −1.3333) | rot a=%.4f b=%.4f level=%.4f (want 0.7854 −0.7854 0.0000) | pot hung=%.4f %.4f %.4f (want 1.5556 2.7500 −0.2333) on y=%.4f (want −1.3056) regrow visible=%s (want false) | nod tip=%.4f (want −0.3363) rest=%.4f (want 0.0000) k@32=%.0f (want −1)" % [node.get_child_count(), deck.get_child_count(), stem0.get_child_count(), node.position.x, node.position.y, node.position.z, rot_a, rot_b, rot_0, hung_p.x, hung_p.y, hung_p.z, on_y, regrow_vis, nod_tip, nod_rest, k32])
	# 자세: 오르막(balance_k 0.5, v 0): 골반 0.370 몸통 0.1125 (lean 0.25 × 0.45) 엉덩이 −0.200/−0.200 무릎 0.400 어깨 −0.100 어깨 z ∓1.350 팔꿈치 −0.200; 기우는 중(v 1): 골반 0.340 무릎 0.650 어깨 z ∓1.650 엉덩이는 −0.2 ± 0.12 의 잔걸음, 몸통 그대로
	fig.pose_request = "balance"
	fig.set_meta("balance_k", 0.5); fig.set_meta("balance_v", 0.0)
	await process_frame; await process_frame; await process_frame
	var early_z: float = (fig.shoulders[1.0] as Node3D).rotation.z
	for i in 60: await process_frame
	var pel_h := fig.pelvis.position.y; var torso_h := fig.torso.rotation.x; var hip_h: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_hb: float = (fig.hips[-1.0] as Node3D).rotation.x; var knee_h: float = (fig.knees[1.0] as Node3D).rotation.x
	var sh_h: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz_h: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shz_hb: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var el_h: float = (fig.elbows[1.0] as Node3D).rotation.x
	fig.set_meta("balance_v", 1.0)
	for i in 30: await process_frame
	var pel_v := fig.pelvis.position.y; var torso_v := fig.torso.rotation.x; var knee_v: float = (fig.knees[1.0] as Node3D).rotation.x; var shz_v: float = (fig.shoulders[1.0] as Node3D).rotation.z; var hip_v: float = (fig.hips[1.0] as Node3D).rotation.x
	print("POSE early z=%.2f (want > −1.3: the arms have only begun to open) uphill: pelvis=%.3f (want 0.370) torso=%.4f (want 0.1125) hips=%.3f %.3f (want −0.200 −0.200) knee=%.3f (want 0.400) shoulder=%.3f (want −0.100) z=%.3f %.3f (want −1.350 1.350) elbow=%.3f (want −0.200) | tipping: pelvis=%.3f (want 0.340) torso=%.4f (want 0.1125) knee=%.3f (want 0.650) z=%.3f (want −1.650) hip=%.3f (want −0.2 ± 0.12) pose_t=%.2f" % [early_z, pel_h, torso_h, hip_h, hip_hb, knee_h, sh_h, shz_h, shz_hb, el_h, pel_v, torso_v, knee_v, shz_v, hip_v, fig.pose_t])
	# 진짜 탑: 1..60층에 plan 이 찾는 화분 — 공중정원 층 5..9, 40..44 중 바람구멍 층(7, 43)이 아니고 덩굴·다리·그물·집라인(taken)이 안 든 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var vp: Array = cv.plan(n, pl); var bp: Array = cb.plan(n, pl); var hp: Array = ch.plan(n, pl, gm.wind_of(n), bp); var zp: Array = cz.plan(n, pl, hp + bp)
		var out2 := cp.plan(n, pl, vp + bp + hp + zp)
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f dy %.0f top %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["b_y"]) - float(v["a_y"]), float(v["y_top"]) - float(v["a_y"])])]); count += out2.size()
	print("TOWER floors=", bands, " troughs=", count, " (want a subset of 5, 6, 8, 9, 40, 41, 42, 44 — one each, never 7 or 43, never another theme; top ≈ dy)")
	quit()
