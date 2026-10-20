extends SceneTree
## 구름 웅덩이 팩 점검(헤드리스): 자료가 읽히나, 구름바다 층의 잇단 두 still 발판 사이 틈(60..200, 높이차 140 안) 중 웅덩이 상자를 다른 판이 가르지 않고 taken 조각이 닿지 않는 가장 넓은 하나에만 웅덩이가 차나(지름길 판이 든 틈은 진다, 뗏목이 든 틈은 비켜 그다음 넓은 틈으로, 통풍구 층·다른 테마 층은 아니다),
## 틈 안에서 수면을 지나 떨어지는 몸만 catch 가 받나(오르는 몸·틈 가장자리·수면 아래·앞뒤 밖·이미 떠 있는 웅덩이는 아니다, 받으면 오늘을 세고 splash), 받히면 0.4 s 에 걸쳐 18 까지 들어갔다 4 로 떠올라(afl_c) 흐름(30 px/s, a 쪽)에 실려 가고 2.4 s 에 3 px 까딱이나, ← → 가 0.35 × WALK 로 젓나(afl_v, 틈 가장자리에서 멎는다),
## a 의 끝에 닿으면 0.6 s 에 기어올라 a 에 서나(afl_o, stand = a, slosh), 떠난 0.4 s 는 안 받고 0.5 s 엔 받나, ↓ 가 0.3 s 에 바닥 밑으로 내보내나(afl_s, stand 없음), 뜬 몸의 틱이 0.25 s 끊기면 웅덩이가 비나, 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 세고 날이 바뀌면 0 으로 가나,
## 구름 판·솜 여섯·그늘 둘·고리 기둥·고리·소리 둘이 그려지고 솜이 a 쪽으로 흘러 돌아 나오나, afloat 자세가 빠질 땐 무릎을 가슴으로 팔을 위로 벌리고 뜨면 등을 대고 팔을 옆으로 펴 하늘을 보고 기어오르면 턱을 짚었다 서고 가라앉으면 접히나, 메타 없이 3.0 에 done 인가,
## 진짜 탑의 1..70층에서 plan 이 구름바다 층(25..29, 60..64, 통풍구 층 27·63 빼고)에만 다른 팩의 틈을 비켜 웅덩이를 찾나
const C = preload("res://scripts/games/climb.gd")
const DT := 0.05

