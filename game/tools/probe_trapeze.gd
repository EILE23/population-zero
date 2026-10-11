extends SceneTree
## 공중그네 팩 점검(헤드리스): 자료가 읽히나, 별밤 층의 잇단 still 발판 짝(80..200 px 틈, 높이차 150 안) 중 가장 넓은 틈 하나에만 그네가 걸리나(지름길 판이 쐐기를 가르는 틈·taken 조각(등롱 장대·고드름)이 든 틈은 지고 다음으로 넓은 틈으로, 움직이는 발판 옆은 아니다, 다른 테마 층은 아니다, 거울 층은 반대로),
## 기하가 맞나(들보는 위 발판 + 170, 바닥의 발은 두 발판 높이의 평균, 진폭은 가로대 끝이 턱 끝에서 8 떨어지게), 닿는 거리 안의 ↑ 만 잡나(twang — 멀거나 낮거나 앞이면 아니다), 잡을 때 몸 속도의 0.3 만 각속도로 남나,
## 매달리면 3초 진자로 흔들리며(반음해 오일러, 감쇠 0.05) 가는 쪽으로 누르면 펌프질이 붙고(0.9 rad/s²) 진폭 끝까지만인가, 끝(각속도의 부호가 바뀌는 틱)에서 creak 이 나나, 메타(fly_v·fly_a·fly_e·fly_pump)가 적히나,
## 놓으면 접선 속도를 주고(twang) 빈 가로대가 닫힌꼴로 잦아들며(감쇠 1.0) 양 끝에서 creak 이 나고 진폭이 0.03 아래로 내려가기 전엔 잡히지 않다가 그 뒤 곧게 서서 다시 잡히나, 모르는 그네는 lost 인가,
## 들보·고리 둘·깃·팔 노드(밧줄 둘·가로대·띠 둘)·소리 둘이 그려지고 팔이 각대로 도나, fly 자세가 가는 쪽으로 다리를 모아 따라가고 펌프질이면 높이 차다 돌아올 땐 접으며 밧줄을 따라 기울고 끝에서 등이 휘고 놓으면 접었다가 0.45초 뒤 done 인가, 진짜 탑의 1..70층에서 plan 이 별밤 층에만 그네를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var ct := ClimbTrapeze.new(); root.add_child(ct)
	var cn := ClimbLantern.new(); root.add_child(cn)
	var ci := ClimbIcicle.new(); root.add_child(ci)
	await process_frame
	print("PACK id=", ct.pack.get("id"), " kind=", ct.kind.size() > 0, " pose=", ct.pack.get("pose"), " themes=", ct.pack.get("themes"), " period=%.1f omega=%.4f hang=%.0f bar_w=%.0f pump=%.1f catch_k=%.1f damp=%.2f empty_damp=%.1f settle_a=%.2f (want 3.0 2.0944 58 28 0.9 0.3 0.05 1.0 0.03)" % [ct.period(), ct.omega(), ct.hang(), ct.bar_w(), ct.pump(), ct.catch_k(), ct.damp(), ct.empty_damp(), ct.settle_a()])
	var plats: Array = [
		{ "id": "32.0", "x": 60.0, "y": 19300.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "32.1", "x": 400.0, "y": 19410.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "32.2", "x": 700.0, "y": 19520.0, "w": 130.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "32.3", "x": 430.0, "y": 19640.0, "w": 130.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "32.4", "x": 180.0, "y": 19750.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "32.5", "x": 20.0, "y": 19860.0, "w": 80.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 40.0, "freq": 0.3, "phase": 0.0 },
		{ "id": "32s", "x": 600.0, "y": 19720.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := ct.plan(32, plats)
	var ic := ci.plan(32, plats); var ln := cn.plan(32, plats, ic)
	var real := ct.plan(32, plats, ic + ln)
	var hand_lantern: Array = [{ "id": "32.L0", "kind": "lantern", "x": 232.0, "w": 184.0, "y": 19300.0, "len": 317.7 }]   # 등롱 장대가 160 틈(32.0↔32.1)에 선 경우
	var lant := ct.plan(32, plats, hand_lantern)
	var both := ct.plan(32, plats, hand_lantern + ic)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := ct.plan(32, mirror)
	var rest := ct.plan(30, plats); var other := ct.plan(35, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	ct.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s hx %.0f hp %.0f len %.0f amax %.3f reach %.0f low %.0f x %.0f w %.0f y %.0f z %.0f" % [float(v["dir"]), float(v["gap"]), String(v["a_id"]), String(v["b_id"]), float(v["hx"]), float(v["hp"]), float(v["len"]), float(v["amax"]), float(v["reach"]), float(v["low_y"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["z"])]
	var brief := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f hx %.0f amax %.3f" % [float(v["dir"]), float(v["gap"]), float(v["hx"]), float(v["amax"])]
	print("PLAN free=", free.map(show), " (want 1: 32.T0 dir 1 gap 160 32.0→32.1 wins over 150, 140 and 110; 32.4↔32.5 is 80 but 32.5 moves: hx 320 hp 19580 len 167 amax 0.355 reach 58 low 19413 x 238 w 164 y 19355 z −29)")
	print("PLAN real taken: icicles=", ic.size(), " lantern=", ln.map(func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f on %s" % [float(v["gap"]), String(v["a_id"])]), " (want 4 icicles — the lips of 32.3 and 32.1 — and the lantern in the 110 gap on 32.3: the icicles cut its sweep in 160, 150 and 140) trapeze=", real.map(brief), " (want 32.T0 dir 1 gap 160 — the icicles under 32.1's lip stop 6 px past the bar's end, the lantern is a floor lower) | hand lantern in 160: ", lant.map(brief), " (want 32.T0 dir 1 gap 150 hx 625 amax 0.323) | + icicles: ", both.map(brief), " (want 32.T0 dir −1 gap 110 hx 375 amax 0.199: 150 has 32.3's icicles in the wedge, 140 has the short slab 32s in the ropes' sweep) | mirror: ", right.map(brief), " (want 32.T0 dir −1 gap 160 hx 640 amax 0.355) | rest30=", rest.size(), " other35=", other.size(), " (want 1 0: floor 30 is Starlit too, 35 is Old hall)")
	var s: Dictionary = ct.bars[0]
	var z := float(plats[0]["z"])
	# 기하: 멈춘 가로대 (320, 19413); 진폭 끝의 가로대 (378, 19423.4) — 끝 392 는 턱 끝 400 − 8; 매달린 발은 바닥에서 19355 = (19300 + 19410) / 2
	s["held"] = true; s["th"] = float(s["amax"]); var end_bar := ct.bar(s, 0.0); s["held"] = false; s["th"] = 0.0
	var rest_bar := ct.bar(s, 0.0)
	print("GEOMETRY rest bar=%.1f,%.1f (want 320,19413) end bar=%.1f,%.1f (want 378.0,19423.4: 320 + 58, 19580 − sqrt(167² − 58²)) feet at rest=%.0f (want 19355) parked=%s (want true)" % [rest_bar.x, rest_bar.y, end_bar.x, end_bar.y, rest_bar.y - ct.hang(), ct.parked(s, 0.0)])
	# 잡기(t 0): 발 19355 손 19413 — x 320 은 잡힌다; x 350 (30 떨어짐)·발 19320 (손 19378, 35 아래)·앞 z 20 은 아니다; vx 300 → 각속도 0.3 × 300 / 167 = 0.5389 (진폭 0.257 < 0.355, 안 깎인다)
	ct.sync(0.0)
	var far := ct.grab(350.0, 19355.0, z); var low := ct.grab(320.0, 19320.0, z); var front := ct.grab(320.0, 19355.0, 20.0)
	var twang: AudioStreamPlayer3D = s["twang"]
	var g := ct.grab(320.0, 19355.0, z, 300.0)
	print("REACH far=%s low=%s front=%s (want empty ×3) | caught=%s x=%.0f y=%.0f dir=%.0f t0=%.1f (want 32.T0 320 19355 1 0.0) held=%s om=%.6f amp=%.4f twang=%s (want true 0.538922 0.2573 true)" % [far.is_empty(), low.is_empty(), front.is_empty(), g.get("id", "-"), float(g.get("x", 0.0)), float(g.get("y", 0.0)), float(g.get("dir", 0.0)), float(g.get("t0", 9.0)), bool(s["held"]), float(s["om"]), ct.amp(float(s["th"]), float(s["om"])), twang.playing])
	# 흔들기(1/60 틱): 1..30 누르지 않고, 31..120 → 를 누른다 — 가는 쪽(om > 0)인 동안만 펌프질이 붙고(31 부터), 72 틱에 끝(om 의 부호가 바뀐다, creak)을 지나면 눌러도 안 붙는다
	var fig := Stick3D.new(); root.add_child(fig)
	var creak: AudioStreamPlayer3D = s["creak"]
	var got: Dictionary = {}; var dt := 1.0 / 60.0; var creaks: Array = []
	for k in 120:
		ct.sync(float(k + 1) / 60.0)
		creak.stop()
		var r := ct.swing(g, dt, 0.0 if k < 30 else 1.0, fig)
		if creak.playing: creaks.append(k + 1)
		if (k + 1) in [10, 30, 31, 45, 60, 90, 120]: got[k + 1] = { "r": r, "th": float(s["th"]), "om": float(s["om"]), "amp": ct.amp(float(s["th"]), float(s["om"])), "v": float(fig.get_meta("fly_v", 9.0)), "a": float(fig.get_meta("fly_a", 9.0)), "e": float(fig.get_meta("fly_e", 9.0)), "p": float(fig.get_meta("fly_pump", 9.0)) }
	var showr := func(k: int) -> String: var e: Dictionary = got[k]; var r: Dictionary = e["r"]; return "%d: th=%.5f om=%.5f amp=%.5f x=%.2f y=%.2f vx=%.2f vy=%.2f face=%.0f v=%.3f a=%.5f e=%.3f pump=%.3f" % [k, float(e["th"]), float(e["om"]), float(e["amp"]), float(r["x"]), float(r["y"]), float(r["vx"]), float(r["vy"]), float(r["face"]), float(e["v"]), float(e["a"]), float(e["e"]), float(e["p"])]
	print("SWING ", showr.call(10), " (want 0.08762 0.50532 0.25669 334.61 19355.64 84.06 7.38 1 0.680 0.08762 0.247 0) | ", showr.call(30), " (want 0.22001 0.26857 0.25465 356.45 19359.03 43.77 9.79 1 0.362 — 0.620 0) | ", showr.call(31), " (want 0.22446 0.26724 0.25820 pump 0.133: the first pumped tick) | ", showr.call(45), " (want 0.28158 0.21623 0.29991 366.40 19361.58 34.69 10.03 pump 1) | ", showr.call(60), " (want 0.32198 0.10694 0.32600 372.85 19363.58 16.94 5.65 0.144 e 0.908) | ", showr.call(90), " (want 0.26479 −0.40699 0.32844 363.70 19360.82 −65.60 −17.79 face −1 v −0.548 pump 0: past the end, → no longer pumps) | ", showr.call(120), " (want −0.03670 −0.67738 0.32550 313.87 19355.11 −113.05 4.15) creaks=", creaks, " (want [72]: the one end passed)")
	# 놓기(t 2.0, 120 틱): 접선 속도 −113.05/4.15 (twang), ra 0.32550 rp 1.68377, 멈추기까지 ln(0.3255 / 0.03) = 2.3842; fig 의 fly_rel 이 적히고 fly_v 는 지워진다
	twang.stop()
	var v := ct.let_go(g, fig)
	var rel_meta: float = float(fig.get_meta("fly_rel", -1.0))
	print("LETGO vx=%.2f vy=%.2f (want −113.05 4.15) held=%s rel=%.1f ra=%.5f rp=%.5f settle=%.4f twang=%s (want false 2.0 0.32550 1.68377 2.3842 true) | fig fly_rel=%.3f (want ≥ 0: the tuck began) fly_v left=%s (want false)" % [float(v["vx"]), float(v["vy"]), bool(s["held"]), float(s["rel"]), float(s["ra"]), float(s["rp"]), ct.settle_s(s), twang.playing, rel_meta, fig.has_meta("fly_v")])
	# 빈 가로대(τ = t − 2.0): 0.5 에 각 −0.18101 가로대 289.94/19415.73; 1.0 에 −0.09629; 2.0 에 0.04039; 끝은 τ 0.484 와 1.984 — 0.47→0.49 창에 creak, 0.98→1.0 창은 조용; 1.5 엔 잡히지 않고 2.4 (멈춘 뒤) 엔 곧게 서서 다시 잡힌다; 모르는 그네는 lost
	ct.sync(2.5); var a05 := ct.ang(s, 2.5); var b05 := ct.bar(s, 2.5)
	var a10 := ct.ang(s, 3.0); var a20 := ct.ang(s, 4.0); var a_park := ct.ang(s, 4.4)
	creak.stop(); ct.sync(2.47); ct._process(0.02); var c1 := creak.playing
	creak.stop(); ct.sync(2.98); ct._process(0.02); var c2 := creak.playing
	creak.stop(); ct.sync(3.97); ct._process(0.02); var c3 := creak.playing
	ct.sync(3.5); var busy := ct.grab(320.0, 19355.0, z); var busy_near := ct.grab(304.0, 19355.0, z)
	ct.sync(4.4); var g2 := ct.grab(320.0, 19355.0, z)
	var lost := ct.swing({ "id": "nope", "x": 5.0, "y": 7.0 }, dt, 0.0)
	print("EMPTY ang 0.5=%.5f bar=%.2f,%.2f (want −0.18101 289.94 19415.73) 1.0=%.5f (want −0.09629) 2.0=%.5f (want 0.04039) 2.4=%.5f (want 0: parked) | creak 0.47→0.49=%s 0.98→1.0=%s 1.97→1.99=%s (want true false true) | grab at 1.5: plumb=%s near the bar=%s (want empty ×2: still swinging) | 2.4: caught=%s t0=%.1f om=%.1f (want 32.T0 4.4 0.0: a standing catch starts still) | unknown: lost=%s x=%.0f y=%.0f (want true 5 7)" % [a05, b05.x, b05.y, a10, a20, a_park, c1, c2, c3, busy.is_empty(), busy_near.is_empty(), g2.get("id", "-"), float(g2.get("t0", 9.0)), float(s["om"]), lost["lost"], float(lost["x"]), float(lost["y"])])
	# 멈춘 채 잡고 → 를 누르면 제자리에서 펌프질이 시작된다(om 0 → +); ↓ 로 놓으면 fig 없이 — 자세 메타는 로더가 비운다
	var r0 := ct.swing(g2, dt, 1.0, fig)
	var om0 := float(s["om"])
	ct.let_go(g2)
	print("PUMP from rest: om=%.5f (want 0.01499 = 0.9 / 60 less one tick of damping) x=%.3f face=%.0f (want ≈ 320.04 0: too slow to face yet) | let go again: held=%s ra=%.5f (want false ≈ 0.00716)" % [om0, float(r0["x"]), float(r0["face"]), bool(s["held"]), float(s["ra"])])
	# 그림(τ 0.5 의 빈 가로대, t 2.5): 노드 아이 7(들보·고리 2·깃·팔·소리 2), 팔 아이 5(밧줄 2·가로대·띠 2); 노드 자리 −4.444 543.889 −0.806; 팔 각 −0.18101; 가로대 local y −4.639 (= −167/36)
	s["rel"] = 2.0; s["ra"] = 0.32550; s["rp"] = 1.68377
	ct.sync(2.5); ct._process(0.0)
	var node: Node3D = s["node"]; var arm: Node3D = s["arm"]
	var bar_box: Node3D = arm.get_child(2)
	print("VISUAL node children=%d (want 7) arm children=%d (want 5) node pos=%.3f %.3f %.3f (want −4.444 543.889 −0.806) | arm angle=%.5f (want −0.18101) bar local y=%.3f (want −4.639) ropes x=%.3f %.3f (want −0.389 0.389)" % [node.get_child_count(), arm.get_child_count(), node.position.x, node.position.y, node.position.z, arm.rotation.z, bar_box.position.y, (arm.get_child(0) as Node3D).position.x, (arm.get_child(1) as Node3D).position.x])
	# 자세(+x 를 본다): 매달림(v 1, a 0.1, e 0, pump 0) — 엉덩이 −0.43(다리가 가는 쪽으로), 무릎 0.05, 어깨 x −2.80, 어깨 z −0.25 (어깨 폭), 팔꿈치 −0.10, 골반 0.45, 몸통 < 0 (밧줄을 따라 뒤로 젖혀진다 = −0.8 × 0.1 × 0.45);
	# 펌프질(pump 1): 엉덩이 −0.93; 돌아올 때(v −1, a −0.1, pump 1): 엉덩이 0.665 (다리가 뒤로), 무릎 0.745 (접힌다), 몸통 > 0; 끝(e 1): 가슴이 0.3 더 젖혀진다; 놓으면(release) 0.15 뒤 엉덩이 −1.35 무릎 1.70 어깨 −0.90 팔꿈치 −1.90, done 은 0.45 뒤(헤드리스는 60 fps 보다 느려 30 프레임이면 접기가 끝나 있다)
	fig.pose_request = ""; await process_frame
	fig.pose_request = "fly"; fig._yaw = PI / 2.0; fig._yaw_target = PI / 2.0
	fig.set_meta("fly_v", 1.0); fig.set_meta("fly_a", 0.1); fig.set_meta("fly_e", 0.0); fig.set_meta("fly_pump", 0.0)
	await process_frame; await process_frame; await process_frame
	var early: float = (fig.shoulders[1.0] as Node3D).rotation.x
	for i in 60: await process_frame
	var hip_h: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_h: float = (fig.knees[1.0] as Node3D).rotation.x
	var sh_h: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz_h: float = (fig.shoulders[1.0] as Node3D).rotation.z; var el_h: float = (fig.elbows[1.0] as Node3D).rotation.x
	var pel_h := fig.pelvis.position.y; var torso_h := fig.torso.rotation.x; var chest_h := fig.chest.rotation.x
	var t60 := fig.pose_t
	fig.set_meta("fly_pump", 1.0)
	for i in 60: await process_frame
	var hip_p: float = (fig.hips[1.0] as Node3D).rotation.x
	fig.set_meta("fly_v", -1.0); fig.set_meta("fly_a", -0.1)
	for i in 60: await process_frame
	var hip_b: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_b: float = (fig.knees[1.0] as Node3D).rotation.x; var torso_b := fig.torso.rotation.x
	fig.set_meta("fly_v", 1.0); fig.set_meta("fly_a", 0.1); fig.set_meta("fly_pump", 0.0); fig.set_meta("fly_e", 1.0)
	for i in 60: await process_frame
	var chest_e := fig.chest.rotation.x
	FlyPoses.release(fig)
	var done0 := FlyPoses.done(fig)
	for i in 10: await process_frame
	var done_early := FlyPoses.done(fig)
	for i in 50: await process_frame
	var hip_t: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_t: float = (fig.knees[1.0] as Node3D).rotation.x
	var sh_t: float = (fig.shoulders[1.0] as Node3D).rotation.x; var el_t: float = (fig.elbows[1.0] as Node3D).rotation.x
	for i in 60: await process_frame
	var done2 := FlyPoses.done(fig)
	print("POSE early=%.2f (want > −2.0: the grab has only begun) pose_t after 60 frames=%.2f (want ≥ 0.2: the grab is complete) hanging: hip=%.2f (want −0.43) knee=%.2f (want 0.05) shoulder=%.2f (want −2.80) z=%.2f (want −0.25) elbow=%.2f (want −0.10) pelvis=%.3f (want 0.450) torso=%.3f (want ≈ −0.036 ± 0.014: tilted back along the rope) | pumping: hip=%.2f (want −0.93: legs kicked high together) | back: hip=%.2f (want ≈ 0.665) knee=%.2f (want ≈ 0.745: folded) torso=%.3f (want > 0) | end: chest=%.3f vs %.3f (want 0.30 lower: the back arches) | tuck: done at release=%s (want false) hip=%.2f (want ≈ −1.35) knee=%.2f (want ≈ 1.70) shoulder=%.2f (want ≈ −0.90) elbow=%.2f (want ≈ −1.90) done after 10 frames=%s after 120=%s (want false true: 0.45 s falls between 10 and 120 frames at any headless rate between 22 and 266 fps)" % [early, t60, hip_h, knee_h, sh_h, shz_h, el_h, pel_h, torso_h, hip_p, hip_b, knee_b, torso_b, chest_e, chest_h, done0, hip_t, knee_t, sh_t, el_t, done_early, done2])
	# 진짜 탑: 1..70층에 plan 이 찾는 그네 — 별밤 층 30..34, 65..69 중 고드름·등롱이 비켜 준 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var icn: Array = ci.plan(n, pl)
		var out := ct.plan(n, pl, icn + cn.plan(n, pl, icn))
		if out.size() > 0: bands.append("%d:%s" % [n, out.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f amax %.2f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["amax"])])]); count += out.size()
	print("TOWER floors=", bands, " trapezes=", count, " (want a subset of 30..34 and 65..69, one each)")
	quit()
