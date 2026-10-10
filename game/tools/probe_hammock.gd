extends SceneTree
## 해먹 그물 팩 점검(헤드리스): 자료가 읽히나, 공중 정원 층의 잇단 두 still 발판 사이 틈(70..200, 높이차 130 안) 중 그물 상자를 다른 판이 가르지 않고 taken 조각(다리·유령 판·버섯)이 닿지 않는 가장 넓은 하나에만 그물이 걸리나(깊은 처짐이 닿을 판이 밑에 깔린 틈은 진다, 좁은 틈·움직이는 발판 옆 틈은 아니다, 통풍구 층·다른 테마 층은 아니다),
## 틈 안에서 쉼선을 지나 빠르게 떨어지는 몸만 catch 가 받나(느린 낙하·오르는 몸·틈 가장자리·선 아래·앞뒤 밖·이미 누운 그물은 아니다), 받히면 0.4초에 걸쳐 떨어진 속도만큼 처지며 가운데로 굴러가고 3초에 걸쳐 쉼 처짐으로 돌아오나(메타도),
## SPACE 가 지금 처짐 × 4 의 높이로 던져 올리나(깊은 처짐 직후 733, 쉼 처짐 620, 가장 깊은 56 에 1037, 받힌 지 0.1초엔 410), ↓ 가 0 으로 놓나, 놓은 뒤 0.4초는 안 받나, 빈 그물이 바람만큼 흔들리나, 말뚝·끌줄·그물(세로 줄 5·가로 살 7·베개)·creak·snap 이 그려지나,
## loll 자세가 충격엔 팔다리를 벌리고 자리를 잡으면 깊이 누워 오른팔은 머리 뒤·왼팔은 가장자리 너머·다리는 뻗나, 진짜 탑의 1..46층에서 plan 이 공중 정원 층에만(통풍구 층 빼고, 다른 팩의 틈을 비켜) 그물을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var ch := ClimbHammock.new(); root.add_child(ch)
	var cb := ClimbBridge.new(); root.add_child(cb)
	var cg := ClimbGhost.new(); root.add_child(cg)
	var cm := ClimbMushroom.new(); root.add_child(cm)
	await process_frame
	print("PACK id=", ch.pack.get("id"), " kind=", ch.kind.size() > 0, " pose=", ch.pack.get("pose"), " themes=", ch.pack.get("themes"), " hang=%.0f (want 16) dip=%.0f (want 10) sag_s=%.2f (want 0.40) rest_s=%.1f (want 3.0) sag(−400)=%.0f (want 28) sag(−900)=%.0f (want 56) sag(−100)=%.0f (want 16) throw(28)=%.2f (want 733.21)" % [ch.hang(), ch.dip(), ch.sag_s(), ch.rest_s(), ch.sag_of(-400.0), ch.sag_of(-900.0), ch.sag_of(-100.0), ch.throw_v(28.0)])
	var plats: Array = [
		{ "id": "5r", "x": 250.0, "y": 2900.0, "w": 400.0, "kind": "rest", "z": 0.0, "d": 180.0 },
		{ "id": "5.0", "x": 100.0, "y": 3100.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "5.1", "x": 380.0, "y": 3210.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "5.2", "x": 620.0, "y": 3320.0, "w": 200.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "5.3", "x": 400.0, "y": 3430.0, "w": 160.0, "kind": "ice", "z": -35.0, "d": 70.0 },
		{ "id": "5.4", "x": 200.0, "y": 3540.0, "w": 170.0, "kind": "move", "z": -35.0, "d": 70.0 },
		{ "id": "5.5", "x": 25.0, "y": 3650.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "5s", "x": 680.0, "y": 3468.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var free := ch.plan(5, plats)
	var bridged := ch.plan(5, plats, 0.0, [{ "id": "5.b0", "kind": "bridge", "x": 280.0, "w": 100.0, "y0": 3100.0, "y1": 3210.0, "y": 3155.0 }])
	var shroomed := ch.plan(5, plats, 0.0, [{ "id": "5.m0", "x": 330.0, "y": 3040.0, "z": -48.0 }])
	var six := ch.plan(6, plats, 90.0); var vent := ch.plan(7, plats); var other := ch.plan(1, plats); var eight := ch.plan(8, plats)
	var low := plats.duplicate(true); (low[0] as Dictionary)["y"] = 3020.0   # 쉼터 판이 첫 틈 밑 80 에 깔리면 그 틈은 진다(가장 깊은 처짐 3018 이 판 3020 을 뚫는다)
	var rested := ch.plan(5, low)
	var band_root := Node3D.new(); root.add_child(band_root)
	ch.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " %s-%s gap %.0f x0 %.0f x1 %.0f mid %.0f line %.0f anchor %.0f wind %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"]), float(v["x0"]), float(v["x1"]), float(v["mid"]), float(v["line"]), float(v["anchor"]), float(v["wind"])]
	print("PLAN free=", free.map(show), " (want 1: 5.H0 5.0-5.1 gap 100 x0 280 x1 380 mid 330 line 3074 anchor 3084 — 5.1-5.2 is 90, 5.2-5.3 is 60 → out, 5.4 moves → out)")
	print("PLAN bridged=", bridged.map(show), " (want 5.H0 5.1-5.2 gap 90 x0 530 x1 620 mid 575 line 3184: the bridge takes the first gap) shroomed=", shroomed.map(show), " (want the same: the mushroom roots under it) rested=", rested.map(show), " (want 5.1-5.2: the rest slab at 3020 is under the first gap's deepest sag) six=", six.map(show), " (want 6.H0 the same shape, wind 90) vent=", vent.size(), " other=", other.size(), " (want 0 0) eight=", eight.size(), " (want 1)")
	var s: Dictionary = ch.nets[0]
	var z := C.PLAYER_Z
	# 받기(t 1): 틈 안(x 320)에서 3080 → 3065 로 −400 에 떨어지는 몸 → 받는다(sag 28); −100 느린 낙하·+400 오르는 몸·x 285 가장자리(290 안)·3060 → 3050 선 아래·z 0 앞은 아니다; 이미 누운 그물은 다시 안 받는다
	ch.sync(1.0)
	var c_slow := ch.catch(320.0, 3080.0, 3065.0, z, -100.0); var c_up := ch.catch(320.0, 3065.0, 3080.0, z, 400.0); var c_edge := ch.catch(285.0, 3080.0, 3065.0, z, -400.0); var c_below := ch.catch(320.0, 3060.0, 3050.0, z, -400.0); var c_front := ch.catch(320.0, 3080.0, 3065.0, 0.0, -400.0)
	var c_ok := ch.catch(320.0, 3080.0, 3065.0, z, -400.0)
	var creak: AudioStreamPlayer3D = s["creak"]; var creak_on := creak.playing
	var c_twice := ch.catch(340.0, 3080.0, 3065.0, z, -400.0)
	print("CATCH slow=%s up=%s edge=%s below=%s front=%s (want true ×5: empty) | ok kind=%s x=%.0f y=%.0f sag=%.0f rider=%s creak=%s (want hammock 320 3074 28 true true) twice=%s (want true: empty)" % [c_slow.is_empty(), c_up.is_empty(), c_edge.is_empty(), c_below.is_empty(), c_front.is_empty(), c_ok.get("kind", "-"), float(c_ok.get("x", 0.0)), float(c_ok.get("y", 0.0)), float(s["sag"]), bool(s["rider"]), creak_on, c_twice.is_empty()])
	# 누운 길: 1.1 → 처짐 4.375 (y 3069.63) 가운데로 1.56 (x 321.56), loll_c 0.16; 1.4 → 28 (3046, 330); 2.4 → 25.33 (3048.67); 4.4 → 20 (3054) 쉼
	var fig := Stick3D.new(); root.add_child(fig)
	ch.sync(1.1); var r1 := ch.cling(c_ok, fig); var m_c := float(fig.get_meta("loll_c", 9.0)); var m_d := float(fig.get_meta("loll_d", 9.0))
	ch.sync(1.4); var r2 := ch.cling(c_ok, fig); var m_d2 := float(fig.get_meta("loll_d", 9.0))
	ch.sync(2.4); var r3 := ch.cling(c_ok, fig)
	ch.sync(4.4); var r4 := ch.cling(c_ok, fig)
	print("CLING 1.1: x=%.2f y=%.2f c=%.3f d=%.3f (want 321.56 3069.63 0.156 0.078) | 1.4: x=%.0f y=%.0f d=%.2f (want 330 3046 0.50) | 2.4: y=%.2f (want 3048.67) | 4.4: y=%.0f lost=%s (want 3054 false)" % [float(r1["x"]), float(r1["y"]), m_c, m_d, float(r2["x"]), float(r2["y"]), m_d2, float(r3["y"]), float(r4["y"]), r4["lost"]])
	# 던지기: 4.4 쉼 처짐 20 → 619.68; 4.6 은 grace 안이라 안 받고 5.0 은 받는다; 5.4 깊은 처짐 28 직후 → 733.21 (snap); 7.0 에 −900 → 56, 7.4 → 1036.92; 9.0 받고 9.2 ↓ → 0 0, 그 뒤 cling 은 lost; 11.0 에 −900, 11.1 (처짐 8.75) → 409.88
	var lg_rest := ch.let_go(c_ok, true); var rider_after := bool(s["rider"]); var held := float(s["held"])
	ch.sync(4.6); var c_grace := ch.catch(320.0, 3080.0, 3065.0, z, -400.0)
	ch.sync(5.0); var c_again := ch.catch(320.0, 3080.0, 3065.0, z, -400.0)
	ch.sync(5.4); ch.cling(c_again, fig); var lg_deep := ch.let_go(c_again, true); var snap: AudioStreamPlayer3D = s["snap"]; var snap_on := snap.playing
	ch.sync(7.0); var c_fast := ch.catch(320.0, 3080.0, 3065.0, z, -900.0); ch.sync(7.4); var lg_max := ch.let_go(c_fast, true)
	ch.sync(9.0); var c_drop := ch.catch(320.0, 3080.0, 3065.0, z, -400.0); ch.sync(9.2); var lg_drop := ch.let_go(c_drop, false); var lost := ch.cling(c_drop, fig)
	ch.sync(11.0); var c_early := ch.catch(320.0, 3080.0, 3065.0, z, -900.0); ch.sync(11.1); var lg_early := ch.let_go(c_early, true)
	print("LETGO rest: vy=%.2f vx=%.0f rider=%s held=%.1f (want 619.68 0 false 4.4) | grace=%s (want true: empty) again=%s (want false) | deep: vy=%.2f snap=%s (want 733.21 true) | max: sag=%.0f vy=%.2f (want 56 1036.92) | drop: vy=%.0f vx=%.0f lost=%s (want 0 0 true) | early: vy=%.2f (want 409.88)" % [float(lg_rest["vy"]), float(lg_rest["vx"]), rider_after, held, c_grace.is_empty(), c_again.is_empty(), float(lg_deep["vy"]), snap_on, float(c_fast.get("sag", 0.0)), float(lg_max["vy"]), float(lg_drop["vy"]), float(lg_drop["vx"]), lost["lost"], float(lg_early["vy"])])
	# 그림: 노드 아이 9(말뚝·윗줄·면줄 × 2, 그물, creak, snap), 그물 아이 13(세로 5·가로 7·베개); 노드 자리 −4.167 85.667 −1.333; 빈 그물은 바람 0 에 |0.04| 안, 바람 90 이면 |0.10| 안에서 흔들린다; 받히면 처진 만큼 내려간다
	var node: Node3D = s["node"]; var net: Node3D = s["net"]
	ch.sync(20.0); ch._process(0.0); var rot_still := net.rotation.x; var y_empty := net.position.y
	s["wind"] = 90.0; var sw_max := 0.0
	for i in 40: ch.sync(20.0 + float(i) * 0.1); sw_max = maxf(sw_max, absf(ch.sway(s)))
	s["wind"] = 0.0
	ch.sync(30.0); var c_vis := ch.catch(320.0, 3080.0, 3065.0, z, -400.0); ch.sync(30.4); ch._process(0.0); var y_loaded := net.position.y; ch.let_go(c_vis, false)
	print("VISUAL node children=", node.get_child_count(), " (want 9) net children=", net.get_child_count(), " (want 13) node pos=%.3f %.3f %.3f (want −4.167 85.667 −1.333) | empty: y=%.3f (want −0.278: dip 10) rot=%.3f (want |·| ≤ 0.04) | wind 90: max sway=%.3f (want ≤ 0.10, > 0.04) | loaded 0.4 s: y=%.3f (want −1.056: dip 10 + sag 28)" % [node.position.x, node.position.y, node.position.z, y_empty, rot_still, sw_max, y_loaded])
	# 자세: 충격(c 0): 엉덩이 −1.1/−0.9, 무릎 1.3, 어깨 z 벌림 |0.9|; 자리(c 1, d 0.5): 골반 −1.35 높이 0.11, 오른어깨 −2.70 오른팔꿈치 −2.30, 왼어깨 z +1.10 왼팔꿈치 −0.30, 엉덩이 오른 −0.475 ± 0.05 왼 −0.375, 무릎 0.40 0.25, 고개 < 0
	fig.pose_request = "loll"
	fig.set_meta("loll_c", 0.0); fig.set_meta("loll_d", 0.5); fig.set_meta("loll_sw", 0.0)
	for i in 40: await process_frame
	var hip_i: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_j: float = (fig.hips[-1.0] as Node3D).rotation.x; var knee_i: float = (fig.knees[1.0] as Node3D).rotation.x; var shz_i: float = (fig.shoulders[1.0] as Node3D).rotation.z; var pel_i := fig.pelvis.rotation.x
	fig.set_meta("loll_c", 1.0)
	for i in 60: await process_frame
	var pel := fig.pelvis.rotation.x; var pel_y := fig.pelvis.position.y
	var sh_r: float = (fig.shoulders[1.0] as Node3D).rotation.x; var el_r: float = (fig.elbows[1.0] as Node3D).rotation.x; var shz_l: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var el_l: float = (fig.elbows[-1.0] as Node3D).rotation.x
	var hip_r: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_l: float = (fig.hips[-1.0] as Node3D).rotation.x; var knee_r: float = (fig.knees[1.0] as Node3D).rotation.x; var knee_l: float = (fig.knees[-1.0] as Node3D).rotation.x; var neck_x := fig.neck.rotation.x
	print("POSE impact: hips=%.2f %.2f (want −1.10 −0.90) knee=%.2f (want 1.30) shoulder z=%.2f (want −0.90: out) pelvis=%.2f (want −1.00) | settled: pelvis=%.2f y=%.3f (want −1.35 0.110) shoulder r=%.2f elbow r=%.2f (want −2.70 −2.30) shoulder l z=%.2f elbow l=%.2f (want 1.10 −0.30) hips=%.2f %.2f (want −0.475 ± 0.05, −0.375) knees=%.2f %.2f (want 0.40 0.25) neck=%.2f (want < 0: the sky)" % [hip_i, hip_j, knee_i, shz_i, pel_i, pel, pel_y, sh_r, el_r, shz_l, el_l, hip_r, hip_l, knee_r, knee_l, neck_x])
	# 진짜 탑: 1..46층에 plan 이 찾는 그물 — 공중 정원 층 5, 6, 8, 9, 41, 42, 44 중 다른 팩의 틈을 비켜 빈 틈이 있는 층만(7, 43 은 통풍구 층)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 47):
		var pl: Array = gm.band(n)
		var out := ch.plan(n, pl, gm.wind_of(n), cb.plan(n, pl) + cg.plan(n, pl) + cm.plan(n, pl))
		if out.size() > 0: bands.append("%d:%s" % [n, out.map(func(v: Dictionary) -> String: return "%s-%s gap %.0f dy %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"]), absf(float(v["y_l"]) - float(v["y_r"]))])]); count += out.size()
	print("TOWER floors=", bands, " nets=", count, " (want a subset of 5, 6, 8, 9, 41, 42, 44 — one each)")
	quit()