func _init() -> void:
	var po := ClimbPool.new(); root.add_child(po)
	var cr := ClimbRaft.new(); root.add_child(cr)
	var mu := ClimbMushroom.new(); root.add_child(mu)
	var cp := ClimbPlank.new(); root.add_child(cp)
	var ba := ClimbBalloon.new(); root.add_child(ba)
	var ln := ClimbLens.new(); root.add_child(ln)
	var lj := ClimbPit.new(); root.add_child(lj)
	var cg := ClimbGreen.new(); root.add_child(cg)
	var cb := ClimbBridge.new(); root.add_child(cb)
	var gh := ClimbGhost.new(); root.add_child(gh)
	await process_frame
	print("PACK id=", po.pack.get("id"), " kind=", po.kind.size() > 0, " pose=", po.pack.get("pose"), " themes=", po.pack.get("themes"), " lip=%.0f depth=%.0f d=%.0f dunk=%.0f/%.2f ride=%.0f bob=%.0f/%.1f flow=%.0f paddle=%.2f out=%.2f sink=%.2f grace=%.2f day=%.0f (want pool true afloat [Cloud sea] 8 48 40 18/0.40 4 3/2.4 30 0.35 0.60 0.30 0.40 600)" % [po.lip(), po.depth(), po.d(), po.dunk(), po.dunk_s(), po.ride(), po.bob_a(), po.bob_s(), po.flow(), po.paddle(), po.out_s(), po.sink_s(), po.grace_s(), po.day_s()])
	var plats: Array = [
		{ "id": "26.0", "x": 100.0, "y": 15700.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "26.1", "x": 380.0, "y": 15810.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "26.2", "x": 650.0, "y": 15920.0, "w": 160.0, "kind": "ice", "z": -35.0, "d": 70.0 },
		{ "id": "26.3", "x": 400.0, "y": 16030.0, "w": 120.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "26.4", "x": 200.0, "y": 16140.0, "w": 110.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "26.5", "x": 25.0, "y": 16250.0, "w": 90.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "26s", "x": 560.0, "y": 15940.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var free := po.plan(26, plats)
	var rafted := po.plan(26, plats, [{ "id": "26.R0", "kind": "raft", "x": 530.0, "w": 120.0, "y": 15840.0 }])
	var vent := po.plan(27, plats); var other := po.plan(30, plats); var wind := po.plan(24, plats)
	var plats25: Array = plats.duplicate(true)
	for pv in plats25: (pv as Dictionary)["y"] = float((pv as Dictionary)["y"]) - 600.0; (pv as Dictionary)["id"] = "25" + String((pv as Dictionary)["id"]).substr(2)
	var five := po.plan(25, plats25)
	var band_root := Node3D.new(); root.add_child(band_root)
	po.build(band_root, free + five)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " %s-%s gap %.0f x0 %.0f x1 %.0f surf %.0f dir %.0f edge %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"]), float(v["x0"]), float(v["x1"]), float(v["surf"]), float(v["dir"]), float(v["a_edge"])]
	print("PLAN free=", free.map(show), " (want 1: 26.P0 26.1-26.2 gap 120 x0 530 x1 650 surf 15802 dir 1 edge 530 — 26.2-26.3 is 130 but the short slab 26s cuts its basin, 26.0-26.1 is 100, 26.3-26.4 is 90, 26.4-26.5 is 85)")
	print("PLAN rafted=", rafted.map(show), " (want 26.P0 26.0-26.1 gap 100 x0 280 x1 380 surf 15692: the raft takes the 120 gap) five=", five.map(show), " (want 25.P0 25.1-25.2 surf 15202) vent=", vent.size(), " other=", other.size(), " wind=", wind.size(), " (want 0 0 0)")
	var s: Dictionary = po.pools[0]
	var z := C.PLAYER_Z
	# 그림: 노드 아이 14(구름 판·솜 여섯·그늘 둘·기둥·고리 둘·splash·slosh); 노드 자리 3.056 438.944 −1.333; 솜 0 은 −1.389 에서 1 s 뒤 a 쪽(−x)으로 0.833 흘러 끝을 넘어 반대쪽(1.111)으로 돌아 나온다
	var node: Node3D = s["node"]; var tufts: Array = s["tufts"]
	var tx0: float = (tufts[0] as Node3D).position.x
	po.sync(0.0); po._process(1.0); var tx1: float = (tufts[0] as Node3D).position.x
	print("VISUAL node children=", node.get_child_count(), " (want 14) tufts=", tufts.size(), " (want 6) node pos=%.3f %.3f %.3f (want 3.056 438.944 −1.333) | tuft 0: x=%.3f → %.3f (want −1.389 → 1.111: 0.833 toward a, wrapped)" % [node.position.x, node.position.y, node.position.z, tx0, tx1])
	# 받기(t 1): 틈 안(x 590)에서 15810 → 15795 로 −300 에 떨어지는 몸 → 받는다; +100 오르는 몸·x 535 가장자리(540 안)·15790 → 15780 수면 아래·z 0 앞은 아니다; 이미 떠 있는 웅덩이는 다시 안 받는다
	po.sync(1.0)
	var c_up := po.catch(590.0, 15795.0, 15810.0, z, 100.0); var c_edge := po.catch(535.0, 15810.0, 15795.0, z, -300.0); var c_below := po.catch(590.0, 15790.0, 15780.0, z, -300.0); var c_front := po.catch(590.0, 15810.0, 15795.0, 0.0, -300.0)
	var c_ok := po.catch(590.0, 15810.0, 15795.0, z, -300.0)
	var splash: AudioStreamPlayer3D = s["splash"]; var splash_on := splash.playing
	var c_twice := po.catch(600.0, 15810.0, 15795.0, z, -300.0)
	print("CATCH up=%s edge=%s below=%s front=%s (want true ×4: empty) | ok kind=%s x=%.0f y=%.0f rider=%s sw=%s dips=%d day=%d splash=%s (want pool 590 15802 true in 1 0 true) | twice=%s (want true: empty)" % [c_up.is_empty(), c_edge.is_empty(), c_below.is_empty(), c_front.is_empty(), c_ok.get("kind", "-"), float(c_ok.get("x", 0.0)), float(c_ok.get("y", 0.0)), bool(s["rider"]), String(s["sw"]), int(s["dips"]), int(s["day"]), splash_on, c_twice.is_empty()])
	# 빠짐·뜸: 1.2 → 15784 (18 깊이, afl_c 0.5); 1.4 → 15798 뜸; 1.9 (dt 0.5, dir 0) → x 575 (흐름 30 × 0.5, a 쪽) y 15800.90 (bob); 2.4 (dir 1) → x 605.5 (−30 + 91 의 반) afl_v 1; dt 2.0 더 → 640 (틈 끝)
	var fig := Stick3D.new(); root.add_child(fig)
	po.sync(1.2); var r1 := po.swim(c_ok, 0.0, false, 0.2, fig); var m_c := float(fig.get_meta("afl_c", 9.0))
	po.sync(1.4); var r2 := po.swim(c_ok, 0.0, false, 0.2, fig); var sw2 := String(s["sw"])
	po.sync(1.9); var r3 := po.swim(c_ok, 0.0, false, 0.5, fig); var m_c3 := float(fig.get_meta("afl_c", 9.0)); var m_v3 := float(fig.get_meta("afl_v", 9.0))
	po.sync(2.4); var r4 := po.swim(c_ok, 1.0, false, 0.5, fig); var m_v4 := float(fig.get_meta("afl_v", 9.0))
	po.sync(4.4); var r5 := po.swim(c_ok, 1.0, false, 2.0, fig)
	print("SWIM 1.2: x=%.0f y=%.0f c=%.2f lost=%s (want 590 15784 0.50 false) | 1.4: y=%.0f sw=%s (want 15798 float) | 1.9: x=%.0f y=%.2f c=%.0f v=%.0f (want 575 15800.90 1 0) | 2.4 paddling: x=%.1f y=%.1f v=%.0f (want 605.5 15799.5 1) | 4.4 paddling 2 s: x=%.0f (want 640: the far edge)" % [float(r1["x"]), float(r1["y"]), m_c, r1["lost"], float(r2["y"]), sw2, float(r3["x"]), float(r3["y"]), m_c3, m_v3, float(r4["x"]), float(r4["y"]), m_v4, float(r5["x"])])
	# 기어오름: 640 에서 흐름만으로 a 의 끝(541 = 530 + HW + 1)까지 0.05 s 틱 66..67 번, 그다음 0.3 s 에 x 529.5 y 15804 afl_o 0.5, 0.6 s 에 a(26.1) 위 518 15810 lost, slosh
	var ticks := 0; var tt := 4.4
	while String(s["sw"]) == "float" and ticks < 200:
		tt += DT; po.sync(tt); po.swim(c_ok, 0.0, false, DT, fig); ticks += 1
	var cx := float(s["cx"]); var t_out := tt
	po.sync(t_out + 0.3); var r6 := po.swim(c_ok, 0.0, false, 0.3, fig); var m_o := float(fig.get_meta("afl_o", 9.0))
	po.sync(t_out + 0.6); var r7 := po.swim(c_ok, 0.0, false, 0.3, fig); var slosh: AudioStreamPlayer3D = s["slosh"]; var slosh_on := slosh.playing
	var stand: Dictionary = r7["stand"]
	print("OUT ticks=%d sw=%s cx=%.0f (want 66..67 out 541) | 0.3: x=%.1f y=%.0f o=%.2f lost=%s (want 529.5 15804 0.50 false) | 0.6: x=%.0f y=%.0f stand=%s lost=%s rider=%s slosh=%s metas=%s (want 518 15810 26.1 true false true false)" % [ticks, String(s["sw"]) if ticks >= 200 else "out", cx, float(r6["x"]), float(r6["y"]), m_o, r6["lost"], float(r7["x"]), float(r7["y"]), String(stand.get("id", "-")), r7["lost"], bool(s["rider"]), slosh_on, fig.has_meta("afl_o")])
	# 가라앉음: 떠난 0.2 s 는 안 받고(grace 0.4) 0.5 s 엔 받는다(dips 2); 0.4 s 떠오른 뒤 ↓ → 0.15 s 에 15776 (afl_s 0.5), 0.3 s 에 15754 (바닥 48 밑) lost, stand 없음
	po.sync(t_out + 0.8); var c_grace := po.catch(590.0, 15810.0, 15795.0, z, -300.0)
	po.sync(t_out + 1.1); var c_again := po.catch(590.0, 15810.0, 15795.0, z, -300.0)
	po.sync(t_out + 1.5); po.swim(c_again, 0.0, false, 0.4, fig)
	po.sync(t_out + 1.55); po.swim(c_again, 0.0, true, DT, fig); var sw_sink := String(s["sw"])
	po.sync(t_out + 1.7); var r8 := po.swim(c_again, 0.0, false, 0.15, fig); var m_s := float(fig.get_meta("afl_s", 9.0))
	po.sync(t_out + 1.85); var r9 := po.swim(c_again, 0.0, false, 0.15, fig)
	print("SINK grace=%s again=%s dips=%d (want true false 2) | sw=%s 0.15: y=%.0f s=%.2f (want sink 15776 0.50) | 0.3: y=%.0f stand=%s lost=%s rider=%s (want 15754 true true false)" % [c_grace.is_empty(), c_again.is_empty(), int(s["dips"]), sw_sink, float(r8["y"]), m_s, float(r9["y"]), (r9["stand"] as Dictionary).is_empty(), r9["lost"], bool(s["rider"])])
	# 사라진 몸: 받은 뒤 0.3 s 동안 swim 이 안 오면 웅덩이가 빈다(dips 3); 그 뒤 swim 은 lost
	po.sync(t_out + 2.4); var c_gone := po.catch(590.0, 15810.0, 15795.0, z, -300.0)
	po.sync(t_out + 2.7); po._process(0.0); var gone_rider := bool(s["rider"]); var r10 := po.swim(c_gone, 0.0, false, DT, fig)
	print("GONE caught=%s rider after 0.3 s without ticks=%s lost=%s dips=%d (want false false true 3)" % [c_gone.is_empty(), gone_rider, r10["lost"], int(s["dips"])])
	# 판: note(25) 는 25..29 의 웅덩이 둘(26 만 받았다), note(31) 은 위가 비어 아래 26..30 로; 날이 바뀌면(t 1300, 둘째 날) 0 으로, 한 번 받으면 'dip'
	var n25 := po.note(25); var n31 := po.note(31)
	po.sync(1300.0); var n_day := po.note(25)
	po.catch(590.0, 15810.0, 15795.0, z, -300.0); var n_one := po.note(25); po.swim(c_ok, 0.0, false, DT, fig); po.sync(1301.0); po._process(0.0)
	print("NOTE 25: '", n25, "' (want 'Cloud pools, floors 25–29: 1 of 2 floated in today, 3 dips today.') | 31: '", n31, "' (want floors 26–30: 1 of 1 …, 3 dips) | day 2: '", n_day, "' (want 0 of 2 …, 0 dips today.) | one: '", n_one, "' (want 1 of 2 …, 1 dip today.)")
	await _pose(fig)
	# 진짜 탑: 1..70층에 plan 이 찾는 웅덩이 — 구름바다 층 25, 26, 28, 29, 60, 61, 62, 64 중 다른 팩의 틈을 비켜 빈 틈이 있는 층만(27, 63 은 통풍구 층)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var bands: Array = []; var count := 0
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var tk: Array = cr.plan(n, pl) + mu.plan(n, pl); var pp: Array = cp.plan(n, pl, tk); var bp: Array = ba.plan(n, pl, tk + pp); var lp: Array = ln.plan(n, pl, tk + pp + bp); var jp: Array = lj.plan(n, pl, tk + pp + bp + lp)
		var gp: Array = cg.plan(n, pl, gm.wind_of(n), tk + pp + bp + lp + jp)
		var out2 := po.plan(n, pl, tk + pp + bp + lp + jp + gp + cb.plan(n, pl) + gh.plan(n, pl))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s-%s gap %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"])])]); count += out2.size()
	print("TOWER floors=", bands, " pools=", count, " (want a subset of 25, 26, 28, 29, 60, 61, 62, 64 — one each, never a vent floor or another theme)")
	quit()

