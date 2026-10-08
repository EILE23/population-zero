extends SceneTree
## 구름 뗏목 팩 점검(헤드리스): 자료가 읽히나, 구름바다 층의 선 발판(std·ice·spring·crumble) 사이 틈 하나에만 뗏목이 뜨나(가장 긴 틈 한둘은 그 층의 다른 팩 몫 — 다리·유령 층은 하나, 버섯 층은 둘; 지름길 판이 가르는 틈은 지고, 통풍구 층·다른 테마 층은 아니다),
## 너비·흐름 폭이 기하대로 나와 턱에서 margin 을 남기고 멈추나, 흐름이 sin 으로 오가고 속도가 끝에서 0 인가, 지금 자리의 윗면을 지나 떨어지는 몸만 land 가 받나(옆·앞뒤 밖·흘러간 뒤의 빈자리는 아니다),
## 서 있으면 흐름에 실려 가고 가라앉으며 메타가 적히나, 턱 밖이면 off 인가, 비면 도로 떠오르나, 솜 덩이들이 그려지고 눌리면 납작해지며 발이 닿는 틱에 푹 소리가 나나,
## wade 자세가 가라앉을수록 골반이 내려가고 서면 팔을 옆으로 들고 걸으면 무릎을 높이 드나, 진짜 탑의 1..65층에서 plan 이 구름바다 층에만 뗏목을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cr := ClimbRaft.new(); root.add_child(cr)
	await process_frame
	print("PACK id=", cr.pack.get("id"), " kind=", cr.kind.size() > 0, " pose=", cr.pack.get("pose"), " themes=", cr.pack.get("themes"), " drift=%.1f (want 6.0) sink=%.0f (want 36)" % [cr.drift_s(), cr.sink_max()])
	var plats: Array = [
		{ "id": "28.0", "x": 100.0, "y": 16900.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "28.1", "x": 380.0, "y": 17010.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "28.2", "x": 650.0, "y": 17120.0, "w": 160.0, "kind": "ice", "z": -35.0, "d": 70.0 },
		{ "id": "28.3", "x": 400.0, "y": 17230.0, "w": 120.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "28.4", "x": 200.0, "y": 17340.0, "w": 110.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "28.5", "x": 25.0, "y": 17450.0, "w": 90.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "28s", "x": 560.0, "y": 17200.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var planned := cr.plan(28, plats)
	var two := cr.plan(25, plats)
	var vent := cr.plan(27, plats)
	var other := cr.plan(30, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cr.build(band_root, planned)
	print("PLAN n28=", planned.size(), " (want 1: gaps 100 (28.0↔28.1), 120 (28.1↔28.2), 130 (28.2↔28.3, cut by the short slab 28s in its drift box → out), 90 (28.3↔28.4), 85 (28.4↔28.5, under min_gap → out) — a bridge floor leaves the longest, 120, so the 100 gap gets the raft: hx 330, w 50, amp 15 = (100 − 50)/2 − 10, y 16955 the mean of 16900 and 17010) ids=", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + " hx %.0f w %.0f amp %.0f y %.0f x %.0f a_y %.0f b_y %.0f" % [float(v["hx"]), float(v["w"]), float(v["amp"]), float(v["y"]), float(v["x"]), float(v["a_y"]), float(v["b_y"])]), " n25=", two.map(func(v: Dictionary) -> String: return String(v["id"]) + " hx %.0f w %.0f amp %.0f y %.0f" % [float(v["hx"]), float(v["w"]), float(v["amp"]), float(v["y"])]), " (want 25.c0 hx 355 w 50 amp 10 y 17285: a mushroom floor leaves two, 120 and 100, so the 90 gap) n27=", vent.size(), " n30=", other.size(), " (want 0 0: vent floor, Starlit) nodes=", band_root.get_child_count())
	var s: Dictionary = cr.rafts[0]
	# 흐름: 위상 0 이라 t 0 은 한가운데(330)로 +x 로 가는 중, 1.5 는 +x 끝(345, 멈춤), 3.0 은 한가운데로 −x 로, 4.5 는 −x 끝(315)
	print("DRIFT cx t0 %.1f (want 330) 1.5 %.1f (want 345: the hop 28.1's edge 380 − margin 10 − half 25) 3.0 %.1f (want 330) 4.5 %.1f (want 315: 28.0's edge 280 + 10 + 25) | vx t0 %.1f (want 15.7 = 15 × 2π / 6) 1.5 %.1f (want 0) 3.0 %.1f (want −15.7) | top unloaded %.0f (want 16955)" % [cr.cx(s, 0.0), cr.cx(s, 1.5), cr.cx(s, 3.0), cr.cx(s, 4.5), cr.vx(s, 0.0), cr.vx(s, 1.5), cr.vx(s, 3.0), cr.top(s)])
	# 착지(t 0, 뗏목 305..355): 윗면 16955 를 지나 떨어지는 몸 → 받는다; 옆(x 400)·앞뒤 밖·위를 지나지 않는 몸은 아니다; t 1.5 엔 뗏목이 320..370 이라 x 300 은 빈자리
	cr.t = 0.0
	var l_ok := cr.land(330.0, 16960.0, 16950.0, float(s["z"]))
	var l_side := cr.land(400.0, 16960.0, 16950.0, float(s["z"]))
	var l_z := cr.land(330.0, 16960.0, 16950.0, float(s["z"]) + 100.0)
	var l_above := cr.land(330.0, 16990.0, 16970.0, float(s["z"]))
	cr.t = 1.5
	var l_gone := cr.land(300.0, 16960.0, 16950.0, float(s["z"]))
	var l_moved := cr.land(365.0, 16960.0, 16950.0, float(s["z"]))
	print("LAND ok=%s x=%.0f y=%.0f (want 28.c0 305 16955) | side=%s far_z=%s above=%s (want all empty) | t1.5 at x 300=%s (want empty — the raft drifted to 320..370) at x 365=%s (want 28.c0: it is there now)" % [l_ok.get("id", "-"), float(l_ok.get("x", 0.0)), float(l_ok.get("y", 0.0)), l_side.get("id", "-"), l_z.get("id", "-"), l_above.get("id", "-"), l_gone.get("id", "-"), l_moved.get("id", "-")])
	# 서기: t 0 → 0.1 에 한 틱 — 흐름만큼 실려 간다(330 + 15 sin(2π·0.1/6) = 331.6), off 는 아니다; x 400 은 off; 모르는 id 는 off
	var fig := Stick3D.new(); root.add_child(fig)
	s["load"] = 0.0; s["stood"] = -9.0
	cr.t = 0.1
	var st := cr.stand(l_ok, 330.0, 0.1, fig, 1.0)
	var m_k := float(fig.get_meta("wade_k", 9.0)); var m_w := float(fig.get_meta("wade_w", 9.0))
	var st_off := cr.stand(l_ok, 400.0, 0.1)
	var st_lost := cr.stand({ "id": "nope", "y": 2.0 }, 1.0, 0.1)
	print("STAND x=%.1f y=%.0f off=%s (want 331.6 16955 false) meta k=%.2f w=%.1f (want 0.00 1.0) | x 400: off=%s (want true) | unknown id: off=%s y=%.0f (want true 2)" % [float(st["x"]), float(st["y"]), st["off"], m_k, m_w, st_off["off"], st_lost["off"], float(st_lost["y"])])
	# 가라앉기: 로더처럼 매 틱 stand 다음 _process — 0.75 초(15 × 0.05) 뒤 load 0.5, 윗면 16955 − 36 × 0.5 × 1.5 = 16928, 납작 0.89; 비우고 2 초 뒤 load 0, 윗면 16955
	cr.t = 0.0
	for i in 15:
		cr.stand(l_ok, 330.0, 0.05, fig)
		cr._process(0.05)
	var load_half := float(s["load"]); var top_half := cr.top(s); var sq: float = (s["node"] as Node3D).scale.y
	var pf: AudioStreamPlayer3D = s["puff"]
	var puffed := pf.playing
	for i in 40: cr._process(0.05)
	var load_up := float(s["load"]); var top_up := cr.top(s)
	print("SINK after 0.75 s standing: load=%.2f top=%.0f (want 0.50 16928) squash y=%.2f (want 0.89) puffed=%s (want true: the first loaded tick) | 2 s empty: load=%.2f top=%.0f (want 0.00 16955)" % [load_half, top_half, sq, puffed, load_up, top_up])
	# 그림: 노드 아이 9(솜 다섯·그늘 솜 셋·푹); 노드가 흐름 x 에 있나
	cr.t = 1.5; cr._float(s)
	var node: Node3D = s["node"]
	print("VISUAL children=", node.get_child_count(), " (want 9) node x=%.3f (want %.3f: cx 345 in metres) puff stream=%s" % [node.position.x, C.to3(345.0, 0.0).x, pf.stream != null])
	# 자세: 서서 다 가라앉은 몸(k 1, w 0) — 골반 0.30 (0.42 − 0.12), 엉덩이 ≈ −0.45 ± 0.05, 무릎 ≈ 0.65 ± 0.08, 어깨 z −1.0 (옆으로 든 팔), 팔꿈치 −1.5; 걸으면(w 1) 엉덩이가 −1.15 까지 들리고 무릎이 1.4 까지 접힌다
	fig.pose_request = "wade"
	fig.set_meta("wade_k", 1.0); fig.set_meta("wade_w", 0.0)
	await process_frame; await process_frame; await process_frame
	var early := fig.pelvis.position.y
	for i in 40: await process_frame
	var hip_y := fig.pelvis.position.y; var hp: float = (fig.hips[1.0] as Node3D).rotation.x; var kn: float = (fig.knees[1.0] as Node3D).rotation.x
	var shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var elx: float = (fig.elbows[1.0] as Node3D).rotation.x; var torso := fig.torso.rotation.x
	fig.set_meta("wade_w", 1.0)
	var lo := 10.0; var hi := -10.0; var klo := 10.0; var khi := -10.0
	for i in 80:
		await process_frame
		var v: float = (fig.hips[1.0] as Node3D).rotation.x; var kv: float = (fig.knees[1.0] as Node3D).rotation.x
		lo = minf(lo, v); hi = maxf(hi, v); klo = minf(klo, kv); khi = maxf(khi, kv)
	var torso_w := fig.torso.rotation.x
	print("POSE early=%.2f (want 0.38..0.42: the brace has only begun) standing sunk: hip_y=%.2f (want 0.30) hip=%.2f (want −0.45 ± 0.05) knee=%.2f (want 0.65 ± 0.08) arm z=%.2f (want −1.00: held out) elbow=%.2f (want −1.50) torso=%.3f (want ≈ 0.036) | walking: hip lo=%.2f hi=%.2f (want lo ≤ −1.0, hi ≥ 0.0: knees up, legs trailing) knee lo=%.2f hi=%.2f (want lo ≤ 0.5, hi ≥ 1.2) torso=%.3f (want ≈ 0.11, leaning in)" % [early, hip_y, hp, kn, shz, elx, torso, lo, hi, klo, khi, torso_w])
	# 진짜 탑: 1..65층에 plan 이 찾는 뗏목 — 구름바다 층 25, 26, 28, 29, 60, 61, 62, 64 중 틈이 맞는 층(27, 63 은 통풍구 층)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var g: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 66):
		var pl := cr.plan(n, g.band(n))
		if pl.size() > 0: bands.append("%d:%d" % [n, pl.size()]); count += pl.size()
	print("TOWER floors=", bands, " rafts=", count, " (want a subset of 25, 26, 28, 29, 60, 61, 62, 64, one each)")
	quit()
