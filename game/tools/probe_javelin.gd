extends SceneTree
## 절벽 투창 팩 점검(헤드리스): 자료가 읽히나, 바람 절벽 층의 still std 발판 중 min_w 110 보다 넓고 복도가 비고 taken 이 없는 가장 넓은 것에만 투창장이 서나(허들 줄이 선 발판은 비켜 가고, 복도에 지름길 판이 든 발판도 비켜 가고, 좁은 발판뿐이면 없고, 다른 테마 층은 아니다; 가운데 오른쪽 발판은 왼쪽으로 던진다),
## 받침대 곁의 C 가 당김에 들고(busy, hurl_d, throwing, 손의 창, 받침대 2) 받침대에서 떠나면 창이 돌아가고 몸이 바로 풀리나, C 없는 몸·먼 z·다른 발판은 아무것도 아니나(평이 100%),
## 쥐면 0.2 s 당김·0.45 s 에 모으기(hurl_c)·need_k 0.389 에 놓으면 던짐(hurl_t)이 되어 0.2 s 에 창이 811 px/s·60° 로 손(188, +48)을 떠나나(whish, me_t, throws), 0.27 s 에 고리(296, +150)에 꽂혀(stuck, thunk, hits 1, day 0) 자루 236..296 이 발판이 되나(land·holds), 0.75 s 에 몸이 풀리나(메타·손의 창이 사라진다),
## 톡 던진 창(0)이 발판 300 에 눕고(down, clatter) 3 s 뒤 받침대로 돌아오나, 가득 던진 창(1)이 고리 위를 넘어 잃히나(lost, 먼지) 3 s 뒤 돌아오나, 꽂힌 창 곁 고리에 둘째는 안 꽂히나, 12 s 뒤 고리가 놓아 창이 곧장 떨어져 발판 266 에 눕나(holds 거짓, land 빈 사전),
## 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 세나, 다음 날 다른 몸(count 거짓)의 명중은 세지 않나(0/1), 받침대·고리(3)·창 셋(3)·소리 셋이 그려지나, 노드 자리, 기댄 창의 자리,
## hurl 자세가 당김 끝(0.45)에 던지는 팔 +1.9/z −0.25/팔꿈치 −0.35·가리키는 팔 −1.5/−0.1·앞 엉덩이 −0.5·무릎 0.35·뒷 엉덩이 0.35·무릎 0.5·골반 0.37·상체 −0.09·고개 < 0 이고, 가득 모아(1.0) 팔 2.185±0.04·골반 0.30·상체 −0.2025 이고, 던짐(0.2)에 팔 −1.7/−0.4·막는 팔 0.2/−1.3·앞 엉덩이 −0.35·골반 0.42·상체 0.2025 이고, 따라감(0.4)에 팔 −0.6·뒷 엉덩이 −0.7·무릎 0.9·골반 0.36·상체 0.135 이고, 0.75 에 서나(done),
## 진짜 탑의 1..70층에서 plan 이 바람 절벽 층(20..24, 55..59)에만 투창장을 찾나
const C = preload("res://scripts/games/climb.gd")
const DT := 1.0 / 60.0