## afloat 자세(메타로 세운다) — 빠짐(c 0), 뜸(c 1), 기어오름(o 0.3: 구르기 반), 선 끝(o 1), 가라앉음(s 1); 메타 없이 3.0 에 done
func _pose(fig: Stick3D) -> void:
	fig.pose_request = "afloat"; fig.set_meta("afl_c", 0.0); fig.set_meta("afl_v", 0.0); fig.set_meta("afl_o", 0.0); fig.set_meta("afl_s", 0.0)
	for i in 45: await process_frame
	var r_sh: Node3D = fig.shoulders[1.0]; var l_sh: Node3D = fig.shoulders[-1.0]; var r_el: Node3D = fig.elbows[1.0]
	var r_hip: Node3D = fig.hips[1.0]; var l_hip: Node3D = fig.hips[-1.0]; var r_knee: Node3D = fig.knees[1.0]; var l_knee: Node3D = fig.knees[-1.0]
	var a := "pelvis=%.2f y=%.2f hips=%.2f %.2f knee=%.2f shoulder=%.2f z=%.2f/%.2f elbow=%.2f neck=%.2f" % [fig.pelvis.rotation.x, fig.pelvis.position.y, r_hip.rotation.x, l_hip.rotation.x, r_knee.rotation.x, r_sh.rotation.x, r_sh.rotation.z, l_sh.rotation.z, r_el.rotation.x, fig.neck.rotation.x]
	fig.set_meta("afl_c", 1.0)
	for i in 45: await process_frame
	var e1 := r_el.rotation.x; var k1 := r_knee.rotation.x
	for i in 20: await process_frame
	var b := "pelvis=%.2f y=%.3f hips=%.2f %.2f knees=%.2f %.2f shoulder=%.2f z=%.2f/%.2f elbow=%.2f→%.2f sculls=%s foot wags=%s neck=%.2f" % [fig.pelvis.rotation.x, fig.pelvis.position.y, r_hip.rotation.x, l_hip.rotation.x, r_knee.rotation.x, l_knee.rotation.x, r_sh.rotation.x, r_sh.rotation.z, l_sh.rotation.z, e1, r_el.rotation.x, absf(r_el.rotation.x - e1) > 0.01, absf(r_knee.rotation.x - k1) > 0.005, fig.neck.rotation.x]
	fig.set_meta("afl_o", 0.3)
	for i in 45: await process_frame
	var c := "pelvis=%.3f y=%.3f hips=%.3f %.3f knee=%.2f shoulder=%.2f z=%.2f elbow=%.2f" % [fig.pelvis.rotation.x, fig.pelvis.position.y, r_hip.rotation.x, l_hip.rotation.x, l_knee.rotation.x, r_sh.rotation.x, r_sh.rotation.z, r_el.rotation.x]
	fig.set_meta("afl_o", 1.0)
	for i in 45: await process_frame
	var d := "pelvis=%.2f y=%.2f hip=%.2f knee=%.2f shoulder=%.2f z=%.2f" % [fig.pelvis.rotation.x, fig.pelvis.position.y, r_hip.rotation.x, r_knee.rotation.x, r_sh.rotation.x, r_sh.rotation.z]
	fig.set_meta("afl_o", 0.0); fig.set_meta("afl_s", 1.0)
	for i in 45: await process_frame
	var e := "pelvis=%.2f hip=%.2f knee=%.2f±0.08 shoulder=%.2f" % [fig.pelvis.rotation.x, r_hip.rotation.x, r_knee.rotation.x, r_sh.rotation.x]
	for key: String in ["afl_c", "afl_v", "afl_o", "afl_s"]: fig.remove_meta(key)
	fig.pose_t = AfloatPoses.LAP - 0.01; var before := AfloatPoses.done(fig)
	fig.pose_t = AfloatPoses.LAP + 0.001; var after := AfloatPoses.done(fig)
	print("AFLOAT pose plunge: ", a, " (want −0.50 0.32 −1.20 −1.20 1.40 −1.50 −0.80/0.80 −0.30 ≈ base + 0.10) | float: ", b, " (want −1.45 0.090..0.110 −0.25 −0.15 0.02..0.18 0.10 −0.40 −1.25/1.25 −0.65..−0.05 true true ≈ −0.35 + the base: the sky) | out 0.3: ", c, " (want −0.475 0.165..0.185 −0.675 −0.725 0.70 −0.75 −0.75 −0.53..−0.23) | stood: ", d, " (want 0.00 0.42 0.00 0.00 0.00 0.00) | sunk: ", e, " (want −0.85 −1.05 1.10 −1.70) | done(2.99 → 3.001)=%s LAP=%.1f (want true 3.0)" % [(not before) and after, AfloatPoses.LAP])
	fig.pose_request = ""
