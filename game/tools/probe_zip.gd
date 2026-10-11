extends SceneTree
## 집라인 팩 점검(헤드리스): 자료가 읽히나, 공중정원 층의 잇단 still 발판 짝(60..200 px 틈, 위 발판이 60..150 px 높다) 중 가장 넓은 틈 하나에만 집라인이 서나(높이차가 너무 큰 짝·지름길 판이 상자를 가르는 짝·진폭째 상자에 드는 움직이는 발판·taken 조각(그물·유령 판)이 든 틈은 지고, 다른 테마 층·바람구멍 층은 아니다, 거울 층은 반대로),
## 닿는 거리 안의 ↑ 만 잡나(zing — 멀거나 낮거나 앞이면 아니다), 트롤리가 비탈을 굴러 속도가 붙고(568 px/s²) 범퍼 앞 48 px 에서 늦춰져(388 → 60) 범퍼에 닿으면(clunk) 0.25초에 걸쳐 발판 윗면에 내려놓고 done 인가, 메타(zip_v·zip_brk·zip_set)가 적히나,
## 놓인 트롤리가 3초에 걸쳐 되감겨 오르며 그동안 잡히지 않고 윈치가 0.25초마다 딸깍이나, 다 오르면 다시 잡히나, 중간에 놓으면 비탈대로 나눈 속도를 주나(zing), 모르는 집라인은 lost 인가,
## 말뚝·머리쇠·윈치·범퍼·케이블 둘·되감는 줄·트롤리(바퀴 둘·걸이·가로대·번호판)·소리 셋이 그려지고 케이블이 말뚝에서 트롤리를 지나 말뚝까지 이어지나, zip 자세가 두 손을 벌려 쥐고 다리를 접은 채 뒤로 처졌다 제동에 앞으로 쏠리고 내려놓으면 다리가 내려오나, 진짜 탑의 1..60층에서 plan 이 공중정원 층(바람구멍 층 빼고)에만 집라인을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cz := ClimbZip.new(); root.add_child(cz)
	var ch := ClimbHammock.new(); root.add_child(ch)
	await process_frame
	print("PACK id=", cz.pack.get("id"), " kind=", cz.kind.size() > 0, " pose=", cz.pack.get("pose"), " themes=", cz.pack.get("themes"), " hang=%.0f inset=%.0f stop=%.0f brake=%.0f max_v=%.0f v_end=%.0f land=%.2f return=%.1f click=%.2f (want 58 24 24 48 420 60 0.25 3.0 0.25)" % [cz.hang(), cz.inset(), cz.stop(), cz.brake(), cz.max_v(), cz.v_end(), cz.land_s(), cz.return_s(), cz.click_s()])
	var plats: Array = [
		{ "id": "5.0", "x": 100.0, "y": 3100.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5.1", "x": 370.0, "y": 3210.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5.2", "x": 110.0, "y": 3320.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "5.3", "x": 380.0, "y": 3480.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5.4", "x": 560.0, "y": 3590.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "5s", "x": 520.0, "y": 3560.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cz.plan(5, plats)
	var netted := cz.plan(5, plats, [{ "id": "5.H0", "kind": "hammock", "x": 270.0, "w": 100.0, "y": 3140.0 }])   # 그물이 5.1↔5.2 틈 밑(3140)에 — 지그재그라 그 자리는 5.0↔5.1 의 케이블 길이기도 해서 둘 다 진다
	var slabbed := cz.plan(5, plats, [{ "id": "5.G0", "kind": "ghost", "x": 290.0, "w": 60.0, "y": 3330.0 }])   # 유령 판이 5.1↔5.2 틈 위에 — 다음으로 넓은 5.0↔5.1
	var moved := plats.duplicate(true); moved.append({ "id": "5m", "x": 420.0, "y": 3380.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째 5.1↔5.2 의 상자에 든다
	var movep := cz.plan(5, moved)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := cz.plan(5, mirror)
	var lib := cz.plan(10, plats); var vent := cz.plan(7, plats); var g8 := cz.plan(8, plats); var g6 := cz.plan(6, plats); var g43 := cz.plan(43, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cz.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s top %.0f/%.0f bot %.0f/%.0f len %.2f sin %.4f cos %.4f bar %.0f feet %.0f x %.0f w %.0f y %.0f z %.0f" % [float(v["dir"]), float(v["gap"]), String(v["b_id"]), String(v["a_id"]), float(v["top_x"]), float(v["top_y"]), float(v["bot_x"]), float(v["bot_y"]), float(v["len"]), float(v["sin"]), float(v["cos"]), float(v["bar_y"]), float(v["feet_y"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["z"])]
	print("PLAN free=", free.map(show), " (want 1: 5.Z0 dir 1 gap 100 5.2→5.1 wins over 5.0↔5.1 gap 90; 5.2↔5.3 dy 160 > 150 out; 5.3↔5.4 gap 60 but 5s cuts the box: top 246/3416 bot 394/3280 len 201.00 sin 0.6766 cos 0.7363 bar 3408 feet 3350 x 246 w 148 y 3210 z −29)")
	print("PLAN netted=", netted.size(), " (want 0: the net under 5.1↔5.2 hangs at 3140, inside the 5.0↔5.1 cable box too) slabbed=", slabbed.map(show), " (want 1: 5.Z0 dir −1 gap 90 5.1→5.0 top 394/3306 bot 256/3170) moved=", movep.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f" % [float(v["dir"]), float(v["gap"])]), " (want 5.Z0 dir −1 gap 90) right=", right.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f top %.0f bot %.0f" % [float(v["dir"]), float(v["gap"]), float(v["top_x"]), float(v["bot_x"])]), " (want 5.Z0 dir −1 gap 100 top 714 bot 566) lib=", lib.size(), " vent=", vent.size(), " g8=", g8.size(), " g6=", g6.size(), " g43=", g43.size(), " (want 0 0 1 1 0)")
	var s: Dictionary = cz.zips[0]
	var z := float(plats[0]["z"])
	# 닿는 거리(t 0, 꼭대기에 선 트롤리): 발 3350 손 3408 — x 246 은 잡힌다; x 282 (36 떨어짐)·발 3320 (손 3378, 30 아래)·앞 z 20 은 아니다
	cz.sync(0.0)
	var far := cz.grab(282.0, 3350.0, z); var low := cz.grab(246.0, 3320.0, z); var front := cz.grab(246.0, 3350.0, 20.0)
	var g := cz.grab(246.0, 3350.0, z)
	var zing: AudioStreamPlayer3D = s["zing"]
	print("REACH far=%s low=%s front=%s (want empty ×3) | caught=%s x=%.0f y=%.0f dir=%.0f t0=%.1f (want 5.Z0 246 3350 1 0.0) held=%s zing=%s (want true true)" % [far.is_empty(), low.is_empty(), front.is_empty(), g.get("id", "-"), float(g.get("x", 0.0)), float(g.get("y", 0.0)), float(g.get("dir", 0.0)), float(g.get("t0", 9.0)), bool(s["held"]), zing.playing])
	# 굴러 내려가기(1/60 틱, 568.4 px/s²): 10틱 x 252.39 y 3342.77 v 0.226; 30틱 300.06/3291.21 v 0.677 vx 209.25 vy −192.29; 41틱 제동 구간에 든다(brk 0.010, vb 388.38, v 0.917); 47틱 365.02/3234.86 brk 0.615 v 0.444; 56틱 범퍼(clunk) 376.33/3226.58 v 0 set 0; 64틱 y 3217.46 set 0.533; 71틱 done y 3210 set 1, 놓여 rel 1.1833 rpos 177.00
	var fig := Stick3D.new(); root.add_child(fig)
	var clunk: AudioStreamPlayer3D = s["clunk"]
	var got: Dictionary = {}; var dt := 1.0 / 60.0
	for k in 71:
		cz.sync(float(k + 1) / 60.0)
		var r := cz.ride(g, dt, fig)
		if (k + 1) in [10, 30, 41, 47, 56, 64, 71]: got[k + 1] = { "r": r, "v": float(fig.get_meta("zip_v", 9.0)), "b": float(fig.get_meta("zip_brk", 9.0)), "s": float(fig.get_meta("zip_set", 9.0)), "vb": float(s["vb"]), "clunk": clunk.playing }
	var showr := func(k: int) -> String: var e: Dictionary = got[k]; var r: Dictionary = e["r"]; return "%d: x=%.2f y=%.2f v=%.3f brk=%.3f set=%.3f vx=%.2f vy=%.2f done=%s clunk=%s" % [k, float(r["x"]), float(r["y"]), float(e["v"]), float(e["b"]), float(e["s"]), float(r["vx"]), float(r["vy"]), r["done"], e["clunk"]]
	print("RIDE ", showr.call(10), " (want 252.39 3342.77 0.226 0 0 69.75 −64.10 false false) | ", showr.call(30), " (want 300.06 3291.21 0.677 0 0 209.25 −192.29) | ", showr.call(41), " vb=%.2f (want brk 0.010 v 0.917 vb 388.38) | " % [float((got[41] as Dictionary)["vb"])], showr.call(47), " (want 365.02 3234.86 0.444 0.615) | ", showr.call(56), " (want 376.33 3226.58 0 1 0 0 0 false true) | ", showr.call(64), " (want y 3217.46 set 0.533) | ", showr.call(71), " (want y 3210.00 set 1.000 done true) held=%s rel=%.4f rpos=%.2f (want false 1.1833 177.00)" % [bool(s["held"]), float(s["rel"]), float(s["rpos"])])
	# 되감기(1.1833 → 4.1833): 2.0 엔 잡히지 않는다; 2.6833 엔 반(88.50 — 트롤리 local x 1.810 m); 1.45 에 _process 가 딸깍(n 1), 1.47 은 조용, 1.71 에 다시(n 2); 4.2 엔 꼭대기라 다시 잡힌다
	var click: AudioStreamPlayer3D = s["click"]
	cz.sync(2.0); var busy := cz.grab(246.0, 3350.0, z)
	cz.sync(1.1833 + 1.5); cz._process(0.0); var half := cz.dist(s, cz.t); var tx: float = (s["trolley"] as Node3D).position.x
	cz.sync(1.45); click.stop(); cz._process(0.0); var c1 := click.playing; var n1 := int(s["clicks"])
	click.stop(); cz.sync(1.47); cz._process(0.0); var c2 := click.playing
	cz.sync(1.71); cz._process(0.0); var c3 := click.playing; var n3 := int(s["clicks"])
	cz.sync(4.2); var g2 := cz.grab(246.0, 3350.0, z)
	print("RETURN grab while returning=%s (want empty) | half: dist=%.2f trolley x=%.3f (want 88.50 1.810) | clicks 1.45=%s n=%d 1.47=%s 1.71=%s n=%d (want true 1 false true 2) | 4.2: caught=%s t0=%.1f (want 5.Z0 4.2)" % [busy.is_empty(), half, tx, c1, n1, c2, c3, n3, g2.get("id", "-"), float(g2.get("t0", 9.0))])
	# 놓기(t0 4.2): 30틱 뒤 SPACE — v 284.18 을 비탈대로 vx 209.25 vy −192.29 (zing), rel 4.7 rpos 73.41; 5.0 의 잡기는 안 된다; 6.2 엔 반(36.71 → local x 0.751); 7.7 엔 다시 잡힌다; 모르는 집라인은 lost
	for k in 30:
		cz.sync(4.2 + float(k + 1) / 60.0); cz.ride(g2, dt, fig)
	zing.stop(); var v := cz.let_go(g2); var zing_out := zing.playing; var held_out := bool(s["held"])
	cz.sync(5.0); var busy2 := cz.grab(246.0, 3350.0, z)
	cz.sync(6.2); cz._process(0.0); var half2 := cz.dist(s, cz.t); var tx2: float = (s["trolley"] as Node3D).position.x
	cz.sync(7.7); var g3 := cz.grab(246.0, 3350.0, z)
	var lost := cz.ride({ "id": "nope", "x": 5.0, "y": 7.0 }, dt)
	print("LETGO vx=%.2f vy=%.2f (want 209.25 −192.29) held=%s rel=%.1f rpos=%.2f zing=%s (want false 4.7 73.41 true) | 5.0 grab=%s (want empty) | 6.2: dist=%.2f trolley x=%.3f (want 36.71 0.751) | 7.7: caught=%s (want 5.Z0) | unknown: lost=%s x=%.0f y=%.0f (want true 5 7)" % [float(v["vx"]), float(v["vy"]), held_out, float(s["rel"]), float(s["rpos"]), zing_out, busy2.is_empty(), half2, tx2, g3.get("id", "-"), lost["lost"], float(lost["x"]), float(lost["y"])])
	# 그림(꼭대기에 선 트롤리, t 12): 노드 아이 13(말뚝 2·머리쇠 2·윈치·범퍼·케이블 2·되감는 줄·트롤리·소리 3), 트롤리 아이 5(바퀴 2·걸이·가로대·번호판); 노드 자리 −6.5 92.222 −0.806; 트롤리 local 0 2.667 −0.528; 범퍼 3.620 −0.660; 케이블 아래 토막 길이 5.583 (= 201/36), 위 토막 0.02(붙었다); 되감는 줄은 윈치(2.817)에서 트롤리까지 ≈ 0.13
	cz.let_go(g3); cz.sync(12.0); cz._process(0.0)
	var node: Node3D = s["node"]; var trolley: Node3D = s["trolley"]; var down: Node3D = s["down"]; var up: Node3D = s["up"]; var haul: Node3D = s["haul"]
	var bumper: Node3D = node.get_child(5)
	print("VISUAL node children=%d (want 13) trolley children=%d (want 5) node pos=%.3f %.3f %.3f (want −6.500 92.222 −0.806) | trolley=%.3f %.3f %.3f (want 0.000 2.667 −0.528) bumper=%.3f %.3f (want 3.620 −0.660) | cable down len=%.3f (want 5.583) up len=%.3f (want 0.020) haul len=%.3f (want ≈ 0.13)" % [node.get_child_count(), trolley.get_child_count(), node.position.x, node.position.y, node.position.z, trolley.position.x, trolley.position.y, trolley.position.z, bumper.position.x, bumper.position.y, down.scale.y, up.scale.y, haul.scale.y])
	# 자세: 매달림(v 1, brk 0, set 0): 두 어깨 −2.85, 어깨 z ∓0.55 (벌려 쥔다), 팔꿈치 −0.20, 엉덩이 ≈ −1.0 ± 0.1 (접힌 다리), 무릎 1.60, 골반 0.470, 몸통 < 0 (트롤리 뒤로 처진다); 제동(brk 1): 엉덩이 ≈ −1.15 ± 0.1, 무릎 1.70, 몸통 > 0 (앞으로 쏠린다); 내려놓기(set 1): 엉덩이 −0.15, 무릎 0.30, 팔꿈치 −0.45, 골반 0.420, 몸통 ≈ 0
	fig.pose_request = "zip"
	fig.set_meta("zip_v", 1.0); fig.set_meta("zip_brk", 0.0); fig.set_meta("zip_set", 0.0)
	await process_frame; await process_frame; await process_frame
	var early_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	for i in 60: await process_frame
	var sh_a: float = (fig.shoulders[1.0] as Node3D).rotation.x; var sh_b: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var shz_a: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shz_b: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var el_h: float = (fig.elbows[1.0] as Node3D).rotation.x
	var hip_h: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_h: float = (fig.knees[1.0] as Node3D).rotation.x; var pel_h := fig.pelvis.position.y; var torso_h := fig.torso.rotation.x
	fig.set_meta("zip_brk", 1.0)
	for i in 30: await process_frame
	var hip_b: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_b: float = (fig.knees[1.0] as Node3D).rotation.x; var torso_b := fig.torso.rotation.x
	fig.set_meta("zip_set", 1.0)
	for i in 30: await process_frame
	var hip_s: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_s: float = (fig.knees[1.0] as Node3D).rotation.x; var el_s: float = (fig.elbows[1.0] as Node3D).rotation.x; var pel_s := fig.pelvis.position.y; var torso_s := fig.torso.rotation.x
	print("POSE early=%.2f (want > −2.0: the grab has only begun) hanging: shoulders=%.2f %.2f (want −2.85 both) z=%.2f %.2f (want −0.55 0.55: hands apart) elbow=%.2f (want −0.20) hip=%.2f (want ≈ −1.0 ± 0.1: tucked) knee=%.2f (want 1.60) pelvis=%.3f (want 0.470) torso=%.3f (want < 0: hanging behind the trolley) | braking: hip=%.2f (want ≈ −1.15 ± 0.1) knee=%.2f (want 1.70) torso=%.3f (want > 0: thrown forward) | set down: hip=%.2f (want −0.15) knee=%.2f (want 0.30) elbow=%.2f (want −0.45) pelvis=%.3f (want 0.420) torso=%.3f (want ≈ 0)" % [early_sh, sh_a, sh_b, shz_a, shz_b, el_h, hip_h, knee_h, pel_h, torso_h, hip_b, knee_b, torso_b, hip_s, knee_s, el_s, pel_s, torso_s])
	# 진짜 탑: 1..60층에 plan 이 찾는 집라인 — 공중정원 층 5..9, 40..44 중 바람구멍 층(7, 43)을 뺀, 그물(taken)이 안 깔린 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var out := cz.plan(n, pl, ch.plan(n, pl, gm.wind_of(n)))
		if out.size() > 0: bands.append("%d:%s" % [n, out.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f len %.0f" % [String(v["b_id"]), String(v["a_id"]), float(v["dir"]), float(v["gap"]), float(v["len"])])]); count += out.size()
	print("TOWER floors=", bands, " zips=", count, " (want a subset of 5, 6, 8, 9, 40, 41, 42, 44 — one each, never 7 or 43)")
	quit()
