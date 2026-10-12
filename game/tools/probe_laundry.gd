extends SceneTree
## 빨랫줄 팩 점검(헤드리스): 자료가 읽히나, 옛 회관 층의 잇단 still 발판 짝(90..220 px 틈, 위 발판이 60..120 px 높다) 중 가장 넓은 틈 하나에만 줄이 서나(높이차가 너무 큰 짝·틈이 좁은 짝·진폭째 상자에 드는 움직이는 발판·taken 조각(종 줄)이 든 틈은 지고, 회전문은 발판 가운데라 비켜 가며, 다른 테마 층·바람구멍 층은 아니다, 거울 층은 반대로),
## 두 말뚝 사이의 줄 밑 ↑ 만 잡나(creak — 말뚝 밖·낮거나 높거나·앞이면 아니다), 손이 110 px/s 로 가다 이불 밑에선 55 로 느려지고(flap) 이불을 지나면 도로 빠른가, 메타(shimmy_v·ph·sheet·hood·walk)가 적히나, 끝 말뚝에서 end 가 서나,
## 한 이불 밑에 1.5초 있으면 집게가 튀어(pop) 이불이 머리(socket_hat)로 가고 그 뒤 손은 제 빠르기로 가나, 놓으면 hooded 가 따라오나, 내려선 뒤 blind 가 1초 동안 걸음 메타를 적고 끝나면 이불을 아래 말뚝 밑 무더기로 놓나, 8초 뒤 도로 줄에 걸리나, 모르는 줄은 lost 인가,
## 말뚝 둘·머리쇠 둘·줄 두 토막·이불 셋(집게 둘씩, 가운데 것은 띠)·소리 셋이 그려지고 줄이 말뚝에서 말뚝까지 이어지나, shimmy 자세가 두 손을 머리 위 줄에 번갈아 뻗고 발목을 꼰 다리가 늘어지며 걸음엔 두 손이 얼굴로 가나, 진짜 탑의 1..60층에서 plan 이 옛 회관 층(바람구멍 층 빼고)에만 줄을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cl := ClimbLaundry.new(); root.add_child(cl)
	var cb := ClimbBell.new(); root.add_child(cb)
	var cr := ClimbDoor.new(); root.add_child(cr)
	await process_frame
	print("PACK id=", cl.pack.get("id"), " kind=", cl.kind.size() > 0, " pose=", cl.pack.get("pose"), " themes=", cl.pack.get("themes"), " hang=%.0f inset=%.0f pace=%.0f sheet_k=%.2f stride=%.0f sheet_w=%.0f sheet_h=%.0f peg=%.2f hood=%.2f repeg=%.1f (want 58 24 110 0.50 24 30 48 1.50 1.00 8.0)" % [cl.hang(), cl.inset(), cl.pace(), cl.sheet_k(), cl.stride(), cl.sheet_w(), cl.sheet_h(), cl.peg_s(), cl.hood_s(), cl.repeg_s()])
	var plats: Array = [
		{ "id": "1.0", "x": 100.0, "y": 700.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "1.1", "x": 400.0, "y": 790.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "1.2", "x": 150.0, "y": 885.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "1.3", "x": 420.0, "y": 1010.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "1.4", "x": 600.0, "y": 1100.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "1s", "x": 560.0, "y": 1028.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cl.plan(1, plats)
	var belled := cl.plan(1, plats, [{ "id": "1.b0", "kind": "bell", "x": 335.0, "w": 10.0, "y": 750.0 }])   # 종 줄이 1.0↔1.1 틈에(sally 750..870) — 그 상자도, 1.1↔1.2 의 상자(791..975)도 가른다
	var doored := cl.plan(1, plats, [{ "id": "1.R0", "kind": "door", "x": 162.0, "w": 56.0, "y": 700.0 }])   # 회전문이 1.0 의 가운데(162..218) — 말뚝 상자(242..438) 밖
	var moved := plats.duplicate(true); moved.append({ "id": "1m", "x": 330.0, "y": 760.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째 1.0↔1.1 의 상자에 든다 — 1.1↔1.2 의 상자(791..)엔 아니다
	var movep := cl.plan(1, moved)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := cl.plan(1, mirror)
	var hg := cl.plan(5, plats); var vent := cl.plan(3, plats); var f2 := cl.plan(2, plats); var f4 := cl.plan(4, plats); var f36 := cl.plan(36, plats); var f35 := cl.plan(35, plats); var f39 := cl.plan(39, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cl.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s lo %.0f/%.0f hi %.0f/%.0f run %.0f rise %.0f len %.2f x %.0f w %.0f y %.0f z %.0f" % [float(v["dir"]), float(v["gap"]), String(v["a_id"]), String(v["b_id"]), float(v["lo_x"]), float(v["lo_y"]), float(v["hi_x"]), float(v["hi_y"]), float(v["run"]), float(v["rise"]), float(v["len"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["z"])]
	print("PLAN free=", free.map(show), " (want 1: 1.L0 dir 1 gap 120 1.0→1.1 wins over 1.1↔1.2 gap 90; 1.2↔1.3 dy 125 > 120 out; 1.3↔1.4 gap 60 < 90 out: lo 256/836 hi 424/870 run 168 rise 34 len 171.41 x 256 w 168 y 700 z −29)")
	print("PLAN belled=", belled.size(), " (want 0: the bell's sally in 1.0↔1.1 stands in both boxes) doored=", doored.map(show), " (want 1: 1.L0 as free) moved=", movep.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f lo %.0f/%.0f hi %.0f/%.0f len %.2f" % [float(v["dir"]), float(v["gap"]), float(v["lo_x"]), float(v["lo_y"]), float(v["hi_x"]), float(v["hi_y"]), float(v["len"])]), " (want 1.L0 dir −1 gap 90 lo 424/926 hi 286/965 len 143.41) right=", right.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f lo %.0f hi %.0f" % [float(v["dir"]), float(v["gap"]), float(v["lo_x"]), float(v["hi_x"])]), " (want 1.L0 dir −1 gap 120 lo 704 hi 536) hg=", hg.size(), " vent=", vent.size(), " f2=", f2.size(), " f4=", f4.size(), " f36=", f36.size(), " f35=", f35.size(), " f39=", f39.size(), " (want 0 0 1 1 1 0 0)")
	var s: Dictionary = cl.lines[0]
	var z := float(plats[0]["z"])
	# 닿는 거리(줄의 아래 끝 256/836, 손은 발 + 58): 발 778 → 손 836 은 잡힌다; x 240 (말뚝 밖)·발 740 (손 798, 38 아래)·발 801 (손 859, 23 위)·앞 z 20 은 아니다
	cl.sync(0.0)
	var out := cl.grab(240.0, 778.0, z); var low := cl.grab(256.0, 740.0, z); var high := cl.grab(256.0, 801.0, z); var front := cl.grab(256.0, 778.0, 20.0)
	var g := cl.grab(256.0, 778.0, z)
	var creak: AudioStreamPlayer3D = s["creak"]
	print("REACH out=%s low=%s high=%s front=%s (want empty ×4) | caught=%s x=%.0f y=%.0f dir=%.0f t0=%.1f (want 1.L0 256 778 1 0.0) held=%s creak=%s (want true true) | busy=%s (want empty: held)" % [out.is_empty(), low.is_empty(), high.is_empty(), front.is_empty(), g.get("id", "-"), float(g.get("x", 0.0)), float(g.get("y", 0.0)), float(g.get("dir", 0.0)), float(g.get("t0", 9.0)), bool(s["held"]), creak.playing, cl.grab(300.0, 785.0, z).is_empty()])
	# 손 옮기기(1/16 틱, → 로): 4틱 27.5 (full, 1.8333·… = 6.875/틱) 5틱 이불 0 밑(27..57) 30.9375 v 0.5 flap; 13틱 58.4375 under_t 0.5; 14틱 밖 65.3125 v 1; 16틱 이불 1 밑 75.625 flap; 24틱 밖 106.5625; 38틱 끝 168 end 1
	var fig := Stick3D.new(); root.add_child(fig)
	var flap: AudioStreamPlayer3D = s["flap"]
	var got: Dictionary = {}; var dt := 0.0625
	for k in 38:
		cl.sync(float(k + 1) * dt)
		flap.stop()
		var r := cl.ride(g, dt, 1.0, fig)
		if (k + 1) in [4, 5, 13, 14, 16, 24, 38]: got[k + 1] = { "r": r, "v": float(fig.get_meta("shimmy_v", 9.0)), "ph": float(fig.get_meta("shimmy_ph", 9.0)), "sh": float(fig.get_meta("shimmy_sheet", 9.0)), "hd": float(fig.get_meta("shimmy_hood", 9.0)), "ut": float(s["under_t"]), "flap": flap.playing, "pos": float(s["pos"]) }
	var showr := func(k: int) -> String: var e: Dictionary = got[k]; var r: Dictionary = e["r"]; return "%d: pos=%.4f x=%.4f y=%.4f v=%.2f ph=%.6f sheet=%.0f hood=%.0f under_t=%.4f flap=%s end=%d" % [k, float(e["pos"]), float(r["x"]), float(r["y"]), float(e["v"]), float(e["ph"]), float(e["sh"]), float(e["hd"]), float(e["ut"]), e["flap"], int(r["end"])]
	print("RIDE ", showr.call(4), " (want 27.5000 283.5000 779.6304 1 0.145833 0 0 0 false 0) | ", showr.call(5), " (want 30.9375 286.9375 779.8868 0.5 0.289062 1 0 0 true 0) | ", showr.call(13), " (want 58.4375 314.4375 782.7234 0.5 0.434896 1 0 0.5000 false) | ", showr.call(14), " (want 65.3125 321.3125 783.7015 1 0.721354 0 0 0 false) | ", showr.call(16), " (want 75.6250 331.6250 785.4030 0.5 0.151042 1 0 0 true) | ", showr.call(24), " (want 106.5625 362.5625 792.2678 1 0.440104 0) | ", showr.call(38), " (want 168.0000 424.0000 812.0000 1 0.000000 0 0 0 false end 1)")
	# 집게(끝 168 에서 ← 5틱: 140.5 → 이불 2 밑(111..141) 137.0625, 그 뒤 가만히): 28틱 under_t 1.4375 hood 없음; 29틱 1.5 → pop, 이불 2 가 머리(socket_hat)로, 메타 hood 1 sheet 0; 30·31틱 ← 는 제 빠르기로 130.1875 → 123.3125 v −1
	var pop: AudioStreamPlayer3D = s["pop"]
	var dirs: Array = [-1.0, -1.0, -1.0, -1.0, -1.0]
	for i in 24: dirs.append(0.0)
	dirs.append(-1.0); dirs.append(-1.0)
	var got2: Dictionary = {}
	for k in dirs.size():
		cl.sync(2.375 + float(k + 1) * dt)
		pop.stop()
		var r := cl.ride(g, dt, float(dirs[k]), fig)
		if (k + 1) in [5, 28, 29, 31]: got2[k + 1] = { "r": r, "v": float(fig.get_meta("shimmy_v", 9.0)), "sh": float(fig.get_meta("shimmy_sheet", 9.0)), "hd": float(fig.get_meta("shimmy_hood", 9.0)), "ut": float(s["under_t"]), "pop": pop.playing, "pos": float(s["pos"]), "hood": cl.hood.size(), "state": String(((s["sheets"] as Array)[2] as Dictionary)["state"]), "parent": (((s["sheets"] as Array)[2] as Dictionary)["pivot"] as Node3D).get_parent() == fig.socket_hat }
	var showp := func(k: int) -> String: var e: Dictionary = got2[k]; var r: Dictionary = e["r"]; return "%d: pos=%.4f y=%.4f v=%.2f sheet=%.0f hood=%.0f under_t=%.4f pop=%s hooded=%s hood=%d state=%s on_head=%s" % [k, float(e["pos"]), float(r["y"]), float(e["v"]), float(e["sh"]), float(e["hd"]), float(e["ut"]), e["pop"], r["hooded"], int(e["hood"]), String(e["state"]), e["parent"]]
	print("POP ", showp.call(5), " (want 137.0625 801.3645 −0.5 1 0 0 false false 0 pegged false) | ", showp.call(28), " (want 137.0625 … 0 1 0 1.4375 false false 0 pegged false) | ", showp.call(29), " (want 137.0625 801.3645 0 0 1 0 true true 4 hood true) | ", showp.call(31), " (want 123.3125 797.0222 −1 0 1 0 false true 4 hood true)")
	# 놓기(덮인 채): hooded 가 따라오고 줄은 비어 creak; 공중에선 blind(false) true; 땅에 선 첫 틱(t 5.0)부터 1초 — 5.5 에 walk 0.5, 6.0 에 끝: 이불은 아래 말뚝 밑 무더기(노드 아이, 0.25 0.05 0, x 회전 −π/2, y 배율 0.45), 메타는 지워지고 false; 14.0 엔 도로 걸려(pegged) 제자리(3.5 4.4861 −0.5278); 모르는 줄은 lost
	creak.stop(); var v := cl.let_go(g); var creak_out := creak.playing; var held_out := bool(s["held"])
	cl.sync(4.5); var air := cl.blind(false, fig)
	cl.sync(5.0); var b0 := cl.blind(true, fig); var w0 := float(fig.get_meta("shimmy_walk", 9.0))
	cl.sync(5.5); var b1 := cl.blind(true, fig); var w1 := float(fig.get_meta("shimmy_walk", 9.0)); var h1 := float(fig.get_meta("shimmy_hood", 9.0))
	cl.sync(6.0); var b2 := cl.blind(true, fig); var meta_gone := not fig.has_meta("shimmy_walk") and not fig.has_meta("shimmy_hood")
	var sh2: Dictionary = (s["sheets"] as Array)[2]; var pv2: Node3D = sh2["pivot"]; var node: Node3D = s["node"]
	var heap_ok := pv2.get_parent() == node and String(sh2["state"]) == "heap"
	var heap_pos := pv2.position; var heap_rx := pv2.rotation.x; var heap_sy := pv2.scale.y
	cl.sync(13.9); cl._process(0.0); var still_heap := String(sh2["state"])
	cl.sync(14.0); cl._process(0.0); var back := String(sh2["state"]); var back_pos := pv2.position; var back_sy := pv2.scale.y
	var lost := cl.ride({ "id": "nope", "x": 5.0, "y": 7.0 }, dt, 1.0)
	var again := cl.grab(340.0, 795.0, z)
	print("HOOD let_go hooded=%s held=%s creak=%s (want true false true) | air=%s (want true) | land: %s walk=%.2f (want true 0.00) | 5.5: %s walk=%.2f hood=%.0f (want true 0.50 1) | 6.0: %s metas gone=%s heap=%s pos=%.2f %.2f %.2f rx=%.3f sy=%.2f (want false true true 0.25 0.05 0.00 −1.571 0.45) | 13.9=%s 14.0=%s pos=%.4f %.4f %.4f sy=%.2f (want heap pegged 3.5000 4.4861 −0.5278 1.00) | unknown: lost=%s x=%.0f y=%.0f (want true 5 7) | regrab mid=%s y=%.0f (want 1.L0 787)" % [v["hooded"], held_out, creak_out, air, b0, w0, b1, w1, h1, b2, meta_gone, heap_ok, heap_pos.x, heap_pos.y, heap_pos.z, heap_rx, heap_sy, still_heap, back, back_pos.x, back_pos.y, back_pos.z, back_sy, lost["lost"], float(lost["x"]), float(lost["y"]), again.get("id", "-"), float(again.get("y", 0.0))])
	# 그림(빈 줄, t 20): 노드 아이 12(말뚝 2·머리쇠 2·줄 2·이불 3·소리 3), 이불 아이 3·4·3(천·집게 둘, 가운데 것은 띠); 노드 자리 −6.222 19.444 −0.806; 줄 아래 토막 길이 4.761 (= 171.41/36), 위 토막 0.02(붙었다); 이불 0 자리 1.1667 4.0139 −0.5278
	cl.let_go(again); cl.sync(20.0); cl._process(0.0)
	var seg1: Node3D = s["seg1"]; var seg2: Node3D = s["seg2"]
	var pv0: Node3D = ((s["sheets"] as Array)[0] as Dictionary)["pivot"]; var pv1: Node3D = ((s["sheets"] as Array)[1] as Dictionary)["pivot"]
	print("VISUAL node children=%d (want 12) sheet children=%d %d %d (want 3 4 3) node pos=%.3f %.3f %.3f (want −6.222 19.444 −0.806) | seg1 len=%.3f (want 4.761) seg2 len=%.3f (want 0.020) | sheet0=%.4f %.4f %.4f (want 1.1667 4.0139 −0.5278) flap rx=%.3f (want |rx| ≤ 0.35)" % [node.get_child_count(), pv0.get_child_count(), pv1.get_child_count(), pv2.get_child_count(), node.position.x, node.position.y, node.position.z, seg1.scale.y, seg2.scale.y, pv0.position.x, pv0.position.y, pv0.position.z, pv0.rotation.x])
	# 자세: 매달림(v 1, ph 0.25, sheet 0, hood 0, walk 0): 오른 어깨 −3.10 왼 어깨 −2.50 (앞 손이 뻗는다), 어깨 z ∓0.35, 오른 팔꿈치 −0.20 왼 −0.45 (뒤 손이 당긴다), 엉덩이 ≈ −0.5 ± 0.12 (손이 바뀌는 흔들림), 엉덩이 z ±0.14 (꼰 발목), 무릎 0.45, 골반 0.460, 몸통 0.0675 (가는 쪽으로);
	# 이불(sheet 1): 몸통 그대로, 고개는 돌고 숙는다(여기선 안 잰다); 걸음(hood 1, walk 1): 어깨 ≈ −1.9 ± 0.25, 어깨 z ∓0.30, 팔꿈치 −1.90, 엉덩이 z 0, 골반 0.420, 몸통 0.135
	fig.pose_request = "shimmy"
	fig.set_meta("shimmy_v", 1.0); fig.set_meta("shimmy_ph", 0.25); fig.set_meta("shimmy_sheet", 0.0); fig.set_meta("shimmy_hood", 0.0); fig.set_meta("shimmy_walk", 0.0)
	await process_frame; await process_frame; await process_frame
	var early_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	for i in 60: await process_frame
	var sh_a: float = (fig.shoulders[1.0] as Node3D).rotation.x; var sh_b: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var shz_a: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shz_b: float = (fig.shoulders[-1.0] as Node3D).rotation.z
	var el_a: float = (fig.elbows[1.0] as Node3D).rotation.x; var el_b: float = (fig.elbows[-1.0] as Node3D).rotation.x
	var hip_h: float = (fig.hips[1.0] as Node3D).rotation.x; var hipz_a: float = (fig.hips[1.0] as Node3D).rotation.z; var hipz_b: float = (fig.hips[-1.0] as Node3D).rotation.z; var knee_h: float = (fig.knees[1.0] as Node3D).rotation.x; var pel_h := fig.pelvis.position.y; var torso_h := fig.torso.rotation.x
	fig.set_meta("shimmy_hood", 1.0); fig.set_meta("shimmy_walk", 1.0); fig.set_meta("shimmy_v", 0.0)
	for i in 40: await process_frame
	var sh_w: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz_w: float = (fig.shoulders[1.0] as Node3D).rotation.z; var el_w: float = (fig.elbows[1.0] as Node3D).rotation.x; var hipz_w: float = (fig.hips[1.0] as Node3D).rotation.z; var pel_w := fig.pelvis.position.y; var torso_w := fig.torso.rotation.x
	print("POSE early=%.2f (want > −2.0: the grab has only begun) hanging: shoulders=%.2f %.2f (want −3.10 −2.50: the right hand reaches) z=%.2f %.2f (want −0.35 0.35) elbows=%.2f %.2f (want −0.20 −0.45: the left hand pulls) hip=%.2f (want ≈ −0.5 ± 0.12: the swing peaks with the reach) hip z=%.2f %.2f (want 0.14 −0.14: ankles crossed) knee=%.2f (want 0.45) pelvis=%.3f (want 0.460) torso=%.4f (want 0.0675) | blind walk: shoulder=%.2f (want ≈ −1.9 ± 0.25) z=%.2f (want −0.30) elbow=%.2f (want −1.90) hip z=%.2f (want 0) pelvis=%.3f (want 0.420) torso=%.3f (want 0.135)" % [early_sh, sh_a, sh_b, shz_a, shz_b, el_a, el_b, hip_h, hipz_a, hipz_b, knee_h, pel_h, torso_h, sh_w, shz_w, el_w, hipz_w, pel_w, torso_w])
	# 진짜 탑: 1..60층에 plan 이 찾는 줄 — 옛 회관 층 1..4, 35..39 중 바람구멍 층(3, 35, 39)을 뺀, 종 줄·회전문(taken)이 안 든 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var bl: Array = cb.plan(n, pl)
		var out2 := cl.plan(n, pl, bl + cr.plan(n, pl, bl))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f run %.0f rise %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["run"]), float(v["rise"])])]); count += out2.size()
	print("TOWER floors=", bands, " lines=", count, " (want a subset of 1, 2, 4, 36, 37, 38 — one each, never 3, 35 or 39)")
	quit()
