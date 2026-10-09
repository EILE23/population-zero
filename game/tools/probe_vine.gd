extends SceneTree
## 덩굴 커튼 팩 점검(헤드리스): 자료가 읽히나, 공중 정원 층의 선 발판(std·ice, ≥ min_w) 중 기둥이 막히지 않은 가장 넓은 것 하나에만 커튼이 걸리나(지름길 판이 가르는 발판은 진다, 움직이는 발판은 아니다, 통풍구 층·다른 테마 층은 아니다), 막대·자락 높이가 기하대로 나오나,
## 안에 선 몸만 part 가 받아 slow 와 깊이를 주나(옆·위·밑·앞뒤 밖은 아니다), 기둥 안으로 빠르게 떨어지는 몸만 catch 가 받나(느린 낙하·오르는 몸·막대 위·방금 놓은 커튼은 아니다), 안기면 처졌다 멈췄다 미끄러져 발판에 서나(메타도), 놓을 때 미끄러지면 −slide_v·멈춰 있으면 0 인가,
## 들보·막대·두 쪽·가닥·rustle 이 그려지고 두 쪽이 젖혀졌다 되돌아오며 갈라지는 틱에 rustle 이 울리나, part 자세가 젖힐 땐 팔을 앞으로 숙이고 안기면 벌려 쥐고 미끄러지면 무릎을 드나, 진짜 탑의 1..60층에서 plan 이 공중 정원 층에만 커튼을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cv := ClimbVine.new(); root.add_child(cv)
	await process_frame
	print("PACK id=", cv.pack.get("id"), " kind=", cv.kind.size() > 0, " pose=", cv.pack.get("pose"), " themes=", cv.pack.get("themes"), " slow=%.2f (want 0.45) slide_v=%.0f (want 90) catch_s=%.2f (want 0.50)" % [cv.slow(), cv.slide_v(), cv.catch_s()])
	var plats: Array = [
		{ "id": "5r", "x": 250.0, "y": 3000.0, "w": 400.0, "kind": "rest", "z": 0.0, "d": 180.0 },
		{ "id": "5.0", "x": 100.0, "y": 3100.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "5.1", "x": 380.0, "y": 3210.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "5.2", "x": 620.0, "y": 3320.0, "w": 200.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "5.3", "x": 400.0, "y": 3430.0, "w": 160.0, "kind": "ice", "z": -35.0, "d": 70.0 },
		{ "id": "5.4", "x": 200.0, "y": 3540.0, "w": 170.0, "kind": "move", "z": -35.0, "d": 70.0 },
		{ "id": "5.5", "x": 25.0, "y": 3650.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "5s", "x": 680.0, "y": 3468.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var planned := cv.plan(5, plats)
	var six := cv.plan(6, plats)
	var vent := cv.plan(7, plats)
	var other := cv.plan(1, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cv.build(band_root, planned)
	print("PLAN n5=", planned.size(), " (want 1: 5.2 is the widest (200) but the shortcut slab 5s cuts its column → out; 5.4 (170) moves → out; so 5.0 (180) over 5.3 (160): hx 190, top 3100, bar 3250, hem 3112) ids=", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + " hx %.0f top %.0f bar %.0f hem %.0f hop %s" % [float(v["hx"]), float(v["top"]), float(v["bar"]), float(v["hem_y"]), String(v["hop_id"])]), " n6=", six.map(func(v: Dictionary) -> String: return String(v["id"])), " (want 6.v0: the same floor shape on a residue-2 floor) n7=", vent.size(), " n1=", other.size(), " (want 0 0: vent floor, Old hall) nodes=", band_root.get_child_count())
	var s: Dictionary = cv.curtains[0]
	# 젖히기(t 0): 안에 선 몸(x 200, y 3100) → slow 0.45, 깊이 0.74; x 240 옆 → 1; y 3260 막대 위 → 1; y 3050 자락 밑 → 1; 앞뒤 밖 → 1
	var fig := Stick3D.new(); root.add_child(fig)
	cv.t = 0.0
	var p_in := cv.part(200.0, 3100.0, float(s["z"]), fig)
	var deep := float(fig.get_meta("part_k", 9.0))
	var p_side := cv.part(240.0, 3100.0, float(s["z"]))
	var p_up := cv.part(200.0, 3260.0, float(s["z"]))
	var p_low := cv.part(200.0, 3050.0, float(s["z"]))
	var p_z := cv.part(200.0, 3100.0, float(s["z"]) + 100.0)
	print("PART in: f=%.2f in=%s deep=%.2f (want 0.45 true 0.74) | side f=%.2f | above f=%.2f | below f=%.2f | far_z f=%.2f (want 1.00 ×4)" % [float(p_in["f"]), p_in["in"], deep, float(p_side["f"]), float(p_up["f"]), float(p_low["f"]), float(p_z["f"])])
	# 받기(t 1): 기둥 안으로 −300 으로 떨어지는 몸(x 195, y 3200) → 받는다(cy 3200, go 1); −100 느린 낙하 → 아니다; +300 오르는 몸 → 아니다; y 3260 막대 위 → 아니다; x 240 옆 → 아니다
	cv.t = 1.0
	var c_slow := cv.catch(195.0, 3200.0, 3198.0, float(s["z"]), -100.0)
	var c_up := cv.catch(195.0, 3200.0, 3205.0, float(s["z"]), 300.0)
	var c_high := cv.catch(195.0, 3260.0, 3255.0, float(s["z"]), -300.0)
	var c_side := cv.catch(240.0, 3200.0, 3195.0, float(s["z"]), -300.0)
	var c_ok := cv.catch(195.0, 3200.0, 3195.0, float(s["z"]), -300.0)
	print("CATCH ok=%s x=%.1f y=%.1f go=%.1f (want 5.v0 190.0 3200.0 1.0) | slow=%s up=%s high=%s side=%s (want all empty)" % [c_ok.get("id", "-"), float(c_ok.get("x", 0.0)), float(c_ok.get("y", 0.0)), float(s.get("go", -9.0)), c_slow.get("id", "-"), c_up.get("id", "-"), c_high.get("id", "-"), c_side.get("id", "-")])
	# 안김의 길(go 1, cy 3200, sag 10/0.2, catch 0.5, slide 90, top 3100): 1.1 처지는 중 3195(c 0.5, v 0), 1.4 멈춤 3190(c 1), 2.0 미끄러지는 중 3145(v −1), 놓으면 −90; 2.5 발판 3100 done; 모르는 id 는 lost
	cv.t = 1.1
	var h1 := cv.cling(c_ok, fig)
	var m_c1 := float(fig.get_meta("part_c", 9.0)); var m_v1 := float(fig.get_meta("part_v", 9.0))
	cv.t = 1.4
	var h2 := cv.cling(c_ok, fig)
	var m_c2 := float(fig.get_meta("part_c", 9.0)); var m_v2 := float(fig.get_meta("part_v", 9.0))
	var lg_hold := cv.let_go(c_ok)
	s["held"] = -9.0; s["rider"] = true   # 놓은 셈 치지 않고 계속 — 길을 마저 본다
	cv.t = 2.0
	var h3 := cv.cling(c_ok, fig)
	var m_v3 := float(fig.get_meta("part_v", 9.0))
	var lg_slide := cv.let_go(c_ok)
	s["held"] = -9.0; s["rider"] = true
	cv.t = 2.5
	var h4 := cv.cling(c_ok, fig)
	var h_lost := cv.cling({ "id": "nope", "x": 1.0, "y": 2.0 })
	print("CLING 1.1: x=%.1f y=%.1f done=%s c=%.2f v=%.2f (want 190.0 3195.0 false 0.50 0.00) | 1.4: y=%.1f c=%.2f v=%.2f let_go vy=%.1f (want 3190.0 1.00 0.00 0.0) | 2.0: y=%.1f v=%.2f let_go vy=%.1f (want 3145.0 −1.00 −90.0) | 2.5: y=%.1f done=%s rider=%s (want 3100.0 true false) | unknown id: lost=%s x=%.0f (want true 1)" % [float(h1["x"]), float(h1["y"]), h1["done"], m_c1, m_v1, float(h2["y"]), m_c2, m_v2, float(lg_hold["vy"]), float(h3["y"]), m_v3, float(lg_slide["vy"]), float(h4["y"]), h4["done"], s["rider"], h_lost["lost"], float(h_lost["x"])])
	# 방금 놓은 커튼(3.0)은 3.2 에 안 받는다(grace 0.4); 3.5 엔 받는다(go 3.5)
	cv.t = 3.0
	cv.let_go(c_ok)
	cv.t = 3.2
	var c_grace := cv.catch(195.0, 3200.0, 3195.0, float(s["z"]), -300.0)
	cv.t = 3.5
	var c_again := cv.catch(195.0, 3200.0, 3195.0, float(s["z"]), -300.0)
	print("GRACE 3.2: %s (want empty — let go 0.2 s ago) | 3.5: %s go=%.1f (want 5.v0 3.5)" % [c_grace.get("id", "-"), c_again.get("id", "-"), float(s.get("go", -9.0))])
	# 그림: 노드 아이 5(들보·막대·왼쪽·오른쪽·rustle), 왼쪽 가닥 4·오른쪽 3; 안에 선 몸이 0.33초 있으면 두 쪽이 ±0.55 로 젖혀지고 rustle 이 울리며, 떠나면 0.5초 뒤엔 되돌아와 있다
	s["rider"] = false; s["go"] = -9.0
	var left: Node3D = s["left"]; var right: Node3D = s["right"]; var ru: AudioStreamPlayer3D = s["rustle"]
	var rang := false
	for i in 20:   # 헤드리스 프레임은 몇 ms 뿐이라 시간을 직접 민다(1/60 × 20 = 0.33 s > part_s)
		cv.part(200.0, 3100.0, float(s["z"]))
		cv._process(1.0 / 60.0)
		if ru.playing: rang = true
	var open_l := left.rotation.z; var open_r := right.rotation.z
	for i in 30: cv._process(1.0 / 60.0)   # 0.5 s 뒤 — want 가 묵어 0.12 s 뒤부터 되돌아온다(0.25 s)
	var node: Node3D = s["node"]
	print("VISUAL children=", node.get_child_count(), " (want 5) left=", left.get_child_count(), " right=", right.get_child_count(), " (want 4 3) parted left=%.2f right=%.2f (want ≈ 0.55 / −0.55 ± 0.03) closed left=%.2f (want ≈ 0 ± 0.03) | rustle stream=%s rang at the parting=%s (want true)" % [open_l, open_r, left.rotation.z, ru.stream != null, rang])
	# 자세: 젖히며 섬(k 1, c 0) — 엉덩이 −0.25, 무릎 0.45, 어깨 x ≈ −1.60 ± 0.15(가슴 앞), 팔꿈치 −0.7..−1.1, 몸통 ≈ 0.126(앞으로), 골반 0.39; 안김(c 1, v 0) — 엉덩이 −0.04..−0.20(흔들림), 무릎 0.25, 어깨 x −2.30, 어깨 z −0.65(옆 위로), 팔꿈치 −0.70, 몸통 ≈ −0.036, 골반 0.45; 미끄러짐(v −1) — 엉덩이 −0.34..−0.50, 무릎 0.70, 어깨 x −2.80, 팔꿈치 −0.30
	fig.pose_request = "part"; fig._yaw = PI / 2.0; fig._yaw_target = PI / 2.0
	fig.set_meta("part_k", 1.0); fig.set_meta("part_c", 0.0); fig.set_meta("part_v", 0.0)
	await process_frame; await process_frame; await process_frame
	var early := fig.torso.rotation.x
	for i in 40: await process_frame
	var torso := fig.torso.rotation.x; var hp_r: float = (fig.hips[1.0] as Node3D).rotation.x; var kn: float = (fig.knees[1.0] as Node3D).rotation.x
	var shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var elx: float = (fig.elbows[1.0] as Node3D).rotation.x; var hip_y := fig.pelvis.position.y
	fig.set_meta("part_c", 1.0)
	for i in 40: await process_frame
	var torso2 := fig.torso.rotation.x; var hp_r2: float = (fig.hips[1.0] as Node3D).rotation.x; var kn2: float = (fig.knees[1.0] as Node3D).rotation.x
	var shx2: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz2: float = (fig.shoulders[1.0] as Node3D).rotation.z; var elx2: float = (fig.elbows[1.0] as Node3D).rotation.x; var hip_y2 := fig.pelvis.position.y
	fig.set_meta("part_v", -1.0)
	for i in 40: await process_frame
	var hp_r3: float = (fig.hips[1.0] as Node3D).rotation.x; var kn3: float = (fig.knees[1.0] as Node3D).rotation.x
	var shx3: float = (fig.shoulders[1.0] as Node3D).rotation.x; var elx3: float = (fig.elbows[1.0] as Node3D).rotation.x
	print("POSE early=%.3f (≈ 0, before the arms come up) parting: torso=%.3f (want ≈ 0.126 ± 0.009: bowed forward) hip=%.2f (want −0.25) knee=%.2f (want 0.45) arm x=%.2f (want −1.60 ± 0.15: in front at chest height) elbow=%.2f (want −0.7..−1.1) hip_y=%.2f (want 0.39) | caught: torso=%.3f (want ≈ −0.036 ± 0.009) hip=%.2f (want −0.04..−0.20: dangling) knee=%.2f (want 0.25) arm x=%.2f (want −2.30) arm z=%.2f (want −0.65: out to the side) elbow=%.2f (want −0.70) hip_y=%.2f (want 0.45) | sliding: hip=%.2f (want −0.34..−0.50: knees up) knee=%.2f (want 0.70) arm x=%.2f (want −2.80) elbow=%.2f (want −0.30)" % [early, torso, hp_r, kn, shx, elx, hip_y, torso2, hp_r2, kn2, shx2, shz2, elx2, hip_y2, hp_r3, kn3, shx3, elx3])
	# 진짜 탑: 1..60층에 plan 이 찾는 커튼 — 공중 정원 층 5, 6, 8, 9, 40, 41, 42, 44 중 넓은 선 발판이 맞는 층(7, 43 은 통풍구 층)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var g: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl := cv.plan(n, g.band(n))
		if pl.size() > 0: bands.append("%d:%d" % [n, pl.size()]); count += pl.size()
	print("TOWER floors=", bands, " curtains=", count, " (want a subset of 5, 6, 8, 9, 40, 41, 42, 44, one each)")
	quit()
