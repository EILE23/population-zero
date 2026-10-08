extends SceneTree
## 추 팩 점검(헤드리스): 자료가 읽히나, 태엽 층의 선 발판(std·ice·spring·crumble) 사이 틈 하나에만 추가 걸리나(가장 긴 틈 한둘은 그 층의 다른 팩 몫 — 다리·유령 층은 하나, 버섯 층은 둘; 지름길 판이 가르는 틈은 진다, 상승기류 층·다른 테마 층은 아니다), 막대 길이·진폭이 기하대로 나와 추의 바깥이 두 턱에서 clear 만큼 떨어진 곳에서 멈추나,
## 손이 가로대 범위 안인 공중의 몸만 grab 이 받나(높이·좌우·앞뒤 밖은 아니다), 매달리면 가로대 밑을 따라가고 메타가 적히나, 놓을 때 바닥에선 빠르고 끝에선 0 인가, 달리는 추에 닿은 공중의 몸만 옆·위로 밀리나(끝의 멈춘 추·방금 놓은 추·위의 몸은 아니다),
## 받침대·핀·막대·가로대·추가 그려지고 막대가 각대로 돌며 끝에서 tock 이 울리나, dangle 자세가 가는 쪽으로 기울고 앞으로 갈 땐 다리를 차고 돌아올 땐 접나, 진짜 탑의 1..60층에서 plan 이 태엽 층에만 추를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cp := ClimbPendulum.new(); root.add_child(cp)
	await process_frame
	print("PACK id=", cp.pack.get("id"), " kind=", cp.kind.size() > 0, " pose=", cp.pack.get("pose"), " themes=", cp.pack.get("themes"), " period=%.1f (want 2.4)" % cp.period())
	var plats: Array = [
		{ "id": "16.0", "x": 100.0, "y": 9700.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.1", "x": 380.0, "y": 9810.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.2", "x": 650.0, "y": 9920.0, "w": 160.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.3", "x": 400.0, "y": 10030.0, "w": 120.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.4", "x": 200.0, "y": 10140.0, "w": 110.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.5", "x": 25.0, "y": 10250.0, "w": 90.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16s", "x": 560.0, "y": 10100.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var planned := cp.plan(17, plats)
	var vent := cp.plan(15, plats)
	var other := cp.plan(20, plats)
	var one := cp.plan(16, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cp.build(band_root, planned)
	print("PLAN n17=", planned.size(), " (want 1: gaps 100 (16.0↔16.1), 120 (16.1↔16.2), 130 (16.2↔16.3, cut by the short slab 16s in its wedge → out), 90 (16.3↔16.4), 85 (16.4↔16.5) — a mushroom floor leaves the two longest, 120 and 100, so the third, 90, gets the weight: hub 355 above the upper hop 16.4 at 10290, len 147 = 150 + 55 − 58, amax asin(25/147) = 0.171, low_y 10143) ids=", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + " hx %.0f hp %.0f len %.1f amax %.3f low %.0f a_y %.0f b_y %.0f" % [float(v["hx"]), float(v["hp"]), float(v["len"]), float(v["amax"]), float(v["low_y"]), float(v["a_y"]), float(v["b_y"])]), " n15=", vent.size(), " n20=", other.size(), " (want 0 0: vent floor, Wind cliffs) n16=", one.map(func(v: Dictionary) -> String: return String(v["id"]) + " hx %.0f amax %.3f" % [float(v["hx"]), float(v["amax"])]), " (want 16.p0 hx 330 amax 0.206: a bridge floor leaves only the longest, so the 100 gap) nodes=", band_root.get_child_count())
	var s: Dictionary = cp.bobs[0]
	# 가로대의 길: phase 0 이라 t 0 은 바닥에서 +x 로, 0.6 은 오른 끝(아래 턱 16.3 쪽), 1.2 는 바닥에서 −x 로, 1.8 은 왼 끝(위 턱 16.4 쪽)
	var p0 := cp.bar(s, 0.0); var p1 := cp.bar(s, 0.6); var p2 := cp.bar(s, 1.2); var p3 := cp.bar(s, 1.8)
	var v0 := cp.vel(s, 0.0); var v1 := cp.vel(s, 0.3); var v2 := cp.vel(s, 0.6); var sp := cp.speed(s, 0.0)
	print("BAR t0 %.1f,%.1f (want 355,10143: the bottom) | 0.6 %.1f,%.1f (want 380,10145: the lower hop's edge 400 − clear 8 − r 12, 2 px up) | 1.2 %.1f,%.1f (want 355,10143) | 1.8 %.1f,%.1f (want 330,10145: the upper hop's edge 310 + 8 + 12) | vel t0 %.2f,%.2f (want 1.00,0.00) 0.3 %.2f,%.2f (want 0.70,0.09) 0.6 %.2f,%.2f (want 0,0) | top speed %.1f px/s (want 65.8 = 147 × 0.171 × 2π / 2.4)" % [p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, v0.x, v0.y, v1.x, v1.y, v2.x, v2.y, sp.x])
	# 잡기(t 0.6, 오른 끝): 손(발 + 58)이 가로대 10145 의 22 안·x 380 의 26 안인 몸 → 받는다; 47 아래 → 아니다; x 40 옆 → 아니다; 앞뒤 밖 → 아니다
	cp.t = 0.6
	var g_ok := cp.grab(376.0, 10090.0, float(s["z"]))
	var g_low := cp.grab(376.0, 10040.0, float(s["z"]))
	var g_side := cp.grab(420.0, 10090.0, float(s["z"]))
	var g_z := cp.grab(376.0, 10090.0, float(s["z"]) + 100.0)
	print("GRAB ok=%s x=%.1f y=%.1f (want 17.p0 380.0 10087.1: under the bar) | low=%s side=%s far_z=%s (want all empty)" % [g_ok.get("id", "-"), float(g_ok.get("x", 0.0)), float(g_ok.get("y", 0.0)), g_low.get("id", "-"), g_side.get("id", "-"), g_z.get("id", "-")])
	# 매달리기: 바닥(1.2)에선 −x 로 전속, 메타 v −1·a 0; 왼 끝(1.8)에선 멈춤, a −0.171; 모르는 id 는 lost
	var fig := Stick3D.new(); root.add_child(fig)
	cp.t = 1.2
	var h1 := cp.hang_on(g_ok, fig)
	var m_v1 := float(fig.get_meta("dangle_v", 9.0)); var m_a1 := float(fig.get_meta("dangle_a", 9.0))
	var lg1 := cp.let_go(g_ok)
	cp.t = 1.8
	var h2 := cp.hang_on(g_ok, fig)
	var m_v2 := float(fig.get_meta("dangle_v", 9.0)); var m_a2 := float(fig.get_meta("dangle_a", 9.0))
	var lg2 := cp.let_go(g_ok)
	cp.t = 0.3
	var lg3 := cp.let_go(g_ok)
	var h_lost := cp.hang_on({ "id": "nope", "x": 1.0, "y": 2.0 })
	print("HANG 1.2: x=%.1f y=%.1f lost=%s meta v=%.2f a=%.3f (want 355.0 10085.0 false −1.00 0.000) let_go vx=%.1f vy=%.1f (want −65.8 0.0) | 1.8: x=%.1f y=%.1f meta v=%.2f a=%.3f (want 330.0 10087.1 0.00 −0.171) let_go vx=%.1f vy=%.1f (want 0 0) | 0.3: let_go vx=%.1f vy=%.1f (want 46.2 5.6: rising toward the right end) | unknown id: lost=%s x=%.0f (want true 1)" % [float(h1["x"]), float(h1["y"]), h1["lost"], m_v1, m_a1, float(lg1["vx"]), float(lg1["vy"]), float(h2["x"]), float(h2["y"]), m_v2, m_a2, float(lg2["vx"]), float(lg2["vy"]), float(lg3["vx"]), float(lg3["vy"]), h_lost["lost"], float(h_lost["x"])])
	# 밀치기: 방금 놓은 추는 grace 0.3 동안 안 민다 → held 를 되돌리고 본다. 바닥(1.2, −x 전속)의 추 원(355, 10122, r 12)에 몸(350, 10100: 상자 y 10100..10140)이 닿으면 −220/240; 위의 몸(10050)은 아니다; 왼 끝(1.8, 멈춤)의 추 밑 몸은 아니다
	cp.t = 1.2; cp.let_go(g_ok)
	var sw_grace := cp.sweep(350.0, 10100.0, float(s["z"]))
	s["held"] = -9.0
	var sw_hit := cp.sweep(350.0, 10100.0, float(s["z"]))
	var sw_above := cp.sweep(350.0, 10050.0, float(s["z"]))
	var sw_z := cp.sweep(350.0, 10100.0, float(s["z"]) + 100.0)
	cp.t = 1.8
	var sw_end := cp.sweep(328.0, 10100.0, float(s["z"]))
	cp.t = 0.0
	var sw_back := cp.sweep(350.0, 10100.0, float(s["z"]))
	print("SWEEP just let go: %s (want empty — grace) | bottom going −x: vx=%s vy=%s (want −220 240) | above: %s far_z: %s (want empty) | at the still end: %s (want empty — a body may stand under a stopped weight) | bottom going +x: vx=%s (want 220)" % [sw_grace.size(), sw_hit.get("vx", "-"), sw_hit.get("vy", "-"), sw_above.size(), sw_z.size(), sw_end.size(), sw_back.get("vx", "-")])
	# 그림: 노드 아이 4(받침대·핀·막대 노드·tock), 막대 노드 아이 4(막대·가로대·추·띠); 막대 각이 ang 과 같나; tock 은 끝(0.6)을 지나는 프레임에
	cp.t = 0.6; cp._turn(s)
	var arm: Node3D = s["arm"]
	var rot_end := arm.rotation.z
	cp.t = 0.55
	var tk: AudioStreamPlayer3D = s["tock"]
	var ticked := false
	for i in 12:
		await process_frame
		if tk.playing: ticked = true
	var node: Node3D = s["node"]
	print("VISUAL children=", node.get_child_count(), " (want 4) arm=", arm.get_child_count(), " (want 4) arm angle at the right end=%.3f (want 0.171) | tock stream=%s tocked passing the end=%s (want true)" % [rot_end, tk.stream != null, ticked])
	# 자세: +x 를 보며 +x 로 전속(v 1) — 몸통 앞으로(0.158 = 0.45 × 0.35), 오른 엉덩이 −0.44(다리를 앞으로 참), 무릎 0.10(거의 펴짐), 어깨 x −2.9(머리 위), 팔꿈치 −0.15, 골반 0.45; 돌아올 땐(v −1) 몸통 −0.158, 엉덩이 0.16, 무릎 0.60(접힘)
	fig.pose_request = "dangle"; fig._yaw = PI / 2.0; fig._yaw_target = PI / 2.0
	fig.set_meta("dangle_v", 1.0); fig.set_meta("dangle_a", 0.1)
	await process_frame; await process_frame; await process_frame
	var early := fig.torso.rotation.x
	for i in 40: await process_frame
	var torso := fig.torso.rotation.x; var hp_r: float = (fig.hips[1.0] as Node3D).rotation.x; var kn: float = (fig.knees[1.0] as Node3D).rotation.x
	var shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var elx: float = (fig.elbows[1.0] as Node3D).rotation.x; var hip_y := fig.pelvis.position.y
	fig.set_meta("dangle_v", -1.0); fig.set_meta("dangle_a", -0.1)
	for i in 40: await process_frame
	var torso2 := fig.torso.rotation.x; var hp_r2: float = (fig.hips[1.0] as Node3D).rotation.x; var kn2: float = (fig.knees[1.0] as Node3D).rotation.x
	print("POSE early=%.3f (≈ 0, before the grab) forward: torso=%.3f (want ≈ 0.158 ± 0.014: leaning the way it goes) hip=%.2f (want −0.44: legs kicked forward) knee=%.2f (want 0.10) arm x=%.2f (want −2.90: overhead) elbow=%.2f (want −0.15) hip_y=%.2f (want 0.45) | back: torso=%.3f (want ≈ −0.158) hip=%.2f (want 0.16) knee=%.2f (want 0.60: tucked)" % [early, torso, hp_r, kn, shx, elx, hip_y, torso2, hp_r2, kn2])
	# 진짜 탑: 1..60층에 plan 이 찾는 추 — 태엽 층 16, 17, 18, 50, 52, 53, 54 중 세 번째 틈이 맞는 층(15, 19, 51 은 바람개비·상승기류 층)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var g: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl := cp.plan(n, g.band(n))
		if pl.size() > 0: bands.append("%d:%d" % [n, pl.size()]); count += pl.size()
	print("TOWER floors=", bands, " weights=", count, " (want a subset of 16, 17, 18, 50, 52, 53, 54, one each)")
	quit()
