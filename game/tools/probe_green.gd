extends SceneTree
## 구름 그린 팩 점검(헤드리스): 자료가 읽히나, 구름바다 층의 잇단 still 발판 쌍 중 티 발판이 가장 넓고 티 → 홀이 v_max 의 0.5..0.92 인 쌍에만 그린이 서나(모래밭이 선 발판은 비켜 가고, 상자에 지름길 판이 든 쌍도 비켜 가고, 홀이 너무 먼 쌍은 아니고, 다른 테마 층은 아니다; 티는 깃발 쪽 가장자리 24 안, 홀은 먼 끝 30 안),
## 못 곁의 C 가 어드레스에 들고(busy, stroke_c, stroke_lead, 손의 채) 못에서 떠나면 풀리나, 0.53 s 모으면 0.757 이고 놓으면 스윙(stroke_t)이 되어 0.12 s 에 공이 930 px/s·60° 로 못을 떠나나(tock, me_t, shots), 공이 513 에 튀고 529 에서 굴러 551 에서 홀에 드나(cup, 오늘 1/1, 7.3 m), 스윙이 0.6 s 에 풀리나(메타·채가 사라진다), 2.5 s 뒤 공이 못으로 돌아오나,
## 다음 날 0.85 로 친 공이 561 에 튀어 그린을 넘어 구름에 잃히나(올렸다 1, 들어갔다 0 — plop), 톡 친 공(0)이 아래 발판 26.3 에 떨어져 439 에서 서나, 0.5 로 친 공이 틈에 빠지나, 바람 120 에 569 까지 밀려 넘어가나, 다른 몸(count 거짓)의 홀인은 세지 않나, 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 세나,
## 잔디·못·공·홀·깃대·깃·소리 셋이 그려지나, stroke 자세가 백스윙 꼭대기에서 두 팔을 트레일 쪽으로 감고 몸통을 틀고 공을 보나, 피니시에 리드 어깨 위로 팔을 올리고 가슴을 목표로 돌리고 고개를 드나, 풀리면 서나, 진짜 탑의 1..65층에서 plan 이 구름바다 층에만 그린을 찾나;
## 골퍼(run 173)가 못 뒤 40 에 카메라를 보고 서나, 차례에 못으로 걸어가 count 거짓으로 어드레스하고 차례의 충전(0.84 / 0.74 / 0.64)까지 모아 치나(me_t·오늘은 안 바뀐다), 스윙이 풀리면 track 으로 공을 쫓고(track_x·track_y) 끝에 젓거나 끄덕이고 손을 내려 집에 오나, 아홉 샷에 셋이 들어가나, 플레이어의 샷 1.5 s 뒤에 따라가 공이 돌아오면 치나, 플레이어가 먼저 어드레스하면 기다리나, track 자세가 이마의 손·공 쪽 고개·끄덕임·회수를 그리나
const C = preload("res://scripts/games/climb.gd")
const DT := 1.0 / 60.0

