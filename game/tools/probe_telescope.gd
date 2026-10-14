extends SceneTree
## 망원경 팩 점검(헤드리스): 자료가 읽히나, 별밤 층의 잇단 still 발판 짝(90..220 px 틈, 위 발판이 40..150 px 높다) 중 가장 넓은 틈에만 망원경이 서나(틈이 좁은 짝은 지고, taken 조각(그네)이 든 틈은 비켜 가며, 위 발판 높이의 조각은 위 틈의 것이고, 진폭째 상자에 드는 움직이는 발판도, 통풍구 층·다른 테마 층은 아니다, 거울 층은 반대로),
## 받침 곁의 아래 발판에서 C 를 누를 때만 눈을 대나(다른 발판·멀리·앞·C 없이·이미 보는 동안엔 아니다), 윤곽의 농도가 자리 잡기 뒤 켜지고 끝에 잦아드나, 화살표가 pan 을 ±pan_max 안에서 옮기고 자세의 메타에 적나,
## 받침·통·윤곽(위 층 발판마다 테 넷·별 넷)이 그려지고 틈 폭 안의 칸만 보이며 켜질 때 반짝 소리가 나나, peer 자세가 숙이고 훑고 바로 서나, 진짜 탑의 1..70층에서 plan 이 별밤 층(통풍구 층 빼고)에만 망원경을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var ts := ClimbTelescope.new(); root.add_child(ts)
	var ci := ClimbIcicle.new(); root.add_child(ci)
	var cn := ClimbLantern.new(); root.add_child(cn)
	var ct := ClimbTrapeze.new(); root.add_child(ct)
	var cc := ClimbCandle.new(); root.add_child(cc)
	await process_frame
	print("PACK id=", ts.pack.get("id"), " kind=", ts.kind.size() > 0, " pose=", ts.pack.get("pose"), " themes=", ts.pack.get("themes"), " inset=%.0f tripod=%.0f tube=%.0f reach=%.0f show=%.1f settle=%.2f fade=%.2f scale=%.2f up=%.0f pan=%.0f/%.0f (want 22 34 40 18 4.0 0.50 0.60 0.25 30 240/240)" % [ts.inset(), ts.tripod_h(), ts.tube_len(), ts.reach(), ts.show_s(), ts.settle_s(), ts.fade_s(), ts.view_scale(), ts.view_up(), ts.pan_v(), ts.pan_max()])
	var plats: Array = [
		{ "id": "30.0", "x": 60.0, "y": 18700.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "30.1", "x": 420.0, "y": 18790.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "30.2", "x": 180.0, "y": 18880.0, "w": 140.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "30.3", "x": 540.0, "y": 19000.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "30.4", "x": 300.0, "y": 19060.0, "w": 100.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "30s", "x": 700.0, "y": 19020.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var above: Array = [   # 위 층(31)의 발판 — 윤곽의 원본: 바닥 18600
		{ "id": "31.0", "x": 500.0, "y": 18700.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31.1", "x": 120.0, "y": 18800.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31.2", "x": 600.0, "y": 18900.0, "w": 120.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 60.0 },
		{ "id": "31.3", "x": 20.0, "y": 19000.0, "w": 100.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31s", "x": 860.0, "y": 19100.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 },
		{ "id": "31l", "x": 700.0, "y": 19180.0, "w": 80.0, "kind": "ledge", "z": 0.0, "d": 180.0 },
	]
	var free := ts.plan(30, plats)
	var swung := ts.plan(30, plats, [{ "id": "30.T0", "kind": "trapeze", "x": 360.0, "w": 100.0, "y": 18910.0 }])   # 그네가 30.2↔30.3 의 틈(290..548, 띠 18860..18980 안) — 그 틈은 그네의 것: 30.0↔30.1 (200) 로
	var over := ts.plan(30, plats, [{ "id": "30.C0", "kind": "candle", "x": 400.0, "w": 44.0, "y": 19000.0 }])   # 위 발판(30.3, y 19000) 높이의 초는 위 틈의 것 — 30.2↔30.3 은 그대로
	var moved := plats.duplicate(true); moved.append({ "id": "30m", "x": 400.0, "y": 18920.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째(310..550, 18920) 30.2↔30.3 의 상자에 든다
	var movep := ts.plan(30, moved)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := ts.plan(30, mirror)
	var f29 := ts.plan(29, plats); var f31 := ts.plan(31, plats); var f32 := ts.plan(32, plats); var f33 := ts.plan(33, plats); var f34 := ts.plan(34, plats); var f35 := ts.plan(35, plats); var f65 := ts.plan(65, plats); var f67 := ts.plan(67, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	ts.build(band_root, free, above)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s hinge %.0f tri %.0f mid %.0f x %.0f w %.0f y %.0f y_top %.0f" % [float(v["dir"]), float(v["gap"]), String(v["a_id"]), String(v["b_id"]), float(v["hinge_x"]), float(v["tri_x"]), float(v["mid_x"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"])]
	print("PLAN free=", free.map(show), " (want 1: 30.S0 dir 1 gap 220 30.2→30.3 wins over 30.0↔30.1 gap 200; 30.1↔30.2 gap 100 and 30.3↔30.4 gap 140 lose: hinge 320 tri 298 mid 430 x 298 w 242 y 18880 y_top 18934)")
	print("PLAN swung=", swung.map(show), " (want 30.S0 dir 1 gap 200 30.0→30.1 hinge 220 tri 198 mid 320) over=", over.map(func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f" % float(v["gap"])), " (want 30.S0 gap 220: a piece at the upper hop's height belongs to the gap above) moved=", movep.map(func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f hinge %.0f" % [float(v["gap"]), float(v["hinge_x"])]), " (want 30.S0 gap 200 hinge 220) right=", right.map(show), " (want 30.S0 dir −1 gap 220 hinge 640 tri 662 mid 530 x 420 w 242) floors 29/31/32/33/34/35/65/67=", [f29.size(), f31.size(), f32.size(), f33.size(), f34.size(), f35.size(), f65.size(), f67.size()], " (want 0 0 1 1 1 0 1 0: a vent floor and another theme get none)")
	var c: Dictionary = ts.scopes[0]
	var a: Dictionary = plats[2]; var b: Dictionary = plats[3]
	# 보기(10.0, 받침 tri 298, 몸은 HW + reach = 28 안): 다른 발판(30.3)·x 260 (38)·앞 z −30·C 없이는 아니다; x 300 에서 C 는 본다(until 14); 바로 다시는 아니다(busy); 농도 10.5 0 / 10.65 0.5 / 10.8 1 / 13.4 1 / 13.7 0.5 / 14.0 0; 14.0 뒤엔 다시 볼 수 있다
	var fig := Stick3D.new(); root.add_child(fig)
	ts.sync(10.0)
	var wrong := ts.peer(b, 300.0, C.PLAYER_Z, true); var far := ts.peer(a, 260.0, C.PLAYER_Z, true); var front := ts.peer(a, 300.0, -30.0, true); var unpressed := ts.peer(a, 300.0, C.PLAYER_Z, false)
	var idle := ts.peering()
	var ok := ts.peer(a, 300.0, C.PLAYER_Z, true, fig); var again := ts.peer(a, 300.0, C.PLAYER_Z, true)
	var busy := ts.peering()
	var s105 := ts.solidity(c, 10.5); var s1065 := ts.solidity(c, 10.65); var s108 := ts.solidity(c, 10.8); var s134 := ts.solidity(c, 13.4); var s137 := ts.solidity(c, 13.7); var s140 := ts.solidity(c, 14.0)
	var p1 := ts.pan(1.0, 0.5, fig); var p2 := ts.pan(1.0, 1.0, fig); var m2 := float(fig.get_meta("peer_pan", 9.0)); var p3 := ts.pan(-1.0, 2.0, fig); var m3 := float(fig.get_meta("peer_pan", 9.0))
	ts.sync(14.0); var p4 := ts.pan(1.0, 1.0); var later := ts.peering(); var re := ts.peer(a, 300.0, C.PLAYER_Z, true)
	print("PEER wrong=%s far=%s front=%s unpressed=%s (want false ×4) idle=%s ok=%s until=%.0f busy=%s (want false true 14 false) again=%s busy=%s peering=%s (want false true true) sol 10.5=%.2f 10.65=%.2f 10.8=%.2f 13.4=%.2f 13.7=%.2f 14.0=%.2f (want 0.00 0.50 1.00 1.00 0.50 0.00) pan 0.5s=%.0f +1s=%.0f meta=%.2f (want 120 240 1.00: clamped at pan_max) −2s=%.0f meta=%.2f (want −240 −1.00) after: pan=%.0f peering=%s re=%s (want 0 false true)" % [wrong["peered"], far["peered"], front["peered"], unpressed["peered"], idle, ok["peered"], float(ok["until"]), ok["busy"], again["peered"], again["busy"], busy, s105, s1065, s108, s134, s137, s140, p1, p2, m2, p3, m3, p4, later, re["peered"]])
	# 그림: 노드 아이 8(다리 셋·머리판·통·윤곽·소리 둘), 통 아이 3, 윤곽 아이 5(ledge 는 빼고), 칸 아이 8; 노드 자리 −5.0556 524.4444 −1.7222; 윤곽 칸의 자리 31.0: cx (575 − 480) × 0.25 = 23.75 → 0.6597 m, y (18700 − 18600) × 0.25 = 25 → 0.6944 m
	# 농도: 20.0 (안 봄) 0 → 보이는 칸 0; 25.0 에 본 뒤 26.0: 농도 1, pan 0 → 틈 반폭 110 안의 칸: 31.0 cx 23.75 ✓ 31.1 cx −72.5 ✓ 31.2 cx 45 ✓ 31.3 cx −102.5 ✓ 31s cx 102.5 ✓ → 5; pan 240 → 가운데 60 → 31.1 (−72.5−60 = −132.5 ✗) 31.3 ✗ → 3, 윤곽 x = (430 − 298 − 60)/36 = 2.0; 통 y 각 −0.25
	ts.sync(20.0); ts._process(0.0)
	var node: Node3D = c["node"]; var tube: Node3D = c["tube"]; var view: Node3D = c["view"]; var hops: Array = c["hops"]
	var lm: StandardMaterial3D = c["line_mat"]; var tw: AudioStreamPlayer3D = c["twinkle"]
	var h0: Node3D = (hops[0] as Dictionary)["node"]
	var vis := func() -> int:
		var k := 0
		for hv in hops:
			if ((hv as Dictionary)["node"] as Node3D).visible: k += 1
		return k
	var a20 := lm.albedo_color.a; var v20: int = vis.call(); var tw20 := tw.playing
	ts.sync(25.0); ts.peer(a, 300.0, C.PLAYER_Z, true); ts._process(0.0); var tw25 := tw.playing
	ts.sync(26.0); ts._process(0.0); var a26 := lm.albedo_color.a; var v26: int = vis.call(); var tw26 := tw.playing; var vx26 := view.position.x
	ts.pan(1.0, 1.0); ts._process(0.0); var v26p: int = vis.call(); var vx26p := view.position.x; var ty := tube.rotation.y
	print("VISUAL node children=%d (want 8) tube=%d view=%d hop=%d (want 3 5 8) node pos=%.4f %.4f %.4f (want −5.0556 524.4444 −1.7222) hop0 pos=%.4f %.4f (want 0.6597 0.6944) tube z=%.2f (want 0.42: aimed up over the gap) dark: alpha=%.2f visible=%d twinkle=%s (want 0.00 0 false) lit@26: alpha=%.2f visible=%d twinkle=%s view x=%.4f (want 0.85 5 true 3.6667: twinkled at 25.5) panned: visible=%d view x=%.4f tube y=%.2f (want 3 2.0000 −0.25)" % [node.get_child_count(), tube.get_child_count(), view.get_child_count(), h0.get_child_count(), node.position.x, node.position.y, node.position.z, h0.position.x, h0.position.y, tube.rotation.z, a20, v20, tw20 or tw25, a26, v26, tw26, vx26, v26p, vx26p, ty])
	# 자세(peer_t 0.5 자리 잡음: 오른 어깨 x −1.250 z 0.100 팔꿈치 −1.100 엉덩이 0.300 무릎 0.350; 왼 어깨 x −1.900 z 0.300 팔꿈치 −2.200 엉덩이 −0.150 무릎 0.100; 골반 0.361 | 2.0 훑기, peer_pan 1: 오른 어깨 x −1.370 고개 y 0.300 몸통 y 0.150 | 3.7 바로 서기: bend 0.5 오른 어깨 x −0.625 골반 0.395 done false | 4.0 done)
	fig.remove_meta("peer_pan")
	fig.pose_request = "peer"; fig.set_meta("peer_t", 0.5)
	for i in 90: await process_frame
	var r_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var r_shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var r_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var r_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var r_knee: float = (fig.knees[1.0] as Node3D).rotation.x
	var l_shx: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var l_shz: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var l_el: float = (fig.elbows[-1.0] as Node3D).rotation.x; var l_hip: float = (fig.hips[-1.0] as Node3D).rotation.x; var l_knee: float = (fig.knees[-1.0] as Node3D).rotation.x
	var r_pel := fig.pelvis.position.y; var r_done := PeerPoses.done(fig); var r_chx := fig.chest.rotation.x; var r_nkx := fig.neck.rotation.x
	var lhand_y: float = (fig.elbows[-1.0] as Node3D).global_position.y - (fig.shoulders[-1.0] as Node3D).global_position.y
	fig.set_meta("peer_t", 2.0); fig.set_meta("peer_pan", 1.0)
	for i in 90: await process_frame
	var m_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var m_nky := fig.neck.rotation.y; var m_tor := fig.torso.rotation.y
	fig.set_meta("peer_t", 3.7)
	for i in 90: await process_frame
	var d_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var d_pel := fig.pelvis.position.y; var d_done := PeerPoses.done(fig); var d_nkx := fig.neck.rotation.x
	fig.set_meta("peer_t", 4.0); var e_done := PeerPoses.done(fig)
	print("POSE settle: R sh=%.3f %.3f el=%.3f hip=%.3f knee=%.3f (want −1.250 0.100 −1.100 0.300 0.350) L sh=%.3f %.3f el=%.3f hip=%.3f knee=%.3f (want −1.900 0.300 −2.200 −0.150 0.100) pelvis=%.3f done=%s chest x=%.3f neck x=%.3f (want 0.361 false 0.471 −0.585: lean 0.55 × 0.55 + 0.169; the lean’s own head-levelling −0.385 and the −0.2 along the tube) cupped elbow dy=%.3f (want > 0: the left elbow rises to the face) | sweep: R sh=%.3f neck y=%.3f torso y=%.3f (want −1.370 0.300 0.150) | rise: R sh=%.3f pelvis=%.3f neck x=%.3f done=%s (want −0.655 0.392 −0.447 false: bend 0.5 with the pan still at 1 → sweep 0.5; lean 0.245 levels the head −0.172 and the rise lifts it −0.275) | done@4.0=%s (want true)" % [r_shx, r_shz, r_el, r_hip, r_knee, l_shx, l_shz, l_el, l_hip, l_knee, r_pel, r_done, r_chx, r_nkx, lhand_y, m_shx, m_nky, m_tor, d_shx, d_pel, d_nkx, d_done, e_done])
	# 진짜 탑: 1..70층에 plan 이 찾는 망원경 — 별밤 층 30, 32, 33, 34, 65, 66, 68, 69 중 고드름·등롱·그네·초(taken)가 안 든 틈이 있는 층만; 윤곽은 band(n + 1)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []; var built := 0
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var ic: Array = ci.plan(n, pl); var cnp: Array = cn.plan(n, pl, ic)
		var out2 := ts.plan(n, pl, ic + cnp + ct.plan(n, pl, ic + cnp) + cc.plan(n, pl, cnp + ic))
		if out2.size() > 0:
			bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"])])]); count += out2.size()
			var br := Node3D.new(); root.add_child(br); ts.build(br, out2, gm.band(n + 1)); built += (ts.scopes[ts.scopes.size() - 1]["hops"] as Array).size()
	print("TOWER floors=", bands, " telescopes=", count, " outline hops=", built, " (want a subset of 30, 32, 33, 34, 65, 66, 68, 69 — one each, never another theme or a vent floor; every built telescope draws the floor above's hops)")
	quit()
