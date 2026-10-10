extends SceneTree
## 풍향계 팩 점검(헤드리스): 자료가 읽히나, 바람 절벽 층의 잇단 두 still 발판 사이 틈(70..170, 높이차 140 안) 중 쓸 상자를 다른 판이 가르지 않고 taken 조각(연)이 닿지 않는 가장 넓은 하나에만 풍향계가 서나(바람 있는 층은 건너편이 바람 아래쪽인 짝만, 지름길 판이 틈에 있으면 진다, 움직이는 발판 옆 틈은 아니다, 다른 테마 층은 아니다),
## 리본 끝 손 범위 안에서 ↑ 만 grab 이 받나(옆으로 먼 손·높이 먼 손·앞뒤 밖·이미 매달린 것·되감기는 중은 아니다), 매달리면 0.25초에 리본이 6 늘어나고 1.6초에 반 바퀴 돌아 몸을 건너편으로 실어 가며(가운데서 속도 비 1) 멈춤쇠에서 0.3초에 걸쳐 발판에 내려놓나(메타도),
## 도는 가운데서 놓으면 깃의 옆 속도(223.84)를 주나, 놓인 뒤 1.5초는 안 받나, 되감기가 π/2 에서 0.75초 뒤 π/4 쯤이고 1.5초 뒤 제자리인가, 바람이 셀수록 빨리 도나(90 → 1.16, 180 → 0.91), 빈 풍향계가 바람만큼 떠나, 받침대·기둥·십자·글자판 넷·축·화살(대·촉·깃)·리본·creak·clack 이 그려지나, 리본이 깃 끝에서 손까지 뻗나,
## trail 자세가 오른팔을 머리 위로·왼팔을 옆으로 활짝 들고 다리를 젓다 내려놓으면 앞으로 내리나, 진짜 탑의 1..60층에서 plan 이 바람 절벽 층(20..24, 55..59)에만 풍향계를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cv := ClimbVane.new(); root.add_child(cv)
	var ck := ClimbKite.new(); root.add_child(ck)
	await process_frame
	print("PACK id=", cv.pack.get("id"), " kind=", cv.kind.size() > 0, " pose=", cv.pack.get("pose"), " themes=", cv.pack.get("themes"), " hang=%.0f (want 58) pennant=%.0f (want 14) over=%.0f (want 26) post_h=%.0f (want 96) take=%.2f land=%.2f return=%.2f (want 0.25 0.30 1.50) turn(0)=%.2f turn(90)=%.4f turn(180)=%.4f turn(300)=%.4f (want 1.60 1.1636 0.9143 0.9143) rate(0.5)=%.2f (want 1.00)" % [cv.hang(), cv.pennant(), cv.over(), cv.post_h(), cv.take_s(), cv.land_s(), cv.return_s(), cv.turn_s(0.0), cv.turn_s(90.0), cv.turn_s(180.0), cv.turn_s(300.0), ClimbVane.rate(0.5)])
	var plats: Array = [
		{ "id": "20r", "x": 250.0, "y": 11900.0, "w": 400.0, "kind": "rest", "z": 0.0, "d": 180.0 },
		{ "id": "20.0", "x": 100.0, "y": 12100.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "20.1", "x": 380.0, "y": 12210.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "20.2", "x": 620.0, "y": 12320.0, "w": 200.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "20.3", "x": 400.0, "y": 12430.0, "w": 160.0, "kind": "ice", "z": -35.0, "d": 70.0 },
		{ "id": "20.4", "x": 200.0, "y": 12540.0, "w": 170.0, "kind": "move", "z": -35.0, "d": 70.0 },
		{ "id": "20.5", "x": 25.0, "y": 12650.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "20s", "x": 680.0, "y": 12468.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var free := cv.plan(20, plats)
	var kited := cv.plan(20, plats, 0.0, [{ "id": "20.K0", "kind": "kite", "x": 280.0, "w": 100.0, "y": 12230.0 }])
	var against := cv.plan(20, plats, -90.0); var with := cv.plan(20, plats, 90.0)
	var cut := plats.duplicate(true); cut.append({ "id": "20c", "x": 300.0, "y": 12250.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 })   # 첫 틈에 지름길 판 — 깃이 걸린다
	var cutp := cv.plan(20, cut)
	var one := cv.plan(21, plats); var clock := cv.plan(19, plats); var cloud := cv.plan(25, plats); var high := cv.plan(55, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cv.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " %s-%s gap %.0f hx %.0f dir %.0f arm %.0f feet %.0f tail %.0f post %.0f x %.0f turn %.2f" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"]), float(v["hx"]), float(v["dir"]), float(v["arm"]), float(v["feet_y"]), float(v["tail_y"]), float(v["post_y"]), float(v["x"]), float(v["turn"])]
	print("PLAN free=", free.map(show), " (want 1: 20.V0 20.0-20.1 gap 100 hx 330 dir 1 arm 76 feet 12222 tail 12294 post 12192 x 280 turn 1.60 — 20.1-20.2 is 90, 20.2-20.3 is 60 → out, 20.4 moves → out)")
	print("PLAN kited=", kited.map(show), " (want 20.V0 20.1-20.2 gap 90 hx 575 arm 71 feet 12332 tail 12404 post 12302: the kite takes the first gap) against=", against.size(), " (want 0: every pair runs +x, the wind −90 refuses) with=", with.map(show), " (want 20.0-20.1, turn 1.16) cut=", cutp.map(show), " (want 20.1-20.2: a shortcut slab in the first gap) one=", one.size(), " clock=", clock.size(), " cloud=", cloud.size(), " high=", high.size(), " (want 1 0 0 1)")
	var s: Dictionary = cv.vanes[0]
	var z := C.PLAYER_Z
	# 잡기(t 1): 리본 끝(254, 12280) 밑 hang 의 몸(254, 12222) → 잡는다; x 300 옆·y 12300 높이·z 20 앞은 아니다; 이미 매달린 것은 다시 안 받는다
	cv.sync(1.0)
	var g_side := cv.grab(300.0, 12222.0, z); var g_high := cv.grab(254.0, 12300.0, z); var g_front := cv.grab(254.0, 12222.0, 20.0)
	var g_ok := cv.grab(254.0, 12222.0, z)
	var creak: AudioStreamPlayer3D = s["creak"]; var creak_on := creak.playing
	var g_twice := cv.grab(254.0, 12222.0, z)
	print("GRAB side=%s high=%s front=%s (want true ×3: empty) | ok kind=%s x=%.1f y=%.0f dir=%.0f held=%s creak=%s (want vane 254.0 12222 1 true true) twice=%s (want true: empty)" % [g_side.is_empty(), g_high.is_empty(), g_front.is_empty(), g_ok.get("kind", "-"), float(g_ok.get("x", 0.0)), float(g_ok.get("y", 0.0)), float(g_ok.get("dir", 0.0)), bool(s["held"]), creak_on, g_twice.is_empty()])
	# 매달린 길: 1.1 → 리본 2.112 늘어남(y 12219.89, x 254, v 0); 2.05 → 가운데(u 0.5, x 330, y 12216, v 1.0, 속도 223.84); 2.85 → 멈춤쇠(x 406, clack, set 시작); 3.0 → 내려놓는 중(y 12213, set 0.5); 3.15 → done(y 12210), 그 뒤 lost
	var fig := Stick3D.new(); root.add_child(fig)
	cv.sync(1.1); var r1 := cv.hang_on(g_ok, fig); var v1 := float(fig.get_meta("trail_v", 9.0))
	cv.sync(2.05); var r2 := cv.hang_on(g_ok, fig); var v2 := float(fig.get_meta("trail_v", 9.0)); var k2 := float(fig.get_meta("trail_k", 9.0)); var sp2 := cv.speed(s, 2.05)
	cv.sync(2.85); var r3 := cv.hang_on(g_ok, fig); var clack: AudioStreamPlayer3D = s["clack"]; var clack_on := clack.playing
	cv.sync(3.0); var r4 := cv.hang_on(g_ok, fig); var st4 := float(fig.get_meta("trail_set", 9.0))
	cv.sync(3.16); var r5 := cv.hang_on(g_ok, fig)
	cv.sync(3.3); var r6 := cv.hang_on(g_ok, fig)
	print("HANG 1.1: x=%.0f y=%.2f v=%.2f (want 254 12219.89 0.00) | 2.05: x=%.0f y=%.0f v=%.2f k=%.2f speed=%.2f (want 330 12216 1.00 0.50 223.84) | 2.85: x=%.0f y=%.0f done=%s clack=%s (want 406 12216 false true) | 3.0: y=%.0f set=%.2f (want 12213 0.50) | 3.16: y=%.0f done=%s (want 12210 true) | 3.3: lost=%s held=%s (want true false)" % [float(r1["x"]), float(r1["y"]), v1, float(r2["x"]), float(r2["y"]), v2, k2, sp2, float(r3["x"]), float(r3["y"]), r3["done"], clack_on, float(r4["y"]), st4, float(r5["y"]), r5["done"], r6["lost"], bool(s["held"])])
	# 되감기: 3.3·4.6 은 안 받고(놓인 3.16 + 1.5초) 4.7 은 받는다; 4.7 에 잡고 5.75 가운데서 놓으면 vx 223.84 vy 0, 그 뒤 lost; 되감기 6.5 에 π/4 쯤(±0.02), 7.3 에 제자리(|·| ≤ 0.02)
	cv.sync(3.3); var g_wait := cv.grab(254.0, 12222.0, z); cv.sync(4.6); var g_wait2 := cv.grab(254.0, 12222.0, z); cv.sync(4.7); var g_home := cv.grab(254.0, 12222.0, z)
	cv.sync(5.75); var lg_mid := cv.let_go(g_home); var lost_mid := cv.hang_on(g_home, fig)
	var a65 := cv.ang(s, 6.5); var a73 := cv.ang(s, 7.3)
	print("RETURN 3.3=%s 4.6=%s (want true true: empty) 4.7=%s (want false: home again) | mid let-go: vx=%.2f vy=%.0f lost=%s (want 223.84 0 true) | ang 6.5=%.3f (want 0.785 ± 0.02) 7.3=%.3f (want |·| ≤ 0.02)" % [g_wait.is_empty(), g_wait2.is_empty(), g_home.is_empty(), float(lg_mid["vx"]), float(lg_mid["vy"]), lost_mid["lost"], a65, a73])
	# 그림: 노드 아이 13(받침대·기둥·팔 둘·글자판 넷·축·화살·리본·creak·clack), 화살 아이 3(대·촉·깃); 노드 자리 −4.167 338.667 −0.972; 빈 화살은 바람 0 에 |0.02| 안, 바람 120 이면 떨림 |0.06| 안(> 0.04); 가운데 매달리면 화살 π/2, 리본은 깃 끝에서 손까지 2.534; 빈 채 제자리면 0.389
	var node: Node3D = s["node"]; var vane: Node3D = s["vane"]; var rib: Node3D = s["ribbon"]
	cv.sync(9.0); cv._process(0.0); var rot_empty := vane.rotation.y; var rib_empty := rib.scale.z
	s["wind"] = 120.0; var q_max := 0.0
	for i in 40: q_max = maxf(q_max, absf(cv.quiver(s, 9.0 + float(i) * 0.05)))
	s["wind"] = 0.0
	cv.sync(10.0); var g_vis := cv.grab(254.0, 12222.0, z); cv.sync(11.05); cv._process(0.0); var rot_mid := vane.rotation.y; var rib_mid := rib.scale.z; cv.let_go(g_vis)
	print("VISUAL node children=", node.get_child_count(), " (want 13) vane children=", vane.get_child_count(), " (want 3) node pos=%.3f %.3f %.3f (want −4.167 338.667 −0.972) | empty: rot=%.3f (want |·| ≤ 0.02) ribbon=%.3f (want 0.389) | wind 120: max quiver=%.3f (want ≤ 0.06, > 0.04) | mid: rot=%.3f (want 1.571) ribbon=%.3f (want 2.534) grabbed=%s (want false)" % [node.position.x, node.position.y, node.position.z, rot_empty, rib_empty, q_max, rot_mid, rib_mid, g_vis.is_empty()])
	# 자세: 유지(v 1, set 0): 오른어깨 −3.00 오른팔꿈치 −0.10, 왼어깨 z +1.30 왼팔꿈치 −0.30, 골반 높이 0.450, 엉덩이 둘이 다르다(젓는다); 내려놓기(set 1): 엉덩이 −0.15 −0.15, 무릎 0.25 0.25, 골반 0.420, 오른어깨 그대로 −3.00
	fig.pose_request = "trail"
	fig.set_meta("trail_v", 1.0); fig.set_meta("trail_set", 0.0); fig.set_meta("trail_k", 0.5)
	for i in 90: await process_frame
	var sh_r: float = (fig.shoulders[1.0] as Node3D).rotation.x; var el_r: float = (fig.elbows[1.0] as Node3D).rotation.x; var shz_l: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var el_l: float = (fig.elbows[-1.0] as Node3D).rotation.x
	var pel_y := fig.pelvis.position.y; var hip_a: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_b: float = (fig.hips[-1.0] as Node3D).rotation.x; var neck_up := fig.neck.rotation.x
	fig.set_meta("trail_set", 1.0)
	for i in 60: await process_frame
	var hip_r: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_l: float = (fig.hips[-1.0] as Node3D).rotation.x; var knee_r: float = (fig.knees[1.0] as Node3D).rotation.x; var knee_l: float = (fig.knees[-1.0] as Node3D).rotation.x
	var pel_y2 := fig.pelvis.position.y; var sh_r2: float = (fig.shoulders[1.0] as Node3D).rotation.x; var neck_dn := fig.neck.rotation.x
	print("POSE hang: shoulder r=%.2f elbow r=%.2f (want −3.00 −0.10) shoulder l z=%.2f elbow l=%.2f (want 1.30 −0.30) pelvis y=%.3f (want 0.450) hips=%.2f %.2f (want unequal: pedalling) neck=%.2f (want < 0: the vane) | set: hips=%.2f %.2f knees=%.2f %.2f (want −0.15 −0.15 0.25 0.25) pelvis y=%.3f (want 0.420) shoulder r=%.2f (want −3.00) neck=%.2f (want > hang's: the hop)" % [sh_r, el_r, shz_l, el_l, pel_y, hip_a, hip_b, neck_up, hip_r, hip_l, knee_r, knee_l, pel_y2, sh_r2, neck_dn])
	# 진짜 탑: 1..60층에 plan 이 찾는 풍향계 — 바람 절벽 층 20..24, 55..59 중 연이 안 가져간 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var out := cv.plan(n, pl, gm.wind_of(n), ck.plan(n, pl, gm.wind_of(n)))
		if out.size() > 0: bands.append("%d:%s" % [n, out.map(func(v: Dictionary) -> String: return "%s-%s gap %.0f dy %.0f wind %.0f turn %.2f" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"]), absf(float(v["b_y"]) - float(v["a_y"])), float(v["wind"]), float(v["turn"])])]); count += out.size()
	var windy: Array = []   # 55..59: 그 층의 바람, 연 없이 셌을 때의 풍향계, 연의 수 — 바람을 거스르는 지그재그와 연이 가져간 틈을 읽는다
	for n in range(55, 60):
		var pl: Array = gm.band(n)
		windy.append("%d: wind %.0f alone %d kite %d" % [n, gm.wind_of(n), cv.plan(n, pl, gm.wind_of(n)).size(), ck.plan(n, pl, gm.wind_of(n)).size()])
	print("TOWER floors=", bands, " vanes=", count, " (want a subset of 20..24, 55..59 — one each) windy=", windy)
	quit()
