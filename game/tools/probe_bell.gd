extends SceneTree
## 종 줄 팩 점검(헤드리스): 자료가 읽히나, 옛 회관 층의 선 발판(std·ice·spring·crumble) 사이 틈 하나에만 줄이 걸리나(가장 긴 틈 한둘은 그 층의 다른 팩 몫 — 다리·유령 층은 하나, 버섯 층은 둘; 지름길 판이 가르는 틈은 진다, 통풍구 층·다른 테마 층은 아니다), 쉼·꼭대기·들보 높이가 기하대로 나오나,
## 손잡이가 한 바퀴(내려앉기 → 감기 → 머물기 → 내리기)를 시각대로 도나, 손이 손잡이 범위 안인 공중의 몸만 grab 이 받나(높이·좌우·앞뒤 밖·도는 중·방금 놓은 줄은 아니다), 매달리면 손잡이 밑을 따라가고 메타가 적히나, 놓을 때 감기면 +hoist_v·내리면 −drop_v·머물면 0 인가,
## 들보·종·바퀴·줄·손잡이가 그려지고 종이 당김대로 돌며 줄이 늘고 종이 치는 순간 dong 이 울리나, haul 자세가 당기면 팔꿈치·무릎을 접고 뒤로 젖혀지고 오르면 펴지나, 진짜 탑의 1..60층에서 plan 이 옛 회관 층에만 줄을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cb := ClimbBell.new(); root.add_child(cb)
	await process_frame
	print("PACK id=", cb.pack.get("id"), " kind=", cb.kind.size() > 0, " pose=", cb.pack.get("pose"), " themes=", cb.pack.get("themes"), " hoist_v=%.0f (want 160) drop_v=%.0f (want 90)" % [cb.hoist_v(), cb.drop_v()])
	var plats: Array = [
		{ "id": "16.0", "x": 100.0, "y": 9700.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.1", "x": 380.0, "y": 9810.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.2", "x": 650.0, "y": 9920.0, "w": 160.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.3", "x": 400.0, "y": 10030.0, "w": 120.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.4", "x": 200.0, "y": 10140.0, "w": 110.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.5", "x": 25.0, "y": 10250.0, "w": 90.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16s", "x": 560.0, "y": 10100.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var planned := cb.plan(1, plats)
	var ghost := cb.plan(2, plats)
	var vent := cb.plan(3, plats)
	var other := cb.plan(5, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cb.build(band_root, planned)
	print("PLAN n1=", planned.size(), " (want 1: gaps 100 (16.0↔16.1), 120 (16.1↔16.2), 130 (16.2↔16.3, cut by the short slab 16s in its column → out), 90 (16.3↔16.4), 85 (16.4↔16.5) — a mushroom floor leaves the two longest, 120 and 100, so the third, 90, gets the rope: hx 355, beam 10290 = 10140 + 150, rest 10138 = 10030 + 58 + 50, top 10228 = 10140 + 58 + 30, dirx −1 — the upper hop is to the left) ids=", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + " hx %.0f hp %.0f rest %.0f top %.0f dirx %.0f a_y %.0f b_y %.0f" % [float(v["hx"]), float(v["hp"]), float(v["rest"]), float(v["top"]), float(v["dirx"]), float(v["a_y"]), float(v["b_y"])]), " n2=", ghost.map(func(v: Dictionary) -> String: return String(v["id"]) + " hx %.0f dirx %.0f" % [float(v["hx"]), float(v["dirx"])]), " (want 2.b0 hx 330 dirx 1: a ghost floor leaves only the longest, so the 100 gap) n3=", vent.size(), " n5=", other.size(), " (want 0 0: vent floor, Hanging garden) nodes=", band_root.get_child_count())
	var s: Dictionary = cb.ropes[0]
	print("CYCLE hoist_s=%.2f (want 0.65 = (10228 − 10124) / 160) drop_s=%.2f (want 1.00) cycle=%.2f (want 2.55) rest grip=%.0f (want 10138, idle)" % [cb.hoist_s(s), cb.drop_s(s), cb.cycle_s(s), cb.grip_y(s, 0.0)])
	# 잡기(t 0, 쉬는 줄): 손(발 + 58)이 손잡이 10138 의 22 안·x 355 의 26 안인 몸 → 받는다; 42 아래 → 아니다; x 35 옆 → 아니다; 앞뒤 밖 → 아니다; 잡은 뒤 도는 중(0.5) → 아니다
	cb.t = 0.0
	var g_low := cb.grab(352.0, 10040.0, float(s["z"]))
	var g_side := cb.grab(390.0, 10082.0, float(s["z"]))
	var g_z := cb.grab(352.0, 10082.0, float(s["z"]) + 100.0)
	var g_ok := cb.grab(352.0, 10082.0, float(s["z"]))
	cb.t = 0.5
	var g_busy := cb.grab(352.0, 10082.0, float(s["z"]))
	print("GRAB ok=%s x=%.1f y=%.1f go=%.1f (want 1.b0 355.0 10080.0 0.0: under the grip, the cycle starts) | low=%s side=%s far_z=%s busy=%s (want all empty)" % [g_ok.get("id", "-"), float(g_ok.get("x", 0.0)), float(g_ok.get("y", 0.0)), float(s.get("go", -9.0)), g_low.get("id", "-"), g_side.get("id", "-"), g_z.get("id", "-"), g_busy.get("id", "-")])
	# 손잡이의 길(go 0): 0.15 내려앉는 중 10131(−70 px/s), 0.3 바닥 10124, 0.625 감는 중 10176(+160), 0.95 꼭대기 10228, 1.25 머묾(0), 2.05 내리는 중 10183(−90), 2.55 쉼 10138
	print("GRIP 0.15 %.1f v %.1f (want 10131.0 −70.0) | 0.3 %.1f (want 10124.0) | 0.625 %.1f v %.1f (want 10176.0 160.0) | 0.95 %.1f (want 10228.0) | 1.25 %.1f v %.1f pull %.2f (want 10228.0 0.0 1.00) | 2.05 %.1f v %.1f (want 10183.0 −90.0) | 2.55 %.1f v %.1f busy=%s (want 10138.0 0.0 false)" % [cb.grip_y(s, 0.15), cb.grip_vy(s, 0.15), cb.grip_y(s, 0.3), cb.grip_y(s, 0.625), cb.grip_vy(s, 0.625), cb.grip_y(s, 0.95), cb.grip_y(s, 1.25), cb.grip_vy(s, 1.25), cb.pull(s, 1.25), cb.grip_y(s, 2.05), cb.grip_vy(s, 2.05), cb.grip_y(s, 2.55), cb.grip_vy(s, 2.55), cb.busy(s, 2.55)])
	# 매달리기: 0.15 내려앉는 중 — 몸 10073, 메타 p 0.5·v −0.44; 0.625 감는 중 — 10118, p 0·v 1; 1.25 머묾 — 10170, v 0; 놓으면 감기 160·내리기 −90; 모르는 id 는 lost
	var fig := Stick3D.new(); root.add_child(fig)
	cb.t = 0.15
	var h1 := cb.hang_on(g_ok, fig)
	var m_p1 := float(fig.get_meta("haul_p", 9.0)); var m_v1 := float(fig.get_meta("haul_v", 9.0))
	cb.t = 0.625
	var h2 := cb.hang_on(g_ok, fig)
	var m_p2 := float(fig.get_meta("haul_p", 9.0)); var m_v2 := float(fig.get_meta("haul_v", 9.0))
	var lg_up := cb.let_go(g_ok)
	cb.t = 1.25
	var h3 := cb.hang_on(g_ok, fig)
	var m_v3 := float(fig.get_meta("haul_v", 9.0))
	cb.t = 2.5
	var lg_dn := cb.let_go(g_ok)
	var h_lost := cb.hang_on({ "id": "nope", "x": 1.0, "y": 2.0 })
	print("HANG 0.15: x=%.1f y=%.1f face=%.0f lost=%s meta p=%.2f v=%.2f (want 355.0 10073.0 −1 false 0.50 −0.44) | 0.625: y=%.1f p=%.2f v=%.2f (want 10118.0 0.00 1.00) let_go vy=%.1f (want 160.0) | 1.25: y=%.1f v=%.2f (want 10170.0 0.00) | 2.5: let_go vy=%.1f (want −90.0) | unknown id: lost=%s x=%.0f (want true 1)" % [float(h1["x"]), float(h1["y"]), float(h1["face"]), h1["lost"], m_p1, m_v1, float(h2["y"]), m_p2, m_v2, float(lg_up["vy"]), float(h3["y"]), m_v3, float(lg_dn["vy"]), h_lost["lost"], float(h_lost["x"])])
	# 방금 놓은 줄(2.5)은 2.7 에 쉬고 있어도 grace 0.4 안이라 안 잡힌다; 3.0 엔 잡힌다(새 바퀴 go 3.0)
	cb.t = 2.7
	var g_grace := cb.grab(352.0, 10082.0, float(s["z"]))
	cb.t = 3.0
	var g_again := cb.grab(352.0, 10082.0, float(s["z"]))
	print("GRACE 2.7: %s (want empty — let go 0.2 s ago) | 3.0: %s go=%.1f (want 1.b0 3.0)" % [g_grace.get("id", "-"), g_again.get("id", "-"), float(s.get("go", -9.0))])
	# 그림: 노드 아이 5(들보·종 노드·줄·손잡이·dong), 종 노드 아이 4(종머리·종·입술 띠·바퀴); 머무는 동안(pull 1) 종이 −1.1 돌고 줄이 바퀴 밑에서 꼭대기 손잡이까지, 손잡이가 꼭대기에; dong 은 내려앉기가 끝나는 프레임에
	s["go"] = cb.t - 1.0; cb._place(s)
	var swing: Node3D = s["swing"]; var rope: Node3D = s["rope"]; var sally: Node3D = s["sally"]
	var rot_top := swing.rotation.z; var rope_len := rope.scale.y; var sally_y := sally.position.y
	s["go"] = cb.t - 0.28
	var dg: AudioStreamPlayer3D = s["dong"]
	var rang := false
	for i in 12:
		await process_frame
		if dg.playing: rang = true
	var node: Node3D = s["node"]
	print("VISUAL children=", node.get_child_count(), " (want 5) swing=", swing.get_child_count(), " (want 4) bell angle at the top=%.2f (want −1.10: amax × pull 1 × dirx −1) rope=%.2f m (want 1.28 = (10290 − 10228) / 36 − 16 / 36) sally y=%.2f (want −1.72) | dong stream=%s rang at the strike=%s (want true)" % [rot_top, rope_len, sally_y, dg.stream != null, rang])
	# 자세: 당김(p 1, v 0) — 몸통 뒤로(−0.081 = −0.18 × 0.45), 오른 엉덩이 −0.72(무릎을 몸 쪽으로), 무릎 1.10(접힘), 어깨 x −2.75(머리 위 줄), 팔꿈치 −1.10(줄을 끌어내린다), 골반 0.40; 오름(p 0, v 1) — 몸통 0.045, 엉덩이 −0.09, 무릎 0.30, 어깨 −2.90, 팔꿈치 −0.35, 골반 0.45
	fig.pose_request = "haul"; fig._yaw = PI / 2.0; fig._yaw_target = PI / 2.0
	fig.set_meta("haul_p", 1.0); fig.set_meta("haul_v", 0.0)
	await process_frame; await process_frame; await process_frame
	var early := fig.torso.rotation.x
	for i in 40: await process_frame
	var torso := fig.torso.rotation.x; var hp_r: float = (fig.hips[1.0] as Node3D).rotation.x; var kn: float = (fig.knees[1.0] as Node3D).rotation.x
	var shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var elx: float = (fig.elbows[1.0] as Node3D).rotation.x; var hip_y := fig.pelvis.position.y
	fig.set_meta("haul_p", 0.0); fig.set_meta("haul_v", 1.0)
	for i in 40: await process_frame
	var torso2 := fig.torso.rotation.x; var hp_r2: float = (fig.hips[1.0] as Node3D).rotation.x; var kn2: float = (fig.knees[1.0] as Node3D).rotation.x
	var shx2: float = (fig.shoulders[1.0] as Node3D).rotation.x; var elx2: float = (fig.elbows[1.0] as Node3D).rotation.x; var hip_y2 := fig.pelvis.position.y
	print("POSE early=%.3f (≈ 0, before the grab) pulling: torso=%.3f (want ≈ −0.081 ± 0.009: leaning back) hip=%.2f (want −0.72: knees drawn up) knee=%.2f (want 1.10) arm x=%.2f (want −2.75: overhead on the rope) elbow=%.2f (want −1.10: hauling) hip_y=%.2f (want 0.40) | rising: torso=%.3f (want ≈ 0.045) hip=%.2f (want −0.09: legs trailing) knee=%.2f (want 0.30) arm x=%.2f (want −2.90) elbow=%.2f (want −0.35) hip_y=%.2f (want 0.45)" % [early, torso, hp_r, kn, shx, elx, hip_y, torso2, hp_r2, kn2, shx2, elx2, hip_y2])
	# 진짜 탑: 1..60층에 plan 이 찾는 줄 — 옛 회관 층 1, 2, 4, 36, 37, 38 중 다음 틈이 맞는 층(3, 35, 39 는 통풍구 층)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var g: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl := cb.plan(n, g.band(n))
		if pl.size() > 0: bands.append("%d:%d" % [n, pl.size()]); count += pl.size()
	print("TOWER floors=", bands, " ropes=", count, " (want a subset of 1, 2, 4, 36, 37, 38, one each)")
	quit()
