extends SceneTree
## 구르는 통나무 팩 점검(헤드리스): 자료가 읽히나, 옛 회관 층의 min_w 이상 가장 넓은 still 발판에만 통나무가 누우나(회전문이 선 발판·상자를 가르는 지름길 판은 비켜 가고, 틈의 종 줄은 상관없고, 다른 테마 층은 아니다),
## 걸어서 닿으면 올라서고(x 가 통나무 위로, dy 16) 걸으면 걷는 속도의 0.6 배로 통나무가 몸을 싣고 구르나(각이 미끄러짐 없이 따라 도나), 말뚝에 서면 몸이 제 걸음으로 넘어 내려서고 타기가 세이나,
## 위에서 0.2 s 서면 엎어지나(spill, dy 0, 통나무가 마지막으로 돌던 쪽으로 30 px 굴러 나가나), grace 0.6 s 안엔 못 타나, 점프를 모으는 중엔 엎어지지 않나, 6 s 뒤 가운데로 되돌아오나, 날이 바뀌면 수가 비나,
## 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 읽나, 홈·말뚝 둘·축(통 + 끈 둘)·소리 둘이 그려지나, log 자세가 팔을 벌리고 무릎을 들고 멈추면 허둥대나, 진짜 탑의 1..70층에서 plan 이 옛 회관 층에만 통나무를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var lg := ClimbLog.new(); root.add_child(lg)
	var cb := ClimbBell.new(); root.add_child(cb)
	var cr := ClimbDoor.new(); root.add_child(cr)
	await process_frame
	print("PACK id=", lg.pack.get("id"), " kind=", lg.kind.size() > 0, " pose=", lg.pack.get("pose"), " themes=", lg.pack.get("themes"), " length=%.0f radius=%.0f min_w=%.0f end_in=%.0f slow=%.2f stop=%.2f spill=%.2f kick=%.0f/%.2f grace=%.2f settle=%.0f/%.0f ride=%.0f day=%.0f (want 40 8 150 20 0.60 0.20 0.40 30/0.40 0.60 6/24 40 600)" % [lg.length(), lg.radius(), lg.min_w(), lg.end_in(), lg.slow(), lg.stop_s(), lg.spill_s(), lg.kick(), lg.kick_s(), lg.grace_s(), lg.settle_s(), lg.settle_v(), lg.ride_px(), lg.day_s()])
	var plats: Array = [
		{ "id": "2.0", "x": 60.0, "y": 1300.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.1", "x": 400.0, "y": 1400.0, "w": 200.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.2", "x": 150.0, "y": 1500.0, "w": 170.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "2.3", "x": 500.0, "y": 1600.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.4", "x": 250.0, "y": 1700.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2s", "x": 700.0, "y": 1648.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := lg.plan(2, plats)
	var doored := lg.plan(2, plats, [{ "id": "2.R0", "kind": "door", "x": 470.0, "y": 1400.0, "w": 60.0 }])   # 회전문이 2.1 가운데 — 2.0 (180) 으로
	var belled := lg.plan(2, plats, [{ "id": "2.b0", "kind": "bell", "x": 315.0, "y": 1350.0, "w": 10.0, "a_y": 1300.0, "b_y": 1400.0 }])   # 종 줄은 2.0 과 2.1 사이 틈 — 2.1 그대로
	var cut := plats.duplicate(true); cut.append({ "id": "2c", "x": 480.0, "y": 1430.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 })   # 지름길 판이 2.1 의 상자를 가른다 — 2.0 으로
	var cutp := lg.plan(2, cut)
	var narrow := lg.plan(2, [plats[3]])
	var f0 := lg.plan(0, plats); var f4 := lg.plan(4, plats); var f5 := lg.plan(5, plats); var f35 := lg.plan(35, plats); var f39 := lg.plan(39, plats); var f40 := lg.plan(40, plats)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " on %s/%s hop_w %.0f cx %.0f x0 %.0f x1 %.0f x %.0f w %.0f lx %.0f y %.0f y_top %.0f z %.0f d %.0f" % [String(v["hop_id"]), String(v["hop_kind"]), float(v["hop_w"]), float(v["cx"]), float(v["x0"]), float(v["x1"]), float(v["x"]), float(v["w"]), float(v["lx"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	var brief := func(v: Dictionary) -> String: return String(v["hop_id"])
	print("PLAN free=", free.map(show), " (want 1: 2.L0 on 2.1/std hop_w 200 cx 500 x0 420 x1 580 x 420 w 160 lx 500 y 1400 y_top 1416 z −48 d 40)")
	print("PLAN doored=", doored.map(brief), " (want [2.0]) belled=", belled.map(brief), " (want [2.1]) cut=", cutp.map(brief), " (want [2.0]) narrow=", narrow.size(), " (want 0) floors 0/4/5/35/39/40=", [f0.size(), f4.size(), f5.size(), f35.size(), f39.size(), f40.size()], " (want 1 1 0 1 1 0)")
	var band_root := Node3D.new(); root.add_child(band_root)
	lg.build(band_root, free)
	var g: Dictionary = lg.logs[0]
	var on: Dictionary = plats[1]; var other: Dictionary = plats[0]
	var fig := Stick3D.new(); root.add_child(fig)
	# 타기(10.0, 통나무 500, 말뚝 사이 428..572, dt 0.1, 걸음 +260 → 한 틱 15.6): 480 은 닿지 않는다(20 > 12), 490 은 올라서(10 ≤ 12) 바로 구른다 → x 515.6 dy 16 각 1.95; 세 틱 더 → 562.4 각 7.8; 다음은 말뚝에 걸려 572 (9.6); 그 뒤 로더가 옮긴 578 은 아직 위(dy 16), 598 은 내려선다 → 타기 72 px, 오늘 1 ride
	lg.sync(10.0)
	var r480 := lg.roll(on, 480.0, C.PLAYER_Z, 260.0, 0.1, fig); var r486 := lg.roll(on, 490.0, C.PLAYER_Z, 260.0, 0.1, fig); var m486 := float(fig.get_meta("log_v", 9.0)); var a1 := float(g["a"])
	for i in 3: lg.roll(on, float(g["lx"]) + 26.0, C.PLAYER_Z, 260.0, 0.1, fig)
	var lx4 := float(g["lx"]); var a4 := float(g["a"])
	var r5 := lg.roll(on, lx4 + 26.0, C.PLAYER_Z, 260.0, 0.1, fig)
	var r578 := lg.roll(on, 578.0, C.PLAYER_Z, 260.0, 0.1, fig); var r598 := lg.roll(on, 598.0, C.PLAYER_Z, 260.0, 0.1, fig); var m598 := fig.has_meta("log_v")
	var d1 := lg.today(2, 2)
	var wrong := lg.roll(other, 500.0, C.PLAYER_Z, 260.0, 0.1, fig); var front := lg.roll(on, 572.0, -10.0, 260.0, 0.1, fig)
	print("ROLL 480 riding=%s x=%.0f (want false 480) 490 mounted=%s riding=%s x=%.1f dy=%.0f meta=%.2f a=%.3f (want true true 515.6 16 1.00 1.950) +3 lx=%.1f a=%.3f (want 562.4 7.800) peg x=%.1f dy=%.0f (want 572.0 16) 578 riding=%s dy=%.0f (want true 16) 598 riding=%s dy=%.0f x=%.0f meta=%s (want false 0 598 false) today rides=%d spills=%d (want 1 0) wrong=%s front=%s (want false false)" % [r480["riding"], float(r480["x"]), r486["mounted"], r486["riding"], float(r486["x"]), float(r486["dy"]), m486, a1, lx4, a4, float(r5["x"]), float(r5["dy"]), r578["riding"], float(r578["dy"]), r598["riding"], float(r598["dy"]), float(r598["x"]), m598, int(d1["rides"]), int(d1["spills"]), wrong["riding"], front["riding"]])
	# 엎어짐: 572 에서 되돌아 타면(−260) 556.4 로 구른다(last −1); 서서 0.1 은 아직(dy 16, meta 0), 0.2 에 엎어진다(spill, dy 0, 오늘 1 spill, 타기 15.6 은 세지 않는다); 0.3 s 뒤엔 못 탄다(grace); 0.7 s 뒤 점프를 모으며 0.3 s 서 있어도 엎어지지 않고, 모으기를 놓고 0.2 s 서면 다시 엎어진다(2 spills)
	var back := lg.roll(on, 572.0, C.PLAYER_Z, -260.0, 0.1, fig); var still1 := lg.roll(on, float(g["lx"]), C.PLAYER_Z, 0.0, 0.1, fig); var m_still := float(fig.get_meta("log_v", 9.0)); var still2 := lg.roll(on, float(g["lx"]), C.PLAYER_Z, 0.0, 0.1, fig)
	var d2 := lg.today(2, 2); var spill_t1 := float(g["spill_t"]); var kick_dir := float(g["kick_dir"])
	lg.sync(10.3); var grace := lg.roll(on, float(g["lx"]), C.PLAYER_Z, 0.0, 0.1, fig)
	lg.sync(10.7); var held := false
	for i in 3: held = lg.roll(on, float(g["lx"]), C.PLAYER_Z, 0.0, 0.1, fig, true)["riding"]
	var rel1 := lg.roll(on, float(g["lx"]), C.PLAYER_Z, 0.0, 0.1, fig); var rel2 := lg.roll(on, float(g["lx"]), C.PLAYER_Z, 0.0, 0.1, fig)
	var d3 := lg.today(2, 2)
	print("SPILL back x=%.1f (want 556.4) still 0.1 riding=%s dy=%.0f meta=%.2f (want true 16 0.00) 0.2 spill=%s riding=%s dy=%.0f (want true false 0) today rides=%d spills=%d (want 1 1) spill_t=%.1f dir=%.0f (want 10.0 −1) grace riding=%s (want false) charging held=%s (want true: 0.3 s and no spill) release spill=%s/%s (want false/true) today spills=%d (want 2)" % [float(back["x"]), still1["riding"], float(still1["dy"]), m_still, still2["spill"], still2["riding"], float(still2["dy"]), int(d2["rides"]), int(d2["spills"]), spill_t1, kick_dir, grace["riding"], held, rel1["spill"], rel2["spill"], int(d3["spills"])])
	print("NOTE 0=\"%s\" (want Rolling log, floors 0–4: 1 ride, 2 spills today.) 5=\"%s\" (want the same: nothing on 5..9, so the floors below) 10=\"%s\" (want empty)" % [lg.note(0), lg.note(5), lg.note(10)])
	# 굴러 나감(spill_t 10.7, 556.4 에서 −x 로 30): 0.2 s 에 0.75 → 533.9, 0.4 s 에 526.4, 그 뒤 멈춘다; 되돌아옴: 마지막 탄 10.7 에서 6 s 뒤 24 px/s 로 가운데(500)로 — _process(1.0) 두 번에 502.4 → 500.0; 날이 바뀌면(610) 오늘의 수가 빈다
	lg.sync(10.9); lg._process(0.0); var k2 := float(g["lx"]); var pivx: float = (g["piv"] as Node3D).position.x
	lg.sync(11.1); lg._process(0.0); var k4 := float(g["lx"])
	lg.sync(11.2); lg._process(0.0); var k5 := float(g["lx"])
	lg.sync(16.8); lg._process(1.0); var s1 := float(g["lx"]); var a_s1 := float(g["a"])
	lg._process(1.0); var s2 := float(g["lx"]); var a_s2 := float(g["a"])
	lg.sync(610.0); var d4 := lg.today(2, 2)
	print("KICK @0.2 lx=%.1f piv x=%.4f (want 533.9 0.9417) @0.4 lx=%.1f (want 526.4) @0.5 lx=%.1f (want 526.4) SETTLE +1 s lx=%.1f (want 502.4) +2 s lx=%.1f (want 500.0) a moved=%s (want true) DAY rides=%d spills=%d (want 0 0)" % [k2, pivx, k4, k5, s1, s2, absf(a_s2 - a_s1) > 0.01, int(d4["rides"]), int(d4["spills"])])
	# 그림: 노드 아이 6(홈·말뚝 둘·축·소리 둘), 축 아이 3(통·끈 둘); 노드 자리 (500 − 480)/36 = 0.5556, 1400/36 = 38.8889, −70/36 = −1.9444; 축 자리 (0, 8/36 = 0.2222, 22/36 = 0.6111); 말뚝 x ±(160/72 + 0.04) = ±2.2622
	var node: Node3D = g["node"]; var piv: Node3D = g["piv"]; var peg: Node3D = node.get_child(1)
	print("VISUAL node children=%d piv=%d (want 6 3) node pos=%.4f %.4f %.4f (want 0.5556 38.8889 −1.9444) piv pos=%.4f %.4f %.4f (want 0.0000 0.2222 0.6111) peg x=%.4f (want −2.2622) rot z=%.3f (want −a: %.3f)" % [node.get_child_count(), piv.get_child_count(), node.position.x, node.position.y, node.position.z, piv.position.x, piv.position.y, piv.position.z, peg.position.x, piv.rotation.z, -float(g["a"])])
	# 자세(log_v 1.0, 예비 0.3 s 뒤 한 박자 0.5 s 표본): 어깨 z 오른 −(0.15 + 1.25) = −1.40 왼 +1.40 (±0.1 — 블렌딩), 고개 > 0.15 아래, 골반 < 0.42 − 0.03, 두 무릎 늘 > 0.15, 가장 높이 든 엉덩이 < −0.6 (박자 0.5 s 에 −1.15 까지); log_v 0.0 (허둥댐): 어깨 x 가 0.25 s 안에 0.05 넘게 움직인다
	fig.pose_request = "log"; fig.set_meta("log_v", 1.0)
	while fig.pose_t < 0.3: await process_frame
	var rsh: float = (fig.shoulders[1.0] as Node3D).rotation.z; var lsh: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var neck := fig.neck.rotation.x; var pel := fig.pelvis.position.y
	var min_knee := 9.0; var min_hip := 9.0; var t0 := fig.pose_t
	while fig.pose_t < t0 + 0.5:   # 한 박자(두 걸음) — 헤드리스의 프레임 수가 아니라 pose_t 로 기다린다
		await process_frame
		min_knee = minf(min_knee, minf((fig.knees[1.0] as Node3D).rotation.x, (fig.knees[-1.0] as Node3D).rotation.x))
		min_hip = minf(min_hip, minf((fig.hips[1.0] as Node3D).rotation.x, (fig.hips[-1.0] as Node3D).rotation.x))
	fig.set_meta("log_v", 0.0)
	t0 = fig.pose_t
	while fig.pose_t < t0 + 0.2: await process_frame
	var shx_lo := 9.0; var shx_hi := -9.0; t0 = fig.pose_t
	while fig.pose_t < t0 + 0.25:
		await process_frame
		var sx: float = (fig.shoulders[1.0] as Node3D).rotation.x
		shx_lo = minf(shx_lo, sx); shx_hi = maxf(shx_hi, sx)
	print("POSE arms R=%.2f L=%.2f (want −1.40 +1.40 ±0.1) neck=%.2f (want > 0.15) pelvis=%.3f (want < 0.39) knees min=%.2f (want > 0.15) hip min=%.2f (want < −0.6) | scramble shoulder x swing=%.2f (want > 0.05)" % [rsh, lsh, neck, pel, min_knee, min_hip, shx_hi - shx_lo])
	# 진짜 탑: 1..70층에 plan 이 찾는 통나무 — 옛 회관 층 0..4, 35..39, 70 중 회전문(taken)이 비켜 가고 150 px 이상 남는 발판이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var out2 := lg.plan(n, pl, cb.plan(n, pl) + cr.plan(n, pl, cb.plan(n, pl)))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s w %.0f" % [String(v["hop_id"]), float(v["w"])])])
	print("TOWER floors=", bands, " (want a subset of 1..4, 35..39 and 70 — one log each on a hop ≥ 150 px that the door did not take, never another theme)")
	quit()
