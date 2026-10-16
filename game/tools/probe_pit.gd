extends SceneTree
## 멀리뛰기 모래밭 팩 점검(헤드리스): 자료가 읽히나, 구름바다 층의 min_w 보다 넓은 still 발판 중 가장 넓은 것에만 모래밭이 서나(턱의 널·띠에 닿는 뗏목·진폭째 상자에 드는 움직이는 발판은 비켜 가고, 틈 가운데의 뗏목·위 발판 높이의 조각은 아니다, 윗층은 min_w_high, 다른 테마 층은 아니다),
## 구름판 위에서 힘을 끝까지 모은 점프만 도약이고(밖·덜 모음·앞 깊이는 아니다) 같은 발판의 모래 안에 내린 것만 기록이며(구름판 위·모래 끝 너머·다른 발판·앞 깊이는 아니다) 말뚝이 오늘의 최고에 서나(세지 않는 몸은 옮기지 않는다), 날이 바뀌면 말뚝이 뽑히나,
## 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 m 로 읽나, 모래 띠·구름판·가장자리 선·갈퀴 줄·말뚝·소리 둘·리퍼가 그려지나, 리퍼(run 163)가 1분마다·플레이어의 기록 뒤 1.5 s 에 구름판으로 가 limber → 웅크림 → 같은 뜀으로 모래 안에 내리고(plant, 말뚝은 그대로) 집으로 돌아와 wheel 로 돌아서나,
## plant 자세가 뒤꿈치부터 닿고 주저앉았다 무릎을 털며 일어나나, limber 자세가 무게를 옮겨 정강이를 털고 팔을 흔들다 서나, 진짜 탑의 1..70층에서 plan 이 구름바다 층에만 모래밭을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var lj := ClimbPit.new(); root.add_child(lj)
	var cr := ClimbRaft.new(); root.add_child(cr)
	var mu := ClimbMushroom.new(); root.add_child(mu)
	var cp := ClimbPlank.new(); root.add_child(cp)
	var ba := ClimbBalloon.new(); root.add_child(ba)
	var ln := ClimbLens.new(); root.add_child(ln)
	await process_frame
	print("PACK id=", lj.pack.get("id"), " kind=", lj.kind.size() > 0, " pose=", lj.pack.get("pose"), " themes=", lj.pack.get("themes"), " min_w=%.0f/%.0f margin=%.0f board=%.0f±%.0f strip=%.0f sand=%.0f full=%.2f day=%.0f peg=%.0f (want 150/120 12 16±12 30 2 0.98 600 14)" % [lj.min_w(27), lj.min_w(62), lj.margin(), lj.board_w(), lj.board_r(), lj.strip_d(), lj.sand_h(), lj.full_k(), lj.day_s(), lj.peg_h()])
	var plats: Array = [
		{ "id": "27.0", "x": 60.0, "y": 16300.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "27.1", "x": 420.0, "y": 16400.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "27.2", "x": 180.0, "y": 16500.0, "w": 140.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "27.3", "x": 540.0, "y": 16600.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "27.4", "x": 300.0, "y": 16700.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "27s", "x": 700.0, "y": 16650.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := lj.plan(27, plats)
	var planked := lj.plan(27, plats, [{ "id": "27.P0", "kind": "plank", "x": 580.0, "y": 16400.0, "w": 70.0 }])   # 널이 27.1 의 오른 턱(580; 띠의 상자 422..578 와 겹친다) — 27.0 (150, 더 낮다) 으로, 오른쪽에서 와 구름판은 오른 끝
	var rafted := lj.plan(27, plats, [{ "id": "27.c0", "kind": "raft", "x": 600.0, "y": 16450.0, "w": 80.0 }])   # 뗏목이 틈 가운데(600..680) — 27.1 그대로
	var edged := lj.plan(27, plats, [{ "id": "27.c0", "kind": "raft", "x": 560.0, "y": 16450.0, "w": 80.0 }])    # 뗏목이 띠에 닿는다(550..) — 27.0 으로
	var above := lj.plan(27, plats, [{ "id": "27.x", "kind": "vent", "x": 500.0, "y": 16500.0 }])   # 위 발판 높이의 조각은 위 발판의 것 — 27.1 그대로
	var moved := plats.duplicate(true); moved.append({ "id": "27m", "x": 450.0, "y": 16420.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째(360..600, 16420) 27.1 의 상자에 든다 — 27.0 으로
	var movep := lj.plan(27, moved)
	var narrow: Array = [
		{ "id": "62.0", "x": 100.0, "y": 37300.0, "w": 125.0, "kind": "std", "z": -29.0, "d": 60.0 },
		{ "id": "62.1", "x": 400.0, "y": 37400.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 60.0 },
		{ "id": "62.2", "x": 200.0, "y": 37500.0, "w": 118.0, "kind": "ice", "z": -29.0, "d": 60.0 },
	]
	var high := lj.plan(62, narrow)
	var f24 := lj.plan(24, plats); var f25 := lj.plan(25, plats); var f29 := lj.plan(29, plats); var f30 := lj.plan(30, plats); var f59 := lj.plan(59, plats); var f60 := lj.plan(60, plats); var f64 := lj.plan(64, plats)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " on %s dir %.0f board %.0f sand %.0f..%.0f x %.0f w %.0f y %.0f y_top %.0f z %.0f d %.0f" % [String(v["hop_id"]), float(v["dir"]), float(v["board_x"]), float(v["sand_x0"]), float(v["sand_x1"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	var brief := func(v: Dictionary) -> String: return String(v["hop_id"]) + " dir %.0f board %.0f" % [float(v["dir"]), float(v["board_x"])]
	print("PLAN free=", free.map(show), " (want 1: 27.J0 on 27.1 dir 1 board 440 sand 448..568 x 432 w 136 y 16400 y_top 16402 z −48 d 30)")
	print("PLAN planked=", planked.map(brief), " (want 27.0 dir −1 board 190) rafted=", rafted.map(brief), " (want 27.1 dir 1 board 440) edged=", edged.map(brief), " (want 27.0 dir −1 board 190) above=", above.map(brief), " (want 27.1) moved=", movep.map(brief), " (want 27.0) high=", high.map(show), " (want 62.J0 on 62.0 dir −1 board 205 sand 197..112 x 112 w 101) floors 24/25/29/30/59/60/64=", [f24.size(), f25.size(), f29.size(), f30.size(), f59.size(), f60.size(), f64.size()], " (want 0 1 1 0 0 1 1)")
	var band_root := Node3D.new(); root.add_child(band_root)
	lj.build(band_root, free)
	var p: Dictionary = lj.pits[0]
	var on: Dictionary = plats[1]; var other: Dictionary = plats[2]
	# 도약과 착지(10.0): 구름판 445 에서 다 모아 뛰어 540 에 내리면 기록 100(2.8 m), 500 은 60(최고 100 그대로), 560 은 120(최고 120 — 말뚝 (560 − 500)/36 = 1.6667);
	# 구름판 밖 460·덜 모음 0.9·앞 깊이는 도약이 아니고(그 뒤의 착지는 아무것도 아니다), 구름판 위 445·모래 끝 너머 572·다른 발판·앞 깊이의 착지는 모래가 아니다; 세지 않는 몸(st)의 126 은 말뚝을 옮기지 않는다
	lj.sync(10.0)
	var t1 := lj.takeoff(on, 445.0, C.PLAYER_Z, 1.0); var l1 := lj.land(on, 540.0, C.PLAYER_Z)
	var t2 := lj.takeoff(on, 445.0, C.PLAYER_Z, 1.0); var l2 := lj.land(on, 500.0, C.PLAYER_Z)
	var t3 := lj.takeoff(on, 445.0, C.PLAYER_Z, 1.0); var l3 := lj.land(on, 560.0, C.PLAYER_Z)
	var peg: MeshInstance3D = p["peg"]; var peg_x := peg.position.x; var peg_on := peg.visible
	var t_off := lj.takeoff(on, 460.0, C.PLAYER_Z, 1.0); var l_off := lj.land(on, 540.0, C.PLAYER_Z)
	var t_half := lj.takeoff(on, 445.0, C.PLAYER_Z, 0.9); var t_front := lj.takeoff(on, 445.0, -20.0, 1.0)
	var t4 := lj.takeoff(on, 445.0, C.PLAYER_Z, 1.0); var l_board := lj.land(on, 445.0, C.PLAYER_Z)
	var t5 := lj.takeoff(on, 445.0, C.PLAYER_Z, 1.0); var l_past := lj.land(on, 572.0, C.PLAYER_Z)
	var t6 := lj.takeoff(on, 445.0, C.PLAYER_Z, 1.0); var l_wrong := lj.land(other, 540.0, C.PLAYER_Z)
	var t7 := lj.takeoff(on, 445.0, C.PLAYER_Z, 1.0); var l_front := lj.land(on, 540.0, -20.0)
	var st := { "pit": "", "x0": 0.0, "count": false }
	var t8 := lj.takeoff(on, 445.0, C.PLAYER_Z, 1.0, st); var l_st := lj.land(on, 566.0, C.PLAYER_Z, st)
	print("JUMP 540: take=%s sand=%s dist=%.0f best=%.0f (want true true 100 100) 500: take=%s sand=%s dist=%.0f best=%.0f (want true true 60 100) 560: take=%s sand=%s dist=%.0f best=%.0f (want true true 120 120) peg x=%.4f on=%s (want 1.6667 true) | off=%s/%s half=%s front=%s (want false false false false) board=%s/%s past=%s/%s wrong=%s/%s depth=%s/%s (want true/false ×4) st=%s/%s dist=%.0f best=%.0f (want true/true 126 120: not counted)" % [t1, l1["sand"], float(l1["dist"]), float(l1["best"]), t2, l2["sand"], float(l2["dist"]), float(l2["best"]), t3, l3["sand"], float(l3["dist"]), float(l3["best"]), peg_x, peg_on, t_off, l_off["sand"], t_half, t_front, t4, l_board["sand"], t5, l_past["sand"], t6, l_wrong["sand"], t7, l_front["sand"], t8, l_st["sand"], float(l_st["dist"]), float(l_st["best"])])
	# 그림: 노드 아이 15(모래·구름판·가장자리 선·갈퀴 줄 8·말뚝·소리 둘·리퍼); 노드 자리 (500 − 480)/36 = 0.5556, 16400/36 = 455.5556, −70/36 = −1.9444; 모래 x (508 − 500)/36 = 0.2222 y 1/36 = 0.0278 z 22/36 = 0.6111; 구름판 x (440 − 500)/36 = −1.6667; 말뚝 y 7/36 = 0.1944
	var node: Node3D = p["node"]; var sand: Node3D = node.get_child(0); var board: Node3D = node.get_child(1)
	print("VISUAL node children=%d (want 15) node pos=%.4f %.4f %.4f (want 0.5556 455.5556 −1.9444) sand=%.4f %.4f %.4f (want 0.2222 0.0278 0.6111) board x=%.4f (want −1.6667) peg y=%.4f (want 0.1944)" % [node.get_child_count(), node.position.x, node.position.y, node.position.z, sand.position.x, sand.position.y, sand.position.z, board.position.x, peg.position.y])
	# 다음 날(610.0): 말뚝이 뽑힌다(보이지 않는다, note 는 no mark); 540 에 내리면 오늘 100 → 2.8 m; note 는 25 → 위 다섯 층, 30 → 아래 다섯 층, 22 → 빈 줄
	lj.sync(610.0); lj._process(0.0)
	var peg_day2 := peg.visible; var best_day2 := lj.best_today(p); var note_empty := lj.note(25)
	lj.takeoff(on, 445.0, C.PLAYER_Z, 1.0); var l_day2 := lj.land(on, 540.0, C.PLAYER_Z)
	print("DAY peg=%s best=%.0f (want false −1) note25=\"%s\" (want Long jump, floor 27: no mark today.) then 540: best=%.0f peg=%s x=%.4f (want 100 true 1.1111) note25=\"%s\" note30=\"%s\" (want Long jump, floor 27: 2.8 m today. ×2) note22=\"%s\" (want empty)" % [peg_day2, best_day2, note_empty, float(l_day2["best"]), peg.visible, peg.position.x, lj.note(25), lj.note(30), lj.note(22)])
	# 리퍼(run 163, 주민 반쪽): 집 430(구름판 440 뒤 10), next 20 + (27 % 5) × 8 = 36, 자리 (430 − 500)/36 = −1.9444, z 22/36 = 0.6111; 셋째 날(1300.0 — 말뚝 없음)에 뛰게 해 phases 를 센다:
	# walk@0.02 → 구름판 440 에 limber@0.07(1.0 s) → charge@1.07(0.7 s, 웅크림 ≤ 0.879 — 마지막 틱 0.683/0.7 × 0.9) → air@1.77(JUMP_V 860·RUN 300; 0.25 s 뒤부터 겨냥 448 + 0.55 × 120 = 514 보다 멀리 내릴 동안 AIR 로 뒤로) → 511.25 에 내려(기록 71.25, 꼭대기 +147, 0.7 s 공중) plant@2.47(0.9 s) → back@3.37 → 집에서 wheel@3.68(0.5 s) → idle@4.20, next = idle + 60
	# 말뚝은 그대로(count false — best −1, 보이지 않는다); 그 뒤 플레이어가 540 에 기록(100)을 내면 1.5 s 뒤 따라 뛴다(walk@1.52) — 둘째 겨냥 0.72 → 534.4, 530.42 에 내려 90.42; 말뚝은 플레이어의 100 그대로(x 1.1111). 값은 같은 식의 파이썬 모형으로 먼저 냈다
	var le: ClimbLeaper = p["leaper"]
	var l0 := "%s x=%.0f y=%.0f home=%.0f board=%.0f kind=%s next=%.0f pos=%.4f %.4f %.4f" % [le.phase, le.x, le.y, le.home_x, le.board_x, le.hop_kind, le.next_at, le.fig.position.x, le.fig.position.y, le.fig.position.z]
	lj.sync(1300.0); le.next_at = 1300.0
	var sim := func(t0: float) -> Dictionary:
		var tt := t0; var seen: Array = [le.phase]; var at: Dictionary = {}; var top := -1.0e9; var cmax := 0.0; var land_x := 0.0; var lim := false; var pl := false; var wh := false; var n := 0
		while n < 900:
			tt += 1.0 / 60.0; lj.sync(tt); le.step(1.0 / 60.0); n += 1
			if String(seen[seen.size() - 1]) != le.phase:
				seen.append(le.phase); at[le.phase] = tt - t0
				if le.phase == "plant": land_x = le.x
			if le.phase == "air": top = maxf(top, le.y)
			if le.phase == "charge": cmax = maxf(cmax, le.fig.crouch)
			lim = lim or (le.phase == "limber" and le.fig.pose_request == "limber" and not le.fig.airborne)
			pl = pl or (le.phase == "plant" and le.fig.pose_request == "plant" and not le.fig.airborne)
			wh = wh or (le.phase == "wheel" and le.fig.pose_request == "wheel")
			if seen.size() > 1 and le.phase == "idle": break
		return { "seen": seen, "at": at, "top": top, "cmax": cmax, "land_x": land_x, "lim": lim, "pl": pl, "wh": wh, "t": tt }
	var r1: Dictionary = sim.call(1300.0); var at1: Dictionary = r1["at"]
	var best1 := lj.best_today(p); var peg1 := peg.visible; var flights1 := le.flights; var marks1 := le.marks; var next1 := le.next_at; var dist1 := le.last_dist
	var tm := float(r1["t"]); lj.takeoff(on, 445.0, C.PLAYER_Z, 1.0); lj.land(on, 540.0, C.PLAYER_Z)   # 플레이어의 기록 — mark_t = tm
	var r2: Dictionary = sim.call(tm); var at2: Dictionary = r2["at"]
	print("LEAPER start: ", l0, " (want idle 430 16400 430 440 std 36 −1.9444 0.0000 0.6111) first: phases=%s (want [idle, walk, limber, charge, air, plant, back, wheel, idle]) walk@%.2f limber@%.2f charge@%.2f air@%.2f plant@%.2f back@%.2f wheel@%.2f idle@%.2f (want ≈0.02 0.07 1.07 1.77 2.47 3.37 3.68 4.20) crouch=%.3f (want 0.879) land x=%.2f dist=%.2f top=%.1f (want 511.25 71.25 ≈16547: 147 px up, 0.7 s in the air) limber=%s plant=%s wheel=%s (want true ×3) flights=%d marks=%d best=%.0f peg=%s next=%.1f (want 1 1 −1 false ≈1364.2: the leaper's mark never moves the peg; next = idle + 60) | after your mark at 540: walk@%.2f (want ≈1.52) land x=%.2f dist=%.2f best=%.0f peg x=%.4f (want 530.42 90.42 100 1.1111: aim 0.72, the peg stays yours)" % [str(r1["seen"]), float(at1.get("walk", -1.0)), float(at1.get("limber", -1.0)), float(at1.get("charge", -1.0)), float(at1.get("air", -1.0)), float(at1.get("plant", -1.0)), float(at1.get("back", -1.0)), float(at1.get("wheel", -1.0)), float(at1.get("idle", -1.0)), float(r1["cmax"]), float(r1["land_x"]), dist1, float(r1["top"]), r1["lim"], r1["pl"], r1["wh"], flights1, marks1, best1, peg1, next1, float(at2.get("walk", -1.0)), float(r2["land_x"]), le.last_dist, lj.best_today(p), peg.position.x])
	# 자세(plant_t 로 세운다; Stick3D 가 앞 각도와 섞으니 90 프레임 기다린다): 0.05 뒤꿈치 R 엉덩이 −0.450 무릎 0.100 어깨 −1.000 z −0.100 팔꿈치 −0.150 골반 0.420 | 0.25 주저앉기 −1.094 1.172 −1.287 −0.430 0.226 | 0.5 일어나기(오른손이 무릎을 턴다) R −0.981 1.390 −1.436 −1.709 L 어깨 −0.736 팔꿈치 −0.409 골반 0.175 done 거짓 | 0.95 모두 0, 골반 0.420, done 참
	var fig := Stick3D.new(); root.add_child(fig)
	fig.pose_request = "plant"; fig.set_meta("plant_t", 0.05)
	for i in 90: await process_frame
	var a_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var a_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var a_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x; var a_shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var a_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var a_pel := fig.pelvis.position.y
	fig.set_meta("plant_t", 0.25)
	for i in 90: await process_frame
	var b_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var b_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var b_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x; var b_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var b_pel := fig.pelvis.position.y
	fig.set_meta("plant_t", 0.5)
	for i in 90: await process_frame
	var c_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var c_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var c_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x; var c_el: float = (fig.elbows[1.0] as Node3D).rotation.x
	var c_lsh: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var c_lel: float = (fig.elbows[-1.0] as Node3D).rotation.x; var c_pel := fig.pelvis.position.y; var c_done := PlantPoses.done(fig)
	fig.set_meta("plant_t", 0.95)
	for i in 90: await process_frame
	var d_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var d_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x; var d_el: float = (fig.elbows[-1.0] as Node3D).rotation.x; var d_pel := fig.pelvis.position.y; var d_done := PlantPoses.done(fig)
	print("POSE heels: hip=%.3f knee=%.3f sh=%.3f z=%.3f el=%.3f pelvis=%.3f (want −0.450 0.100 −1.000 −0.100 −0.150 0.420) | sit: hip=%.3f knee=%.3f sh=%.3f el=%.3f pelvis=%.3f (want −1.094 1.172 −1.287 −0.430 0.226) | rise: R hip=%.3f knee=%.3f sh=%.3f el=%.3f L sh=%.3f el=%.3f pelvis=%.3f done=%s (want −0.981 1.390 −1.436 −1.709 −0.736 −0.409 0.175 false) | up: hip=%.3f sh=%.3f L el=%.3f pelvis=%.3f done=%s (want 0.000 0.000 0.000 0.420 true)" % [a_hip, a_knee, a_sh, a_shz, a_el, a_pel, b_hip, b_knee, b_sh, b_el, b_pel, c_hip, c_knee, c_sh, c_el, c_lsh, c_lel, c_pel, c_done, d_hip, d_sh, d_el, d_pel, d_done])
	# limber(limber_t): 0.1 옮기기(up 0.5) R 엉덩이 −0.175 무릎 0.300 어깨 −0.075 z −0.060 팔꿈치 −0.200 골반 0.400 | 0.5 털기(shake 0.588, swing −0.588) R 엉덩이 −0.350 무릎 0.806 어깨 −0.003 팔꿈치 −0.312 L 어깨 −0.297 팔꿈치 −0.488 골반 0.380 done 거짓 | 0.95 서기(up 0.156) R 무릎 0.094 L 팔꿈치 −0.063 골반 0.414 done 거짓 | 1.0 done 참
	fig.pose_request = "limber"; fig.set_meta("limber_t", 0.1)
	for i in 90: await process_frame
	var la_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var la_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var la_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x; var la_shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var la_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var la_pel := fig.pelvis.position.y
	fig.set_meta("limber_t", 0.5)
	for i in 90: await process_frame
	var lb_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var lb_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var lb_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x; var lb_el: float = (fig.elbows[1.0] as Node3D).rotation.x
	var lb_lsh: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var lb_lel: float = (fig.elbows[-1.0] as Node3D).rotation.x; var lb_pel := fig.pelvis.position.y; var lb_done := LimberPoses.done(fig)
	fig.set_meta("limber_t", 0.95)
	for i in 90: await process_frame
	var lc_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var lc_lel: float = (fig.elbows[-1.0] as Node3D).rotation.x; var lc_pel := fig.pelvis.position.y; var lc_done := LimberPoses.done(fig)
	fig.set_meta("limber_t", 1.0); var ld_done := LimberPoses.done(fig)
	print("LIMBER shift: hip=%.3f knee=%.3f sh=%.3f z=%.3f el=%.3f pelvis=%.3f (want −0.175 0.300 −0.075 −0.060 −0.200 0.400) | shake: R hip=%.3f knee=%.3f sh=%.3f el=%.3f L sh=%.3f el=%.3f pelvis=%.3f done=%s (want −0.350 0.806 −0.003 −0.312 −0.297 −0.488 0.380 false) | set: R knee=%.3f L el=%.3f pelvis=%.3f done=%s (want 0.094 −0.063 0.414 false) | done@1.0=%s (want true)" % [la_hip, la_knee, la_sh, la_shz, la_el, la_pel, lb_hip, lb_knee, lb_sh, lb_el, lb_lsh, lb_lel, lb_pel, lb_done, lc_knee, lc_lel, lc_pel, lc_done, ld_done])
	# 진짜 탑: 1..70층에 plan 이 찾는 모래밭 — 구름바다 층 25..29, 60..64 중 뗏목·버섯·널·열기구·렌즈(taken)가 비켜 가고 min_w 보다 넓은 발판이 남는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var tk: Array = cr.plan(n, pl) + mu.plan(n, pl)
		var pp: Array = cp.plan(n, pl, tk); var bp: Array = ba.plan(n, pl, tk + pp); var lp: Array = ln.plan(n, pl, tk + pp + bp)
		var out2 := lj.plan(n, pl, tk + pp + bp + lp)
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s w %.0f dir %.0f" % [String(v["hop_id"]), float(v["w"]), float(v["dir"])])]); count += out2.size()
	print("TOWER floors=", bands, " pits=", count, " (want a subset of 25..29 and 60..64 — one each, never another theme)")
	quit()
