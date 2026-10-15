extends SceneTree
## 풍경 팩 점검(헤드리스): 자료가 읽히나, 공중 정원 층의 잇단 still 발판 짝(80..220 px 틈, 위 발판이 30..150 px 높다) 중 가장 넓은 틈의 위 턱에만 풍경이 서나(턱의 화분·턱까지 닿는 해먹 줄은 그 턱을 가져가고, 낮게 걸린 해먹·발판 가운데의 통풍구는 아니다, 진폭째 상자에 드는 움직이는 발판도, 다른 테마 층은 아니다, 거울 층은 반대로, 바람은 자리가 아니라 세기만),
## 공중의 몸이 걷는 깊이에서 통의 띠를 지날 때만 두드리나(선 몸·멀리·위·아래·앞·rehit_s 안은 아니다), 엉킴이 1 에서 tangle_s 에 걸쳐 0 으로 가나, 받침대·팔·매듭·통 다섯(줄·통·마디)·소리 둘이 그려지고 통의 각이 바람의 숨 + 엉킴인가, 바람이 있는 층만 이따금 띵 하나(없는 층은 영영 없다),
## brush 자세가 움찔하고 쓸고 착지에 받치며 고개를 터나, 진짜 탑의 1..70층에서 plan 이 공중 정원 층에만 풍경을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cw := ClimbChime.new(); root.add_child(cw)
	var cu := ClimbUpdraft.new(); root.add_child(cu)
	var cpl := ClimbPlanter.new(); root.add_child(cpl)
	var ctu := ClimbTulip.new(); root.add_child(ctu)
	var cv := ClimbVine.new(); root.add_child(cv)
	var chm := ClimbHammock.new(); root.add_child(chm)
	var cz := ClimbZip.new(); root.add_child(cz)
	var sd := ClimbSundial.new(); root.add_child(sd)
	await process_frame
	print("PACK id=", cw.pack.get("id"), " kind=", cw.kind.size() > 0, " pose=", cw.pack.get("pose"), " themes=", cw.pack.get("themes"), " out=%.0f post=%.0f string=%.0f pitch=%.0f tubes=%s r=%.1f half=%.1f body=%.0f breeze=%.2f wind_sw=%.2f hz=%.2f tangle=%.1f/%.1f rehit=%.2f ring=%.1f tink=%.1f (want 22 56 8 7 [28, 24, 20, 17, 14] 1.6 15.6 44 0.06 0.35 0.45 2.0/0.9 0.25 1.2 2.4)" % [cw.out(), cw.post_h(), cw.string_px(), cw.pitch(), str(cw.tubes()), cw.tube_r(), cw.half_span(), cw.body_h(), cw.breeze(), cw.wind_sw(), cw.sway_hz(), cw.tangle_s(), cw.tangle_amp(), cw.rehit_s(), cw.ring_s(), cw.tink_every()])
	var plats: Array = [
		{ "id": "40.0", "x": 60.0, "y": 24100.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "40.1", "x": 420.0, "y": 24190.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "40.2", "x": 180.0, "y": 24280.0, "w": 140.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "40.3", "x": 540.0, "y": 24400.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "40.4", "x": 300.0, "y": 24460.0, "w": 100.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "40s", "x": 700.0, "y": 24420.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cw.plan(40, plats)
	var planted := cw.plan(40, plats, [{ "id": "40.P0", "kind": "planter", "x": 540.0, "w": 30.0, "y": 24400.0, "y_top": 24440.0 }])   # 40.3 의 턱에 선 화분 — 그 턱은 화분의 것: 40.0→40.1 (200) 로
	var high := cw.plan(40, plats, [{ "id": "40.H0", "kind": "hammock", "x": 330.0, "w": 200.0, "y": 24300.0, "rail_y": 24395.0 }])   # 40.2↔40.3 의 틈에 걸린 해먹, 줄이 턱 가까이(24395 ≥ 24380) — 턱은 해먹의 것
	var low := cw.plan(40, plats, [{ "id": "40.H0", "kind": "hammock", "x": 330.0, "w": 200.0, "y": 24300.0, "rail_y": 24350.0 }])    # 같은 해먹이 낮게(24350 < 24380) — 아래 틈의 것, 턱은 빈다
	var vented := cw.plan(40, plats, [{ "id": "40.V0", "kind": "vent", "x": 580.0, "w": 40.0, "y": 24400.0 }])   # 40.3 가운데의 통풍구 — 턱(496..548)과 안 겹친다
	var moved := plats.duplicate(true); moved.append({ "id": "40m", "x": 480.0, "y": 24440.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 40.0 })   # 진폭째(430..590, 24440) 40.3 턱의 상자에 든다
	var movep := cw.plan(40, moved)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := cw.plan(40, mirror, [], 120.0)
	var f4 := cw.plan(4, plats); var f5 := cw.plan(5, plats); var f7 := cw.plan(7, plats); var f9 := cw.plan(9, plats); var f10 := cw.plan(10, plats); var f40 := cw.plan(40, plats); var f44 := cw.plan(44, plats); var f45 := cw.plan(45, plats)
	var w0 := float((cw.plan(40, plats, [], 0.0)[0] as Dictionary)["wind_k"]); var w120 := float((right[0] as Dictionary)["wind_k"]); var w200 := float((cw.plan(40, plats, [], -200.0)[0] as Dictionary)["wind_k"])
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s hinge %.0f cx %.0f post %.0f x %.1f w %.1f y %.0f y_top %.0f" % [float(v["dir"]), float(v["gap"]), String(v["a_id"]), String(v["b_id"]), float(v["hinge_x"]), float(v["cx"]), float(v["post_x"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"])]
	var brief := func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f hinge %.0f" % [float(v["gap"]), float(v["hinge_x"])]
	print("PLAN free=", free.map(show), " (want 1: 40.W0 dir 1 gap 220 40.2→40.3 wins over 40.0↔40.1 gap 200; 40.3↔40.4 gap 140 and 40.1↔40.2 gap 100 lose: hinge 540 cx 518 post 544 x 496.4 w 51.6 y 24400 y_top 24456)")
	print("PLAN planted=", planted.map(brief), " high=", high.map(brief), " (want 40.W0 gap 200 hinge 420 ×2: the lip is the planter's / the hammock rope's) low=", low.map(brief), " vented=", vented.map(brief), " (want gap 220 hinge 540 ×2: a low rope belongs to the gap below, a vent in the hop's middle leaves the lip) moved=", movep.map(brief), " (want gap 200 hinge 420) right=", right.map(show), " (want 40.W0 dir −1 gap 220 hinge 420 cx 442 post 416 x 412.0 w 51.6) floors 4/5/7/9/10/40/44/45=", [f4.size(), f5.size(), f7.size(), f9.size(), f10.size(), f40.size(), f44.size(), f45.size()], " (want 0 1 1 1 0 1 1 0: every Hanging garden floor, the vent floor 7 too, no other theme) wind_k 0/120/−200=%.4f %.4f %.4f (want 0.0000 0.6667 1.0000)" % [w0, w120, w200])
	var band_root := Node3D.new(); root.add_child(band_root)
	cw.build(band_root, free, 0.0)
	var c: Dictionary = cw.chimes[0]
	# 두드림(10.0, cx 518, 통의 띠 24420..24448, x 반폭 15.6 + HW 10): 선 몸·x 470·y 24460(발이 매듭 위)·y 24360(머리가 통 밑)·앞 z −30 은 아니다; 공중 x 518 y 24410 은 두드린다(엉킴 1); 10.1 은 아니다(rehit); 10.3 은 다시; 엉킴 11.3 0.5 / 12.3 0; 가장자리 x 543 은 두드린다
	cw.sync(10.0)
	var stand := cw.brush(518.0, 24410.0, C.PLAYER_Z, false); var far := cw.brush(470.0, 24410.0, C.PLAYER_Z, true); var over := cw.brush(518.0, 24460.0, C.PLAYER_Z, true); var under := cw.brush(518.0, 24360.0, C.PLAYER_Z, true); var front := cw.brush(518.0, 24410.0, -30.0, true)
	var hits0 := int(c["hits"])
	var ok := cw.brush(518.0, 24410.0, C.PLAYER_Z, true); var k10 := cw.tangle(c, 10.0); var rang: bool = (c["ring"] as AudioStreamPlayer3D).playing
	cw.sync(10.1); var again := cw.brush(518.0, 24410.0, C.PLAYER_Z, true); var hits1 := int(c["hits"])
	cw.sync(10.3); var re := cw.brush(518.0, 24410.0, C.PLAYER_Z, true); var hits2 := int(c["hits"])
	var k9 := cw.tangle(c, 9.0); var k113 := cw.tangle(c, 11.3); var k123 := cw.tangle(c, 12.3)
	cw.sync(10.6); var edge := cw.brush(543.0, 24410.0, C.PLAYER_Z, true)
	print("BRUSH stand=%s far=%s over=%s under=%s front=%s hits=%d (want false ×5, 0) ok=%s id=%s tangle=%.2f ring=%s (want true 40.W0 1.00 true) again=%s hits=%d (want false 1: within rehit) re=%s hits=%d (want true 2) tangle 9.0=%.2f 11.3=%.2f 12.3=%.2f (want 0.00 0.50 0.00) edge=%s (want true: 25 px off centre is inside 25.6)" % [stand["brushed"], far["brushed"], over["brushed"], under["brushed"], front["brushed"], hits0, ok["brushed"], String(ok["id"]), k10, rang, again["brushed"], hits1, re["brushed"], hits2, k9, k113, k123, edge["brushed"]])
	# 그림: 노드 아이 10(기둥·팔·매듭·통 다섯·소리 둘), 통 아이 3(줄·통·마디); 노드 자리 (544 − 480)/36 = 1.7778, 24400/36 = 677.7778, −48/36 = −1.3333; 통 0 자리 x (518 − 544 − 14)/36 = −1.1111 y (56 − 0.8)/36 = 1.5333, 통 몸통 y −(8 + 14)/36 = −0.6111
	# 각(위상 40 × 0.37 = 14.8, 숨 0.06): 20.0 에 두드려 엉킴 1 → 통 0 의 각 0.06 sin(0.9π·20 + 14.8) + 0.9 sin(180 + 29.6) = 0.0473 + 0.6975 = 0.7448; 21.0 (엉킴 0.5) −0.0564 − 0.4350 = −0.4913; 22.5 (엉킴 0) 0.0073 — 숨만 남는다
	var node: Node3D = c["node"]; var pivots: Array = c["pivots"]; var p0: Node3D = pivots[0]; var tube0 := p0.get_child(1) as Node3D
	cw.sync(20.0); cw.brush(518.0, 24410.0, C.PLAYER_Z, true); cw._process(0.0); var a20 := p0.rotation.z; var f20 := cw.tube_angle(c, 0, 20.0)
	cw.sync(21.0); cw._process(0.0); var a21 := p0.rotation.z
	cw.sync(22.5); cw._process(0.0); var a225 := p0.rotation.z
	print("VISUAL node children=%d pivot children=%d (want 10 3) node pos=%.4f %.4f %.4f (want 1.7778 677.7778 −1.3333) pivot0 pos=%.4f %.4f tube0 y=%.4f (want −1.1111 1.5333 −0.6111) sway=%.2f (want 0.06: no wind) angle@20=%.4f fn=%.4f (want 0.7448 ×2: knocked) @21=%.4f (want −0.4913: half tangled) @22.5=%.4f (want 0.0073: the breeze alone)" % [node.get_child_count(), p0.get_child_count(), node.position.x, node.position.y, node.position.z, p0.position.x, p0.position.y, tube0.position.y, cw.sway(c), a20, f20, a21, a225])
	# 바람: 거울 층의 풍경을 바람 120 으로(wind_k 0.6667, 숨 0.2933, 띵 −17.33 dB): 30.0 에 지어 31.0 에 첫 띵, 다음은 31 + 2.4/0.6667 × (0.7 + 0.6 × 0.618) = 34.855; 바람 없는 첫 풍경은 100.0 에도 띵이 없다
	var root2 := Node3D.new(); root.add_child(root2)
	cw.sync(30.0); cw.build(root2, right, 120.0)
	var c2: Dictionary = cw.chimes[1]; var tink: AudioStreamPlayer3D = c2["tink"]
	cw.sync(30.5); cw._process(0.0); var t305 := tink.playing; var n305 := int(c2["tinks"])
	cw.sync(31.0); cw._process(0.0); var t31 := tink.playing; var n31 := int(c2["tinks"]); var nx := float(c2["next_tink"])
	cw.sync(100.0); cw._process(0.0); var n100 := int(c["tinks"])
	print("WIND wind_k=%.4f sway=%.4f db=%.2f (want 0.6667 0.2933 −17.33) 30.5: playing=%s tinks=%d (want false 0) 31.0: playing=%s tinks=%d next=%.3f (want true 1 34.855) still chime @100 tinks=%d (want 0: no wind, no tink)" % [float(c2["wind_k"]), cw.sway(c2), tink.volume_db, t305, n305, t31, n31, nx, n100])
	# 자세(brush_t 0.08 움찔 0.7407: 오른 어깨 x −1.7778 z −0.1111 팔꿈치 −1.2593 엉덩이 −0.3333 무릎 0.5185, 왼 어깨 x −0.8148 팔꿈치 −1.4074 | 0.5 쓸기: 오른 어깨 x −1.4474 z −0.9000 팔꿈치 −0.3045 엉덩이 −0.2700 무릎 0.4200 왼 어깨 z −0.1500 골반 0.420 | 착지 0.65, 0.725: 고개 y 0.6 × 0.1563 + 0.3 × 0.7071 = 0.3059 골반 0.3634 | 0.8: 엉덩이 −0.5 무릎 1.0 오른 어깨 x −0.6 z −0.1 골반 0.340 done false | 1.0 done)
	var fig := Stick3D.new(); root.add_child(fig)
	fig.pose_request = "brush"; fig.airborne = true; fig.set_meta("brush_t", 0.08)
	for i in 90: await process_frame
	var a_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var a_shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var a_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var a_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var a_knee: float = (fig.knees[1.0] as Node3D).rotation.x
	var a_lshx: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var a_lel: float = (fig.elbows[-1.0] as Node3D).rotation.x; var a_done := BrushPoses.done(fig)
	fig.set_meta("brush_t", 0.5)
	for i in 90: await process_frame
	var b_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var b_shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var b_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var b_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var b_knee: float = (fig.knees[1.0] as Node3D).rotation.x
	var b_lshz: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var b_pel := fig.pelvis.position.y; var b_done := BrushPoses.done(fig)
	fig.airborne = false; fig.set_meta("brush_t", 0.65)
	for i in 3: await process_frame
	var land := float(fig.get_meta("brush_land", -1.0))
	fig.set_meta("brush_t", 0.725)
	for i in 90: await process_frame
	var c_nky := fig.neck.rotation.y; var c_pel := fig.pelvis.position.y; var c_done := BrushPoses.done(fig)
	fig.set_meta("brush_t", 0.8)
	for i in 90: await process_frame
	var d_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var d_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var d_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var d_shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var d_pel := fig.pelvis.position.y; var d_done := BrushPoses.done(fig)
	fig.set_meta("brush_t", 1.0); var e_done := BrushPoses.done(fig)
	print("POSE flinch: R sh=%.4f %.4f el=%.4f hip=%.4f knee=%.4f L sh=%.4f el=%.4f done=%s (want −1.7778 −0.1111 −1.2593 −0.3333 0.5185 −0.8148 −1.4074 false) | sweep: R sh=%.4f %.4f el=%.4f hip=%.4f knee=%.4f L sh z=%.4f pelvis=%.3f done=%s (want −1.4474 −0.9000 −0.3045 −0.2700 0.4200 −0.1500 0.420 false) | land=%.2f (want 0.65) shake: neck y=%.4f pelvis=%.4f done=%s (want 0.3059 0.3634 false) | brace: hip=%.4f knee=%.4f R sh=%.4f %.4f pelvis=%.3f done=%s (want −0.5000 1.0000 −0.6000 −0.1000 0.340 false) | done@1.0=%s (want true)" % [a_shx, a_shz, a_el, a_hip, a_knee, a_lshx, a_lel, a_done, b_shx, b_shz, b_el, b_hip, b_knee, b_lshz, b_pel, b_done, land, c_nky, c_pel, c_done, d_hip, d_knee, d_shx, d_shz, d_pel, d_done, e_done])
	# 진짜 탑: 1..70층에 plan 이 찾는 풍경 — 공중 정원 층 5..9, 40..44 중 통풍구·화분·튤립·덩굴·해먹·집라인·해시계(taken)가 안 든 턱이 있는 층만, 층마다 하나
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n); var wind: float = gm.wind_of(n)
		var vents: Array = cu.plan(n, pl)
		var taken: Array = vents + cpl.plan(n, pl) + ctu.plan(n, pl) + cv.plan(n, pl) + chm.plan(n, pl, wind) + cz.plan(n, pl) + sd.plan(n, pl, vents)
		var out2 := cw.plan(n, pl, taken, wind)
		if out2.size() > 0:
			bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f wind %.2f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["wind_k"])])]); count += out2.size()
	print("TOWER floors=", bands, " chimes=", count, " (want a subset of 5, 6, 7, 8, 9, 40, 41, 42, 43, 44 — one each, never another theme; wind 0 under floor 40)")
	quit()
