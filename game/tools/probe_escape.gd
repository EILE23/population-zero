extends SceneTree
## 핀 바퀴 팩 점검(헤드리스): 자료가 읽히나, 태엽 층(바람구멍 층은 빼고)의 잇단 발판 짝(90..220 px 틈, 위 발판이 60..150 높이) 중 가장 넓은 틈에만 바퀴가 걸리나(반지름이 기하대로 — r = min((dy − 8) / 2, gap / 2 − 8); 꼭대기가 30 px 넘게 모자라는 틈·좁은 틈·원을 가르는 판·taken(풀무·추)의 틈은 비켜 가고, 층 15/17/19/20/50/51),
## 핀이 박자(0.7 s)마다 한 칸(45°)을 0.18 s 의 smoothstep 으로 덜컥 가나(같은 시각엔 같은 자리), 핀 윗면을 지나는 몸과 catch 안에서 내려서는 몸만 land 가 받나(멀리 위·핀 밖·앞뒤 밖은 아니다, 꼭대기 핀도 받나), 타면 핀 위의 제자리를 지키며 덜컥 실려 가고 꼭대기를 넘으면 세이나, 메타(박자·방향)가 적히나, 핀 밖으로 걸어 나가면 off 인가,
## 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 읽나, 축대·테·판·축머리·바퀴(살 넷 + 핀 여덟, 핀마다 머리)·앵커·소리 둘이 그려지고 바퀴가 제 각으로 돌고 앵커가 박자마다 반대로 기우나, 걸음이 바뀌면 tock 이 울리나,
## jolt 자세가 충격에 무릎이 꺾이고 팔이 튀어 오르고 몸통이 가는 방향의 반대로 쏠리고 고개를 들며, 충격이 지나면 자리를 잡나, 진짜 탑의 1..60층에서 plan 이 태엽 층에만 바퀴를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var ew := ClimbEscape.new(); root.add_child(ew)
	var cg := ClimbGears.new(); root.add_child(cg)
	var pk := ClimbPerch.new(); root.add_child(pk)
	var cpn := ClimbPendulum.new(); root.add_child(cpn)
	var cl := ClimbBellows.new(); root.add_child(cl)
	await process_frame
	print("PACK id=", ew.pack.get("id"), " kind=", ew.kind.size() > 0, " pose=", ew.pack.get("pose"), " themes=", ew.pack.get("themes"), " pins=%d pin_r=%.0f pin_w=%.0f pin_len=%.0f clear=%.0f r_min=%.0f short=%.0f..%.0f tick=%.2f step=%.2f catch=%.0f day=%.0f (want 8 4 20 24 4 32 8..30 0.70 0.18 14 600)" % [ew.pins(), ew.pin_r(), ew.pin_w(), ew.pin_len(), ew.clear(), ew.r_min(), ew.short_min(), ew.short_max(), ew.tick_s(), ew.step_s(), ew.catch(), ew.day_s()])
	var plats: Array = [
		{ "id": "16.0", "x": 100.0, "y": 9600.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.1", "x": 380.0, "y": 9710.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.2", "x": 560.0, "y": 9820.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.3", "x": 330.0, "y": 9930.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.4", "x": 700.0, "y": 10040.0, "w": 100.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16s", "x": 600.0, "y": 9780.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := ew.plan(16, plats)
	var cut := plats.duplicate(true); cut.append({ "id": "16c", "x": 300.0, "y": 9700.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 })   # 지름길 판이 첫 틈의 원을 가른다 — 16.2↔16.3 (110) 으로
	var cutp := ew.plan(16, cut)
	var belled := ew.plan(16, plats, [{ "id": "16.B0", "kind": "bellows", "x": 260.0, "w": 40.0, "y": 9600.0, "px": 320.0, "b_y": 9710.0 }])   # 풀무가 첫 틈에 — 둘째 틈으로
	var pend := [{ "id": "16.p0", "kind": "pendulum", "x": 455.0, "w": 100.0, "y": 9780.0, "len": 60.0, "hx": 505.0 }]   # 추가 둘째 틈에 — 첫 틈 그대로, 판까지 가르면 없다
	var pended := ew.plan(16, plats, pend); var none := ew.plan(16, cut, pend)
	var high := plats.duplicate(true); (high[1] as Dictionary)["y"] = 9750.0   # dy 150: r 52 로는 꼭대기가 46 모자란다 — 둘째 틈으로
	var highp := ew.plan(16, high)
	var narrow := plats.duplicate(true); (narrow[1] as Dictionary)["x"] = 345.0   # 틈 85: r 34.5 로는 41 모자란다 — 둘째 틈으로
	var narrowp := ew.plan(16, narrow)
	var f15 := ew.plan(15, plats); var f17 := ew.plan(17, plats); var f19 := ew.plan(19, plats); var f20 := ew.plan(20, plats); var f50 := ew.plan(50, plats); var f51 := ew.plan(51, plats)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " %s↔%s hx %.0f cy %.0f r %.1f short %.1f dir %.0f x %.0f w %.0f y %.0f y_top %.0f z %.0f d %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["hx"]), float(v["cy"]), float(v["r"]), float(v["short"]), float(v["dir"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	var brief := func(v: Dictionary) -> String: return String(v["a_id"]) + "↔" + String(v["b_id"]) + " r %.1f" % float(v["r"])
	print("PLAN free=", free.map(show), " (want 1: 16.E0 16.0↔16.1 hx 320 cy 9651 r 51.0 short 8.0 dir 1 x 265 w 110 y 9600 y_top 9706 z −48 d 24)")
	print("PLAN cut=", cutp.map(brief), " (want [16.2↔16.3 r 47.0]) bellows=", belled.map(brief), " (want [16.2↔16.3 r 47.0]) pendulum=", pended.map(brief), " (want [16.0↔16.1 r 51.0]) both=", none.size(), " (want 0) high=", highp.map(brief), " (want [16.2↔16.3 r 47.0]) narrow=", narrowp.map(brief), " (want [16.2↔16.3 r 47.0]) floors 15/17/19/20/50/51=", [f15.size(), f17.size(), f19.size(), f20.size(), f50.size(), f51.size()], " (want 0 1 0 0 1 0)")
	var band_root := Node3D.new(); root.add_child(band_root)
	ew.build(band_root, free)
	var s: Dictionary = ew.wheels[0]
	# 핀의 길(phase 0): t 0 — 핀 0 바닥 (320, 9600), 핀 2 a 쪽 수평 (269, 9651), 핀 4 꼭대기 (320, 9702), 핀 6 b 쪽 (371, 9651); t 0.1 — 걸음의 0.583 (26.2°) → 핀 0 (297.5, 9605.3); t 0.18..0.69 — 45° (283.9, 9614.9); t 0.88 — 90° (269, 9651); since 0.1 → 0.1, 0.75 → 0.05
	var p0 := ew.pin(s, 0, 0.0); var p2 := ew.pin(s, 2, 0.0); var p4 := ew.pin(s, 4, 0.0); var p6 := ew.pin(s, 6, 0.0)
	var q1 := ew.pin(s, 0, 0.1); var q2 := ew.pin(s, 0, 0.18); var q3 := ew.pin(s, 0, 0.69); var q4 := ew.pin(s, 0, 0.88)
	print("PIN t0 k0=%.1f,%.1f k2=%.1f,%.1f k4=%.1f,%.1f k6=%.1f,%.1f (want 320,9600 269,9651 320,9702 371,9651) | k0 @0.1 %.1f,%.1f (want 297.5,9605.3: mid-step) @0.18 %.1f,%.1f @0.69 %.1f,%.1f (want both 283.9,9614.9: stopped at 45°) @0.88 %.1f,%.1f (want 269,9651) steps(0.1)=%.3f (want 0.583) since 0.1=%.2f 0.75=%.2f (want 0.10 0.05)" % [p0.x, p0.y, p2.x, p2.y, p4.x, p4.y, p6.x, p6.y, q1.x, q1.y, q2.x, q2.y, q3.x, q3.y, q4.x, q4.y, ew.steps(0.1), ew.since(0.1), ew.since(0.75)])
	# 착지(t 0.5, 걸음 1: 핀 k 는 (1 + k)·45°): 핀 1 (269, 9651) 윗면 9655 를 272 에서 9660 → 9650 으로 지나면 받는다; 275 에서 9663 → 9662 는 step; 25 위는 아니다; 282 는 핀 밖(핀 0 은 멀리 아래); 앞뒤 밖은 아니다; 꼭대기 핀 3 (320, 9702) 윗면 9706 도 받는다
	ew.sync(0.5)
	var l_cross := ew.land(272.0, 9660.0, 9650.0, C.PLAYER_Z); var l_step := ew.land(275.0, 9663.0, 9662.0, C.PLAYER_Z); var l_high := ew.land(272.0, 9680.0, 9679.0, C.PLAYER_Z)
	var l_side := ew.land(282.0, 9660.0, 9650.0, C.PLAYER_Z); var l_z := ew.land(272.0, 9660.0, 9650.0, C.PLAYER_Z + 100.0); var l_top := ew.land(321.0, 9710.0, 9705.0, C.PLAYER_Z)
	print("LAND cross=%s pin=%s y=%.1f step=%s (want 16.E0 1 9655.0 false) | step=%s pin=%s step=%s (want 16.E0 1 true) | high=%s side=%s far_z=%s (want all empty) | top=%s pin=%s y=%.1f (want 16.E0 3 9706.0)" % [l_cross.get("id", "-"), l_cross.get("pin", "-"), float(l_cross.get("y", 0.0)), l_cross.get("step", "-"), l_step.get("id", "-"), l_step.get("pin", "-"), l_step.get("step", "-"), l_high.get("id", "-"), l_side.get("id", "-"), l_z.get("id", "-"), l_top.get("id", "-"), l_top.get("pin", "-"), float(l_top.get("y", 0.0))])
	# 타기: 핀 1 에 +3 치우쳐 선 몸이 t 2.3(걸음 4: 핀 1 은 225°, b 쪽으로 내려가는 중 (356.1, 9687.1)) 까지 실려 간다 — 치우침을 지키고, 꼭대기(π)를 넘어 오늘 1, 메타 jolt_t 0.2 / dx +0.71 / dy −0.71; 30 밖으로 걸어 나가면 off; 모르는 id 도 off
	var fig := Stick3D.new(); root.add_child(fig)
	ew.sync(2.3)
	var r1 := ew.ride(l_cross, 272.0, 1.8, fig)
	var m_t := float(fig.get_meta("jolt_t", 9.0)); var m_dx := float(fig.get_meta("jolt_dx", 9.0)); var m_dy := float(fig.get_meta("jolt_dy", 9.0))
	var r_off := ew.ride(l_cross, float(r1["x"]) + 30.0, 0.0001, fig); var r_lost := ew.ride({ "id": "nope", "y": 1.0 }, 5.0, 0.016)
	var d1 := ew.today(15, 19)
	print("RIDE @2.3: x=%.1f y=%.1f off=%s (want 359.1 9691.1 false — the +3 kept, pin_r 4 over the pin) meta t=%.2f dx=%.2f dy=%.2f (want 0.20 0.71 −0.71) | walked 30 out: off=%s (want true) | unknown id: off=%s (want true) | today over=%d wheels=%d (want 1 1)" % [float(r1["x"]), float(r1["y"]), r1["off"], m_t, m_dx, m_dy, r_off["off"], r_lost["off"], int(d1["over"]), int(d1["wheels"])])
	print("NOTE 15=\"%s\" (want Pin wheel, floors 15–19: 1 ride over the top today.) 20=\"%s\" (want the same: nothing on 20..24, so the floors below) 25=\"%s\" (want empty)" % [ew.note(15), ew.note(20), ew.note(25)])
	# 그림: 노드 아이 8(축대·테·판·축머리·바퀴·앵커·소리 둘), 바퀴 아이 12(살 넷 + 핀 여덟), 핀 아이 1(머리); 노드 자리 (320 − 480)/36 = −4.4444, 9651/36 = 268.0833, −70/36 = −1.9444; t 0 바퀴 0 앵커 +0.22, t 0.5(걸음 1, dir +1) 바퀴 −π/4 앵커 −0.22; 0.69 → 0.71 을 지나는 프레임에 tock
	var node: Node3D = s["node"]; var wheel: Node3D = s["wheel"]; var anchor: Node3D = s["anchor"]; var pin_n: Node3D = wheel.get_child(4)
	ew.sync(0.0); ew._process(0.0); var w0 := wheel.rotation.z; var a0 := anchor.rotation.z
	ew.sync(0.5); ew._process(0.0); var w1 := wheel.rotation.z; var a1 := anchor.rotation.z
	ew.t = 0.69
	var tk: AudioStreamPlayer3D = s["tock"]; var ticked := false
	for i in 10:
		await process_frame
		if tk.playing: ticked = true
	print("VISUAL children=%d (want 8) wheel=%d (want 12) pin=%d (want 1) node pos=%.4f %.4f %.4f (want −4.4444 268.0833 −1.9444) wheel rot t0=%.4f t0.5=%.4f (want 0.0000 −0.7854) anchor t0=%.2f t0.5=%.2f (want 0.22 −0.22) tock crossing 0.7=%s (want true)" % [node.get_child_count(), wheel.get_child_count(), pin_n.get_child_count(), node.position.x, node.position.y, node.position.z, w0, w1, a0, a1, ticked])
	# 자세(+x 를 보며, 충격의 꼭대기 jolt_t 0.0875, 핀이 +x 로): 무릎 0.35 + 0.9 = 1.25 (±0.03 숨), 오른 어깨 z −(0.12 + 0.5 + 1.1) = −1.72, 상체 0.45 × −0.3 = −0.135 (±0.02), 골반 0.42 − 0.13 = 0.29 (±0.01), 고개 0.15 − 0.35 = −0.20; 충격이 지난 뒤(0.5): 무릎 0.35, 어깨 −0.62, 상체 ≈ 0, 골반 0.37, 고개 +0.15
	fig.pose_request = "jolt"; fig._yaw = PI / 2.0; fig._yaw_target = PI / 2.0
	fig.set_meta("jolt_t", 0.0875); fig.set_meta("jolt_dx", 1.0)
	while fig.pose_t < 0.3: await process_frame
	var kn: float = (fig.knees[1.0] as Node3D).rotation.x; var shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var torso := fig.torso.rotation.x; var hip_y := fig.pelvis.position.y; var neck := fig.neck.rotation.x
	fig.set_meta("jolt_t", 0.5)
	for i in 3: await process_frame
	var kn2: float = (fig.knees[1.0] as Node3D).rotation.x; var shz2: float = (fig.shoulders[1.0] as Node3D).rotation.z; var torso2 := fig.torso.rotation.x; var hip_y2 := fig.pelvis.position.y; var neck2 := fig.neck.rotation.x
	print("POSE shock: knee=%.2f (want 1.25) arm z=%.2f (want −1.72) torso=%.3f (want −0.135: thrown back against +x) hip_y=%.2f (want 0.29) neck=%.2f (want −0.20: head up) | settled: knee=%.2f (want 0.35) arm z=%.2f (want −0.62) torso=%.3f (want ≈ 0) hip_y=%.2f (want 0.37) neck=%.2f (want 0.15)" % [kn, shz, torso, hip_y, neck, kn2, shz2, torso2, hip_y2, neck2])
	fig.pose_request = ""; fig.remove_meta("jolt_t"); fig.remove_meta("jolt_dx")
	# 진짜 탑: 1..60층에 plan 이 찾는 바퀴 — 태엽 층 15..19, 50..54 중 바람구멍 층(15, 19, 51)이 아니고 띠·추·뻐꾸기 집·풀무가 비켜 간 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var others: Array = cg.plan(n, pl) + pk.plan(n, pl) + cpn.plan(n, pl)
		var out2 := ew.plan(n, pl, others + cl.plan(n, pl, others))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s↔%s gap %.0f r %.0f short %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"]), float(v["r"]), float(v["short"])])])
	print("TOWER floors=", bands, " (want a subset of 16, 17, 18, 50, 52, 53, 54 — one wheel each in a gap ≥ 90 px whose top pin stops within 30 px of the upper hop and that no other Clockwork pack took, never another theme)")
	quit()