func _init() -> void:
	var cg := ClimbGreen.new(); root.add_child(cg)
	var lj := ClimbPit.new(); root.add_child(lj)
	var cr := ClimbRaft.new(); root.add_child(cr)
	var mu := ClimbMushroom.new(); root.add_child(mu)
	var cp := ClimbPlank.new(); root.add_child(cp)
	var ba := ClimbBalloon.new(); root.add_child(ba)
	var ln := ClimbLens.new(); root.add_child(ln)
	await process_frame
	print("PACK id=", cg.pack.get("id"), " kind=", cg.kind.size() > 0, " pose=", cg.pack.get("pose"), " themes=", cg.pack.get("themes"), " tee_in=%.0f min_w=%.0f reach=%.0f d=%.0f loft=%.0f v=%.0f..%.0f need=%.2f..%.2f charge=%.2f strike=%.2f swing=%.2f bounce=%.0f/%.2f/%.2f/%.2f friction=%.0f cup_v=%.0f hole=%.0f/%.0f lose=%.0f rest=%.1f day=%.0f flag=%.0f need_v(264,110)=%.1f (want 24 60 14 24 60 400..1100 0.50..0.92 0.70 0.12 0.60 220/0.25/0.70/0.60 160 260 30/10 160 2.5 600 40 981.6)" % [cg.tee_in(), cg.min_w(), cg.reach(), cg.green_d(), rad_to_deg(cg.loft()), cg.v_min(), cg.v_max(), cg.need_lo(), cg.need_hi(), cg.charge_s(), cg.strike_s(), cg.swing_s(), cg.bounce_v(), cg.bounce_k(), cg.hit_k(), cg.roll_k(), cg.friction(), cg.cup_v(), cg.hole_in(), cg.hole_r(), cg.lose_dy(), cg.rest_s(), cg.day_s(), cg.flag_h(), cg.need_v(264.0, 110.0)])
	var plats: Array = [
		{ "id": "26.0", "x": 60.0, "y": 15700.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "26.1", "x": 320.0, "y": 15810.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "26.2", "x": 100.0, "y": 15920.0, "w": 140.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "26.3", "x": 380.0, "y": 16030.0, "w": 130.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "26.4", "x": 150.0, "y": 16140.0, "w": 170.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "26.5", "x": 450.0, "y": 16250.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "26s", "x": 700.0, "y": 16190.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cg.plan(26, plats)
	var pit := { "id": "26.J0", "kind": "pit", "x": 170.0, "w": 130.0, "y": 16140.0, "y_top": 16143.0 }   # 모래밭이 26.4 를 가졌다 — 26.0 으로
	var pitted := cg.plan(26, plats, 0.0, [pit])
	var cut := plats.duplicate(true); cut.append({ "id": "26c", "x": 250.0, "y": 15760.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 })   # 26.0 → 26.1 의 상자에 지름길 판 — 26.1 로(왼쪽으로 친다)
	var cutp := cg.plan(26, cut, 0.0, [pit])
	var far := plats.duplicate(true); (far[5] as Dictionary)["x"] = 650.0   # 홀이 760 — 1220 px/s 가 든다, 넘는다 — 26.0 으로
	var farp := cg.plan(26, far)
	var f24 := cg.plan(24, plats); var f25 := cg.plan(25, plats); var f29 := cg.plan(29, plats); var f30 := cg.plan(30, plats); var f60 := cg.plan(60, plats)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " %s→%s w %.0f dir %.0f tee %.0f hole %.0f dx %.0f need %.1f x %.0f w %.0f y %.0f fy %.0f y_top %.0f z %.0f d %.0f" % [String(v["tee_id"]), String(v["flag_id"]), float(v["hop_w"]), float(v["dir"]), float(v["tee_x"]), float(v["hole_x"]), float(v["dx"]), float(v["need"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["fy"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	var brief := func(v: Dictionary) -> String: return "%s→%s tee %.0f hole %.0f need %.1f" % [String(v["tee_id"]), String(v["flag_id"]), float(v["tee_x"]), float(v["hole_x"]), float(v["need"])]
	print("PLAN free=", free.map(show), " (want 1: 26.G0 26.4→26.5 w 170 dir 1 tee 296 hole 560 dx 264 need 981.6 x 296 w 264 y 16140 fy 16250 y_top 16290 z −58 d 24)")
	print("PLAN pitted=", pitted.map(brief), " (want [26.0→26.1 tee 196 hole 440 need 956.1]) cut=", cutp.map(brief), " (want [26.1→26.2 tee 344 hole 130 need 918.4]) far=", farp.map(brief), " (want [26.0→26.1 …]) floors 24/25/29/30/60=", [f24.size(), f25.size(), f29.size(), f30.size(), f60.size()], " (want 0 1 1 0 1)")
	var band_root := Node3D.new(); root.add_child(band_root)
	cg.build(band_root, free)
	var s: Dictionary = cg.greens[0]
	var gf: ClimbGolfer = s["golfer"]; gf.phase = "gone"; gf.next_at = 1e9   # 골퍼는 뒤에(GOLFER) — 그때까지 층을 떠나 있다(플레이어의 샷을 따라가면 위 want 가 어긋난다)
	var fig := Stick3D.new(); root.add_child(fig)
	var on: Dictionary = plats[4]; var z := C.PLAYER_Z
	# 어드레스(t 10, 몸 300 — 못 296 곁): busy, stroke_c 0, stroke_lead 1, 채; 못에서 떠나면(200) 풀린다; 다시 들어 0.53 s 모으면 0.757; 놓으면 swing·stroke_t 0
	cg.sync(10.0)
	var a := cg.tee(300.0, z, on, true, fig); var a_meta := "%s/%.0f/%s" % [fig.has_meta("stroke_c"), float(fig.get_meta("stroke_lead", 9.0)), fig.hand_r.get_node_or_null("club") != null]; var a_sw := cg.swinging(fig)
	var gone := cg.tee(200.0, z, on, true, fig); var gone_sw := "%s %s %s %s" % [String(s["sw"]), cg.swinging(fig), fig.has_meta("stroke_c"), String(s["ball"])]
	var far_z := cg.tee(300.0, z + 40.0, on, true, fig); var other_hop := cg.tee(300.0, z, plats[3], true, fig)
	cg.sync(10.0); cg.tee(300.0, z, on, true, fig); cg.sync(10.53)
	var held := cg.tee(300.0, z, on, true, fig); var held_meta := float(fig.get_meta("stroke_c", 9.0))
	var rel := cg.tee(300.0, z, on, false, fig); var rel_state := "%s %s %.3f" % [String(s["sw"]), fig.has_meta("stroke_t"), float(fig.get_meta("stroke_t", 9.0))]
	print("TEE address: busy=%s k=%.2f id=%s meta c/lead/club=%s swinging=%s (want true 0.00 26.G0 true/1/true true) | away: busy=%s → %s (want false '' false false tee) | far z: %s other hop: %s (want false false) | held 0.53 s: busy=%s k=%.3f meta=%.3f (want true 0.757 0.757) | released: busy=%s k=%.3f %s (want true 0.757 swing true 0.000)" % [a["busy"], float(a["k"]), String(a["id"]), a_meta, a_sw, gone["busy"], gone_sw, far_z["busy"], other_hop["busy"], held["busy"], float(held["k"]), held_meta, rel["busy"], float(rel["k"]), rel_state])
	# 스윙·비행(60 Hz 로 손수): 8틱(0.133 s)에 공이 떠난다 — 930 px/s, vx 465, vy 805.4(− 그 틱의 G·dt 40 = 765.4), tock, me_t, shots 1; 513 에 튀고(vy −314.6 → 78.6, vx 325.5) 529 에서 구르고(vx 195.3) 551 에서 홀에 든다(vx 179.3, 0.633 s) — cup, 오늘 1/1 들어갔다 1, 7.3 m; 몸은 0.6 s 에 풀린다(meta·채 없음)
	var tock: AudioStreamPlayer3D = s["tock"]; var cup: AudioStreamPlayer3D = s["cup"]; var plop: AudioStreamPlayer3D = s["plop"]
	for i in 7: cg._process(DT)
	var before := "%s struck=%s" % [String(s["ball"]), s["struck"]]
	cg._process(DT)
	var strike := "%s struck=%s v=%.1f vx=%.1f vy=%.1f tock=%s me_t=%.3f shots=%d" % [String(s["ball"]), s["struck"], Vector2(float(s["vx"]), float(s["vy"]) + C.G * DT).length(), float(s["vx"]), float(s["vy"]), tock.playing, float(s["me_t"]), int(s["shots"])]
	var trail := _flight(cg, s, 400)
	var today := cg.holed_today(26, 26)
	print("SWING before strike: ", before, " (want tee struck=false) | strike: ", strike, " (want fly struck=true 930.0 465.0 765.4 true 10.663 1: me_t is the strike tick) | flight: ", trail, " (want [bounce@513.0, free@0.600, roll@529.3, holed@560.0]: the body relaxes 0.6 s after the release while the ball still rolls; a holed ball snaps to the cup at 560 — it rolled in at 551) cup=%s today hit/holed/total/longest=%d/%d/%d/%.0f (want true 1/1/1/264)" % [cup.playing, int(today["hit"]), int(today["holed"]), int(today["total"]), float(today["longest"])])
	var club_n: Node = fig.hand_r.get_node_or_null("club")
	var done_sw := "sw='%s' meta=%s/%s/%s club_gone=%s swinging=%s" % [String(s["sw"]), fig.has_meta("stroke_c"), fig.has_meta("stroke_t"), fig.has_meta("stroke_lead"), club_n == null or club_n.is_queued_for_deletion(), cg.swinging(fig)]
	print("SWING ends: ", done_sw, " (want '' false/false/false true false)")
	print("NOTE 25=\"%s\" (want Cloud green, floors 25–29: 1 of 1 green hit today, 1 holed, the longest 7.3 m.) 30=\"%s\" (want the same: nothing on 30..34, so the floors below) 35=\"%s\" (want empty)" % [cg.note(25), cg.note(30), cg.note(35)])
	# 못으로(들어간 뒤 2.5 s): rest_s 전엔 홀에, 지나면 못 위 296/16142
	var in_cup := "%s bx=%.1f" % [String(s["ball"]), float(s["bx"])]
	cg.sync(float(s["rest_t0"]) + 2.49); cg._process(DT); var back := "%s bx=%.0f by=%.0f" % [String(s["ball"]), float(s["bx"]), float(s["by"])]
	print("RETEE in cup: ", in_cup, " (want holed 560.0) | 2.5 s later: ", back, " (want tee 296 16142)")
	# 다음 날(620): 0.85 → 561 에 튀어 넘어가 구름에 잃는다(plop) — 올렸다 1, 들어갔다 0; 톡(0) → 아래 발판 26.3 에 떨어져 393 에 튀고 416 에서 굴러 439 에 선다(rest); 0.5 → 틈(lost); 바람 120 에 0.757 → 569 에 튀어 넘어간다
	var over := _shoot(cg, s, fig, on, 620.0, 0.85); var over_plop := plop.playing; var d2 := cg.holed_today(26, 26)
	var tap := _shoot(cg, s, fig, on, 630.0, 0.0)
	var short := _shoot(cg, s, fig, on, 640.0, 0.5)
	s["wind"] = 120.0; var windy := _shoot(cg, s, fig, on, 650.0, 0.757142857); s["wind"] = 0.0
	print("DAY 2 over: ", over, " (want [fly@304.3, free@0.600 or 0.617 — one tick of float rounding, bounce@561.3, lost@741.3]) plop=%s hit/holed=%d/%d (want true 1/0) note=\"%s\" (want … 1 of 1 green hit today.) | tap: %s (want [fly@299.3, bounce@392.7, free@0.6, roll@416.0, rest@438.7] on 26.3 — the hop below) | short: %s (want [fly@302.3, free@0.6, lost@564.8]) | wind 120: %s (want [fly@305.7, bounce@569.0, free@0.6, lost@791.7])" % [over_plop, int(d2["hit"]), int(d2["holed"]), cg.note(25), tap, short, windy])
	# 다른 몸(count 거짓, 셋째 날 1230): 홀에 들어도 오늘은 0/0; 그 몸이 모으는 동안 플레이어의 C 는 기다린다(busy 거짓)
	var fig2 := Stick3D.new(); root.add_child(fig2)
	cg.sync(1230.0); cg._process(0.0); cg.tee(300.0, z, on, true, fig2, false)
	var wait_me := cg.tee(300.0, z, on, true, fig)
	cg.sync(1230.53); cg.tee(300.0, z, on, true, fig2, false); cg.tee(300.0, z, on, false, fig2, false)
	var other := _flight(cg, s, 400); var d3 := cg.holed_today(26, 26)
	print("OTHER body: waits=%s (want false) flight=%s (want [fly@303.7, bounce@513.0, free@0.6, roll@529.3, holed@560.0]) hit/holed today=%d/%d (want 0/0: a resident's ball is never counted)" % [wait_me["busy"], other, int(d3["hit"]), int(d3["holed"])])
	while String(s["sw"]) != "": cg._process(DT)
	# 그림: 노드 아이 10(잔디·못·공·홀·깃대·깃·소리 셋·골퍼), 공 아이 1, 깃 아이 1; 노드 자리 (296 − 480)/36 = −5.1111, 16140/36 = 448.3333, −70/36 = −1.9444; 깃은 바람 없이도 흔들린다
	var node: Node3D = s["node"]; var pen: Node3D = s["pen"]
	cg.sync(2000.0); cg._place(s); var r1 := pen.rotation.y; cg.sync(2000.1); cg._place(s); var r2 := pen.rotation.y
	print("VISUAL children=%d (want 10: 9 + the golfer) ball=%d pen=%d (want 1 1) node pos=%.4f %.4f %.4f (want −5.1111 448.3333 −1.9444) pennant moves=%s (want true) |rot| ≤ 0.14=%s (want true: still air is 4/10 of 0.35)" % [node.get_child_count(), (s["ball_node"] as Node3D).get_child_count(), pen.get_child_count(), node.position.x, node.position.y, node.position.z, absf(r1 - r2) > 0.001, maxf(absf(r1), absf(r2)) <= 0.1401])
	# 자세(백스윙 꼭대기, stroke_c 1, lead 1): 리드(오른, s 1) 어깨 z −2.28, 트레일(왼) 어깨 z −2.12, 어깨 x −0.275, 트레일 팔꿈치 −1.05, 리드 팔꿈치 −0.40, 엉덩이 −0.30, 무릎 0.35, 몸통 y −0.90, 골반 0.37, 상체 0.45 × 0.32 = 0.144, 고개 > 0(공을 본다);
	# 피니시(stroke_t 0.37): 리드 어깨 z 2.32, 트레일 2.48, 어깨 x −0.22 ± 0.04, 트레일 팔꿈치 −0.50, 트레일 엉덩이 z −0.18, 트레일 무릎 0.725, 리드 무릎 0.175, 몸통 y 0.80, 골반 0.405, 상체 −0.0675, 고개 < 0(든다), 고개 y 0.5; 풀림(0.6): 어깨 z 0, 몸통 y 0, 골반 0.42
	fig.pose_request = "stroke"; fig.set_meta("stroke_c", 1.0); fig.set_meta("stroke_lead", 1.0)
	while fig.pose_t < 0.3: await process_frame
	var b_shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var b_shz2: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var b_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var b_el2: float = (fig.elbows[-1.0] as Node3D).rotation.x; var b_el: float = (fig.elbows[1.0] as Node3D).rotation.x
	var b_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var b_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var b_ty := fig.torso.rotation.y; var b_pel := fig.pelvis.position.y; var b_tx := fig.torso.rotation.x; var b_neck := fig.neck.rotation.x
	fig.remove_meta("stroke_c"); fig.set_meta("stroke_t", 0.37)
	for i in 45: await process_frame   # 관절은 섞여 따라온다(Stick3D 의 블렌딩) — 자리를 잡을 때까지
	var f_shz := wrapf((fig.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var f_shz2 := wrapf((fig.shoulders[-1.0] as Node3D).rotation.z, -PI, PI); var f_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var f_el2: float = (fig.elbows[-1.0] as Node3D).rotation.x   # 어깨 z 는 기저에서 되읽혀 2π 돌아 나온다(2.32 가 −3.96 으로) — 같은 각
	var f_hipz2: float = (fig.hips[-1.0] as Node3D).rotation.z; var f_knee2: float = (fig.knees[-1.0] as Node3D).rotation.x; var f_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var f_ty := fig.torso.rotation.y; var f_pel := fig.pelvis.position.y; var f_tx := fig.torso.rotation.x; var f_neck := fig.neck.rotation.x; var f_ny := fig.neck.rotation.y
	fig.set_meta("stroke_t", 0.6)
	for i in 45: await process_frame
	var r_shz := wrapf((fig.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var r_ty := fig.torso.rotation.y; var r_pel := fig.pelvis.position.y
	var d_meta := StrokePoses.done(fig)
	fig.remove_meta("stroke_t"); fig.remove_meta("stroke_lead")
	print("POSE top: lead z=%.2f trail z=%.2f arm x=%.3f trail elbow=%.2f lead elbow=%.2f hip=%.2f knee=%.2f torso y=%.2f pelvis=%.2f torso x=%.3f neck=%.2f (want −2.28 −2.12 −0.275 −1.05 −0.40 −0.30 0.35 −0.90 0.37 0.144 > 0) | finish: lead z=%.2f trail z=%.2f arm x=%.2f trail elbow=%.2f trail hip z=%.2f trail knee=%.3f lead knee=%.3f torso y=%.2f pelvis=%.3f torso x=%.4f neck=%.2f neck y=%.2f (want 2.32 2.48 −0.22±0.04 −0.50 −0.18 0.725 0.175 0.80 0.405 −0.0675 < 0 0.50) | relaxed: z=%.2f torso y=%.2f pelvis=%.2f done(meta)=%s (want 0.00 (±0.01 — 2π wrapped) 0.00 0.42 false)" % [b_shz, b_shz2, b_shx, b_el2, b_el, b_hip, b_knee, b_ty, b_pel, b_tx, b_neck, f_shz, f_shz2, f_shx, f_el2, f_hipz2, f_knee2, f_knee, f_ty, f_pel, f_tx, f_neck, f_ny, r_shz, r_ty, r_pel, d_meta])
	fig.pose_request = ""
	await _golfer(cg, s, gf, fig, on, z)
	# 진짜 탑: 1..65층에 plan 이 찾는 그린 — 구름바다 층 25..29, 60..64 중 모래밭·널이 티·홀 자리를 안 쓴 쌍이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var bands: Array = []
	for n in range(1, 66):
		var pl: Array = gm.band(n); var wind: float = gm.wind_of(n)
		var tk: Array = cr.plan(n, pl) + mu.plan(n, pl); var pp: Array = cp.plan(n, pl, tk); var bp: Array = ba.plan(n, pl, tk + pp); var lp: Array = ln.plan(n, pl, tk + pp + bp)
		var out2 := cg.plan(n, pl, wind, tk + pp + bp + lp + lj.plan(n, pl, tk + pp + bp + lp))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s w %.0f dx %.0f need %.0f" % [String(v["tee_id"]), String(v["flag_id"]), float(v["hop_w"]), float(v["dx"]), float(v["need"])])])
	print("TOWER floors=", bands, " (want a subset of 25..29, 60..64 — one green each on a pair whose tee turf and hole the pit and the plank did not take, need 550..1012, never another theme)")
	quit()

## 공이 서거나 들거나 잃을 때까지 _process 를 돌린다(cap 틱까지) — 튐·구름·끝을 x 와 함께 적는다
func _flight(cg: ClimbGreen, s: Dictionary, cap: int) -> Array:
	var out: Array = []; var n := 0; var was := String(s["ball"]); var vy0 := float(s["vy"]); var sw_was := String(s["sw"])
	while n < cap:
		cg._process(DT); n += 1
		var b := String(s["ball"]); var vy := float(s["vy"])
		if sw_was != "" and String(s["sw"]) == "": out.append("free@%.3f" % (cg.t - float(s["sw_t0"])))   # 몸이 풀린 때 — 놓은 뒤
		sw_was = String(s["sw"])
		if b == "fly" and was == "fly" and vy0 < 0.0 and vy > 0.0: out.append("bounce@%.1f" % float(s["bx"]))
		if b != was: out.append("%s@%.1f" % [b, float(s["bx"])])
		was = b; vy0 = vy
		if b in ["holed", "lost", "rest"]: break
	return out

## 한 샷: at 에 어드레스, c × charge_s 모으고 놓고, 공의 길을 돌려준다(끝까지)
func _shoot(cg: ClimbGreen, s: Dictionary, fig: Stick3D, on: Dictionary, at: float, c: float) -> Array:
	cg.sync(at); cg._process(0.0)   # 못으로 돌아온 공(rest_s 가 지났다)
	cg.tee(300.0, C.PLAYER_Z, on, true, fig)
	cg.sync(at + c * cg.charge_s()); cg.tee(300.0, C.PLAYER_Z, on, true, fig); cg.tee(300.0, C.PLAYER_Z, on, false, fig)
	var out := _flight(cg, s, 400)
	while String(s["sw"]) != "": cg._process(DT)
	return out

## 골퍼(run 173): 집·차례·어드레스·충전·track·끝·귀가, 아홉 샷의 셋, 플레이어를 따라가기, 플레이어가 먼저
func _golfer(cg: ClimbGreen, s: Dictionary, gf: ClimbGolfer, fig: Stick3D, on: Dictionary, z: float) -> void:
	# 집 256(못 296 − 40)·z −48·카메라; 차례가 오면 못으로 걸어가(40 px / 260 = 0.154 s) 어드레스(stroke, 채, count 거짓) — 첫 샷 차례 (26 + 0) % 3 = 2 → 가운데 0.740(need_v(214, 110) = 918.3 → (918.3 − 400) / 700) + 0.10 = 0.840(놓은 c 는 틱 때문에 ≤ +0.024)
	cg.sync(3000.0); cg._process(0.0); gf._home(); var me0 := float(s["me_t"])
	var g0 := "%s x=%.0f home=%.0f z=%.0f visible=%s pose='%s' next=%.1f" % [gf.phase, gf.x, gf.home_x, gf.z, gf.fig.visible, gf.fig.pose_request, gf.next_at - cg.t]
	_until(cg, gf, "address", 60)
	var addr := "%s x=%.0f sw=%s mine=%s pose=%s club=%s count=%s target=%.3f at=%.2f s" % [gf.phase, gf.x, String(s["sw"]), (s["sw_fig"] as Stick3D) == gf.fig, gf.fig.pose_request, gf.fig.hand_r.get_node_or_null("club") != null, s["count"], gf.c_target, cg.t - 3000.0]
	_until(cg, gf, "track", 120)
	var struck := "%s c=%.3f ball=%s me_t same=%s shots=%d pose=%s lead=%.0f at=%.2f s" % [gf.phase, float(gf.charges[0]), String(s["ball"]), float(s["me_t"]) == me0, int(s["shots"]), gf.fig.pose_request, float(gf.fig.get_meta("track_lead", 9.0)), cg.t - 3000.0]
	for i in 20: cg._process(DT)
	var mid := "x=%.1f y=%.1f end='%s'" % [float(gf.fig.get_meta("track_x", 0.0)), float(gf.fig.get_meta("track_y", 0.0)), String(gf.fig.get_meta("track_end", "?"))]
	_until(cg, gf, "back", 300)
	var ended := "%s ends=%s pose='%s' metas=%s at=%.2f s" % [gf.phase, gf.ends, gf.fig.pose_request, gf.fig.has_meta("track_x") or gf.fig.has_meta("track_end"), cg.t - 3000.0]
	_until(cg, gf, "idle", 60)
	var today := cg.holed_today(26, 26)
	var homed := "%s x=%.0f next=%.1f hit/holed=%d/%d" % [gf.phase, gf.x, gf.next_at - cg.t, int(today["hit"]), int(today["holed"])]
	print("GOLFER start: ", g0, " (want idle 256 256 −48 true '' 0.0) | address: ", addr, " (want address 296 charge true stroke true false 0.840 0.20: 40 px at WALK) | struck: ", struck, " (want track 0.857 fly true 7 track 1 1.40: the tick after 0.840, me_t untouched) | 0.33 s on: ", mid, " (want ≈368 ≈50 '': the over shot is past the hole and coming down) | ended: ", ended, " (want back [lost] '' false 3.48: the ball ran off the green into the cloud at ≈1.98, a slow shake 1.2 s and the hand down 0.3 s) | home: ", homed, " (want idle 256 60.0 0/0: the golfer's shots never count) trail=", gf.trail)
	# 아홉 샷: 차례 2·0·1 이 돈다 — 넘김(lost)·홀인(cup)·틈(lost); 충전 0.84 / 0.74 / 0.64(≤ +0.024); 매 샷 뒤 집에서 바로 다음 차례(공은 2.5 s 뒤 못에 — 못에서 기다린다)
	for i in 8:
		gf.next_at = cg.t
		_until(cg, gf, "track", 400); _until(cg, gf, "idle", 400)
	var d9 := cg.holed_today(26, 26)
	print("GOLFER nine shots: ends=", gf.ends, " (want [lost, cup, lost, lost, cup, lost, lost, cup, lost]: over, holed, short) charges=", gf.charges.map(func(v: float) -> String: return "%.3f" % v), " (want 0.857 / 0.762 / 0.643 — the tick after 0.840 / 0.740 / 0.640) hit/holed today=%d/%d (want 0/0)" % [int(d9["hit"]), int(d9["holed"])])
	# 플레이어가 치면(me_t) 1.5 s 뒤 못으로: 1.4 s 엔 집, 1.6 s 엔 걷거나 못에서 기다린다; 공이 못에 돌아오면(2.5 s) 어드레스
	gf._home(); gf.next_at = cg.t + 60.0
	s["me_t"] = cg.t; s["ball"] = "lost"; s["rest_t0"] = cg.t
	for i in 84: cg._process(DT)
	var early := gf.phase
	for i in 12: cg._process(DT)
	var late := "%s x=%.0f" % [gf.phase, gf.x]
	_until(cg, gf, "address", 200)
	var when := cg.t - float(s["me_t"])
	_until(cg, gf, "idle", 600)
	print("GOLFER follows you: 1.4 s after your strike=%s (want idle) 1.6 s=%s (want walk or wait, x 282..296) addresses at %.2f s (want 2.50..2.53: the ball is back on the peg at 2.5)" % [early, late, when])
	# 플레이어가 먼저(공이 못에 돌아온 뒤 — 3 s 건너뛴다): 플레이어가 모으는 동안 차례가 와도 집(idle); 플레이어가 놓고(0.5 s = 0.714 — 들어간다) 공이 못에 돌아오면 그제야 어드레스(놓은 뒤 ≈3.15 s)
	cg.sync(cg.t + 3.0); cg._process(0.0); gf.next_at = cg.t
	cg.tee(300.0, z, on, true, fig)
	for i in 30: cg._process(DT)
	var waits := "%s sw=%s" % [gf.phase, String(s["sw"])]
	cg.tee(300.0, z, on, false, fig); var rel_t := cg.t
	_until(cg, gf, "address", 400)
	var after := "%s at=%.2f s ball_was=%s" % [gf.phase, cg.t - rel_t, s["ball"]]
	_until(cg, gf, "idle", 600)
	print("GOLFER the player first: while you charge=%s (want idle charge) | after your release: %s (want address 3.37 tee: your 0.714 ball landed at 493, rolled in at ≈0.87, re-teed 2.5 s later, the golfer waited at the peg)" % [waits, after])
	# track 자세(메타: 공이 오른쪽 200·위 100, 리드 1, 손이 다 올랐을 때): 오른(이마) 어깨 x −2.00 ± 0.03 z −0.35 팔꿈치 −1.75 ± 0.03, 왼 어깨 x −0.15 팔꿈치 −0.45, 고개 y atan(200/160) = 0.896, 고개 x −0.559(들었다) + 목의 쉼 기울기 = −0.424, 몸통 y 0.269; 컵 끝 0.2 s: 고개 x −0.424 + 0.22 = −0.204(끄덕임의 꼭대기); 끝 1.1 s(NOD_T + DOWN_T): 손 내려 어깨 x −0.05, 고개 y 0, 몸통 y 0
	var f3 := Stick3D.new(); root.add_child(f3)
	f3.set_meta("track_x", 200.0); f3.set_meta("track_y", 100.0); f3.set_meta("track_lead", 1.0); f3.pose_request = "track"
	for i in 60: await process_frame
	var t_sh: float = (f3.shoulders[1.0] as Node3D).rotation.x; var t_shz: float = (f3.shoulders[1.0] as Node3D).rotation.z; var t_el: float = (f3.elbows[1.0] as Node3D).rotation.x
	var t_sh2: float = (f3.shoulders[-1.0] as Node3D).rotation.x; var t_el2: float = (f3.elbows[-1.0] as Node3D).rotation.x
	var t_ny := f3.neck.rotation.y; var t_nx := f3.neck.rotation.x; var t_ty := f3.torso.rotation.y
	f3.set_meta("track_end", "cup"); f3.set_meta("track_end_t", 0.2)
	for i in 45: await process_frame
	var n_nx := f3.neck.rotation.x
	f3.set_meta("track_end_t", 1.1)
	for i in 45: await process_frame
	var d_sh: float = (f3.shoulders[1.0] as Node3D).rotation.x; var d_ny := f3.neck.rotation.y; var d_ty := f3.torso.rotation.y
	var d_meta := TrackPoses.done(f3)
	for key: String in ["track_x", "track_y", "track_lead", "track_end", "track_end_t"]: f3.remove_meta(key)
	f3.pose_request = ""
	print("TRACK pose: brow arm x=%.2f z=%.2f elbow=%.2f other arm x=%.2f elbow=%.2f neck y=%.3f neck x=%.3f torso y=%.3f (want −2.00±0.03 −0.35 −1.75±0.03 −0.15 −0.45 0.895 −0.424 0.269: −0.559 of pitch over the neck's rest tilt) | nod top: neck x=%.3f (want −0.204: +0.22 at the top of the first nod) | down: arm x=%.2f neck y=%.3f torso y=%.3f done(meta)=%s (want −0.05 0.000 0.000 false)" % [t_sh, t_shz, t_el, t_sh2, t_el2, t_ny, t_nx, t_ty, n_nx, d_sh, d_ny, d_ty, d_meta])

## 골퍼의 phase 가 p 가 될 때까지 그린의 _process 를 돌린다(cap_ticks × 5 틱까지 — 안 오면 그냥 돌아온다, 출력의 want 가 어긋난다)
func _until(cg: ClimbGreen, gf: ClimbGolfer, p: String, cap_ticks: int) -> void:
	var n := 0
	while gf.phase != p and n < cap_ticks * 5:
		cg._process(DT); n += 1
