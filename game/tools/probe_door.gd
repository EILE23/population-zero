extends SceneTree
## 회전문 팩 점검(헤드리스): 자료가 읽히나, 옛 회관 층의 넓은 still 발판(120 px 이상) 중 드럼 상자를 다른 판·taken 조각이 가르지 않는 것들 중 가장 넓은 하나에만 문이 서나(지름길 판이 가르는 발판과 종의 줄이 걸리는 발판은 지고, 다른 테마 층은 아니다),
## 드럼 가장자리 reach 안에서 C 를 쥐고 문 쪽으로 걸을 때만 들어서나(멀리·반대쪽·C 없음·다른 발판은 아니다), 0.15초에 속도가 붙고 반 바퀴(π)에 0.9초 걸려 호(x 16, z 12)를 따라 건너편(hx + 16)에 내려놓나(done), 그 뒤 빈 문이 2초에 걸쳐 각속도가 0 으로 줄며 ω·1 만큼 더 도나(1초엔 그 3/4),
## 돌던 문에 다시 들어서면 그 각에서 이어 도나, C 를 떼면(또는 틱이 0.35초 끊기면) 그 자리에 서서 그때 속도로 관성만 남나, 떨어지는 몸이 지붕판에 올라서나(land: 옆·위·앞뒤 밖은 아니다), 바닥판·축·잎 넷·지붕판·테·유리 셋이 그려지고 돌 때 whirr 가 돌다 서면 멎나, turn 자세가 오른손을 손잡이에 대고 잰걸음으로 돌다 서면 두 발로 서나, 진짜 탑의 1..40층에서 plan 이 옛 회관 층에만 문을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cr := ClimbDoor.new(); root.add_child(cr)
	var cb := ClimbBell.new(); root.add_child(cb)
	await process_frame
	print("PACK id=", cr.pack.get("id"), " kind=", cr.kind.size() > 0, " pose=", cr.pack.get("pose"), " themes=", cr.pack.get("themes"), " r=%.0f (want 28) h=%.0f (want 70) path=%.0f (want 16) omega=%.4f (want 3.4907) ease=%.2f (want 0.15) spin=%.1f (want 2.0)" % [cr.r(), cr.h(), cr.path_r(), cr.omega(), cr.ease_s(), cr.spin_s()])
	var plats: Array = [
		{ "id": "2.0", "x": 100.0, "y": 1300.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.1", "x": 400.0, "y": 1410.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.2", "x": 120.0, "y": 1520.0, "w": 110.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "2.3", "x": 390.0, "y": 1650.0, "w": 170.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.4", "x": 150.0, "y": 1780.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.5", "x": 430.0, "y": 1890.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2s", "x": 460.0, "y": 1500.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cr.plan(2, plats)
	var rope := [{ "id": "2.b0", "kind": "bell", "x": 150.0, "y": 1340.0, "w": 40.0, "b_y": 1420.0 }]
	var taken := cr.plan(2, plats, rope)
	var other := cr.plan(7, plats); var lap2 := cr.plan(35, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cr.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " on %s hx %.0f top %.0f x %.0f w %.0f z %.0f" % [String(v["a_id"]), float(v["hx"]), float(v["top_y"]), float(v["x"]), float(v["w"]), float(v["z"])]
	print("PLAN free=", free.map(show), " (want 1: 2.0 is the widest — 2.R0 on 2.0 hx 190 top 1370 x 162 w 56 z −44; 2.1 is cut by the slab 2s over its drum; 2.2 is 110 wide → out)")
	print("PLAN taken=", taken.map(show), " (want 1: the bell rope 140..200 from 1330 to 1430 meets 2.0's drum → 2.3 wins at 170 — 2.R0 on 2.3 hx 475 top 1720) other=", other.size(), " (want 0: Hanging garden) lap2=", lap2.size(), " (want 1: floor 35 is Old hall again)")
	var s: Dictionary = cr.doors[0]
	var on: Dictionary = plats[0]; var z := C.PLAYER_Z
	# 닿는 거리(dir +1 의 가장자리 162): x 150 의 손 160 은 들어선다; x 120 (손 130, 32 떨어짐)·반대쪽·C 없음·다른 발판은 아니다
	cr.sync(0.0)
	var far := cr.push(on, 120.0, z, 1.0, true, 0.1); var wrong := cr.push(on, 150.0, z, -1.0, true, 0.1); var noc := cr.push(on, 150.0, z, 1.0, false, 0.1); var elsewhere := cr.push(plats[1], 150.0, z, 1.0, true, 0.1)
	var fig := Stick3D.new(); root.add_child(fig)
	var g := cr.push(on, 150.0, z, 1.0, true, 0.1, fig); var v0 := float(fig.get_meta("turn_v", 9.0))
	var ck: AudioStreamPlayer3D = s["clack"]; var clack_in := ck.playing
	print("REACH far=%s wrong=%s noC=%s elsewhere=%s (want false ×4) | enter=%s x=%.1f z=%.1f (want true 174 −48: at the near edge, no speed yet) riding=%s t0=%.1f v=%.2f clack=%s (want true 0.0 0.00 true)" % [far["riding"], wrong["riding"], noc["riding"], elsewhere["riding"], g["riding"], float(g["x"]), float(g["z"]), bool(s["riding"]), float(s["t0"]), v0, clack_in])
	# 타는 길(ω 3.4907, ease 0.15): 0.1 → ω 2.3271, a 0.2327 (x 174.43 z −50.77, turn_v 0.67); 0.3 → a 0.9308 (180.45 −57.63, 1.00); 0.3초 틱 셋 → 0.6 a 1.9780 (196.34 −59.02), 0.9 a 3.0252 (205.89 −49.39), 1.2 a π (206 −48 done); 잎은 꼭 π 돌았다
	cr.sync(0.1); var r1 := cr.push(on, float(g["x"]), z, 1.0, true, 0.1, fig); var v1 := float(fig.get_meta("turn_v", 9.0)); var a1 := float(s["a"])
	cr.sync(0.3); var r2 := cr.push(on, float(r1["x"]), z, 1.0, true, 0.2, fig); var v2 := float(fig.get_meta("turn_v", 9.0))
	cr.sync(0.6); var r3 := cr.push(on, float(r2["x"]), z, 1.0, true, 0.3, fig)
	cr.sync(0.9); var r4 := cr.push(on, float(r3["x"]), z, 1.0, true, 0.3, fig)
	cr.sync(1.2); var r5 := cr.push(on, float(r4["x"]), z, 1.0, true, 0.3, fig)
	print("RIDE 0.1: x=%.2f z=%.2f v=%.2f a=%.4f (want 174.43 −50.77 0.67 0.2327) | 0.3: x=%.2f z=%.2f v=%.2f (want 180.45 −57.63 1.00) | 0.6: x=%.2f z=%.2f (want 196.34 −59.02) | 0.9: x=%.2f z=%.2f done=%s (want 205.89 −49.39 false) | 1.2: x=%.0f z=%.0f done=%s riding=%s ang=%.4f rel=%.1f (want 206 −48 true false 3.1416 1.2)" % [float(r1["x"]), float(r1["z"]), v1, a1, float(r2["x"]), float(r2["z"]), v2, float(r3["x"]), float(r3["z"]), float(r4["x"]), float(r4["z"]), r4["done"], float(r5["x"]), float(r5["z"]), r5["done"], bool(s["riding"]), float(s["ang"]), float(s["rel"])])
	# 관성(1.2 → 3.2): 각속도 3.4907 이 2초에 0 으로 — 2.2 엔 π + 2.618 = 5.7596, 3.2 엔 π + 3.4907 = 6.6323, 5.0 도 같다; 돌다 서면 whirr 가 멎는다; 나간 몸이 다시 밀지 않는다(손 216, 반대 가장자리 218 — 들어선 쪽 162 가 아니다)
	cr.sync(1.3); var after := cr.push(on, 206.0, z, 1.0, true, 0.1, fig)
	cr.sync(2.2); cr._process(0.0); var wh: AudioStreamPlayer3D = s["whirr"]; var wh_mid := wh.playing; var spin: Node3D = s["spin"]; var rot_mid := spin.rotation.y
	cr.sync(3.2); cr._process(0.0); var wh_end1 := wh.playing
	cr._process(0.0); var wh_end := wh.playing
	print("COAST after=%s (want false) | 2.2: ang=%.4f (want 5.7596) whirr=%s (want true) leaves=%.4f (want −5.7596) | 3.2: ang=%.4f (want 6.6323) whirr=%s → %s (want true false) | 5.0: ang=%.4f (want 6.6323: stopped)" % [after["riding"], cr.angle_at(s, 2.2), wh_mid, rot_mid, cr.angle_at(s, 3.2), wh_end1, wh_end, cr.angle_at(s, 5.0)])
	# 다시 들어서기(10.0): 그 각 6.6323 에서 이어 돈다; 10.1 에 a 0.2327 (ω 2.3271); 10.5 까지 틱이 끊기면 손을 뗀 것 — 그때 속도 2.3271 로 관성만: 12.5 엔 6.6323 + 0.2327 + 2.3271 = 9.1921; 몸은 174.43 에 선 채(x 는 로더의 것)
	cr.sync(10.0); var re := cr.push(on, 150.0, z, 1.0, true, 0.0, fig); var ang_re := float(s["ang"])
	cr.sync(10.1); var re2 := cr.push(on, float(re["x"]), z, 1.0, true, 0.1, fig); var a_re := float(s["a"])
	cr.sync(10.5); var rid_stale := bool(s["riding"]); var rel_stale := float(s["rel"]); var spd_stale := float(s["spd_rel"])
	var let := cr.push(on, float(re2["x"]), z, 1.0, false, 0.1, fig); var ang_coast := cr.angle_at(s, 12.5)   # 11.0 의 재진입이 각을 굳히기 전에 읽는다
	# C 를 떼면 바로 선다(11.0 들어서 11.1 떼기 → rel 11.1); 반대로 걸어도 선다(11.5 들어서 11.6 반대 → rel 11.6)
	cr.sync(11.0); cr.push(on, 150.0, z, 1.0, true, 0.0, fig); cr.sync(11.1); var drop := cr.push(on, 174.0, z, 1.0, false, 0.1, fig); var rel_drop := float(s["rel"])
	cr.sync(11.5); cr.push(on, 150.0, z, 1.0, true, 0.0, fig); cr.sync(11.6); var back := cr.push(on, 174.0, z, -1.0, true, 0.1, fig); var rel_back := float(s["rel"])
	print("REENTER 10.0: riding=%s ang=%.4f x=%.0f (want true 6.6323 174) | 10.1: x=%.2f a=%.4f (want 174.43 0.2327) | 10.5 stale: riding=%s rel=%.1f spd=%.4f (want false 10.5 2.3271) let=%s x=%.2f (want false 174.43) | 12.5: ang=%.4f (want 9.1921) | drop: riding=%s rel=%.1f (want false 11.1) back: riding=%s rel=%.1f (want false 11.6)" % [re["riding"], ang_re, float(re["x"]), float(re2["x"]), a_re, rid_stale, rel_stale, spd_stale, let["riding"], float(let["x"]), ang_coast, drop["riding"], rel_drop, back["riding"], rel_back])
	# 지붕판(1370, x 162..218, z −44): 떨어지는 몸 180 은 올라선다; 230 은 옆(220 ≥ 218); ny 1375 는 아직 위; z 0 은 앞(44 ≥ 36)
	cr.sync(20.0)
	var l_ok := cr.land(180.0, 1380.0, 1365.0, z); var l_side := cr.land(230.0, 1380.0, 1365.0, z); var l_over := cr.land(180.0, 1380.0, 1375.0, z); var l_front := cr.land(180.0, 1380.0, 1365.0, 0.0)
	print("LAND ok=%s y=%.0f x=%.0f w=%.0f z=%.0f d=%.0f (want canopy 1370 162 56 −44 56) side=%s over=%s front=%s (want empty ×3)" % [l_ok.get("kind", "-"), float(l_ok.get("y", 0.0)), float(l_ok.get("x", 0.0)), float(l_ok.get("w", 0.0)), float(l_ok.get("z", 0.0)), float(l_ok.get("d", 0.0)), l_side.is_empty(), l_over.is_empty(), l_front.is_empty()])
	# 그림: 노드 아이 8(바닥판·축·잎 묶음·지붕판·테·유리·whirr·clack), 잎 묶음 아이 4(축 노드마다 잎판 + 손잡이), 유리 3; 바닥판 반지름 0.778, 지붕판 윗면 1.944
	var node: Node3D = s["node"]; var plate: MeshInstance3D = node.get_child(0); var canopy: MeshInstance3D = node.get_child(3); var wall: Node3D = node.get_child(5)
	print("VISUAL node children=", node.get_child_count(), " (want 8) leaves=", spin.get_child_count(), " (want 4) per leaf=", (spin.get_child(0) as Node3D).get_child_count(), " (want 2) panes=", wall.get_child_count(), " (want 3) plate r=%.3f (want 0.778) canopy top=%.3f (want 1.944) node pos=%.3f %.3f %.3f (want −8.056 36.111 −1.222)" % [(plate.mesh as CylinderMesh).top_radius, canopy.position.y + 0.03, node.position.x, node.position.y, node.position.z])
	# 자세: 돌기(v 1): 오른어깨 −1.10, 오른팔꿈치 −1.00, 왼어깨 +0.30 ± 0.15, 왼팔꿈치 −0.30, 엉덩이는 ±0.26 안에서 번갈아, 고개 y ≈ 0.45, 골반 0.375..0.39; 서기(v 0): 엉덩이 0 0, 무릎 0.10 0.10, 골반 0.390
	fig.pose_request = "turn"
	fig.set_meta("turn_v", 1.0)
	await process_frame; await process_frame; await process_frame
	var early_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	for i in 60: await process_frame   # 손 대기(0.2초)가 끝난 뒤부터 잰다(헤드리스 프레임은 짧을 수 있다)
	var sh_r: float = (fig.shoulders[1.0] as Node3D).rotation.x; var el_r: float = (fig.elbows[1.0] as Node3D).rotation.x; var sh_l: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var el_l: float = (fig.elbows[-1.0] as Node3D).rotation.x
	var hip_a: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_b: float = (fig.hips[-1.0] as Node3D).rotation.x; var neck_y := fig.neck.rotation.y; var pel_p := fig.pelvis.position.y
	fig.set_meta("turn_v", 0.0)
	for i in 30: await process_frame   # 그림의 관절 블렌딩이 따라올 때까지
	var hip_s: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_t: float = (fig.hips[-1.0] as Node3D).rotation.x; var knee_s: float = (fig.knees[1.0] as Node3D).rotation.x; var knee_t: float = (fig.knees[-1.0] as Node3D).rotation.x; var pel_s := fig.pelvis.position.y
	print("POSE early=%.2f (want > −1.0: the hand is only reaching) turning: shoulder r=%.2f (want −1.10) elbow r=%.2f (want −1.00) shoulder l=%.2f (want 0.15..0.45: trailing, swinging) elbow l=%.2f (want −0.30) hips=%.2f %.2f (want opposite signs, |·| ≤ 0.26) neck y=%.2f (want 0.45) pelvis=%.3f (want 0.375..0.390) | stopped: hips=%.2f %.2f (want 0.00 0.00) knees=%.2f %.2f (want 0.10 0.10) pelvis=%.3f (want 0.390)" % [early_sh, sh_r, el_r, sh_l, el_l, hip_a, hip_b, neck_y, pel_p, hip_s, hip_t, knee_s, knee_t, pel_s])
	# 진짜 탑: 1..40층에 plan 이 찾는 문 — 옛 회관 층 1..4, 35..39 (120 px 넘는 발판이 있고 드럼 위를 다른 판이 안 가르는 층만; 종의 자리는 비켜서)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 41):
		var pl: Array = gm.band(n)
		var out := cr.plan(n, pl, cb.plan(n, pl))
		if out.size() > 0: bands.append("%d:%s" % [n, out.map(func(v: Dictionary) -> String: return "%s w %.0f hx %.0f" % [String(v["a_id"]), float(v["aw"]), float(v["hx"])])]); count += out.size()
	print("TOWER floors=", bands, " doors=", count, " (want a subset of 1..4 and 35..39, one each)")
	quit()
