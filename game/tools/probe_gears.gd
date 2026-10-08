extends SceneTree
## 톱니 컨베이어 팩 점검(헤드리스): 자료가 읽히나, 태엽 층의 std 발판(첫 것은 빼고, min_w 이상)에만 띠가 깔리나(얼음·좁은 턱·상승기류 층·다른 테마 층은 아니다), 시계가 간다 → 선다 → 돌아온다 → 선다로 돌고 flip·stagger 가 띠마다 다르나,
## 선 몸이 방향대로 실려 가고(멈추면 0) 자세의 메타(실려 가는 쪽·거슬러/같은 쪽 걷기·돌기 시작한 뒤의 초)가 적히나, 띠 없는 발판은 0 인가, boost 가 띠 방향의 speed 인가, 발판 옆에서 톱니에 닿은 공중의 몸만 띠 쪽·위로 밀리나(턱 위·멀리·아래는 아니다),
## 고무 띠·살·톱니 둘·clank 가 그려지고 살이 흐르며 톱니가 돌고 돌기 시작하는 틱에 clank 가 울리나, tread 자세가 실려 가는 쪽의 반대로 기울고 거슬러 걸으면 숙이며 휘청에 더 내려앉나, 진짜 탑의 1..60층에서 plan 이 태엽 층(16..18, 50, 52..54)에만 띠를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cg := ClimbGears.new(); root.add_child(cg)
	await process_frame
	print("PACK id=", cg.pack.get("id"), " kind=", cg.kind.size() > 0, " pose=", cg.pack.get("pose"), " themes=", cg.pack.get("themes"), " cycle=%.1f (want 11.2)" % cg.cycle())
	var plats: Array = [
		{ "id": "16.0", "x": 100.0, "y": 9700.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.1", "x": 380.0, "y": 9810.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.2", "x": 560.0, "y": 9920.0, "w": 160.0, "kind": "ice", "z": -35.0, "d": 70.0 },
		{ "id": "16.3", "x": 200.0, "y": 10030.0, "w": 100.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.4", "x": 400.0, "y": 10140.0, "w": 140.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16.5", "x": 150.0, "y": 10250.0, "w": 170.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "16s", "x": 700.0, "y": 10178.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var planned := cg.plan(16, plats)
	var vent := cg.plan(15, plats); var vent2 := cg.plan(19, plats); var other := cg.plan(20, plats); var again := cg.plan(50, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cg.build(band_root, planned)
	print("PLAN n16=", planned.size(), " (want 3: hops 16.1, 16.4, 16.5 — 16.0 is the floor's first std hop and stays plain, 16.2 is ice, 16.3 is 100 wide < min_w 110) ", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + " on " + String(v["hop"]) + " phase %.2f flip %.0f" % [float(v["phase"]), float(v["flip"])]), " (want phases 0, 3.47, 6.94 and flips 1, −1, 1) n15=", vent.size(), " n19=", vent2.size(), " (want 0, 0: updraft floors) n20=", other.size(), " (want 0: Wind cliffs) n50=", again.size(), " (want 3) nodes=", band_root.get_child_count())
	# 시계(띠 g0: phase 0, flip +1): 1 s 간다(+1, started 1, travel 90) → 5.3 s 선다(0, 9) → 7 s 돌아온다(−1, started 1.4, travel 324) → 10.9 s 선다 → 12.2 s 다시 간다; g1 은 flip −1 에 phase 3.47 이라 t 0 에 −1
	var s: Dictionary = cg.belts[0]; var s1: Dictionary = cg.belts[1]
	var d_a := cg.dir_at(s, 1.0); var d_b := cg.dir_at(s, 5.3); var d_c := cg.dir_at(s, 7.0); var d_d := cg.dir_at(s, 10.9); var d_e := cg.dir_at(s, 12.2); var d_1 := cg.dir_at(s1, 0.0)
	cg.t = 1.0; var st_a := cg.started(s); var tr_a := cg.travel(s, 1.0)
	cg.t = 5.3; var st_b := cg.started(s)
	cg.t = 7.0; var st_c := cg.started(s); var tr_c := cg.travel(s, 7.0)
	print("CLOCK g0: 1s dir=%.0f started=%.2f travel=%.0f (want 1 1.00 90) | 5.3s dir=%.0f started=%.0f (want 0 9) | 7s dir=%.0f started=%.2f travel=%.0f (want −1 1.40 324) | 10.9s dir=%.0f (want 0) | 12.2s dir=%.0f (want 1) | g1 at 0: dir=%.0f (want −1: flipped)" % [d_a, st_a, tr_a, d_b, st_b, d_c, st_c, tr_c, d_d, d_e, d_1])
	# 실려 가기(t = 1, g0 이 +x 로): +x 를 보는 몸은 0.1 s 에 9 px, 메타 k +1 / w 0 / j 1.0; 거슬러 걸으면 w −1, 같은 쪽이면 +1; 멈춘 띠(t 5.3)에선 0 px 에 걷기는 +1(보통 걸음); 띠 없는 발판은 0 에 belt_of 빈 사전; boost 는 90 / −90 / 0
	var fig := Stick3D.new(); root.add_child(fig); fig._yaw = PI / 2.0; fig._yaw_target = PI / 2.0
	var on := { "id": "16.1", "kind": "std" }; var plain := { "id": "16.0", "kind": "std" }
	cg.t = 1.0
	var c_a := cg.carry(on, 0.1, fig, 0.0); var k_a := float(fig.get_meta("tread_k", 9.0)); var w_a := float(fig.get_meta("tread_w", 9.0)); var j_a := float(fig.get_meta("tread_j", 9.0))
	cg.carry(on, 0.1, fig, -1.0); var w_b := float(fig.get_meta("tread_w", 9.0))
	cg.carry(on, 0.1, fig, 1.0); var w_c := float(fig.get_meta("tread_w", 9.0))
	var b_a := cg.boost(on)
	cg.t = 5.3
	var c_b := cg.carry(on, 0.1, fig, -1.0); var w_d := float(fig.get_meta("tread_w", 9.0)); var b_b := cg.boost(on)
	cg.t = 7.0
	var c_c := cg.carry(on, 0.1, fig, 0.0); var k_c := float(fig.get_meta("tread_k", 9.0)); var b_c := cg.boost(on)
	var c_p := cg.carry(plain, 0.1, fig, 0.0)
	print("CARRY 1s: dx=%.1f k=%.0f w=%.0f j=%.2f (want 9.0 1 0 1.00) against w=%.0f (want −1) with w=%.0f (want 1) boost=%.0f (want 90) | stalled 5.3s: dx=%.1f w=%.0f boost=%.0f (want 0.0 1 0) | 7s: dx=%.1f k=%.0f boost=%.0f (want −9.0 −1 −90) | plain hop: dx=%.1f belt_of empty=%s (want 0.0 true)" % [c_a, k_a, w_a, j_a, w_b, w_c, b_a, c_b, w_d, b_b, c_c, k_c, b_c, c_p, cg.belt_of(plain).is_empty()])
	# 물기(g0: 발판 380..530, 축 390·520, y 9807, 닿는 반지름 18): 오른쪽 끝 옆 x 536(상자 526..546)·y 9790 의 공중 몸 → t 1(+x)엔 +x·위로, t 7(−x)엔 −x·위로, 멈춘 t 5.3 엔 바깥(+x)·위로; 턱 위 x 520 은 아니다; 끝에서 30 px 떨어진 x 560 도, 멀리 아래 y 9700 도 아니다
	cg.t = 1.0; var sw_a := cg.sweep(536.0, 9790.0, -35.0)
	cg.t = 7.0; var sw_b := cg.sweep(536.0, 9790.0, -35.0)
	cg.t = 5.3; var sw_c := cg.sweep(536.0, 9790.0, -35.0)
	var sw_over := cg.sweep(520.0, 9790.0, -35.0); var sw_far := cg.sweep(560.0, 9790.0, -35.0); var sw_low := cg.sweep(536.0, 9700.0, -35.0); var sw_left := cg.sweep(372.0, 9790.0, -35.0)
	print("SWEEP right end: +x belt vx=%s vy=%s (want 200 220) | −x belt vx=%s (want −200) | stalled vx=%s (want 200: outward) | over the hop: %s far: %s low: %s (want 0 0 0) | left end stalled vx=%s (want −200: outward)" % [sw_a.get("vx", "-"), sw_a.get("vy", "-"), sw_b.get("vx", "-"), sw_c.get("vx", "-"), sw_over.size(), sw_far.size(), sw_low.size(), sw_left.get("vx", "-")])
	# 그림: 노드 아이 = 고무 띠 1 + 살 8(130 px / 16) + 톱니 2 + clank 1 = 12; 톱니마다 원판 + 이 8 + 축 머리 = 10; t 1 에 살 0 이 0.69 m(−1.81 + 2.5), 톱니 −6.43 rad; t 0 엔 −1.81, 0; 돌기 시작하는 틱(t = 11.2)에 clank
	var node: Node3D = s["node"]; var gears: Array = s["gears"]; var slats: Array = s["slats"]
	cg.t = 1.0; cg._roll(s)
	var sx1: float = (slats[0] as Node3D).position.x; var ga1: float = (gears[0] as Node3D).rotation.z
	cg.t = 0.0; cg._roll(s)
	var sx0: float = (slats[0] as Node3D).position.x; var ga0: float = (gears[0] as Node3D).rotation.z
	var ck: AudioStreamPlayer3D = s["clank"]
	cg.t = cg.cycle() - 0.02; await process_frame
	var ticked := false
	for i in 40:
		await process_frame
		if ck.playing: ticked = true
	print("VISUAL children=", node.get_child_count(), " (want 12) gear=", (gears[0] as Node3D).get_child_count(), " (want 10) slat0 at 1s=%.2f (want 0.69) at 0=%.2f (want −1.81) gear at 1s=%.2f (want −6.43: clockwise) at 0=%.2f | clank stream=%s clanked at the start=%s (want true)" % [sx1, sx0, ga1, ga0, ck.stream != null, ticked])
	# 자세: +x 를 보며 앞으로 실려 가는 몸 — 몸통 뒤로(−0.063 = 0.45 × −0.14), 골반 0.37, 오른 어깨 z −0.50, 팔은 조금 뒤(x +0.25); 거슬러 걸으면 앞으로 숙이고(+0.099) 팔꿈치 0.9; 휘청(j 0)이면 더 뒤로(−0.176)·골반 0.32
	fig.pose_request = "tread"; fig.set_meta("tread_k", 1.0); fig.set_meta("tread_w", 0.0); fig.set_meta("tread_j", 9.0)
	await process_frame; await process_frame
	var early := fig.torso.rotation.x
	for i in 40: await process_frame
	var torso := fig.torso.rotation.x; var hip_y := fig.pelvis.position.y; var shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var kn: float = (fig.knees[1.0] as Node3D).rotation.x
	fig.set_meta("tread_w", -1.0)
	for i in 24: await process_frame
	var torso2 := fig.torso.rotation.x; var el2: float = (fig.elbows[1.0] as Node3D).rotation.x
	fig.set_meta("tread_w", 0.0); fig.set_meta("tread_j", 0.0)
	for i in 24: await process_frame   # 메타를 0 에 묶어 둔 채(실제론 팩이 매 틱 올린다) 블렌딩이 닿을 때까지
	var torso3 := fig.torso.rotation.x; var hip_y3 := fig.pelvis.position.y
	print("POSE early=%.3f (≈ 0, before the brace) carried forward: torso=%.3f (want ≈ −0.063: leaning back) hip_y=%.2f (want 0.37) arm z=%.2f (want −0.50) arm x=%.2f (want 0.25: a little back) knee=%.2f (want 0.30..0.65, the shuffle) | against: torso=%.3f (want ≈ 0.099: bent into it) elbow=%.2f (want −0.90) | jolt: torso=%.3f (want ≈ −0.176) hip_y=%.2f (want 0.32)" % [early, torso, hip_y, shz, shx, kn, torso2, el2, torso3, hip_y3])
	# 진짜 탑: 1..60층에 plan 이 찾는 띠 — 태엽 층 16, 17, 18, 50, 52, 53, 54 (15, 19, 51 은 상승기류 층)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var g: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl := cg.plan(n, g.band(n))
		if pl.size() > 0: bands.append("%d:%d" % [n, pl.size()]); count += pl.size()
	print("TOWER floors=", bands, " belts=", count, " (want floors 16, 17, 18, 50, 52, 53, 54 only, up to 3 each)")
	quit()
