extends SceneTree
## 등대 렌즈 팩 점검(헤드리스): 자료가 읽히나, 구름바다 층의 잇단 still 발판 짝(90..220 px 틈, 위 발판이 40..150 px 높다) 중 가장 넓은 틈에만 렌즈가 서나(틈이 좁은 짝은 지고, taken 조각(뗏목)이 든 틈은 비켜 가며, 진폭째 상자에 드는 움직이는 발판도, 통풍구 층·다른 테마 층은 아니다, 거울 층은 반대로, 뭉치 셋은 1/4·1/2·3/4 자리에 rise 씩 높이),
## 시계가 뭉치를 차례로 켜나(1.1..2.6, 2.6..4.1, 4.1..5.6 — 뒤 반 바퀴와 바퀴 사이는 아무것도, 12초마다 되돌아온다), 꺼지기 0.4초 전 fading 이고 꺼지면 holds 가 아니며 농도가 appear·fade 를 따르나, 빛줄기의 각이 뭉치를 겨누나,
## 켜진 뭉치의 윗면을 지나 떨어지는 몸만 올라서나(x 밖·꺼짐·아래·앞은 아니다), 아래 발판의 틈 쪽 가장자리에서 C 를 누를 때만 돌리나(다른 발판·멀리·앞·C 없이·이미 빠른 동안엔 아니다), 돌린 뒤 12초 동안 두 배로 돌고(창이 반으로) 그 뒤 본 박자로 이어지며 다시 돌릴 수 있나(boost 가 접히나),
## 돌탑·북·빛줄기·바퀴·축·뭉치 셋이 그려지고 농도와 각이 시계를 따르며 굳을 때 종이 울리나, spin 자세가 쥐고 돌리고 놓고 서나, 진짜 탑의 1..60층에서 plan 이 구름바다 층(통풍구 층 빼고)에만 렌즈를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var ln := ClimbLens.new(); root.add_child(ln)
	var cr := ClimbRaft.new(); root.add_child(cr)
	var mu := ClimbMushroom.new(); root.add_child(mu)
	var cp := ClimbPlank.new(); root.add_child(cp)
	var ba := ClimbBalloon.new(); root.add_child(ba)
	await process_frame
	print("PACK id=", ln.pack.get("id"), " kind=", ln.kind.size() > 0, " pose=", ln.pack.get("pose_spin"), " themes=", ln.pack.get("themes"), " tower=%.0f×%.0f puff=%.0f×%.0f rise=%.0f turn=%.1f lit=%.2f glow=%.2f fade=%.2f appear=%.2f reach=%.0f fast=%.1f×%.1f (want 36×60 34×16 30 12.0 0.80 0.70 0.40 0.15 18 2.0×12.0) puff_w_min=%.0f w_in(100)=%.0f tw_in(100)=%.0f (want 18 21 25)" % [ln.tower_w(), ln.tower_h(), ln.puff_w(), ln.puff_h(), ln.rise(), ln.turn_s(), ln.lit_s(), ln.glow_s(), ln.fade_s(), ln.appear_s(), ln.reach(), ln.fast_rate(), ln.fast_s(), ln.puff_w_min(), ln.puff_w_in(100.0), ln.tower_w_in(100.0)])
	var plats: Array = [
		{ "id": "26.0", "x": 60.0, "y": 700.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "26.1", "x": 420.0, "y": 790.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "26.2", "x": 180.0, "y": 880.0, "w": 140.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "26.3", "x": 540.0, "y": 1000.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "26.4", "x": 300.0, "y": 1060.0, "w": 100.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "26s", "x": 700.0, "y": 1020.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := ln.plan(26, plats)
	var rafted := ln.plan(26, plats, [{ "id": "26.r0", "kind": "raft", "x": 360.0, "w": 100.0, "y": 910.0 }])
	var above := ln.plan(26, plats, [{ "id": "26.b0", "kind": "balloon", "x": 400.0, "w": 44.0, "y": 1000.0 }])   # 위 발판(26.3, y 1000) 높이의 열기구는 위 틈의 것 — 26.2↔26.3 은 그대로 (지그재그 탑: 모든 틈이 한 x 열)   # 뗏목이 26.2↔26.3 의 틈(350..470, y 910 — 띠 860..980 안) — 그 틈은 뗏목의 것: 26.0↔26.1 (200) 로
	var moved := plats.duplicate(true); moved.append({ "id": "26m", "x": 400.0, "y": 950.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째(310..550, 950) 26.2↔26.3 의 상자에 든다
	var movep := ln.plan(26, moved)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := ln.plan(26, mirror)
	var f24 := ln.plan(24, plats); var f25 := ln.plan(25, plats); var f27 := ln.plan(27, plats); var f28 := ln.plan(28, plats); var f29 := ln.plan(29, plats); var f30 := ln.plan(30, plats); var f61 := ln.plan(61, plats); var f63 := ln.plan(63, plats)
	var narrow: Array = [
		{ "id": "25.0", "x": 100.0, "y": 700.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "25.1", "x": 350.0, "y": 810.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
	]
	var tight := ln.plan(25, narrow)   # 탑의 진짜 틈 폭(93..124): 100 px 틈 — 뭉치 21, 탑 25, rise 27.5
	var band_root := Node3D.new(); root.add_child(band_root)
	ln.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s hinge %.0f mid %.0f rise %.1f x %.0f w %.0f y %.0f y_top %.0f tx %.0f puffs %s" % [float(v["dir"]), float(v["gap"]), String(v["a_id"]), String(v["b_id"]), float(v["hinge_x"]), float(v["mid_x"]), float(v["rise"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["tx"]), (v["puffs"] as Array).map(func(p: Dictionary) -> String: return "%s %.0f/%.0f" % [String(p["id"]), float(p["x"]), float(p["y"])])]
	print("PLAN free=", free.map(show), " (want 1: 26.L0 dir 1 gap 220 26.2→26.3 wins over 26.0↔26.1 gap 200; 26.1↔26.2 gap 100 and 26.3↔26.4 gap 140 lose: hinge 320 mid 430 rise 30.0 x 320 w 220 y 880 y_top 986 tx 412 puffs 26.L0.p1 358/910 26.L0.p2 413/940 26.L0.p3 468/970)")
	print("PLAN rafted=", rafted.map(show), " (want 26.L0 dir 1 gap 200 26.0→26.1 hinge 220 mid 320 rise 22.5 puffs p1 253/722 p2 303/745 p3 353/768) above=", above.map(func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f" % float(v["gap"])), " (want 26.L0 gap 220: a piece at the upper hop's height belongs to the gap above) moved=", movep.map(func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f hinge %.0f" % [float(v["gap"]), float(v["hinge_x"])]), " (want 26.L0 gap 200 hinge 220) right=", right.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f hinge %.0f mid %.0f x %.0f p1 %.0f" % [float(v["dir"]), float(v["gap"]), float(v["hinge_x"]), float(v["mid_x"]), float(v["x"]), float(((v["puffs"] as Array)[0] as Dictionary)["x"])]), " (want 26.L0 dir −1 gap 220 hinge 640 mid 530 x 420 p1 568) floors 24/25/27/28/29/30/61/63=", [f24.size(), f25.size(), f27.size(), f28.size(), f29.size(), f30.size(), f61.size(), f63.size()], " (want 0 1 0 1 1 0 1 0: a vent floor and another theme get none) tight=", tight.map(show), " (want 25.L0 dir 1 gap 100 25.0→25.1 hinge 250 mid 300 rise 27.5 x 250 w 100 y 700 y_top 798 tx 288 puffs p1 264/728 p2 290/755 p3 314/782 — 21 px puffs 25 px apart)")
	var c: Dictionary = ln.lenses[0]
	var p1: Dictionary = (c["puffs"] as Array)[0]; var p2: Dictionary = (c["puffs"] as Array)[1]; var p3: Dictionary = (c["puffs"] as Array)[2]
	var a: Dictionary = plats[2]; var b: Dictionary = plats[3]
	# 시계(보통 속도): 0.5 아무것도; 1.1 p1 (농도 0); 1.2 p1 0.667; 2.0 p1 left 0.6 fading 아니다; 2.3 fading, 농도 0.75; 2.6 p1 꺼짐·p2 켜짐; 4.1 p3; 5.61 아무것도(5.6 은 fposmod 의 끝자리라 비켜 잰다); 6.5 아무것도(절벽 반); 12.0 아무것도; 13.15 p1
	var lit_at := func(at: float) -> String: return "%s%s%s" % ["1" if ln.lit(c, 1, at) else "-", "2" if ln.lit(c, 2, at) else "-", "3" if ln.lit(c, 3, at) else "-"]
	print("CLOCK 0.5=%s 1.1=%s 1.2=%s 2.0=%s 2.6=%s 4.1=%s 5.61=%s 6.5=%s 12.0=%s 13.15=%s (want --- 1-- 1-- 1-- -2- --3 --- --- --- 1--) sol 1.1=%.3f 1.2=%.3f 2.0=%.3f 2.3=%.3f (want 0.000 0.667 1.000 0.750) left 2.0=%.2f 2.3=%.2f 3.0=%.2f (want 0.60 0.30 0.00) windows=%s %s %s (want [1.1, 2.6] [2.6, 4.1] [4.1, 5.6])" % [lit_at.call(0.5), lit_at.call(1.1), lit_at.call(1.2), lit_at.call(2.0), lit_at.call(2.6), lit_at.call(4.1), lit_at.call(5.61), lit_at.call(6.5), lit_at.call(12.0), lit_at.call(13.15), ln.solidity(c, 1, 1.1), ln.solidity(c, 1, 1.2), ln.solidity(c, 1, 2.0), ln.solidity(c, 1, 2.3), ln.left(c, 1, 2.0), ln.left(c, 1, 2.3), ln.left(c, 1, 3.0), ln.window(1), ln.window(2), ln.window(3)])
	print("BEAM 0=%.4f 1.5=%.4f 3.0=%.4f 4.5=%.4f 6.0=%.4f 9.0=%.4f (want 0.0000 0.4993 1.5708 2.1193 3.1416 4.7124: the beam aims at each puff in turn, then sweeps the cliff)" % [ln.beam_angle(c, 0.0), ln.beam_angle(c, 1.5), ln.beam_angle(c, 3.0), ln.beam_angle(c, 4.5), ln.beam_angle(c, 6.0), ln.beam_angle(c, 9.0)])
	# 발판(2.0, p1 켜짐): 떨어지는 몸(y 911 → 909)이 x 375 에서 올라선다 — kind puff 26.L0.p1 x 358 y 910 w 34 lens 26.L0; x 349 도(359 > 358), x 335 는 아니다; x 400 도(390 < 392), x 402 는 아니다; 앞 z −20 도(9 < 49), z 30 은 아니다; 아래 y 900 은 아니다; 0.5(꺼짐)엔 아니다; 2.3 에 선 몸은 fading, 2.6 엔 holds 가 아니다
	var z := -29.0
	ln.sync(0.5); var dark := ln.land(375.0, 911.0, 909.0, z)
	ln.sync(2.0)
	var ld := ln.land(375.0, 911.0, 909.0, z); var e1 := ln.land(349.0, 911.0, 909.0, z); var e2 := ln.land(335.0, 911.0, 909.0, z); var e3 := ln.land(400.0, 911.0, 909.0, z); var e4 := ln.land(402.0, 911.0, 909.0, z)
	var fr := ln.land(375.0, 911.0, 909.0, -20.0); var deep := ln.land(375.0, 911.0, 909.0, 30.0); var low := ln.land(375.0, 900.0, 899.0, z)
	var h20 := ln.holds(ld); var f20 := ln.fading(ld)
	ln.sync(2.3); var h23 := ln.holds(ld); var f23 := ln.fading(ld)
	ln.sync(2.6); var h26 := ln.holds(ld); var f26 := ln.fading(ld); var l26 := ln.land(430.0, 941.0, 939.0, z)
	print("DECK dark=%s (want true) land=%s id=%s lens=%s x=%.0f y=%.0f w=%.0f z=%.0f d=%.0f (want puff 26.L0.p1 26.L0 358 910 34 −29 82) edges=%s %s %s %s (want 26.L0.p1 - 26.L0.p1 -) front=%s deep=%s low=%s (want false true true) 2.0 holds=%s fading=%s (want true false) 2.3 holds=%s fading=%s (want true true) 2.6 holds=%s fading=%s (want false false) p2@2.6=%s (want 26.L0.p2)" % [dark.is_empty(), String(ld.get("kind", "-")), String(ld.get("id", "-")), String(ld.get("lens", "-")), float(ld.get("x", 0.0)), float(ld.get("y", 0.0)), float(ld.get("w", 0.0)), float(ld.get("z", 0.0)), float(ld.get("d", 0.0)), String(e1.get("id", "-")), String(e2.get("id", "-")), String(e3.get("id", "-")), String(e4.get("id", "-")), fr.is_empty(), deep.is_empty(), low.is_empty(), h20, f20, h23, f23, h26, f26, String(l26.get("id", "-"))])
	# 돌리기(24.0, 바퀴의 자리 hinge 320, 몸은 HW + reach = 28 안): 다른 발판(26.3)·x 280 (40)·앞 z −30·C 없이는 아니다; x 300 에서 C 는 돌린다(until 36); 바로 다시는 아니다(fast); 24.6 p1 (vt 25.2 → 1.2), left 0.7(두 배); 25.3 p2; 30.0 아무것도; 36.0 rate 1, 다시 돌릴 수 있다(boost 12); 36.5 vt 36.5 + 12 + 0.5 = 49 → 1.0 아무것도; 37.1 vt 50.2 → 2.2 p1
	var fig := Stick3D.new(); root.add_child(fig)
	ln.sync(24.0)
	var wrong := ln.spin(b, 300.0, C.PLAYER_Z, true); var far := ln.spin(a, 280.0, C.PLAYER_Z, true); var front := ln.spin(a, 300.0, -30.0, true); var unpressed := ln.spin(a, 300.0, C.PLAYER_Z, false)
	var ok := ln.spin(a, 300.0, C.PLAYER_Z, true, fig); var again := ln.spin(a, 300.0, C.PLAYER_Z, true)
	var r24 := ln.rate_at(c, 24.0); var r3599 := ln.rate_at(c, 35.99); var r36 := ln.rate_at(c, 36.0)
	var s246: String = lit_at.call(24.6); var left246 := ln.left(c, 1, 24.6); var s253: String = lit_at.call(25.3); var s30: String = lit_at.call(30.0)
	ln.sync(36.0); var twice := ln.spin(a, 300.0, C.PLAYER_Z, true); var boost := float(c["boost"]); var s365: String = lit_at.call(36.5); var half365 := ln.half_at(c, 36.5); var s371: String = lit_at.call(37.1)
	print("SPIN wrong=%s far=%s front=%s unpressed=%s (want false ×4) ok=%s until=%.0f fast=%s (want true 36 false) again=%s fast=%s (want false true) rate 24=%.0f 35.99=%.0f 36=%.0f (want 2 2 1) 24.6=%s left=%.2f (want 1-- 0.70: half the window) 25.3=%s 30.0=%s (want -2- ---) twice=%s boost=%.0f (want true 12: the first spin folded) 36.5=%s half=%.1f 37.1=%s (want --- 1.0 1--: vt 36.5 + 12 + 0.5)" % [wrong["spun"], far["spun"], front["spun"], unpressed["spun"], ok["spun"], float(ok["until"]), ok["fast"], again["spun"], again["fast"], r24, r3599, r36, s246, left246, s253, s30, twice["spun"], boost, s365, half365, s371])
	# 그림: 노드 아이 11(돌탑·갓돌·띠·북·빛줄기·바퀴·축·소리·뭉치 셋), 북 아이 2, 빛줄기 아이 1, 바퀴 아이 2, 뭉치 아이 7(판·앞테·솜 넷·종); 노드 자리 −1.3889 24.4444 −1.9444; 빛줄기 각(시계 100 ≡ 4: 보통 속도로 되돌아간 뒤 — vt 100 + 24 = 124 → 4) 100→ 4.0 ⇒ π − 1.9393 … 103 ≡ 7 → 절벽 반, 농도 0.1; 뭉치 1 농도 1.0 at 97.2 (vt 121.2 → 1.2 → 0.667?) — 계산은 아래
	ln.sync(100.0); ln._process(0.0)
	var node: Node3D = c["node"]; var drum: Node3D = c["drum"]; var beam: Node3D = c["beam"]; var wheel: Node3D = c["wheel"]; var pn1: Node3D = p1["node"]
	var h100 := ln.half_at(c, 100.0); var phi100 := beam.rotation.z; var bm: StandardMaterial3D = c["beam_mat"]; var ba100 := bm.albedo_color.a
	ln.sync(103.0); ln._process(0.0); var ba103 := bm.albedo_color.a; var h103 := ln.half_at(c, 103.0)
	var m1: StandardMaterial3D = (p1["mats"] as Array)[0]; var ch1: AudioStreamPlayer3D = p1["chime"]
	ln.sync(108.0); ln._process(0.0); var a108 := m1.albedo_color.a; var was108 := bool(p1["was"])
	ln.sync(109.3); ln._process(0.0); var a1093 := m1.albedo_color.a; var chimed := ch1.playing   # vt 133.3 → 1.3: p1 켜진 지 0.2 → 농도 1, 종
	print("VISUAL node children=%d (want 11) drum=%d beam=%d wheel=%d puff=%d (want 2 1 2 7) node pos=%.4f %.4f %.4f (want −1.3889 24.4444 −1.9444) half@100=%.1f phi=%.4f alpha=%.2f (want 4.0 1.2051 0.35: π − beam_angle at 4.0 s) half@103=%.1f alpha=%.2f (want 7.0 0.10: the cliff half) puff1 alpha@108=%.2f was=%s (want 0.18 false: dark) @109.3=%.2f chime=%s (want 1.00 true: hardened at 109.1)" % [node.get_child_count(), drum.get_child_count(), beam.get_child_count(), wheel.get_child_count(), pn1.get_child_count(), node.position.x, node.position.y, node.position.z, h100, phi100, ba100, h103, ba103, a108, was108, a1093, chimed])
	# 자세(spin_t 0.25 예비 끝: 오른 어깨 x −0.300 z 0.150 팔꿈치 −1.068 엉덩이 0.360 무릎 0.550 가슴 x 0.157 고개 x 0.300; 왼 어깨 x −0.250 z −0.900 팔꿈치 −0.300 엉덩이 −0.290 무릎 0.150; 골반 0.360 | 1.0 돌림 가운데: 오른 어깨 x −0.629 팔꿈치 −0.578 엉덩이 0.404 가슴 x 0.050 골반 0.380 | 1.6 놓음: hold 0.606 오른 어깨 x −0.194 왼 어깨 z −0.546 골반 0.384 done false | 1.8 done)
	fig.pose_request = "spin"; fig.set_meta("spin_t", 0.25)
	for i in 90: await process_frame
	var r_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var r_shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var r_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var r_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var r_knee: float = (fig.knees[1.0] as Node3D).rotation.x
	var l_shx: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var l_shz: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var l_el: float = (fig.elbows[-1.0] as Node3D).rotation.x; var l_hip: float = (fig.hips[-1.0] as Node3D).rotation.x; var l_knee: float = (fig.knees[-1.0] as Node3D).rotation.x
	var r_pel := fig.pelvis.position.y; var r_done := SpinPoses.done(fig); var r_chx := fig.chest.rotation.x
	var lx: float = (fig.elbows[-1.0] as Node3D).global_position.x - (fig.shoulders[-1.0] as Node3D).global_position.x
	fig.set_meta("spin_t", 1.0)
	for i in 90: await process_frame
	var m_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var m_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var m_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var m_chx := fig.chest.rotation.x; var m_pel := fig.pelvis.position.y
	fig.set_meta("spin_t", 1.6)
	for i in 90: await process_frame
	var d_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var d_lshz: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var d_pel := fig.pelvis.position.y; var d_done := SpinPoses.done(fig)
	fig.set_meta("spin_t", 1.8); var e_done := SpinPoses.done(fig)
	print("POSE wind: R sh=%.3f %.3f el=%.3f hip=%.3f knee=%.3f (want −0.300 0.150 −1.068 0.360 0.550) L sh=%.3f %.3f el=%.3f hip=%.3f knee=%.3f (want −0.250 −0.900 −0.300 −0.290 0.150) pelvis=%.3f done=%s chest x=%.3f (want 0.360 false 0.157: lean 0.14 × 0.55 + the 0.08 bob at the hand's bottom) balance elbow dx=%.3f (want < 0: the left arm spreads outward) | turn: R sh=%.3f el=%.3f hip=%.3f chest x=%.3f pelvis=%.3f (want −0.629 −0.578 0.404 0.050 0.380: lean 0.090 × 0.55, no bob with the hand near the top) | release: R sh=%.3f L sh z=%.3f pelvis=%.3f done=%s (want −0.194 −0.546 0.384 false) | done@1.8=%s (want true)" % [r_shx, r_shz, r_el, r_hip, r_knee, l_shx, l_shz, l_el, l_hip, l_knee, r_pel, r_done, r_chx, lx, m_shx, m_el, m_hip, m_chx, m_pel, d_shx, d_lshz, d_pel, d_done, e_done])
	# 진짜 탑: 1..60층에 plan 이 찾는 렌즈 — 구름바다 층 25, 26, 28, 29, 60, 61, 62, 64 중 뗏목·버섯·널·열기구(taken)가 안 든 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var tk: Array = cr.plan(n, pl) + mu.plan(n, pl)
		var pp: Array = cp.plan(n, pl, tk); var bp: Array = ba.plan(n, pl, tk + pp)
		var out2 := ln.plan(n, pl, tk + pp + bp)
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f rise %.1f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["rise"])])]); count += out2.size()
	print("TOWER floors=", bands, " lenses=", count, " (want a subset of 25, 26, 28, 29, 60, 61, 62, 64 — one each, never another theme or a vent floor)")
	quit()
