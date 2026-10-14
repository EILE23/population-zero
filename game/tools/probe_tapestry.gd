extends SceneTree
## 태피스트리 팩 점검(헤드리스): 자료가 읽히나, 옛 회관 층의 잇단 still 발판 짝(90..220 px 틈, 위 발판이 40..150 px 높다) 중 레일의 상자를 다른 발판이 안 가르는 가장 넓은 틈에만 천이 걸리나(가장 넓은 220 틈은 위의 발판이 레일 자리를 가로질러 진다, taken 조각(종 줄)이 든 틈은 비켜 가며, 위 발판 높이의 조각은 위 틈의 것이고, 진폭째 상자에 드는 움직이는 발판도, 바람구멍 층·다른 테마 층·0층은 아니다, 거울 층은 반대쪽으로),
## 아래 발판의 틈 쪽 가장자리에서 C 를 누를 때만 쥐나(다른 발판·멀리·앞·C 없이·이미 탄 동안은 아니다), 매달리면 발이 40 px/s 로 레일 밑까지 오르고 고리가 30 px/s 로 위 발판 앞까지 가며 둘 다 끝나면 0.35초에 걸쳐 건너가 done 이 되나(그 틱의 y 가 위 발판 윗면), 빈 천이 30 px/s 로 제자리로 돌아간 뒤에야 다시 쥐나, 놓으면 고리의 속도를 안고 가나, 없는 천은 lost 인가,
## 받침·레일·고리·천(무늬·단 띠·술)·소리가 그려지고 고리가 자리를 따르며 천단이 바람에 흔들리나, scale 자세가 뻗고 당기고 멎고 건너가나, 진짜 탑의 1..60층에서 plan 이 옛 회관 층(바람구멍 층 빼고)에만 천을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var tp := ClimbTapestry.new(); root.add_child(tp)
	var cb := ClimbBell.new(); root.add_child(cb)
	var cr := ClimbDoor.new(); root.add_child(cr)
	var cl := ClimbLaundry.new(); root.add_child(cl)
	var dw := ClimbDrawbridge.new(); root.add_child(dw)
	await process_frame
	print("PACK id=", tp.pack.get("id"), " kind=", tp.kind.size() > 0, " pose=", tp.pack.get("pose"), " themes=", tp.pack.get("themes"), " tap_w=%.0f hem=%.0f hang=%.0f lift=%.0f inset=%.0f reach=%.0f climb=%.0f drift=%.0f back=%.0f settle=%.2f grace=%.2f sway=%.0f (want 36 20 58 12 14 18 40 30 30 0.35 0.40 6)" % [tp.tap_w(), tp.hem(), tp.hang(), tp.lift(), tp.inset(), tp.reach(), tp.climb_v(), tp.drift_v(), tp.back_v(), tp.settle_s(), tp.grace_s(), tp.sway()])
	var plats: Array = [
		{ "id": "2.0", "x": 60.0, "y": 700.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.1", "x": 420.0, "y": 790.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.2", "x": 180.0, "y": 880.0, "w": 140.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "2.3", "x": 540.0, "y": 1000.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.4", "x": 300.0, "y": 1060.0, "w": 100.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2s", "x": 700.0, "y": 1020.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := tp.plan(2, plats)
	var belled := tp.plan(2, plats, [{ "id": "2.b0", "kind": "bell", "x": 315.0, "w": 10.0, "y": 750.0 }])   # 종 줄이 2.0↔2.1 의 틈(y 750 — 띠 680..770 안) — 그 틈은 종의 것: 2.3↔2.4 (140) 로
	var above := tp.plan(2, plats, [{ "id": "2.d0", "kind": "door", "x": 300.0, "w": 44.0, "y": 790.0 }])   # 위 발판(2.1, y 790) 높이의 조각은 위 틈의 것 — 2.0↔2.1 은 그대로
	var moved := plats.duplicate(true); moved.append({ "id": "2m", "x": 300.0, "y": 840.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째(210..370, 840) 2.0↔2.1 과 2.1↔2.2 의 상자에 든다
	var movep := tp.plan(2, moved)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := tp.plan(2, mirror)
	var f0 := tp.plan(0, plats); var f1 := tp.plan(1, plats); var f3 := tp.plan(3, plats); var f5 := tp.plan(5, plats); var f35 := tp.plan(35, plats); var f36 := tp.plan(36, plats); var f39 := tp.plan(39, plats)
	var narrow: Array = [
		{ "id": "1.0", "x": 100.0, "y": 700.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "1.1", "x": 350.0, "y": 810.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
	]
	var tight := tp.plan(1, narrow)   # 탑의 진짜 틈 폭(93..124): 100 px 틈
	var band_root := Node3D.new(); root.add_child(band_root)
	tp.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s hinge %.0f start %.0f end %.0f in %.0f rail %.0f hem %.0f top %.0f x %.0f w %.0f y %.0f" % [float(v["dir"]), float(v["gap"]), String(v["a_id"]), String(v["b_id"]), float(v["hinge_x"]), float(v["x_start"]), float(v["x_end"]), float(v["x_in"]), float(v["rail_y"]), float(v["hem_y"]), float(v["top"]), float(v["x"]), float(v["w"]), float(v["y"])]
	print("PLAN free=", free.map(show), " (want 1: 2.T0 dir 1 gap 200 2.0→2.1 — 2.2↔2.3 gap 220 loses because hop 2.4 (y 1060) cuts its rail box; 2.1↔2.2 gap 100 and 2.3↔2.4 gap 140 lose on width: hinge 220 start 242 end 406 in 434 rail 860 hem 720 top 802 x 224 w 200 y 700)")
	print("PLAN belled=", belled.map(show), " (want 2.T0 dir −1 gap 140 2.3→2.4 hinge 540 start 518 end 414 in 386 rail 1130 hem 1020 top 1072 x 396 w 140 y 1000) above=", above.map(func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f" % float(v["gap"])), " (want 2.T0 gap 200: a piece at the upper hop's height belongs to the gap above) moved=", movep.map(func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f dir %.0f" % [float(v["gap"]), float(v["dir"])]), " (want 2.T0 gap 140 dir −1: the mover sweeps both the 200 and the 100 gap) right=", right.map(show), " (want 2.T0 dir −1 gap 200 hinge 740 start 718 end 554 in 526)")
	print("FLOORS 0=%d 1=%d 3=%d 5=%d 35=%d 36=%d 39=%d (want 0 1 0 0 0 1 0: Old hall floors only, never a vent floor or floor 0) tight=" % [f0.size(), f1.size(), f3.size(), f5.size(), f35.size(), f36.size(), f39.size()], tight.map(show), " (want 1.T0 dir 1 gap 100 hinge 250 start 272 end 336 in 364 rail 880 top 822 x 254 w 100)")
	var c: Dictionary = tp.cloths[0]
	var a: Dictionary = plats[0]; var b: Dictionary = plats[1]
	# 쥐기(10.0): 다른 발판(2.1)·x 180 (hinge 220 에서 40 > 28)·앞 z −30·C 없이는 아니다; x 200 에서 C 는 쥔다(x 242 y 700 dir 1); 바로 다시는 아니다(이미 탔다)
	var fig := Stick3D.new(); root.add_child(fig)
	tp.sync(10.0)
	var wrong := tp.grip(b, 200.0, C.PLAYER_Z, true); var far := tp.grip(a, 180.0, C.PLAYER_Z, true); var front := tp.grip(a, 200.0, -30.0, true); var unpressed := tp.grip(a, 200.0, C.PLAYER_Z, false)
	var ok := tp.grip(a, 200.0, C.PLAYER_Z, true); var again := tp.grip(a, 200.0, C.PLAYER_Z, true)
	print("GRIP wrong=%s far=%s front=%s unpressed=%s (want false ×4) ok=%s id=%s x=%.0f y=%.0f dir=%.0f (want true 2.T0 242 700 1) again=%s (want false) rustle=%s (want true)" % [not wrong.is_empty(), not far.is_empty(), not front.is_empty(), not unpressed.is_empty(), not ok.is_empty(), String(ok.get("id", "")), float(ok.get("x", 0.0)), float(ok.get("y", 0.0)), float(ok.get("dir", 0.0)), not again.is_empty(), (c["rustle"] as AudioStreamPlayer3D).playing])
	# 오르기(0.1초 틱): 11.0 발 40 → y 740, 고리 272, 몸 x 272 + 흔들림, v 1; 12.6 발 102 (top) → y 802, v 0, 고리 320; 15.5 고리 406 → 건너가기 시작(click), x 406 y 802; 15.7 k 0.606 → x 422.98 y 794.72; 15.9 done x 434 y 790
	var rec: Dictionary = {}
	for i in range(1, 61):
		var at := 10.0 + float(i) * 0.1
		tp.sync(at)
		var r := tp.climb(ok, 0.1, fig)
		if i in [10, 26, 55, 57, 59]: rec[i] = { "r": r, "sw": tp.sway_y(c, at, float(r["y"]) + tp.hang()), "cx": float(c["cx"]), "v": float(fig.get_meta("scale_v")), "k": float(fig.get_meta("scale_k")), "settle": float(c["settle"]) }
		if bool(r["done"]): break
	var r10: Dictionary = rec[10]; var r26: Dictionary = rec[26]; var r55: Dictionary = rec[55]; var r57: Dictionary = rec[57]; var r59: Dictionary = rec[59]
	print("CLIMB 11.0: x−sw=%.1f y=%.0f cx=%.0f v=%.0f (want 272 740 272 1) 12.6: y=%.0f v=%.0f cx=%.0f (want 802 0 320: hands at the rail, still drifting) 15.5: x=%.1f y=%.0f settle=%.1f click=%s (want 406 802 15.5 true) 15.7: x=%.2f y=%.2f k=%.3f (want 422.98 794.72 0.606) 15.9: x=%.0f y=%.0f done=%s k=%.0f rider=%s (want 434 790 true 1 false)" % [float((r10["r"] as Dictionary)["x"]) - float(r10["sw"]), float((r10["r"] as Dictionary)["y"]), float(r10["cx"]), float(r10["v"]), float((r26["r"] as Dictionary)["y"]), float(r26["v"]), float(r26["cx"]), float((r55["r"] as Dictionary)["x"]), float((r55["r"] as Dictionary)["y"]), float(r55["settle"]), (c["click"] as AudioStreamPlayer3D).playing, float((r57["r"] as Dictionary)["x"]), float((r57["r"] as Dictionary)["y"]), float(r57["k"]), float((r59["r"] as Dictionary)["x"]), float((r59["r"] as Dictionary)["y"]), bool((r59["r"] as Dictionary)["done"]), float(r59["k"]), bool(c["rider"])])
	# 돌아가기: 빈 고리가 30 px/s 로 — 2초 뒤 346 (아직 못 쥔다), 6초 뒤 242 (쥔다); 놓기(23.0 쥐고 1초 오른 뒤): vx 30 (미끄러지는 중), 바로 다시는 아니다(제자리가 아니다), 돌아온 뒤 쥐고 2.55초 뒤 꼭대기에서 놓아도 아직 미끄러지니 vx 30; 없는 천은 lost, 없는 천을 놓으면 vx 0
	tp._process(2.0); var cx2 := float(c["cx"]); var early := tp.grip(a, 200.0, C.PLAYER_Z, true)
	tp._process(4.0); var cx6 := float(c["cx"]); tp.sync(22.0); var late := tp.grip(a, 200.0, C.PLAYER_Z, true)
	tp.sync(23.0); tp.climb(late, 1.0); var v1 := tp.let_go(late); var cxl := float(c["cx"]); var soon := tp.grip(a, 200.0, C.PLAYER_Z, true)
	tp._process(2.0); tp.sync(25.5); var third := tp.grip(a, 200.0, C.PLAYER_Z, true); tp.sync(28.05); var rt := tp.climb(third, 2.55, fig); var vtop := float(fig.get_meta("scale_v")); var v2 := tp.let_go(third)
	var lost := tp.climb({ "id": "nope", "x": 1.0, "y": 2.0 }, 0.1); var v0 := tp.let_go({ "id": "nope" })
	print("BACK cx@2s=%.0f early=%s (want 346 false) cx@6s=%.0f late=%s (want 242 true) let_go vx=%.0f cx=%.0f soon=%s (want 30 272 false) third=%s top y=%.0f v=%.0f vx=%.0f (want true 802 0 30) lost=%s vx0=%.0f (want true 0)" % [cx2, not early.is_empty(), cx6, not late.is_empty(), float(v1["vx"]), cxl, not soon.is_empty(), not third.is_empty(), float(rt["y"]), vtop, float(v2["vx"]), bool(lost["lost"]), float(v0["vx"])])
	# 그림: 노드 아이 6(레일·받침 둘·고리 노드·소리 둘), 고리 노드 아이 6(고리 다섯·천), 천 아이 8(천·무늬·단 띠·술 다섯); 노드 자리 −6.6111 19.4444 −1.9444; 고리 x 는 cx 를 따른다(242 → 0, 272 → 0.8333); 흔들림: 바람 0 이면 2 px(0.714초에), 바람 60 이면 9 px(치우침 3 + 6), 단에서 다·레일에서 0·가운데서 반; 천의 각 asin(2/140)
	tp._process(3.0); tp.sync(0.0); tp._process(0.0)   # 셋째 타기에서 318.5 에 선 빈 고리가 3초에 제자리로
	var node: Node3D = c["node"]; var rings: Node3D = c["rings"]; var cloth: Node3D = c["cloth"]
	var rx0 := rings.position.x
	c["cx"] = 272.0; c["rider"] = true; tp._process(0.0); var rx1 := rings.position.x; c["cx"] = 242.0; c["rider"] = false
	var s0 := tp.sway_at(c, 0.0); var s1 := tp.sway_at(c, 0.714286)
	var windy: Dictionary = c.duplicate(); windy["wind"] = 60.0
	var w0 := tp.sway_at(windy, 0.0); var w1 := tp.sway_at(windy, 0.714286); var wh := tp.sway_y(windy, 0.714286, 720.0); var wr := tp.sway_y(windy, 0.714286, 860.0); var wm := tp.sway_y(windy, 0.714286, 790.0)
	tp.sync(0.714286); tp._process(0.0); var rz := cloth.rotation.z
	print("VISUAL node children=%d (want 6) rings=%d cloth=%d (want 6 8) node pos=%.4f %.4f %.4f (want −6.6111 19.4444 −1.9444) rings x home=%.4f drifted=%.4f (want 0.0000 0.8333) sway still 0=%.1f 0.71=%.1f (want 0.0 2.0) windy 0=%.1f 0.71=%.1f (want 3.0 9.0) hem=%.1f rail=%.1f mid=%.1f (want 9.0 0.0 4.5) cloth rot=%.4f (want 0.0143)" % [node.get_child_count(), rings.get_child_count(), cloth.get_child_count(), node.position.x, node.position.y, node.position.z, rx0, rx1, s0, s1, w0, w1, wh, wr, wm, rz])
	# 자세(scale_t 0.104167 — 당김 1, 오른손이 위(alt 0.707); sw 0): 오른 어깨 x −2.762 z −0.150 팔꿈치 −1.000 엉덩이 −1.235 무릎 1.600; 왼 어깨 x −2.338 z 0.150 팔꿈치 −1.000 엉덩이 −1.065 무릎 1.600; 골반 0.445 몸통 0.144 | 꼭대기(scale_v 0): 어깨 −2.550 팔꿈치 −0.450 엉덩이 −0.700 무릎 1.100 골반 0.420 몸통 0.099 | 건너가기(scale_k 1): 어깨 −1.300 팔꿈치 −0.600 엉덩이 오른 −1.200 왼 −0.350 무릎 오른 1.000 왼 0.300 몸통 0.189
	fig.pose_request = "scale"; fig.set_meta("scale_t", 0.104167); fig.set_meta("scale_sw", 0.0); fig.set_meta("scale_v", 1.0); fig.set_meta("scale_k", 0.0)
	for i in 90: await process_frame
	var r_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var r_shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var r_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var r_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var r_knee: float = (fig.knees[1.0] as Node3D).rotation.x
	var l_shx: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var l_shz: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var l_el: float = (fig.elbows[-1.0] as Node3D).rotation.x; var l_hip: float = (fig.hips[-1.0] as Node3D).rotation.x; var l_knee: float = (fig.knees[-1.0] as Node3D).rotation.x
	var c_pel := fig.pelvis.position.y; var c_tor := fig.torso.rotation.x
	fig.set_meta("scale_v", 0.0)
	for i in 90: await process_frame
	var t_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var t_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var t_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var t_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var t_pel := fig.pelvis.position.y; var t_tor := fig.torso.rotation.x
	fig.set_meta("scale_k", 1.0)
	for i in 90: await process_frame
	var s_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var s_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var s_rhip: float = (fig.hips[1.0] as Node3D).rotation.x; var s_lhip: float = (fig.hips[-1.0] as Node3D).rotation.x; var s_rknee: float = (fig.knees[1.0] as Node3D).rotation.x; var s_lknee: float = (fig.knees[-1.0] as Node3D).rotation.x; var s_tor := fig.torso.rotation.x
	print("POSE climb: R sh=%.3f %.3f el=%.3f hip=%.3f knee=%.3f (want −2.762 −0.150 −1.000 −1.235 1.600) L sh=%.3f %.3f el=%.3f hip=%.3f knee=%.3f (want −2.338 0.150 −1.000 −1.065 1.600) pelvis=%.3f torso=%.3f (want 0.445 0.144) | top: sh=%.3f el=%.3f hip=%.3f knee=%.3f pelvis=%.3f torso=%.3f (want −2.550 −0.450 −0.700 1.100 0.420 0.099) | step: sh=%.3f el=%.3f hip R=%.3f L=%.3f knee R=%.3f L=%.3f torso=%.3f (want −1.300 −0.600 −1.200 −0.350 1.000 0.300 0.189)" % [r_shx, r_shz, r_el, r_hip, r_knee, l_shx, l_shz, l_el, l_hip, l_knee, c_pel, c_tor, t_shx, t_el, t_hip, t_knee, t_pel, t_tor, s_shx, s_el, s_rhip, s_lhip, s_rknee, s_lknee, s_tor])
	# 진짜 탑: 1..60층에 plan 이 찾는 천 — 옛 회관 층 1..4, 35..39 중 바람구멍 층(3, 35, 39)을 뺀, 종 줄·회전문·빨랫줄·도개교(taken)가 안 든 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var bl: Array = cb.plan(n, pl); var dr: Array = cr.plan(n, pl, bl); var ll: Array = cl.plan(n, pl, bl + dr)
		var out2 := tp.plan(n, pl, bl + dr + ll + dw.plan(n, pl, bl + dr + ll), float(gm.wind_of(n)))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f wind %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["wind"])])]); count += out2.size()
	print("TOWER floors=", bands, " cloths=", count, " (want a subset of 1, 2, 4, 36, 37, 38 — one each, never 3, 35 or 39 or another theme)")
	quit()
