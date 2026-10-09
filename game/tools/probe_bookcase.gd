extends SceneTree
## 미는 서가 팩 점검(헤드리스): 자료가 읽히나, 서재 층의 넓은 still 발판(150 px 이상) 중 다음 발판이 한쪽으로 비켜 더 높은 것들에서 dy 가 가장 큰 하나(같으면 넓은 쪽)에만 서가가 서나(taken 의 덤웨이터 기둥이 가르는 발판은 지고, 다른 테마 층은 아니다),
## 뒷면 reach 안에서 C 를 쥐고 서가 쪽으로 밀 때만 미나(다른 발판·반대쪽·C 없음은 아니다), 0.3초에 속도가 붙고 1.2초에 궤도를 다 가 끝막이에서 thud 와 shunt_v 0 으로 버티나, 손을 떼면 4초 쉬고 2초에 걸쳐 집으로 돌아오나(가운데서 절반), 돌아오는 서가를 다시 밀면 그 자리에서 이어 밀리나,
## 떨어지는 몸이 윗면에 올라서고(land) 굴러가는 동안 실려 가다 벗어나면 off 인가, 궤도·끝막이·서가(뒷판·옆판·윗판·선반·책·바퀴)가 그려지고 구를 때 rumble 이 돌다 집에서 thud 와 함께 멎나, shunt 자세가 두 팔을 앞으로 뻗고 깊이 기울어 밀어 걷다 멈추면 벌려 버티나, 진짜 탑의 1..65층에서 plan 이 서재 층에만 서가를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cs := ClimbBookcase.new(); root.add_child(cs)
	var cl := ClimbLadder.new(); root.add_child(cl)
	var cd := ClimbDumbwaiter.new(); root.add_child(cd)
	await process_frame
	print("PACK id=", cs.pack.get("id"), " kind=", cs.kind.size() > 0, " pose=", cs.pack.get("pose"), " themes=", cs.pack.get("themes"), " case=%.0f×%.0f (want 40×72) ease=%.2f (want 0.30) rest=%.1f (want 4.0) roll=%.1f (want 2.0)" % [cs.case_w(), cs.case_h(), cs.ease_s(), cs.rest_s(), cs.roll_s()])
	var plats: Array = [
		{ "id": "10.0", "x": 100.0, "y": 6100.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "10.1", "x": 400.0, "y": 6210.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "10.2", "x": 120.0, "y": 6320.0, "w": 140.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "10.3", "x": 390.0, "y": 6450.0, "w": 170.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "10.4", "x": 150.0, "y": 6580.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "10.5", "x": 430.0, "y": 6690.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "10s", "x": 300.0, "y": 6598.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cs.plan(10, plats)
	var column := [{ "id": "10.D0", "kind": "dumbwaiter", "x": 458.0, "y": 6210.0, "w": 44.0, "b_y": 6450.0, "beam_y": 6546.0 }]
	var taken := cs.plan(10, plats, column)
	var other := cs.plan(15, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cs.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " on %s hx0 %.0f dir %.0f track %.0f top %.0f v %.3f x %.0f w %.0f z %.0f" % [String(v["a_id"]), float(v["hx0"]), float(v["dir"]), float(v["track"]), float(v["top_y"]), float(v["push_v"]), float(v["x"]), float(v["w"]), float(v["z"])]
	print("PLAN free=", free.map(show), " (want 1: 10.3 dy 130 wins — 10.B0 on 10.3 hx0 514 dir −1 track 74 top 6522 v 61.667 x 494 w 40 z −46; 10.2 is 140 wide → out; 10.5 has no next hop)")
	print("PLAN taken=", taken.map(show), " (want 1: the dumbwaiter column 448..512 from 6210 to 6546 cuts 10.3 and 10.1 → 10.0 wins the dy-110 tie by width — 10.B0 on 10.0 hx0 146 dir 1 track 84 top 6172 v 70) other=", other.size(), " (want 0: Clockwork)")
	var s: Dictionary = cs.cases[0]
	var on: Dictionary = plats[3]; var z := C.PLAYER_Z
	# 닿는 거리(집: 뒷면 534): x 546 의 손 536 은 민다; x 570 (손 560, 26 떨어짐)·반대쪽·C 없음·다른 발판은 아니다
	cs.sync(0.0)
	var far := cs.push(on, 570.0, z, -1.0, true, 0.1); var wrong := cs.push(on, 546.0, z, 1.0, true, 0.1); var noc := cs.push(on, 546.0, z, -1.0, false, 0.1); var elsewhere := cs.push(plats[1], 546.0, z, -1.0, true, 0.1)
	var fig := Stick3D.new(); root.add_child(fig)
	var g := cs.push(on, 546.0, z, -1.0, true, 0.1, fig); var v0 := float(fig.get_meta("shunt_v", 9.0))
	print("REACH far=%s wrong=%s noC=%s elsewhere=%s (want false ×4) | push=%s x=%.1f (want true 546: no speed yet) pushing=%s t0=%.1f v=%.2f (want true 0.0 0.00)" % [far["pushing"], wrong["pushing"], noc["pushing"], elsewhere["pushing"], g["pushing"], float(g["x"]), bool(s["pushing"]), float(s["t0"]), v0])
	# 미는 길(v 61.667, ease 0.3): 0.1 → 속도 20.556, 간 거리 2.056 (몸 543.94, shunt_v 0.33); 0.3 → +12.333 = 14.389 (몸 531.61, 1.00); 0.3초 틱 넷 → 1.5 에 74 끝막이 (몸 472, thud, 0); 1.6 C 를 떼면 놓인다(rel 1.6, pos_rel 74)
	cs.sync(0.1); var r1 := cs.push(on, float(g["x"]), z, -1.0, true, 0.1, fig); var v1 := float(fig.get_meta("shunt_v", 9.0)); var p1 := float(s["pos"])
	cs.sync(0.3); var r2 := cs.push(on, float(r1["x"]), z, -1.0, true, 0.2, fig); var v2 := float(fig.get_meta("shunt_v", 9.0))
	var r3 := r2
	for k in 4: cs.sync(0.6 + 0.3 * float(k)); r3 = cs.push(on, float(r3["x"]), z, -1.0, true, 0.3, fig)   # 0.6 → 32.889, 0.9 → 51.389, 1.2 → 69.889, 1.5 → 74 끝막이(틱은 0.35초 안에 이어야 손이 붙어 있다)
	var v3 := float(fig.get_meta("shunt_v", 9.0))
	var th: AudioStreamPlayer3D = s["thud"]; var thud_stop := th.playing
	cs.sync(1.6); var r4 := cs.push(on, float(r3["x"]), z, -1.0, false, 0.1, fig)
	print("PUSH 0.1: x=%.2f v=%.2f pos=%.3f (want 543.94 0.33 2.056) | 0.3: x=%.2f v=%.2f (want 531.61 1.00) | 1.5: x=%.0f v=%.2f pos=%.0f thud=%s (want 472 0.00 74 true) | 1.6 let go: pushing=%s %s rel=%.1f pos_rel=%.0f (want false false 1.6 74)" % [float(r1["x"]), v1, p1, float(r2["x"]), v2, float(r3["x"]), v3, float(s["pos"]), thud_stop, r4["pushing"], bool(s["pushing"]), float(s["rel"]), float(s["pos_rel"])])
	# 쉬기(1.6 → 5.6)와 돌아오기(5.6 → 7.6): 3.0 엔 그대로 74(가운데 440) — 떨어지는 몸이 윗면 6522 에 올라선다(430 은 되고 500 은 안 되고 6525 로는 안 지난다); 6.6 엔 반(37, 가운데 477) — 선 몸은 37 실려 가고 300 은 off
	cs.sync(3.0)
	var l_ok := cs.land(430.0, 6530.0, 6515.0, z); var l_far := cs.land(500.0, 6530.0, 6515.0, z); var l_over := cs.land(430.0, 6530.0, 6525.0, z)
	cs.sync(6.6); cs._process(0.0)
	var st1 := cs.stand(l_ok, 430.0, 0.1); var st2 := cs.stand(l_ok, 300.0, 0.1)
	var unit: Node3D = s["case"]; var rum: AudioStreamPlayer3D = s["rumble"]; var ux := unit.position.x; var rum_on := rum.playing
	print("REST 3.0: centre=%.0f (want 440) land=%s y=%.0f x=%.0f w=%.0f (want shelf 6522 420 40) far=%s over=%s (want empty empty) | 6.6: centre=%.0f (want 477) stand x=%.0f y=%.0f off=%s (want 467 6522 false) off at 300=%s (want true) case x=%.3f (want −1.028) rumble=%s (want true)" % [cs.centre(s, 3.0), l_ok.get("kind", "-"), float(l_ok.get("y", 0.0)), float(l_ok.get("x", 0.0)), float(l_ok.get("w", 0.0)), l_far.is_empty(), l_over.is_empty(), cs.centre(s, 6.6), float(st1["x"]), float(st1["y"]), st1["off"], st2["off"], ux, rum_on])
	# 돌아오는 서가를 다시 민다(6.6, 뒷면 497 → 몸 509): 그 자리 37 에서 이어 밀려 6.7 엔 39.056 (몸 506.94); 6.8 에 놓으면 12.8 에 집 — thud, 한 번 더 자리를 맞추면 rumble 이 멎는다
	var rp := cs.push(on, 509.0, z, -1.0, true, 0.0, fig); var pp := float(s["pos"])
	cs.sync(6.7); var rp2 := cs.push(on, float(rp["x"]), z, -1.0, true, 0.1, fig); cs._process(0.0); var ux2 := unit.position.x
	cs.sync(6.8); cs.push(on, float(rp2["x"]), z, -1.0, false, 0.1, fig)
	cs.sync(12.8); cs._process(0.0); var thud_home := th.playing; var rum_mid := rum.playing
	cs._process(0.0); var rum_end := rum.playing
	print("REPUSH 6.6: pushing=%s pos=%.0f x=%.0f (want true 37 509) | 6.7: pos=%.3f x=%.2f case x=%.3f (want 39.056 506.94 −1.085) | 6.8 let go rel=%.1f (want 6.8) | 12.8: centre=%.0f (want 514: home) thud=%s rumble=%s → %s (want true true false)" % [rp["pushing"], pp, float(rp["x"]), float(s["pos"]), float(rp2["x"]), ux2, float(s["rel"]), cs.centre(s, 12.8), thud_home, rum_mid, rum_end])
	# 그림: 노드 아이 4(궤도·끝막이 둘·서가), 서가 아이 28(뒷판·옆판 둘·윗판·선반 셋·책 15·바퀴 넷·rumble·thud); 궤도는 집에서 끝막이까지 (74 + 40) px = 3.17 m, 가운데가 dir 쪽으로 1.03 m
	var node: Node3D = s["node"]; var rail: MeshInstance3D = node.get_child(0)
	print("VISUAL node children=", node.get_child_count(), " (want 4) case children=", unit.get_child_count(), " (want 28) rail len=%.2f (want 3.17) rail x=%.2f (want −1.03) node pos=%.3f %.3f %.3f (want 0.944 179.167 −1.278)" % [(rail.mesh as BoxMesh).size.x, rail.position.x, node.position.x, node.position.y, node.position.z])
	# 자세: 밀기(v 1): 두 어깨 −1.0 (앞으로 나란히), 팔꿈치 −0.12, 고개 ≈ 0.21 (0.6 에서 기운 몸의 몫을 뺀 것), 몸통 ≈ 0.25 (lean 0.55 의 0.45), 엉덩이는 ±0.38 안에서 번갈아; 버티기(v 0): 엉덩이 −0.22 / +0.42, 무릎 0.55..0.60 / 0.10..0.15
	fig.pose_request = "shunt"
	fig.set_meta("shunt_v", 1.0)
	await process_frame; await process_frame; await process_frame
	var early_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	for i in 60: await process_frame   # 손 대기(0.25초)가 끝난 뒤부터 잰다(헤드리스 프레임은 짧을 수 있다)
	var sh_a: float = (fig.shoulders[1.0] as Node3D).rotation.x; var sh_b: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var el_a: float = (fig.elbows[1.0] as Node3D).rotation.x
	var hip_a: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_b: float = (fig.hips[-1.0] as Node3D).rotation.x; var neck_p := fig.neck.rotation.x; var torso_p := fig.torso.rotation.x; var pel_p := fig.pelvis.position.y
	fig.set_meta("shunt_v", 0.0)
	for i in 30: await process_frame   # 그림의 관절 블렌딩이 따라올 때까지
	var hip_s: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_t: float = (fig.hips[-1.0] as Node3D).rotation.x; var knee_s: float = (fig.knees[1.0] as Node3D).rotation.x; var knee_t: float = (fig.knees[-1.0] as Node3D).rotation.x
	print("POSE early=%.2f (want > −0.9: the hands are only reaching) pushing: shoulders=%.2f %.2f (want −1.00 both) elbow=%.2f (want −0.12) hips=%.2f %.2f (want opposite signs, |·| ≤ 0.38) neck=%.2f (want ≈ 0.21 = 0.6 looking down less the 0.7 × 0.55 lean the rig gives the head) torso=%.3f (want ≈ 0.25: the rig gives the torso 0.45 of the lean) pelvis=%.3f (want 0.350) | braced: hips=%.2f %.2f (want −0.22 +0.42) knees=%.2f %.2f (want 0.55..0.60 0.10..0.15)" % [early_sh, sh_a, sh_b, el_a, hip_a, hip_b, neck_p, torso_p, pel_p, hip_s, hip_t, knee_s, knee_t])
	# 진짜 탑: 1..65층에 plan 이 찾는 서가 — 서재 층 10..14 (넓은 발판이 있는 층만; 45..49 는 발판이 103..148 px 라 거의 없다), 사다리·덤웨이터의 자리는 비켜서
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 66):
		var pl: Array = gm.band(n)
		var out := cs.plan(n, pl, cl.plan(n, pl) + cd.plan(n, pl))
		if out.size() > 0: bands.append("%d:%s" % [n, out.map(func(v: Dictionary) -> String: return "%s dy %.0f track %.0f dir %.0f" % [String(v["a_id"]), float(v["dy"]), float(v["track"]), float(v["dir"])])]); count += out.size()
	print("TOWER floors=", bands, " bookcases=", count, " (want a subset of 10..14 and 45..49, one each)")
	quit()