func _init() -> void:
	var cj := ClimbJavelin.new(); root.add_child(cj)
	var cu := ClimbUpdraft.new(); root.add_child(cu)
	var ci := ClimbIcicle.new(); root.add_child(ci)
	var ck := ClimbKite.new(); root.add_child(ck)
	var ch := ClimbHurdle.new(); root.add_child(ch)
	var cb := ClimbBar.new(); root.add_child(cb)
	var cd := ClimbDandelion.new(); root.add_child(cd)
	var cv := ClimbVane.new(); root.add_child(cv)
	await process_frame
	print("PACK id=", cj.pack.get("id"), " kind=", cj.kind.size() > 0, " pose=", cj.pack.get("pose"), " themes=", cj.pack.get("themes"), " min_w=%.0f reach=%.0f rack_in=%.0f d=%.0f n=%d len=%.0f rack_h=%.0f dx=%.0f dy=%.0f ring=%.0f loft=%.0f v=%.0f..%.0f hand=%.0f/%.0f draw=%.2f charge=%.2f release=%.2f swing=%.2f stay=%.0f back=%.0f lose=%.0f day=%.0f need_v=%.1f need_k=%.3f (want javelin true hurl [Wind cliffs] 110 14 26 24 3 60 40 120 150 12 60 500..1300 12/48 0.45 0.80 0.20 0.75 12 3 300 600 811.3 0.389)" % [cj.min_w(), cj.reach(), cj.rack_in(), cj.range_d(), cj.rack_n(), cj.jav_len(), cj.rack_h(), cj.range_dx(), cj.range_dy(), cj.ring_r(), rad_to_deg(cj.loft()), cj.v_min(), cj.v_max(), cj.hand_dx(), cj.hand_dy(), cj.draw_s(), cj.charge_s(), cj.release_s(), cj.swing_s(), cj.stay_s(), cj.back_s(), cj.lose_dy(), cj.day_s(), cj.need_v(108.0, 102.0), cj.need_k()])
	var plats: Array = [
		{ "id": "21.0", "x": 60.0, "y": 12700.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21.1", "x": 320.0, "y": 12810.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21.2", "x": 100.0, "y": 12920.0, "w": 130.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "21.3", "x": 380.0, "y": 13030.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21.4", "x": 150.0, "y": 13140.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21.5", "x": 450.0, "y": 13250.0, "w": 130.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21s", "x": 700.0, "y": 13190.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cj.plan(21, plats)
	var rail := { "id": "21.H0", "kind": "hurdle", "x": 160.0, "w": 140.0, "y": 13140.0, "rail_y": 13170.0 }   # 허들 줄이 21.4 에 섰다 — 21.0 으로
	var railed := cj.plan(21, plats, 0.0, [rail])
	var cut := plats.duplicate(true); cut.append({ "id": "21c", "x": 230.0, "y": 13230.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 })   # 21.4 의 복도에 지름길 판 — 21.0 으로
	var cutp := cj.plan(21, cut)
	var thin := plats.duplicate(true)
	for pv in thin:   # 전부 좁다 — 없다
		var q: Dictionary = pv; q["w"] = 100.0
	var thinp := cj.plan(21, thin)
	var right := plats.duplicate(true)
	for pv in right:   # 다 가운데 오른쪽 — 왼쪽으로 던진다
		var q: Dictionary = pv; q["x"] = float(q["x"]) + 480.0
	var rightp := cj.plan(21, right)
	var f19 := cj.plan(19, plats); var f20 := cj.plan(20, plats); var f24 := cj.plan(24, plats); var f25 := cj.plan(25, plats); var f55 := cj.plan(55, plats, -60.0)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " on %s w %.0f dir %.0f wx %.0f rx %.0f ry %.0f x %.0f w %.0f y %.0f y_top %.0f z %.0f d %.0f need %.3f" % [String(v["hop_id"]), float(v["hop_w"]), float(v["dir"]), float(v["wx"]), float(v["rx"]), float(v["ry"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"]), float(v["need"])]
	var brief := func(v: Dictionary) -> String: return "%s dir %.0f wx %.0f rx %.0f" % [String(v["hop_id"]), float(v["dir"]), float(v["wx"]), float(v["rx"])]
	print("PLAN free=", free.map(show), " (want 1: 21.J0 on 21.4 w 160 dir 1 wx 176 rx 296 ry 13290 x 184 w 134 y 13140 y_top 13306 z −58 d 24 need 0.389)")
	print("PLAN railed=", railed.map(brief), " (want [21.0 dir 1 wx 86 rx 206]) cut=", cutp.map(brief), " (want [21.0 dir 1 wx 86 rx 206]) thin=", thinp.size(), " (want 0) right=", rightp.map(brief), " (want [21.4 dir −1 wx 764 rx 644]) floors 19/20/24/25/55=", [f19.size(), f20.size(), f24.size(), f25.size(), f55.size()], " (want 0 1 1 0 1) wind 55=%.0f (want −60)" % [float((f55[0] as Dictionary)["wind"]) if f55.size() > 0 else 99.0])
	var band_root := Node3D.new(); root.add_child(band_root)
	cj.build(band_root, free)
	var s: Dictionary = cj.ranges[0]
	var fig := Stick3D.new(); root.add_child(fig)
	var fig2 := Stick3D.new(); root.add_child(fig2)
	var on: Dictionary = plats[4]; var z := C.PLAYER_Z
	var whish: AudioStreamPlayer3D = s["whish"]; var thunk: AudioStreamPlayer3D = s["thunk"]; var clatter: AudioStreamPlayer3D = s["clatter"]
	var javs: Array = s["javs"]; var j0: Dictionary = javs[0]; var j1: Dictionary = javs[1]; var j2: Dictionary = javs[2]
	# 당김(t 10, 몸 180 — 받침대 176 곁): busy, hurl_d 0, throwing 1, 손의 창, 받침대에 둘; 받침대에서 떠나면(100) 창이 돌아가고 몸은 바로 풀린다
	cj.sync(10.0)
	var a := cj.throw(180.0, z, on, true, fig); var a_state := "%s/%.0f/%.0f/%s/%s/%d" % [String(s["sw"]), float(fig.get_meta("hurl_d", 9.0)), cj.throwing(fig), String(j0["st"]), fig.hand_r.get_node_or_null("jav") != null, _racked(s)]
	var gone := cj.throw(100.0, z, on, true, fig); var gone_state := "'%s' %s %s %s %d" % [String(s["sw"]), String(j0["st"]), cj.throwing(fig) == 0.0, fig.has_meta("hurl_d"), _racked(s)]
	var far_z := cj.throw(180.0, z + 40.0, on, true, fig); var other_hop := cj.throw(180.0, z, plats[3], true, fig); var plain := cj.throw(180.0, z, on, false, fig)
	print("DRAW start: busy=%s k=%.2f id=%s sw/meta/dir/jav/hand/racked=%s (want true 0.00 21.J0 draw/0/1/held/true/2) | away: busy=%s → %s (want false '' rack true false 3) | far z: %s other hop: %s plain (no C): %s sw='%s' (want false false false '')" % [a["busy"], float(a["k"]), String(a["id"]), a_state, gone["busy"], gone_state, far_z["busy"], other_hop["busy"], plain["busy"], String(s["sw"])])
	# 쥐고 던진다(t 20): 0.2 당김(hurl_d 0.2), 0.4501 모으기(hurl_c 0 — 실수 끝자리를 피해 0.0001 늦게), need_k 에 놓으면 던짐(hurl_t 0, c 0.389), 0.21 s 에 창이 손을 떠났고(fly, 811 px/s, whish, me_t, throws 1), 틱으로 날아 0.27 s 에 꽂힌다(stuck, 266/13290, thunk, hits 1, day 0, 자루 236..296); 0.76 s 에 풀린다
	var nk := cj.need_k()
	cj.sync(20.0); cj.throw(180.0, z, on, true, fig)
	cj.sync(20.2); var r1 := cj.throw(180.0, z, on, true, fig); var p1 := "%s d=%.2f" % [String(s["sw"]), float(fig.get_meta("hurl_d", 9.0))]
	cj.sync(20.4501); cj.throw(180.0, z, on, true, fig); var p2 := "%s c=%.2f d=%.2f" % [String(s["sw"]), float(fig.get_meta("hurl_c", 9.0)), float(fig.get_meta("hurl_d", 9.0))]
	var t_go := 20.4501 + 0.8 * nk
	cj.sync(t_go); cj.throw(180.0, z, on, true, fig); var p3 := "%s c=%.3f" % [String(s["sw"]), float(fig.get_meta("hurl_c", 9.0))]
	var r4 := cj.throw(180.0, z, on, false, fig); var p4 := "%s c=%.3f t=%.2f busy=%s" % [String(s["sw"]), float(s["c"]), float(fig.get_meta("hurl_t", 9.0)), r4["busy"]]
	cj.sync(t_go + 0.21); cj._process(0.0); var r5 := cj.throw(180.0, z, on, false, fig)
	var p5 := "%s %s x=%.0f y=%.0f v=%.1f/%.1f tilt=%.3f whish=%s me_t=%.2f throws=%d hand=%s busy=%s" % [String(s["sw"]), String(j0["st"]), float(j0["x"]), float(j0["y"]), float(j0["vx"]), float(j0["vy"]), float(j0["tilt"]), whish.playing, float(s["me_t"]), int(s["throws"]), fig.hand_r.get_node_or_null("jav") != null, r5["busy"]]
	var flew := _flight(cj, j0)
	var ledge: Dictionary = j0["ledge"]
	var p6 := "%s at=%.2f s x=%.0f y=%.0f tilt=%.2f thunk=%s hits=%d day=%d ledge=%s x=%.0f w=%.0f y=%.0f z=%.0f d=%.0f" % [String(j0["st"]), flew, float(j0["x"]), float(j0["y"]), float(j0["tilt"]), thunk.playing, int(s["hits"]), int(s["day"]), String(ledge["id"]), float(ledge["x"]), float(ledge["w"]), float(ledge["y"]), float(ledge["z"]), float(ledge["d"])]
	var ld := cj.land(266.0, 13300.0, 13289.0, z); var ld_side := cj.land(340.0, 13300.0, 13289.0, z); var ld_up := cj.land(266.0, 13300.0, 13295.0, z)
	var p7 := "land=%s side=%s rising=%s holds=%s" % [String(ld.get("id", "-")), ld_side.is_empty(), ld_up.is_empty(), cj.holds(ledge)]
	cj.sync(t_go + 0.76); cj._process(0.0); var r8 := cj.throw(180.0, z, on, false, fig)
	var p8 := "'%s' busy=%s throwing=%.0f meta=%s/%s/%s hand=%s" % [String(s["sw"]), r8["busy"], cj.throwing(fig), fig.has_meta("hurl_d"), fig.has_meta("hurl_c"), fig.has_meta("hurl_t"), fig.hand_r.get_node_or_null("jav") != null]
	print("HELD 0.2 s: busy=%s %s (want true draw d=0.20) | 0.45 s: %s (want charge c=0.00 d=0.45) | +0.8·need_k: %s (want charge c=0.389) | let go: %s (want throw c=0.389 t=0.00 busy=true) | +0.21: %s (want throw fly x=188 y=13188 v=405.6/702.6 tilt=1.047 whish=true me_t=%.2f throws=1 hand=false busy=true)" % [r1["busy"], p1, p2, p3, p4, p5, t_go + 0.21])
	print("STUCK ", p6, " (want stuck 0.25..0.27 — 16 ticks from the hand — 266 13290 0.00 true 1 0 21.J0.j0 236 60 13290 −58 24) | ", p7, " (want land=21.J0.j0 side=true rising=true holds=true) | +0.76: ", p8, " (want '' false 0 false/false/false false)")
	# 찬 고리(t 23): 같은 need_k 로 던진 둘째는 안 꽂히고 고리를 지나 아래 발판 21.3(496, 13030)에 눕는다(clatter) — 꽂힌 창은 그대로, hits 1
	cj.sync(23.0); cj.throw(180.0, z, on, true, fig)
	cj.sync(23.4501); cj.throw(180.0, z, on, true, fig)
	cj.sync(23.4501 + 0.8 * nk); cj.throw(180.0, z, on, true, fig); cj.throw(180.0, z, on, false, fig)
	cj.sync(23.4501 + 0.8 * nk + 0.21); cj._process(0.0); var o_t := _flight(cj, j1)
	var occupied := "%s at=%.2f s x=%.0f y=%.0f clatter=%s j0=%s hits=%d" % [String(j1["st"]), o_t, float(j1["x"]), float(j1["y"]), clatter.playing, String(j0["st"]), int(s["hits"])]
	# 톡 던진 창(t 25, 놓은 채 당김 → 모으기 0 → 던짐): 발판 300 에 눕는다(down, clatter); 몸은 0.76 s 에 풀리고(받침대는 비었다 — 0), 누운 지 3 s 뒤 받침대로(2: 21.3 의 것도 돌아왔다)
	cj.sync(25.0); cj.throw(180.0, z, on, true, fig)
	cj.sync(25.4501); cj.throw(180.0, z, on, false, fig); var weak_sw := "%s c=%.2f %s" % [String(s["sw"]), float(s["c"]), String(j2["st"])]
	cj.sync(25.4501 + 0.21); cj._process(0.0); var w_t := _flight(cj, j2)
	var weak := "%s at=%.2f s x=%.0f y=%.0f tilt=%.2f clatter=%s j0=%s" % [String(j2["st"]), w_t, float(j2["x"]), float(j2["y"]), float(j2["tilt"]), clatter.playing, String(j0["st"])]
	var down_t := cj.t
	cj.sync(25.4501 + 0.76); cj._process(0.0); cj.throw(180.0, z, on, false, fig); var weak_free := "'%s' racked=%d" % [String(s["sw"]), _racked(s)]
	cj.sync(down_t + 3.01); cj._process(0.0); var weak_back := "%s racked=%d" % [String(j2["st"]), _racked(s)]
	# 가득 던진 창(t 28): 고리 위를 넘어(12 보다 멀리) 탑 끝에서 잃는다(lost, 발판 아래 300 — 1.18 s); 꽂힌 창은 그대로
	cj.sync(28.0); cj.throw(180.0, z, on, true, fig)
	cj.sync(28.4501); cj.throw(180.0, z, on, true, fig)
	cj.sync(29.2501); cj.throw(180.0, z, on, true, fig); cj.throw(180.0, z, on, false, fig); var full_sw := "%s c=%.2f" % [String(s["sw"]), float(s["c"])]
	cj.sync(29.2501 + 0.21); cj._process(0.0); var f_t := cj.t; var ticks := 0
	var over := 99.0; var jf: Dictionary = javs[int(s["jav"])]
	while String(jf["st"]) in ["held", "fly"] and ticks < 120:
		cj._process(DT); ticks += 1
		if absf(float(jf["x"]) - 296.0) < 12.0: over = minf(over, float(jf["y"]) - 13290.0)
	var full := "%s at=%.2f s x=%.0f y=%.0f over ring by %.0f j0=%s" % [String(jf["st"]), cj.t - f_t, float(jf["x"]), float(jf["y"]), over, String(j0["st"])]
	print("MISS occupied ring: %s (want down ≈0.75 ≈492 13030 true stuck 1: the tick grid) | tap: %s (want throw c=0.00 held) → %s (want down 0.45 ≈300 13140 0.00 true stuck) → %s (want '' 0) → +3 s: %s (want rack 2) | full: %s (want throw c=1.00) → %s (want lost 1.18 ≈957 ≈12816 > 12 stuck)" % [occupied, weak_sw, weak, weak_free, weak_back, full_sw, full])
	# 고리가 놓는다: 꽂힌 지 12 s(t_stick + 12.01) 에 창이 곧장 떨어진다(fly, loose) — holds 거짓, land 빈 사전; 0.35 s 뒤 발판 266 에 눕는다(clatter, 눕는 각 0); 3 s 뒤 받침대로(3 — 잃은 창도 돌아왔다)
	var t_stick := float(j0["t0"])
	cj.sync(t_stick + 12.01); cj._process(0.0); var let_go := "%s loose=%s holds=%s land=%s x=%.0f y=%.0f" % [String(j0["st"]), j0["loose"], cj.holds(ledge), cj.land(266.0, 13300.0, 13289.0, z).is_empty(), float(j0["x"]), float(j0["y"])]
	var g_t := _flight(cj, j0)
	var fell := "%s at=%.2f s x=%.0f y=%.0f tilt=%.2f clatter=%s" % [String(j0["st"]), g_t, float(j0["x"]), float(j0["y"]), float(j0["tilt"]), clatter.playing]
	cj.sync(cj.t + 3.01); cj._process(0.0); var all_back := "racked=%d" % _racked(s)
	print("STAY 12 s: ", let_go, " (want fly loose=true holds=false land=true 266 13290) → ", fell, " (want down 0.35 266 13140 0.00 true) → +3 s: ", all_back, " (want racked=3)")
	print("NOTE 20=\"%s\" (want Javelin range, floors 20–24: 1 of 1 ring hit today, 4 throws today.) 25=\"%s\" (want the same: nothing on 25..29, so the floors below) 30=\"%s\" (want empty)" % [cj.note(20), cj.note(25), cj.note(30)])
	# 다음 날(620): 다른 몸(count 거짓)이 need_k 로 맞힌다 — 꽂히지만 세지 않는다(0/1, 1 throw); 남이 던지는 동안 플레이어의 C 는 기다린다
	cj.sync(620.0); cj.throw(180.0, z, on, true, fig2, false)
	var wait := cj.throw(180.0, z, on, true, fig); var wait_state := "%s" % [(s["sw_fig"] as Stick3D) == fig2]
	cj.sync(620.4501); cj.throw(180.0, z, on, true, fig2, false)
	cj.sync(620.4501 + 0.8 * nk); cj.throw(180.0, z, on, true, fig2, false); cj.throw(180.0, z, on, false, fig2, false)
	cj.sync(620.4501 + 0.8 * nk + 0.21); cj._process(0.0)
	var jx: Dictionary = javs[int(s["jav"])]
	_flight(cj, jx)
	print("OTHER waits: busy=%s fig2=%s (want false true) | next day other body: %s day=%d hits=%d (want stuck 0 2) note 20=\"%s\" (want … 0 of 1 ring hit today, 1 throw today.)" % [wait["busy"], wait_state, String(jx["st"]), int(s["day"]), int(s["hits"]), cj.note(20)])
	# 그림(700 — 남의 창도 고리가 놓고 떨어져 돌아온 뒤): 노드 자리, 받침대(3)·고리(3)·창 셋(3씩)·소리 셋, 기댄 창의 자리
	cj.sync(float(jx["t0"]) + 12.01); cj._process(0.0); _flight(cj, jx); cj.sync(cj.t + 3.01); cj._process(0.0)
	var node: Node3D = s["node"]; var rack: Node3D = s["rack"]; var ring: Node3D = s["ring_node"]; var jn0: Node3D = j0["node"]
	cj.sync(700.0); cj._process(0.0)
	print("VISUAL node=%s (want %s) children=%d (want 8: rack ring + 3 javelins + 3 sounds) rack parts=%d (want 3) ring parts=%d (want 3) ring at x=%.4f y=%.4f (want 3.3333 4.1667) javelin parts=%d (want 3) racked=%d j0: x=%.3f y=%.3f tilt=%.2f visible=%s (want 3 0.193 0.801 1.25 true)" % [node.position, C.to3(176.0, 13140.0, C.WALL_Z * C.K), node.get_child_count(), rack.get_child_count(), ring.get_child_count(), ring.position.x, ring.position.y, jn0.get_child_count(), _racked(s), jn0.position.x, jn0.position.y, jn0.rotation.z, jn0.visible])
	await _pose(fig)
	# 진짜 탑: 1..70층에 plan 이 찾는 투창장 — 바람 절벽 층 20..24, 55..59 중 통풍구·고드름·연·허들·바·민들레가 안 쓴 넓은 발판이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n); var wind: float = gm.wind_of(n)
		var kp: Array = ck.plan(n, pl, wind); var hop_top: Array = cu.plan(n, pl) + ci.plan(n, pl) + kp; var hp: Array = ch.plan(n, pl, hop_top)
		var dp: Array = cd.plan(n, pl, wind, kp + cv.plan(n, pl, wind, kp)); var bp: Array = cb.plan(n, pl, wind, hop_top + hp + dp)
		var out2 := cj.plan(n, pl, wind, hop_top + hp + dp + bp)
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s w %.0f dir %.0f wind %.0f" % [String(v["hop_id"]), float(v["hop_w"]), float(v["dir"]), float(v["wind"])])])
	print("TOWER floors=", bands, " (want a subset of 20..24, 55..59 — one range each on the widest std hop no other Wind cliffs pack took and no hop cuts the corridor, never another theme)")
	quit()

## 받침대에 선 창의 수
func _racked(s: Dictionary) -> int:
	var n := 0
	for jv in (s["javs"] as Array):
		if String((jv as Dictionary)["st"]) == "rack": n += 1
	return n

## 창이 손을 떠나 나는 동안 틱을 돌린다(최대 120 틱) — 떠난 뒤 걸린 시간(s)
func _flight(cj: ClimbJavelin, j: Dictionary) -> float:
	var t0 := cj.t; var ticks := 0
	while String(j["st"]) in ["held", "fly"] and ticks < 120:
		cj._process(DT); ticks += 1
	return cj.t - t0

## hurl 자세 — 당김 끝, 가득 모아, 던짐, 따라감, 섬의 관절(torso 는 lean × 0.45, 골반은 0.42 − dip; 무릎은 숨 ±0.03)
func _pose(fig: Stick3D) -> void:
	fig.pose_request = "hurl"; fig.set_meta("hurl_d", 0.45)
	for i in 45: await process_frame   # 관절은 섞여 따라온다(Stick3D 의 블렌딩) — 자리를 잡을 때까지
	var a_shx: float = wrapf((fig.shoulders[1.0] as Node3D).rotation.x, -PI, PI); var a_shz := wrapf((fig.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var a_el: float = (fig.elbows[1.0] as Node3D).rotation.x
	var a_shx2: float = wrapf((fig.shoulders[-1.0] as Node3D).rotation.x, -PI, PI); var a_el2: float = (fig.elbows[-1.0] as Node3D).rotation.x
	var a_hip2: float = (fig.hips[-1.0] as Node3D).rotation.x; var a_knee2: float = (fig.knees[-1.0] as Node3D).rotation.x; var a_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var a_knee: float = (fig.knees[1.0] as Node3D).rotation.x
	var a_pel := fig.pelvis.position.y; var a_tx := fig.torso.rotation.x; var a_neck := fig.neck.rotation.x
	fig.set_meta("hurl_d", 1.25); fig.set_meta("hurl_c", 1.0)
	for i in 45: await process_frame
	var c_shx: float = wrapf((fig.shoulders[1.0] as Node3D).rotation.x, -PI, PI); var c_pel := fig.pelvis.position.y; var c_tx := fig.torso.rotation.x
	fig.set_meta("hurl_t", 0.2)
	for i in 45: await process_frame
	var t_shx: float = wrapf((fig.shoulders[1.0] as Node3D).rotation.x, -PI, PI); var t_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var t_shx2: float = wrapf((fig.shoulders[-1.0] as Node3D).rotation.x, -PI, PI); var t_el2: float = (fig.elbows[-1.0] as Node3D).rotation.x
	var t_hip2: float = (fig.hips[-1.0] as Node3D).rotation.x; var t_pel := fig.pelvis.position.y; var t_tx := fig.torso.rotation.x; var t_neck := fig.neck.rotation.x
	fig.set_meta("hurl_t", 0.4)
	for i in 45: await process_frame
	var f_shx: float = wrapf((fig.shoulders[1.0] as Node3D).rotation.x, -PI, PI); var f_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var f_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var f_pel := fig.pelvis.position.y; var f_tx := fig.torso.rotation.x
	fig.set_meta("hurl_t", 0.75)
	for i in 45: await process_frame
	var e_shx: float = wrapf((fig.shoulders[1.0] as Node3D).rotation.x, -PI, PI); var e_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var e_pel := fig.pelvis.position.y; var e_tx := fig.torso.rotation.x
	fig.remove_meta("hurl_d"); fig.remove_meta("hurl_c"); fig.remove_meta("hurl_t")
	print("POSE draw end: arm=%.2f z=%.2f elbow=%.2f | pointing arm=%.2f elbow=%.2f | front hip=%.2f knee=%.2f rear hip=%.2f knee=%.2f | pelvis=%.2f torso=%.3f neck<0=%s (want 1.90 −0.25 −0.35 | −1.50 −0.10 | −0.50 0.35±0.03 0.35 0.50±0.03 | 0.37 −0.090 true) | full charge: arm=%.2f pelvis=%.2f torso=%.4f (want 2.185±0.04 0.30 −0.2025)" % [a_shx, a_shz, a_el, a_shx2, a_el2, a_hip2, a_knee2, a_hip, a_knee, a_pel, a_tx, a_neck < 0.0, c_shx, c_pel, c_tx])
	print("POSE release 0.2 s: arm=%.2f elbow=%.2f | blocking arm=%.2f elbow=%.2f | front hip=%.2f | pelvis=%.2f torso=%.4f neck<0=%s (want −1.70 −0.40 | 0.20 −1.30 | −0.35 | 0.42 0.2025 true) | follow 0.4 s: arm=%.2f rear hip=%.2f knee=%.2f pelvis=%.2f torso=%.3f (want −0.60 −0.70 0.90±0.03 0.36 0.135) | 0.75 s: arm=%.2f hip=%.2f pelvis=%.2f torso=%.2f (want 0.00 0.00 0.42 0.00) done(no meta, 1.95 → just past)=%s" % [t_shx, t_el, t_shx2, t_el2, t_hip2, t_pel, t_tx, t_neck < 0.0, f_shx, f_hip, f_knee, f_pel, f_tx, e_shx, e_hip, e_pel, e_tx, _demo_done(fig)])
	fig.pose_request = ""

## 메타 없이 pose_t 로 도는 시연 — 당김 0.45 + 숨 0.15 + 모으기 0.6 + 던짐 0.75 = 1.95 에 done
func _demo_done(fig: Stick3D) -> bool:
	var e := HurlPoses.DRAW_T + HurlPoses.DEMO_WAIT + HurlPoses.DEMO_CHARGE + HurlPoses.SWING_T
	fig.pose_t = e - 0.01; var before := HurlPoses.done(fig)
	fig.pose_t = e + 0.001; var after := HurlPoses.done(fig)
	return (not before) and after
