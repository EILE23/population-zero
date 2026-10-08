extends SceneTree
## 풍차 날 팩 점검(헤드리스): 자료가 읽히나, min_gap..max_gap·dy 안의 가장 긴 틈 하나에 바퀴가 걸리나(지름길 판이 원을 가르는 틈은 진다, 너무 짧은·긴 틈도), 날 길이가 기하대로 나와 컵이 아래 턱 끝을 그 높이에서·반 바퀴 뒤 위 턱 끝을 그 높이에서 지나나,
## 컵 바닥을 지나는 몸과 catch 안에서 내려서는 몸만 land 가 받나(멀리 위·컵 밖·앞뒤 밖은 아니다), 타면 컵 안의 제자리를 지키며 반 바퀴 실려 가나, 컵 밖으로 걸어 나가면 off 인가, 살에 닿은 공중의 몸을 옆·위로 밀어내나(위의 몸은 아니다),
## 날·컵·축이 그려지고 컵이 수평을 지키나, 딸깍이 아래 턱 높이를 지날 때 울리나, ride 자세가 가는 방향의 반대로 기울고 오를 때 무릎이 더 접히나, 진짜 탑의 1..40층에서 plan 이 바퀴를 몇 개 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var wm := ClimbWindmill.new(); root.add_child(wm)
	await process_frame
	print("PACK id=", wm.pack.get("id"), " kind=", wm.kind.size() > 0, " pose=", wm.pack.get("pose"))
	var plats: Array = [
		{ "id": "7.0", "x": 100.0, "y": 4300.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "7.1", "x": 380.0, "y": 4410.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "7.2", "x": 560.0, "y": 4520.0, "w": 160.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "7.3", "x": 200.0, "y": 4630.0, "w": 120.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "7.4", "x": 0.0, "y": 4740.0, "w": 60.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "7s", "x": 100.0, "y": 4700.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var planned := wm.plan(7, plats)
	var none := wm.plan(8, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	wm.build(band_root, planned)
	print("PLAN n7=", planned.size(), " (want 1: the 100 gap 7.0↔7.1 — hub 330,4355, len √(30²+55²) = 62.6, dir −1 (clockwise, the upper hop on the right), a_y 4300; the 140 gap 7.3↔7.4 is longest but the short slab 7s cuts its disc, 30 is too short, 240 too long) ids=", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + " hub %.0f,%.0f len %.1f dir %.0f a_y %.0f" % [float(v["hx"]), float(v["hy"]), float(v["len"]), float(v["dir"]), float(v["a_y"])]), " n8=", none.size(), " nodes=", band_root.get_child_count())
	var s: Dictionary = wm.wheels[0]
	var len := float(s["len"])
	# 컵의 길: 날 0 의 컵이 아래 턱 높이(4300)에 오르며 닿는 시각 — 각 π + asin(55/len), dir −1 이라 t = (2π − 각)/ω
	var ta := (TAU - (PI + asin(55.0 / len))) / wm.omega()
	var p0 := wm.tip(s, 0, ta); var p1 := wm.tip(s, 0, ta + 1.25); var p2 := wm.tip(s, 0, ta + 2.5); var p3 := wm.tip(s, 0, ta + 3.75)
	var v0 := wm.vel(s, 0, ta); var v1 := wm.vel(s, 0, ta + 1.25)
	print("CUP t=%.3f at %.1f,%.1f (want 300,4300: the lower hop's edge 280 + clear 8 + half cup 12, at its height) | +1.25 s %.1f,%.1f (want ≈ 275,4385 — top-left, rising) | +2.5 s %.1f,%.1f (want 360,4410: the upper hop's edge 380 − 8 − 12, at its height) | +3.75 s %.1f,%.1f (bottom-right, going down) | vel at t %.2f,%.2f (want −0.88,0.48: left and up) at +1.25 %.2f,%.2f (want 0.48,0.88: right and up)" % [ta, p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, v0.x, v0.y, v1.x, v1.y])
	# 착지(t = ta): 컵 바닥 4303 위 5px 에서 5px 아래로 → 받는다; 10px 위에서 내려서는 몸 → step; 20px 위 → 아니다; 컵 밖(x +13) → 아니다; 앞뒤 밖 → 아니다
	wm.t = ta
	var sy := wm.surf(s, 0, 300.0, ta); var sy_out := wm.surf(s, 0, 313.0, ta)
	var l_cross := wm.land(300.0, sy + 5.0, sy - 5.0, float(s["z"]))
	var l_step := wm.land(304.0, sy + 10.0, sy + 9.0, float(s["z"]))
	var l_high := wm.land(300.0, sy + 20.0, sy + 19.0, float(s["z"]))
	var l_side := wm.land(313.0, sy + 5.0, sy - 5.0, float(s["z"]))
	var l_z := wm.land(300.0, sy + 5.0, sy - 5.0, float(s["z"]) + 100.0)
	print("LAND surf=%.1f (want 4303) out=%s (want nan) | cross=%s arm=%s y=%.1f step=%s (want 7.w0 0 4303.0 false) | catch=%s step=%s (want 7.w0 true) | high=%s side=%s far_z=%s (want all empty)" % [sy, is_nan(sy_out), l_cross.get("id", "-"), l_cross.get("arm", "-"), float(l_cross.get("y", 0.0)), l_cross.get("step", "-"), l_step.get("id", "-"), l_step.get("step", "-"), l_high.get("id", "-"), l_side.get("id", "-"), l_z.get("id", "-")])
	# 타기: 컵 가운데에서 +4 치우친 몸이 반 바퀴 실려 간다 — 치우침을 지키고, 메타에 속도가 적히고, 위 턱 높이에 닿는다; 컵 밖으로 걸어 나가면 off
	var fig := Stick3D.new(); root.add_child(fig)
	wm.t = ta + 1.25
	var r1 := wm.ride(l_step, 304.0, 1.25, fig)
	var k1 := float(fig.get_meta("ride_k", 9.0)); var vv1 := float(fig.get_meta("ride_v", 9.0))
	wm.t = ta + 2.5
	var r2 := wm.ride(l_step, float(r1["x"]), 1.25, fig)
	var r3 := wm.ride(l_step, float(r2["x"]) + 30.0, 0.0001, fig)
	var r_lost := wm.ride({ "id": "nope", "y": 1.0 }, 5.0, 0.016)
	print("RIDE +1.25: x=%.1f y=%.1f off=%s (want ≈ 279.0 4388.0 false — the +4 kept) meta k=%.2f v=%.2f (want 0.48 0.88) | +2.5: x=%.1f y=%.1f off=%s (want 364.0 4413.0 false — level with the upper hop) | walked 30 out: off=%s (want true) | unknown id: off=%s (want true)" % [float(r1["x"]), float(r1["y"]), r1["off"], k1, vv1, float(r2["x"]), float(r2["y"]), r2["off"], r3["off"], r_lost["off"]])
	# 밀치기(t = ta): 날 1 은 각 ta + 120° ≈ 1.5°(오른쪽으로 거의 수평, 내려가는 쪽) — 살의 u 30 자리 (360, 4356) 에 걸린 몸(y 4330..4370) 은 오른쪽·위로 밀린다; 그 위 4380 의 몸은 아니다; 컵 가까이(u ≥ len − cup_w)는 세지 않는다
	wm.t = ta
	var a1 := wm.ang(s, 1, ta)
	var sw_hit := wm.sweep(330.0 + 30.0 * cos(a1), 4330.0, float(s["z"]))
	var sw_miss := wm.sweep(330.0 + 30.0 * cos(a1), 4380.0, float(s["z"]))
	var sw_cup := wm.sweep(330.0 + (len - 6.0) * cos(a1), 4355.0 + (len - 6.0) * sin(a1) - 20.0, float(s["z"]))
	print("SWEEP arm1 angle=%.1f° hit vx=%s vy=%s (want 220 240: the sail on the right is going down, so sideways means +x) | above: %s (want empty) | at the cup: %s (want empty — that is where a body stands)" % [rad_to_deg(fposmod(a1, TAU)), sw_hit.get("vx", "-"), sw_hit.get("vy", "-"), sw_miss.size(), sw_cup.size()])
	# 그림: 노드 아이 6(축대·축·날 셋·딸깍), 날마다 3(살·뼈대·컵), 컵마다 3(바닥·턱 둘); 컵은 날과 반대로 돌아 수평; 딸깍은 아래 턱 높이를 지나는 프레임에
	wm.t = ta - 0.02; await process_frame
	var arms: Array = s["arms"]; var cups: Array = s["cups"]
	var arm0: Node3D = arms[0]; var cup0: Node3D = cups[0]
	var level := absf(fposmod(arm0.rotation.z + cup0.rotation.z, TAU)) < 0.001 or absf(fposmod(arm0.rotation.z + cup0.rotation.z, TAU) - TAU) < 0.001
	var ck: AudioStreamPlayer3D = s["clack"]
	var ticked := false
	for i in 40:
		await process_frame
		if ck.playing: ticked = true
	var node: Node3D = s["node"]
	print("VISUAL children=", node.get_child_count(), " (want 6) arm=", arm0.get_child_count(), " (want 3) cup=", cup0.get_child_count(), " (want 3) cup level=", level, " (want true) clack stream=", ck.stream != null, " clacked crossing 4300=", ticked, " (want true)")
	# 자세: +x 를 보며 앞으로·위로 가는 컵 — 몸통이 뒤로(음수), 무릎 접힘(오른 0.60), 팔 벌림(오른 어깨 z −0.5), 골반 0.32; 뒤로 가면 몸통이 앞으로(양수)
	fig.pose_request = "ride"; fig._yaw = PI / 2.0; fig._yaw_target = PI / 2.0
	fig.set_meta("ride_k", 1.0); fig.set_meta("ride_v", 1.0)
	await process_frame; await process_frame; await process_frame
	var early := fig.torso.rotation.x
	for i in 40: await process_frame
	var torso := fig.torso.rotation.x; var kn: float = (fig.knees[1.0] as Node3D).rotation.x; var shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var hip_y := fig.pelvis.position.y
	fig.set_meta("ride_k", -1.0); fig.set_meta("ride_v", -1.0)
	for i in 40: await process_frame
	var torso2 := fig.torso.rotation.x; var kn2: float = (fig.knees[1.0] as Node3D).rotation.x; var shz2: float = (fig.shoulders[1.0] as Node3D).rotation.z
	print("POSE early=%.3f (≈ 0, before the brace) forward+rising: torso=%.3f (want ≈ −0.135: leaning back) knee=%.2f (want 0.60) arm z=%.2f (want −0.50) arm x=%.2f (want −0.45: arms forward) hip_y=%.2f (want 0.32) | back+falling: torso=%.3f (want ≈ +0.135) knee=%.2f (want 0.10) arm z=%.2f (want −1.10: arms float up)" % [early, torso, kn, shz, shx, hip_y, torso2, kn2, shz2])
	# 진짜 탑: 1..40층에 plan 이 찾는 바퀴 수
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var g: Node3D = town.game_node
	var count := 0; var bands: Array = []; var lens: Array = []
	for n in range(1, 41):
		var pl := wm.plan(n, g.band(n))
		if pl.size() > 0: bands.append(n); count += pl.size()
		for v in pl: lens.append(int(float(v["len"])))
	print("TOWER floors=", bands, " wheels=", count, " lens=", lens, " (want every 4th floor from 7 — 7, 11 … 39 — one each where two std hops meet 90..200 px apart and 60..150 apart in height with nothing in the disc)")
	quit()
