extends SceneTree
## 해시계 팩 점검(헤드리스): 자료가 읽히나(통풍구 규칙은 상승기류 자료에서), 공중 정원 층의 still 발판(min_w 이상) 중 가장 넓은 것에만 돌판이 서나(통풍구가 가운데 선 발판은 비켜 다음 넓은 것으로, 위 발판 높이의 조각은 그 발판의 것이 아니고, 진폭째 상자를 가르는 움직이는 발판도, 좁은 발판만인 층·다른 테마 층은 아니다),
## 위 통풍구 층·탑의 시각·부는 통풍구가 맞나, 돌판 곁의 그 발판에서 C 를 누를 때만 읽나(다른 발판·멀리·앞·C 없이·이미 읽는 동안엔 아니다), 농도가 손 올리기 뒤 켜지고 show_s 끝에 잦아드나,
## 돌판(눈금 열둘·그노몬·그림자·글자·화살표·소리 둘·키퍼)이 그려지고 그림자가 하루에 한 바퀴 돌며 읽은 뒤 글자와 화살표가 켜지고 부는 통풍구의 화살표만 밝게 떠오르나, squint 자세가 손을 올리고 무게를 옮기고 끄덕이고 바로 서나,
## 다이얼 키퍼(run 158)가 정각에, 그리고 플레이어의 읽기 0.8 s 뒤에 걸어가 같은 squint 로 읽고 시각을 말하고 돌아오나(플레이어의 걷기 잠금은 안 건드린다, 한 읽기에 한 번만), 정오엔 wipe 로 2 s 더 머무나, wipe 자세가 숙여 문지르고 털며 서나, 진짜 탑의 1..70층에서 plan 이 공중 정원 층에만 돌판을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var sd := ClimbSundial.new(); root.add_child(sd)
	var cu := ClimbUpdraft.new(); root.add_child(cu)
	var cpl := ClimbPlanter.new(); root.add_child(cpl)
	var ctu := ClimbTulip.new(); root.add_child(ctu)
	var cv := ClimbVine.new(); root.add_child(cv)
	var chm := ClimbHammock.new(); root.add_child(chm)
	var cz := ClimbZip.new(); root.add_child(cz)
	await process_frame
	print("PACK id=", sd.pack.get("id"), " kind=", sd.kind.size() > 0, " pose=", sd.pack.get("pose"), " themes=", sd.pack.get("themes"), " size=%.0f inset=%.0f margin=%.0f min_w=%.0f gnomon=%.0f day=%.0f reach=%.0f read=%.1f settle=%.2f show=%.1f fade=%.2f scale=%.2f up=%.0f vent=%s/%.1f (want 36 30 24 100 14 600 18 3.2 0.50 6.0 0.60 0.25 40 {from 3, every 4}/4.0)" % [sd.size(), sd.inset(), sd.margin(), sd.min_w(), sd.gnomon_h(), sd.day_s(), sd.reach(), sd.read_s(), sd.settle_s(), sd.show_s(), sd.fade_s(), sd.view_scale(), sd.view_up(), { "from": sd.vent_rule.get("from"), "every": sd.vent_rule.get("every") }, sd.vent_beat])
	var plats: Array = [
		{ "id": "5.0", "x": 60.0, "y": 3700.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5.1", "x": 420.0, "y": 3790.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5.2", "x": 180.0, "y": 3880.0, "w": 150.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "5.3", "x": 540.0, "y": 4000.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5.4", "x": 300.0, "y": 4060.0, "w": 90.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5s", "x": 700.0, "y": 4020.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var vents: Array = [   # 위 통풍구 층(7)의 계획 — 화살표의 원본
		{ "id": "7.v0", "x": 300.0, "y": 4300.0, "z": C.PLAYER_Z, "phase": 0.0 },
		{ "id": "7.v1", "x": 700.0, "y": 4400.0, "z": C.PLAYER_Z, "phase": 0.5 },
	]
	var free := sd.plan(5, plats)
	var vented := sd.plan(5, plats, [{ "id": "5.v0", "x": 150.0, "y": 3700.0, "z": C.PLAYER_Z, "phase": 0.0 }])   # 통풍구가 5.0 의 가운데 — 그 발판은 통풍구의 것: 5.1 (160) 로
	var over := sd.plan(5, plats, [{ "id": "5.P0", "kind": "planter", "x": 120.0, "w": 100.0, "y": 3790.0, "y_top": 3830.0 }])   # 위 발판(5.1, y 3790) 높이의 화분은 5.0 의 띠(3680..3760) 밖 — 5.0 그대로
	var moved := plats.duplicate(true); moved.append({ "id": "5m", "x": 100.0, "y": 3730.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째(10..250, 3730) 5.0 의 상자를 가른다
	var movep := sd.plan(5, moved)
	var narrow: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["w"] = 90.0; return q)
	var narrowp := sd.plan(5, narrow)
	var floors: Array = [4, 5, 6, 7, 8, 9, 10, 40, 44, 45].map(func(n: int) -> int: return sd.plan(n, plats).size())
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " on %s cx %.0f x %.0f w %.0f y %.0f y_top %.0f z %.0f d %.0f" % [String(v["hop_id"]), float(v["cx"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	print("PLAN free=", free.map(show), " (want 1: 5.D0 on 5.0 cx 150 x 132 w 36 y 3700 y_top 3714 z −40 d 36)")
	print("PLAN vented=", vented.map(show), " (want 5.D0 on 5.1 cx 500) over=", over.map(func(v: Dictionary) -> String: return String(v["hop_id"])), " (want 5.0) moved=", movep.map(func(v: Dictionary) -> String: return String(v["hop_id"])), " (want 5.1) narrow=", narrowp.size(), " (want 0) floors 4/5/6/7/8/9/10/40/44/45=", floors, " (want 0 1 1 1 1 1 0 1 1 0: only Hanging garden floors, the vent floor 7 too)")
	print("CLOCK vent above 0/1/5/6/7/9/40/43=", [0, 1, 5, 6, 7, 9, 40, 43].map(func(n: int) -> int: return sd.vent_floor_above(n)), " (want 3 3 7 7 11 11 43 47) time 0/150/437.5/599.9/600=", [sd.time_text(0.0), sd.time_text(150.0), sd.time_text(437.5), sd.time_text(599.9), sd.time_text(600.0)], " (want 00:00 06:00 17:30 23:59 00:00) lit 0@1/0.5@1/0@3=", [sd.lit(0.0, 1.0), sd.lit(0.5, 1.0), sd.lit(0.0, 3.0)], " (want true false false)")
	var band_root := Node3D.new(); root.add_child(band_root)
	sd.build(band_root, free, vents, 7)
	var c: Dictionary = sd.dials[0]
	var a: Dictionary = plats[0]; var b: Dictionary = plats[1]
	# 읽기(10.0, 돌판 cx 150, 몸은 반지름 + reach = 36 안): 다른 발판(5.1)·x 100 (50)·앞 z −30·C 없이는 아니다; x 160 에서 C 는 읽는다(until 13.2); 바로 다시는 아니다(busy); 농도 10.5 0 / 10.65 0.5 / 10.8 1 / 15.4 1 / 15.7 0.5 / 16.0 0; 13.2 뒤엔 다시 읽을 수 있다
	var fig := Stick3D.new(); root.add_child(fig)
	sd.sync(10.0)
	var wrong := sd.read(b, 150.0, C.PLAYER_Z, true); var far := sd.read(a, 100.0, C.PLAYER_Z, true); var front := sd.read(a, 150.0, -30.0, true); var unpressed := sd.read(a, 160.0, C.PLAYER_Z, false)
	var idle := sd.squinting()
	var ok := sd.read(a, 160.0, C.PLAYER_Z, true, fig); var again := sd.read(a, 160.0, C.PLAYER_Z, true)
	var busy := sd.squinting(); var dirm := float(fig.get_meta("squint_dir", 9.0))
	var s105 := sd.solidity(c, 10.5); var s1065 := sd.solidity(c, 10.65); var s108 := sd.solidity(c, 10.8); var s154 := sd.solidity(c, 15.4); var s157 := sd.solidity(c, 15.7); var s160 := sd.solidity(c, 16.0)
	sd.sync(13.2); var later := sd.squinting(); var re := sd.read(a, 160.0, C.PLAYER_Z, true)
	print("READ wrong=%s far=%s front=%s unpressed=%s (want false ×4) idle=%s ok=%s until=%.1f busy=%s text=\"%s\" (want false true 13.2 false \"Tower time 00:24. Vents: floor 7, 2 up. The bright arrow is blowing.\") again=%s busy=%s squinting=%s dir=%.4f (want false true true 0.9945) sol 10.5=%.2f 10.65=%.2f 10.8=%.2f 15.4=%.2f 15.7=%.2f 16.0=%.2f (want 0.00 0.50 1.00 1.00 0.50 0.00) after 13.2: squinting=%s re=%s (want false true)" % [wrong["read"], far["read"], front["read"], unpressed["read"], idle, ok["read"], float(ok["until"]), ok["busy"], String(ok["text"]), again["read"], again["busy"], busy, dirm, s105, s1065, s108, s154, s157, s160, later, re["read"]])
	# 그림: 노드 아이 20(돌판·눈금 열둘·그노몬·그림자·글자·화살표 묶음·소리 둘·키퍼), 화살표 묶음 아이 2, 화살표 아이 3; 노드 자리 −9.1667 102.7778 −1.1111; 화살표 x: (300 − 480) × 0.25 = −45 → −1.25 m, (700 − 480) × 0.25 = 55 → 1.5278 m
	# 그림자 150.0 에 −π/2; 20.0 (읽은 뒤 show_s 지나) 글자·화살표 꺼짐; 25.0 에 읽고 26.5: 글자 "01:03" 농도 1, 26.5/4 = 6.625 → 통풍구 0 멎음(0.3)·1 붊(0.9), 1 의 y = fposmod(26.5 × 18, 12) = 9 px → 0.25 m, 0 의 y 0
	sd.sync(150.0); sd._process(0.0); var shz := (c["shadow"] as Node3D).rotation.y
	sd.sync(20.0); sd._process(0.0)
	var node: Node3D = c["node"]; var view: Node3D = c["view"]; var arrows: Array = c["arrows"]; var label: Label3D = c["label"]; var tk: AudioStreamPlayer3D = c["tick"]
	var a0: Dictionary = arrows[0]; var a1: Dictionary = arrows[1]
	var n0: Node3D = a0["node"]; var n1: Node3D = a1["node"]
	var v20 := label.visible; var av20 := n0.visible; var al20 := (a0["shaft"] as StandardMaterial3D).albedo_color.a; var tk20 := tk.playing
	sd.sync(25.0); sd.read(a, 160.0, C.PLAYER_Z, true); sd._process(0.0); var tk25 := tk.playing
	sd.sync(26.5); sd._process(0.0)
	var v26 := label.visible; var tx26 := label.text; var la26 := label.modulate.a; var al0 := (a0["shaft"] as StandardMaterial3D).albedo_color.a; var al1 := (a1["shaft"] as StandardMaterial3D).albedo_color.a; var hd1 := (a1["head"] as StandardMaterial3D).albedo_color.a
	print("VISUAL node children=%d (want 20) view=%d arrow=%d (want 2 3) node pos=%.4f %.4f %.4f (want −9.1667 102.7778 −1.1111) arrows x=%.4f %.4f (want −1.2500 1.5278) view y=%.4f z=%.4f (want 1.1111 −0.6667) shadow@150=%.4f (want −1.5708) dark: label=%s arrow=%s alpha=%.2f tick=%s (want false false 0.00 false) lit@26.5: label=%s \"%s\" a=%.2f (want true 01:03 1.00) arrow0 a=%.2f y=%.4f arrow1 a=%.2f head=%.2f y=%.4f visible=%s tick=%s (want 0.30 0.0000 0.90 0.90 0.2500 true true)" % [node.get_child_count(), view.get_child_count(), n0.get_child_count(), node.position.x, node.position.y, node.position.z, n0.position.x, n1.position.x, view.position.y, view.position.z, shz, v20, av20, al20, tk20, v26, tx26, la26, al0, n0.position.y, al1, hd1, n1.position.y, n1.visible, tk25 or tk.playing])
	# 키퍼(hop 5.0: cx 150 w 180 → 집 226, 읽는 자리 176, std; 정각은 25 s 마다): 49.0 에서 돌려 50.0 정각에 걸어가(50 px, 0.2 s) 읽고(squint 3.2 s, squint_dir 은 그림자에서) 돌아온다(0.2 s) — [idle, walk, squint, back, idle], 머리 위 "Tower time 02:08."(53.4 의 시각, 2 s 뒤 사라진다),
	#  읽는 동안 돌판의 read_t0 는 그대로(25.0 — squinting 은 false: 플레이어의 걷기는 안 잠긴다). 60.0 에 플레이어가 읽으면 60.8 에 따라 읽고, 같은 읽기에 두 번은 아니다. 299.0 에서 돌려 300.0 정오엔 [idle, walk, squint, wipe, back, idle] — wipe 2.0 s(303.4..305.4), "Tower time 12:08."
	var kp: ClimbKeeper = c["keeper"]
	var k0 := "%s %.0f %.0f %.0f %s %d" % [kp.phase, kp.x, kp.home_x, kp.read_x, kp.hop_kind, kp.hour]
	var tt := 49.0; sd.sync(tt); kp.hour = sd.hour_of(tt)
	var seen: Array = []; var at: Dictionary = {}; var lock := false; var said := ""; var r0 := 0.0; var kdir := 9.0; var hid := false
	while tt < 60.0:
		tt += 1.0 / 60.0; sd.sync(tt); kp.step(1.0 / 60.0)
		if seen.is_empty() or String(seen[seen.size() - 1]) != kp.phase: seen.append(kp.phase); at[kp.phase] = tt - 50.0
		if kp.phase == "squint": lock = lock or sd.squinting(); r0 = float(c["read_t0"]); kdir = float(kp.fig.get_meta("squint_dir", 9.0))
		if kp.line.visible: said = kp.line.text
		if seen.size() > 1 and kp.phase == "idle" and tt > 56.0: hid = not kp.line.visible; break
	var seen2: Array = []; var at2: Dictionary = {}
	tt = 60.0; sd.sync(tt); sd.read(a, 160.0, C.PLAYER_Z, true)
	while tt < 70.0:
		tt += 1.0 / 60.0; sd.sync(tt); kp.step(1.0 / 60.0)
		if seen2.is_empty() or String(seen2[seen2.size() - 1]) != kp.phase: seen2.append(kp.phase); at2[kp.phase] = tt - 60.0
		if seen2.size() > 1 and kp.phase == "idle" and tt > 67.0: break
	print("KEEPER start: ", k0, " (want idle 226 226 176 std 0) hour phases=%s (want [idle, walk, squint, back, idle]) walk@%.2f squint@%.2f back@%.2f idle@%.2f (want ≈0.02 0.22 3.42 3.62) said=\"%s\" (want Tower time 02:08.) hidden=%s read_t0=%.1f lock=%s dir=%.4f (want true 25.0 false 0.8649) | player read: phases=%s (want [idle, walk, squint, back, idle] — once) walk@%.2f (want ≈0.82) seen_t0=%.0f (want 60)" % [str(seen), float(at.get("walk", -1.0)), float(at.get("squint", -1.0)), float(at.get("back", -1.0)), float(at.get("idle", -1.0)), said, hid, r0, lock, kdir, str(seen2), float(at2.get("walk", -1.0)), kp.seen_t0])
	var seen3: Array = []; var at3: Dictionary = {}; var wsaid := ""; var wpose := ""
	tt = 299.0; sd.sync(tt); kp.hour = sd.hour_of(tt)
	while tt < 310.0:
		tt += 1.0 / 60.0; sd.sync(tt); kp.step(1.0 / 60.0)
		if seen3.is_empty() or String(seen3[seen3.size() - 1]) != kp.phase: seen3.append(kp.phase); at3[kp.phase] = tt - 300.0
		if kp.phase == "wipe": wpose = kp.fig.pose_request
		if kp.line.visible: wsaid = kp.line.text
		if seen3.size() > 1 and kp.phase == "idle": break
	print("NOON phases=%s (want [idle, walk, squint, wipe, back, idle]) squint@%.2f wipe@%.2f back@%.2f idle@%.2f (want ≈0.22 3.42 5.42 5.62) pose=\"%s\" said=\"%s\" (want wipe \"Tower time 12:08.\") end x=%.0f phase=%s pose=\"%s\" (want 226 idle \"\")" % [str(seen3), float(at3.get("squint", -1.0)), float(at3.get("wipe", -1.0)), float(at3.get("back", -1.0)), float(at3.get("idle", -1.0)), wpose, wsaid, kp.x, kp.phase, kp.fig.pose_request])
	# wipe 자세(wipe_t 0.4 뻗기 끝: 골반 0.280 몸통 x 0.3375; 오른 엉덩이 −0.650 무릎 1.050 어깨 x −1.250 z −0.200 팔꿈치 −0.250; 왼 엉덩이 −0.550 무릎 0.900 어깨 x −0.500 z 0.150 팔꿈치 −0.950
	#  | 0.9 소매 오른쪽 끝(rub 1): 오른 어깨 z −0.550 팔꿈치 −0.400 고개 y +0.200 몸통 x 0.3555 | 1.1 왼쪽 끝(rub −1): 오른 어깨 z 0.150 고개 y −0.200 | 1.8 털기: 골반 0.350 오른 어깨 x > −0.625(흔들려 들린다) done false | 2.0 done)
	fig.pose_request = ""
	for i in 3: await process_frame
	fig.pose_request = "wipe"; fig.set_meta("wipe_t", 0.4)
	for i in 90: await process_frame
	var p_pel := fig.pelvis.position.y; var p_tx := fig.torso.rotation.x
	var p_rhip: float = (fig.hips[1.0] as Node3D).rotation.x; var p_rknee: float = (fig.knees[1.0] as Node3D).rotation.x; var p_rshx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var p_rshz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var p_rel: float = (fig.elbows[1.0] as Node3D).rotation.x
	var p_lhip: float = (fig.hips[-1.0] as Node3D).rotation.x; var p_lknee: float = (fig.knees[-1.0] as Node3D).rotation.x; var p_lshx: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var p_lshz: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var p_lel: float = (fig.elbows[-1.0] as Node3D).rotation.x
	var p_nky := fig.neck.rotation.y
	fig.set_meta("wipe_t", 0.9)
	for i in 90: await process_frame
	var q_rshz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var q_rel: float = (fig.elbows[1.0] as Node3D).rotation.x; var q_nky := fig.neck.rotation.y - p_nky; var q_tx := fig.torso.rotation.x
	fig.set_meta("wipe_t", 1.1)
	for i in 90: await process_frame
	var u_rshz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var u_nky := fig.neck.rotation.y - p_nky
	fig.set_meta("wipe_t", 1.8)
	for i in 90: await process_frame
	var v_pel := fig.pelvis.position.y; var v_rshx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var v_done := WipePoses.done(fig)
	fig.set_meta("wipe_t", 2.0); var w_done := WipePoses.done(fig)
	print("WIPE reach: pelvis=%.3f torso x=%.4f (want 0.280 0.3375) R hip=%.3f knee=%.3f sh=%.3f %.3f el=%.3f (want −0.650 1.050 −1.250 −0.200 −0.250) L hip=%.3f knee=%.3f sh=%.3f %.3f el=%.3f (want −0.550 0.900 −0.500 0.150 −0.950) | rub right: R sh z=%.3f el=%.3f neck dy=%.3f torso x=%.4f (want −0.550 −0.400 0.200 0.3555) | rub left: R sh z=%.3f neck dy=%.3f (want 0.150 −0.200) | shake: pelvis=%.3f R sh x=%.3f (want 0.350, > −0.625) done=%s (want false) | done@2.0=%s (want true)" % [p_pel, p_tx, p_rhip, p_rknee, p_rshx, p_rshz, p_rel, p_lhip, p_lknee, p_lshx, p_lshz, p_lel, q_rshz, q_rel, q_nky, q_tx, u_rshz, u_nky, v_pel, v_rshx, v_done, w_done])
	fig.remove_meta("wipe_t"); fig.pose_request = ""
	for i in 3: await process_frame
	# 자세(squint_t 0.5 손 올림: 오른 어깨 x −2.350 z −0.300 팔꿈치 −1.750; 왼 어깨 x −0.550 z 0.175 팔꿈치 −0.150; 두 엉덩이 0.060 무릎 0.175(무게 가운데); 골반 0.400; 몸통 x −0.090 고개 x 0.590 y 0.125 몸통 y 0.050
	#  | 0.9 무게 오른발: 오른 엉덩이 0 무릎 0, 왼 엉덩이 0.120 무릎 0.350, 골반 0.420 | 1.7 무게 왼발: 오른 무릎 0.350 왼 무릎 0 | 2.1 끄덕·해: 몸통 x −0.045 고개 x −0.030 done false | 2.9 바로 서기: 오른 어깨 x −0.925 | 3.2 done)
	fig.remove_meta("squint_dir")
	fig.pose_request = "squint"; fig.set_meta("squint_t", 0.5)
	for i in 90: await process_frame
	var r_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var r_shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var r_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var r_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var r_knee: float = (fig.knees[1.0] as Node3D).rotation.x
	var l_shx: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var l_shz: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var l_el: float = (fig.elbows[-1.0] as Node3D).rotation.x; var l_hip: float = (fig.hips[-1.0] as Node3D).rotation.x; var l_knee: float = (fig.knees[-1.0] as Node3D).rotation.x
	var r_pel := fig.pelvis.position.y; var r_tx := fig.torso.rotation.x; var r_nkx := fig.neck.rotation.x; var r_nky := fig.neck.rotation.y; var r_ty := fig.torso.rotation.y; var r_done := SquintPoses.done(fig)
	var rhand_y: float = (fig.elbows[1.0] as Node3D).global_position.y - (fig.shoulders[1.0] as Node3D).global_position.y
	fig.set_meta("squint_t", 0.9)
	for i in 90: await process_frame
	var w_rhip: float = (fig.hips[1.0] as Node3D).rotation.x; var w_rknee: float = (fig.knees[1.0] as Node3D).rotation.x; var w_lhip: float = (fig.hips[-1.0] as Node3D).rotation.x; var w_lknee: float = (fig.knees[-1.0] as Node3D).rotation.x; var w_pel := fig.pelvis.position.y
	fig.set_meta("squint_t", 1.7)
	for i in 90: await process_frame
	var x_rknee: float = (fig.knees[1.0] as Node3D).rotation.x; var x_lknee: float = (fig.knees[-1.0] as Node3D).rotation.x
	fig.set_meta("squint_t", 2.1)
	for i in 90: await process_frame
	var n_tx := fig.torso.rotation.x; var n_nkx := fig.neck.rotation.x; var n_done := SquintPoses.done(fig)
	fig.set_meta("squint_t", 2.9)
	for i in 90: await process_frame
	var d_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x
	fig.set_meta("squint_t", 3.2); var e_done := SquintPoses.done(fig)
	print("POSE up: R sh=%.3f %.3f el=%.3f hip=%.3f knee=%.3f (want −2.350 −0.300 −1.750 0.060 0.175) L sh=%.3f %.3f el=%.3f hip=%.3f knee=%.3f (want −0.550 0.175 −0.150 0.060 0.175) pelvis=%.3f torso x=%.3f neck x=%.3f y=%.3f torso y=%.3f done=%s (want 0.400 −0.090 0.590 0.125 0.050 false) brow elbow dy=%.3f (want > 0: the right elbow rises to the brow) | right foot: R hip=%.3f knee=%.3f L hip=%.3f knee=%.3f pelvis=%.3f (want 0.000 0.000 0.120 0.350 0.420) | left foot: R knee=%.3f L knee=%.3f (want 0.350 0.000) | nod: torso x=%.3f neck x=%.3f done=%s (want −0.045 −0.030 false) | rise: R sh=%.3f (want −0.925) | done@3.2=%s (want true)" % [r_shx, r_shz, r_el, r_hip, r_knee, l_shx, l_shz, l_el, l_hip, l_knee, r_pel, r_tx, r_nkx, r_nky, r_ty, r_done, rhand_y, w_rhip, w_rknee, w_lhip, w_lknee, w_pel, x_rknee, x_lknee, n_tx, n_nkx, n_done, d_shx, e_done])
	# 진짜 탑: 1..70층에 plan 이 찾는 돌판 — 공중 정원 층 5..9, 40..44 중 통풍구·화분·튤립·덩굴·해먹·집라인(taken)이 비켜 가고 남는 발판이 있는 층만; 화살표는 위 통풍구 층의 계획
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []; var built := 0
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var taken: Array = cu.plan(n, pl) + cpl.plan(n, pl) + ctu.plan(n, pl) + cv.plan(n, pl) + chm.plan(n, pl, gm.wind_of(n)) + cz.plan(n, pl)
		var out2 := sd.plan(n, pl, taken)
		if out2.size() > 0:
			var vn := sd.vent_floor_above(n)
			bands.append("%d:%s→%d" % [n, out2.map(func(v: Dictionary) -> String: return "%s cx %.0f" % [String(v["hop_id"]), float(v["cx"])]), vn]); count += out2.size()
			var br := Node3D.new(); root.add_child(br); sd.build(br, out2, cu.plan(vn, gm.band(vn)), vn); built += (sd.dials[sd.dials.size() - 1]["arrows"] as Array).size()
	print("TOWER floors=", bands, " dials=", count, " arrows=", built, " (want a subset of 5..9 and 40..44 — one each, never another theme; each dial draws the vents of the first vent floor above: 7 for 5–6, 11 for 7–9, 43 for 40–42, 47 for 43–44)")
	quit()
