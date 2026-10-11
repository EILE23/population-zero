extends SceneTree
## 파터노스터 팩 점검(헤드리스): 자료가 읽히나, 서재 층의 벽 쪽(짝수 왼·홀수 오른) 레인 — 벽에 가장 가까운 턱에서 8 바깥이 안쪽 가장자리, 거기서 40 안의 발판 둘 이상이 쓴다 — 에만 사슬이 서나(다른 테마 층·쓰는 발판이 하나뿐·레인에 지름길 판·고리 높이 안에서 진폭째 레인에 드는 움직이는 발판·taken 조각은 아니다, 오른벽은 거울로),
## 고리의 수(아래 170·위 10, 9칸 × 160 = 1440, H 664)가 맞나, 칸이 오름 → 꼭대기(옆으로) → 내림 → 바닥(옆으로) → 오름으로 도나, 바닥을 지나 떨어지는 몸만 land 가 받나(가장자리 너머·한참 밑·앞뒤 밖은 아니다), 같은 틱에 발밑으로 솟은 바닥도 받나,
## stand 가 오를 땐 x 를 두고 꼭대기·바닥을 돌 땐 옆으로 실어 가며 on 의 x·y 를 고쳐 쓰나, 가장자리에서 6 을 지나면 off(creak)인가, 나서는 메타가 문턱에서 오르나, 사라진 사슬이면 lost 인가, 칸이 꼭대기 톱니를 지나면 clank 가 우나,
## 레일·사슬 줄·굴대·칸·creak·clank 와 칸 안의 바닥·지붕·뒷벽·난간·걸이·번호판이 그려지고 칸이 제자리에 가나, board 자세가 들어서며 무릎을 들고 손을 난간에 올려 타다 나서며 놓나, 진짜 탑의 1..60층에서 plan 이 서재 층(10..14, 45..49)에만 사슬을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var pn := ClimbPaternoster.new(); root.add_child(pn)
	var cl := ClimbLadder.new(); root.add_child(cl)
	var cd := ClimbDumbwaiter.new(); root.add_child(cd)
	var cb := ClimbBookcase.new(); root.add_child(cb)
	await process_frame
	print("PACK id=", pn.pack.get("id"), " kind=", pn.kind.size() > 0, " pose=", pn.pack.get("pose"), " themes=", pn.pack.get("themes"), " cab=%.0f×%.0f×%.0f pitch=%.0f period=%.2f speed=%.0f lane=%.0f reach=%.0f over=%.0f (want 48×76×40 160 2.00 80 56 40 6)" % [pn.cab_w(), pn.cab_h(), pn.cab_d(), pn.pitch(), pn.period(), pn.speed(), pn.lane_w(), pn.reach(), pn.over()])
	var plats: Array = [
		{ "id": "10r", "x": 250.0, "y": 6000.0, "w": 400.0, "kind": "rest", "z": 0.0, "d": 180.0 },
		{ "id": "10.0", "x": 150.0, "y": 6100.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "10.1", "x": 420.0, "y": 6200.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "10.2", "x": 160.0, "y": 6320.0, "w": 160.0, "kind": "ice", "z": -35.0, "d": 70.0 },
		{ "id": "10.3", "x": 450.0, "y": 6430.0, "w": 160.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "10.4", "x": 140.0, "y": 6540.0, "w": 170.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "10.5", "x": 500.0, "y": 6650.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "10s", "x": 300.0, "y": 6468.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var free := pn.plan(10, plats)
	var laddered := pn.plan(10, plats, [{ "id": "10.L0", "kind": "ladder", "x": 40.0, "w": 90.0, "y": 6150.0 }])   # 사다리가 레인에
	var cased := pn.plan(10, plats, [{ "id": "10.B0", "kind": "bookcase", "x": 450.0, "w": 40.0, "y": 6200.0 }])   # 서가는 발판 위 — 레인 밖
	var cut := plats.duplicate(true); cut.append({ "id": "10c", "x": 60.0, "y": 6300.0, "w": 50.0, "kind": "short", "z": -35.0, "d": 60.0 })   # 레인에 지름길 판
	var cutp := pn.plan(10, cut)
	var moved := plats.duplicate(true); (moved[3] as Dictionary)["kind"] = "move"; (moved[3] as Dictionary)["amp"] = 60.0   # 10.2 가 움직이면 — 쓰지 않고, 진폭째(100..) 레인에 든다
	var movep := pn.plan(10, moved)
	var one: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["id"]) in ["10.2", "10.4"]))   # 쓰는 발판이 10.0 뿐
	var onep := pn.plan(10, one)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := pn.plan(11, mirror); var right_wrong := pn.plan(11, plats)
	var garden := pn.plan(9, plats); var clock := pn.plan(15, plats); var lib12 := pn.plan(12, plats); var lib46 := pn.plan(46, plats); var lib45 := pn.plan(45, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	pn.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " side %.0f inner %.0f up %.0f down %.0f bot %.0f top %.0f H %.0f L %.0f cabins %d serves %s x %.0f w %.0f z %.0f" % [float(v["side"]), float(v["inner"]), float(v["up_cx"]), float(v["down_cx"]), float(v["y_bot"]), float(v["y_top"]), float(v["H"]), float(v["L"]), int(v["cabins"]), str(v["serves"]), float(v["x"]), float(v["w"]), float(v["z"])]
	print("PLAN free=", free.map(show), " (want 1: 10.N0 side 1 inner 132 up 108 down 52 bot 5930 top 6594 H 664 L 1440 cabins 9 serves [10.0, 10.2, 10.4] x 28 w 104 z −50)")
	print("PLAN laddered=", laddered.size(), " cased=", cased.size(), " cut=", cutp.size(), " moved=", movep.size(), " one=", onep.size(), " (want 0 1 0 0 0) right=", right.map(show), " (want 1: 11.N0 side −1 inner −828 up 852 down 908 … cabins 9) right_wrong=", right_wrong.size(), " (want 0) garden=", garden.size(), " clock=", clock.size(), " lib12=", lib12.size(), " lib46=", lib46.size(), " lib45=", lib45.size(), " (want 0 0 1 1 0)")
	var s: Dictionary = pn.chains[0]
	var z := C.PLAYER_Z
	# 도는 칸: 0번 칸이 2.125 에 6100(10.0 의 윗면)·108, 8.65 에 꼭대기를 돌며 80·6594(옆으로 −), 10 에 내림 레인 52·6514, 17.5 에 바닥을 돌며 68·5930(옆으로 +), 18 에 다시 108·5930
	var p1 := pn.pos(s, 0, 2.125); var p2 := pn.pos(s, 0, 8.65); var p3 := pn.pos(s, 0, 10.0); var p4 := pn.pos(s, 0, 17.5); var p5 := pn.pos(s, 0, 18.0)
	var showp := func(p: Dictionary) -> String: return "%.0f/%.0f v %.0f h %.0f lane %d" % [float(p["x"]), float(p["y"]), float(p["v"]), float(p["h"]), int(p["lane"])]
	print("LOOP 2.125 ", showp.call(p1), " | 8.65 ", showp.call(p2), " | 10 ", showp.call(p3), " | 17.5 ", showp.call(p4), " | 18 ", showp.call(p5), " (want 108/6100 v 1 h 0 lane 0 | 80/6594 v 0 h −1 lane 1 | 52/6514 v −1 h 0 lane 2 | 68/5930 v 0 h 1 lane 3 | 108/5930 v 1 h 0 lane 0)")
	# 착지(2.125, 지난 틱 2.0): 136(가장자리 + 4)에서 바닥을 지나 떨어지는 몸은 받는다(creak); 140(너머)·한참 밑(6080)·앞 z 20 은 아니다; 2.125 + 1/60 에 6100 에서 6099.33 으로 떨어지는 몸은 솟은 바닥(6101.33)이 받는다
	pn.sync(2.0); pn.sync(2.125)
	var creak: AudioStreamPlayer3D = s["creak"]
	var l_ok := pn.land(136.0, 6100.0, 6090.0, z); var creak_in := creak.playing
	var l_past := pn.land(140.0, 6100.0, 6090.0, z); var l_under := pn.land(136.0, 6080.0, 6070.0, z); var l_front := pn.land(136.0, 6100.0, 6090.0, 20.0)
	pn.sync(2.125 + 1.0 / 60.0); var l_rise := pn.land(136.0, 6100.0, 6100.0 - 2400.0 / 3600.0, z)
	print("LAND ok id=%s kind=%s chain=%s k=%d x=%.0f y=%.2f w=%.0f creak=%s (want 10.N0.c0 paternoster 10.N0 0 84 6100.00 48 true) | past=%s under=%s front=%s (want true ×3: empty) | rising floor y=%.2f (want 6101.33)" % [l_ok.get("id", "-"), l_ok.get("kind", "-"), l_ok.get("chain", "-"), int(l_ok.get("k", -1)), float(l_ok.get("x", 0.0)), float(l_ok.get("y", 0.0)), float(l_ok.get("w", 0.0)), creak_in, l_past.is_empty(), l_under.is_empty(), l_front.is_empty(), float(l_rise.get("y", 0.0))])
	# 서기: 2.5 오름(120 그대로, 6130, v 1, out 0.1, on.x 84 on.y 6130, vy 80) → 8.65 꼭대기(108 이 100 으로 실려 간다, 6594, h −1, vy 0) → 10 내림(52, 6514, v −1, vy −80) → 17.5 바닥(60 이 68 로, 5930, h 1) → 18.5 오름(실려 가지 않는다) 가장자리 너머 139 는 off(creak), 130 은 out 0.6; 사라진 사슬은 lost
	var fig := Stick3D.new(); root.add_child(fig)
	pn.sync(2.5); var r1 := pn.stand(l_ok, 120.0, 0.1, fig); var v1 := float(fig.get_meta("board_v", 9.0)); var o1 := float(fig.get_meta("board_out", 9.0)); var onx := float(l_ok["x"]); var ony := float(l_ok["y"])
	pn.sync(8.65); var r2 := pn.stand(l_ok, 108.0, 0.1, fig); var h2 := float(fig.get_meta("board_x", 9.0))
	pn.sync(10.0); var r3 := pn.stand(l_ok, 52.0, 0.1, fig); var v3 := float(fig.get_meta("board_v", 9.0))
	pn.sync(17.5); var r4 := pn.stand(l_ok, 60.0, 0.1, fig); var h4 := float(fig.get_meta("board_x", 9.0))
	pn.sync(18.5); creak.stop(); var r5 := pn.stand(l_ok, 139.0, 0.1, fig); var creak_out := creak.playing
	var r6 := pn.stand(l_ok, 130.0, 0.1, fig); var o6 := float(fig.get_meta("board_out", 9.0))
	var r7 := pn.stand({ "chain": "nope", "k": 0, "y": 6000.0 }, 100.0, 0.1, fig)
	print("STAND 2.5 x=%.2f y=%.2f off=%s v=%.0f out=%.2f on=%.0f/%.0f vy=%.0f (want 120.00 6130.00 false 1 0.10 84/6130 80) | 8.65 x=%.2f y=%.2f h=%.0f vy=%.0f (want 100.00 6594.00 −1 0) | 10 x=%.2f y=%.2f v=%.0f vy=%.0f (want 52.00 6514.00 −1 −80) | 17.5 x=%.2f y=%.2f h=%.0f (want 68.00 5930.00 1) | 18.5 off=%s creak=%s (want true true) out=%.2f off=%s (want 0.60 false) | lost=%s off=%s y=%.0f (want true true 6000)" % [float(r1["x"]), float(r1["y"]), r1["off"], v1, o1, onx, ony, float(r1["vy"]), float(r2["x"]), float(r2["y"]), h2, float(r2["vy"]), float(r3["x"]), float(r3["y"]), v3, float(r3["vy"]), float(r4["x"]), float(r4["y"]), h4, r5["off"], creak_out, o6, r6["off"], r7["lost"], r7["off"], float(r7["y"])])
	# 톱니: 0번 칸이 8.3 에 꼭대기에 든다 — 8.29 엔 조용, 8.31 에 clank
	var clank: AudioStreamPlayer3D = s["clank"]
	pn.sync(8.29); pn._process(0.0); clank.stop(); pn.sync(8.31); pn._process(0.0); var clank_on := clank.playing
	# 그림: 노드 아이 19(레일 4·사슬 줄 2·굴대 2·칸 9·creak·clank), 칸 아이 6(바닥·지붕·뒷벽·난간·걸이·번호판); 노드 자리 −10.333 164.722 −1.389; 0 에 0번 칸 0·0, 5번 칸 −1.556·16.222
	var node: Node3D = s["node"]; var cabs: Array = s["cabs"]
	pn.sync(0.0); pn.t = 0.0; pn._place(s)
	var c0: Node3D = cabs[0]; var c5: Node3D = cabs[5]
	print("CLANK=%s (want true) | VISUAL node children=%d (want 19) cab children=%d (want 6) node pos=%.3f %.3f %.3f (want −10.333 164.722 −1.389) | cab0=%.3f %.3f cab5=%.3f %.3f (want 0.000 0.000 −1.556 16.222)" % [clank_on, node.get_child_count(), c0.get_child_count(), node.position.x, node.position.y, node.position.z, c0.position.x, c0.position.y, c5.position.x, c5.position.y])
	# 자세: 들어서기(pose_t 0): 오른 엉덩이 −0.90, 무릎 1.20, 골반 0.360 → 오름(k 1, v 1): 엉덩이 −0.14, 무릎 0.30, 어깨 z −1.38 x −0.10, 팔꿈치 −0.60; 왼 어깨 x −0.15 z 0.10; 골반 0.390 → 내림(v −1): 엉덩이 −0.05, 무릎 0.22, 골반 0.420 → 옆으로(h −1): 왼 어깨 x −0.50 z 0.60, 팔꿈치 −0.40 → 나서기(out 1): 오른 어깨 z −0.08 팔꿈치 −0.10, 왼 엉덩이 −0.70 무릎 0.30, 골반 0.380
	fig.pose_request = "board"
	fig.set_meta("board_v", 1.0); fig.set_meta("board_x", 0.0); fig.set_meta("board_out", 0.0)
	await process_frame; await process_frame
	var hip_s: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_s: float = (fig.knees[1.0] as Node3D).rotation.x; var pel_s := fig.pelvis.position.y
	fig.pose_t = 1.0
	for i in 30: await process_frame
	var hip_u: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_u: float = (fig.knees[1.0] as Node3D).rotation.x; var shz_u: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shx_u: float = (fig.shoulders[1.0] as Node3D).rotation.x; var el_u: float = (fig.elbows[1.0] as Node3D).rotation.x
	var lshx_u: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var lshz_u: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var pel_u := fig.pelvis.position.y
	fig.set_meta("board_v", -1.0)
	for i in 30: await process_frame
	var hip_d: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_d: float = (fig.knees[1.0] as Node3D).rotation.x; var pel_d := fig.pelvis.position.y
	fig.set_meta("board_v", 0.0); fig.set_meta("board_x", -1.0)
	for i in 30: await process_frame
	var lshx_x: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var lshz_x: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var lel_x: float = (fig.elbows[-1.0] as Node3D).rotation.x
	fig.set_meta("board_x", 0.0); fig.set_meta("board_out", 1.0)
	for i in 30: await process_frame
	var shz_o: float = (fig.shoulders[1.0] as Node3D).rotation.z; var el_o: float = (fig.elbows[1.0] as Node3D).rotation.x; var lhip_o: float = (fig.hips[-1.0] as Node3D).rotation.x; var lknee_o: float = (fig.knees[-1.0] as Node3D).rotation.x; var pel_o := fig.pelvis.position.y
	print("POSE step in: hip=%.2f knee=%.2f pelvis=%.3f (want −0.90 1.20 0.360 — the knee within 0.01: two headless frames of pose_t) | rising: hip=%.2f knee=%.2f shoulder z=%.2f x=%.2f elbow=%.2f left shoulder x=%.2f z=%.2f pelvis=%.3f (want −0.14 0.30 −1.38 −0.10 −0.60 −0.15 0.10 0.390) | descending: hip=%.2f knee=%.2f pelvis=%.3f (want −0.05 0.22 0.420) | crossing: left shoulder x=%.2f z=%.2f elbow=%.2f (want −0.50 0.60 −0.40) | step out: shoulder z=%.2f elbow=%.2f left hip=%.2f knee=%.2f pelvis=%.3f (want −0.08 −0.10 −0.70 0.30 0.380)" % [hip_s, knee_s, pel_s, hip_u, knee_u, shz_u, shx_u, el_u, lshx_u, lshz_u, pel_u, hip_d, knee_d, pel_d, lshx_x, lshz_x, lel_x, shz_o, el_o, lhip_o, lknee_o, pel_o])
	# 진짜 탑: 1..60층에 plan 이 찾는 사슬 — 서재 층 10..14, 45..49 중 벽 쪽 턱 둘이 40 안에 모이고 레인이 빈 층만(사다리·덤웨이터·서가의 계획을 taken 으로)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var out := pn.plan(n, pl, cl.plan(n, pl) + cd.plan(n, pl) + cb.plan(n, pl))
		if out.size() > 0: bands.append("%d:%s" % [n, out.map(func(v: Dictionary) -> String: return "side %.0f up %.0f bot %.0f top %.0f cabins %d serves %s" % [float(v["side"]), float(v["up_cx"]), float(v["y_bot"]), float(v["y_top"]), int(v["cabins"]), str(v["serves"])])]); count += out.size()
	print("TOWER floors=", bands, " chains=", count, " (want a subset of 10..14 and 45..49 — at most one each, even floors side 1, odd floors side −1)")
	quit()
