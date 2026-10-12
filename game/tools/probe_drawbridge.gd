extends SceneTree
## 도개교 팩 점검(헤드리스): 자료가 읽히나, 옛 회관 층의 잇단 still 발판 짝(70..220 px 틈, 위 발판이 60..150 px 높다) 중 가장 넓은 틈 하나에만 도개교가 서나(틈이 좁은 짝은 지고, 진폭째 상자에 드는 움직이는 발판·taken 조각(빨랫줄·종 줄·회전문)이 든 틈은 비켜 가며, 다른 테마 층·바람구멍 층은 아니다, 거울 층은 반대로),
## 아래 발판의 윈치 옆에서 C 를 쥘 때만 감나(다른 발판·멀리·앞·C 없이는 아니다), 1/16 틱으로 1.5초에 눕고 반 바퀴마다 래칫이 울리며(여섯 번) 끝에 쿵 하나, 메타(crank_ph·crank_slide)가 적히나, 누운 널은 더 감기지 않나,
## 누운 동안만 널 윗면(발판 높이)에 올라서나(x 밖·위·앞은 아니다, 선 널·세워지는 널은 아니다), 6초 뒤 추가 2초에 걸쳐 세우며 끝에 선 몸이 기운 널을 따라 경첩으로 미끄러져(300 × sin 각 px/s) 16틱에 발판에 서고 off 인가, on["x"]·on["w"] 가 기운 널을 따라 고쳐 쓰이나,
## 다 눕기 전에 손을 떼면(틱이 0.35초 끊기면) creak 과 함께 그 자리에서 도로 세워지고 다시 쥐면 그 자리에서 이어 감기나, 모르는 널은 off 인가,
## 경첩 축(널·가로장 둘·띠)·받침·기둥·북(손잡이)·추·사슬·소리 셋이 그려지고 널이 곧추섰다 눕고 사슬이 북에서 널 끝까지 이어지며 추가 내려가나, crank 자세가 두 손을 가슴 앞 원으로 돌리고 오른발을 버티며 미끄러질 땐 팔을 벌리고 뒤로 젖히나, 진짜 탑의 1..60층에서 plan 이 옛 회관 층(바람구멍 층 빼고)에만 도개교를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var dw := ClimbDrawbridge.new(); root.add_child(dw)
	var cl := ClimbLaundry.new(); root.add_child(cl)
	var cb := ClimbBell.new(); root.add_child(cb)
	var cr := ClimbDoor.new(); root.add_child(cr)
	await process_frame
	print("PACK id=", dw.pack.get("id"), " kind=", dw.kind.size() > 0, " pose=", dw.pack.get("pose"), " themes=", dw.pack.get("themes"), " inset=%.0f reach=%.0f clear=%.0f th=%.0f deck_d=%.0f lower=%.2f hold=%.1f raise=%.1f turns=%.0f slide=%.0f (want 24 18 8 6 24 1.50 6.0 2.0 3 300)" % [dw.inset(), dw.reach(), dw.clear_px(), dw.plank_th(), dw.deck_d(), dw.lower_s(), dw.hold_s(), dw.raise_s(), dw.turns(), dw.slide()])
	var plats: Array = [
		{ "id": "1.0", "x": 100.0, "y": 700.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "1.1", "x": 400.0, "y": 790.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "1.2", "x": 150.0, "y": 885.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "1.3", "x": 420.0, "y": 1010.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "1.4", "x": 600.0, "y": 1100.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "1s", "x": 560.0, "y": 1028.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := dw.plan(1, plats)
	var laundried := dw.plan(1, plats, [{ "id": "1.L0", "kind": "laundry", "x": 256.0, "w": 168.0, "y": 700.0 }])   # 빨랫줄이 1.0↔1.1 틈에(말뚝 상자 246..434, 690..840) — 1.0↔1.1 도, 1.1↔1.2 의 상자(314..456, 791..)도 가른다
	var belled := dw.plan(1, plats, [{ "id": "1.b0", "kind": "bell", "x": 335.0, "w": 10.0, "y": 750.0 }])   # 종 줄(325..355, 740..890) — 세 틈의 상자를 다 가른다
	var doored := dw.plan(1, plats, [{ "id": "1.R0", "kind": "door", "x": 162.0, "w": 56.0, "y": 700.0 }])   # 회전문이 1.0 의 가운데(152..228) — 윈치 뒤의 몸(224..)에 닿는다; 남은 틈 중 1.2↔1.3 (110) 이 1.1↔1.2 (90) 을 이긴다
	var moved := plats.duplicate(true); moved.append({ "id": "1m", "x": 330.0, "y": 760.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째 1.0↔1.1 의 상자에 든다 — 1.1↔1.2·1.2↔1.3 의 상자(791.., 886..)엔 아니다; 넓은 1.2↔1.3 이 남는다
	var movep := dw.plan(1, moved)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := dw.plan(1, mirror)
	var hg := dw.plan(5, plats); var vent := dw.plan(3, plats); var f2 := dw.plan(2, plats); var f4 := dw.plan(4, plats); var f36 := dw.plan(36, plats); var f35 := dw.plan(35, plats); var f39 := dw.plan(39, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	dw.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s hinge %.0f tip %.0f post %.0f len %.0f x %.0f w %.0f y %.0f z %.0f d %.0f" % [float(v["dir"]), float(v["gap"]), String(v["a_id"]), String(v["b_id"]), float(v["hinge_x"]), float(v["tip_x"]), float(v["post_x"]), float(v["len"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["z"]), float(v["d"])]
	print("PLAN free=", free.map(show), " (want 1: 1.D0 dir 1 gap 120 1.0→1.1 wins over 1.2↔1.3 gap 110 and 1.1↔1.2 gap 90; 1.3↔1.4 gap 60 < 70 out: hinge 280 tip 392 post 256 len 112 x 280 w 112 y 700 z −48 d 24)")
	print("PLAN laundried=", laundried.map(show), " (want 1.D0 dir 1 gap 110 1.2→1.3 hinge 310 tip 412 post 286 len 102 x 310 y 885) belled=", belled.size(), " (want 0) doored=", doored.map(show), " (want 1.D0 dir 1 gap 110 1.2→1.3 as laundried: the door's box 152..228 meets the body behind the windlass at 224, and 1.2↔1.3 at 110 beats 1.1↔1.2 at 90) moved=", movep.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f hinge %.0f" % [float(v["dir"]), float(v["gap"]), float(v["hinge_x"])]), " (want 1.D0 dir 1 gap 110 hinge 310: the mover's sweep 240..480 cuts the 1.0↔1.1 box, and 1.2↔1.3 wins the rest) right=", right.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f hinge %.0f tip %.0f post %.0f" % [float(v["dir"]), float(v["gap"]), float(v["hinge_x"]), float(v["tip_x"]), float(v["post_x"])]), " (want 1.D0 dir −1 gap 120 hinge 680 tip 568 post 704) hg=", hg.size(), " vent=", vent.size(), " f2=", f2.size(), " f4=", f4.size(), " f36=", f36.size(), " f35=", f35.size(), " f39=", f39.size(), " (want 0 0 1 1 1 0 0)")
	var s: Dictionary = dw.spans[0]
	var z := C.PLAYER_Z
	var a: Dictionary = plats[0]; var b: Dictionary = plats[1]
	var fig := Stick3D.new(); root.add_child(fig)
	var dt := 0.0625
	# 닿는 거리(기둥 256, 몸은 HW + reach = 28 안): 다른 발판(1.1)·x 300 (44)·앞 z −20·C 없이는 아니다; x 240 에서 C 는 감는다 — 몸은 기둥 뒤 240 에 선다
	dw.sync(0.0)
	var wrong := dw.crank(b, 240.0, z, 0.0, true, dt); var far := dw.crank(a, 300.0, z, 0.0, true, dt); var front := dw.crank(a, 240.0, -20.0, 0.0, true, dt); var unheld := dw.crank(a, 240.0, z, 0.0, false, dt)
	print("REACH wrong=%s far=%s front=%s unheld=%s (want false ×4) k=%.4f state=%s (want 0.0000 up: a refused crank never turns)" % [wrong["cranking"], far["cranking"], front["cranking"], unheld["cranking"], float(s["k"]), String(s["state"])])
	# 감기(1/16 틱, 1.5초 = 24틱): 4틱 k 0.166667 ph 0.5 click 1; 12틱 0.5 ph 0.5 clicks 3; 23틱 0.958333 ph 0.875 clicks 5 lowering; 24틱 1 ph 0 clicks 6 down thud, 손은 놓인다; 25틱 누운 널은 안 감긴다
	var click: AudioStreamPlayer3D = s["click"]; var thud: AudioStreamPlayer3D = s["thud"]
	var got: Dictionary = {}
	for i in 25:
		dw.sync(float(i + 1) * dt)
		click.stop()
		var r := dw.crank(a, 240.0, z, 0.0, true, dt, fig)
		if (i + 1) in [4, 12, 23, 24, 25]: got[i + 1] = { "r": r, "k": float(s["k"]), "ph": float(fig.get_meta("crank_ph", 9.0)), "sl": float(fig.get_meta("crank_slide", 9.0)), "clicks": int(s["clicks"]), "click": click.playing, "thud": thud.playing, "state": String(s["state"]), "cranking": bool(s["cranking"]) }
	var showc := func(k: int) -> String: var e: Dictionary = got[k]; var r: Dictionary = e["r"]; return "%d: cranking=%s x=%.0f k=%.6f ph=%.4f slide=%.0f clicks=%d click=%s thud=%s state=%s held=%s" % [k, r["cranking"], float(r["x"]), float(e["k"]), float(e["ph"]), float(e["sl"]), int(e["clicks"]), e["click"], e["thud"], String(e["state"]), e["cranking"]]
	print("CRANK ", showc.call(4), " (want true 240 0.166667 0.5000 0 1 true false lowering true) | ", showc.call(12), " (want true 240 0.500000 0.5000 0 3 true false lowering true) | ", showc.call(23), " (want true 240 0.958333 0.8750 0 5 false false lowering true) | ", showc.call(24), " (want true 240 1.000000 0.0000 0 6 true true down false) | ", showc.call(25), " (want false 240 1.000000 … 6 false … down false: the flat plank is not cranked)")
	# 발판(t 2.0, 누움): 떨어지는 몸(y 700 → 699)이 x 340 에서 올라선다 — kind drawbridge x 280 y 700 w 112 z −48 d 24; x 395 도(몸의 왼끝 385 < 392), x 403 은 아니다(393 ≥ 392); y 650·앞 z −20 은 아니다; 서서(t 3.0, x 380) 그대로
	dw.sync(2.0)
	var ld := dw.land(340.0, 700.0, 699.0, z); var edge := dw.land(395.0, 700.0, 699.0, z); var past := dw.land(403.0, 700.0, 699.0, z); var low := dw.land(340.0, 650.0, 649.0, z); var fr := dw.land(340.0, 700.0, 699.0, -20.0)
	dw.sync(3.0)
	var st := dw.stand(ld, 380.0, dt, fig)
	print("DECK land=%s x=%.0f y=%.0f w=%.0f z=%.0f d=%.0f (want drawbridge 280 700 112 −48 24) edge=%s (want 1.D0) past=%s low=%s front=%s (want empty ×3) | stand x=%.0f y=%.0f off=%s slide=%s (want 380 700 false false) phase@7.4=%s @7.5=%s @7.5625=%s (want down down raising)" % [String(ld.get("kind", "-")), float(ld.get("x", 0.0)), float(ld.get("y", 0.0)), float(ld.get("w", 0.0)), float(ld.get("z", 0.0)), float(ld.get("d", 0.0)), String(edge.get("id", "-")), past.is_empty(), low.is_empty(), fr.is_empty(), float(st["x"]), float(st["y"]), st["off"], st["slide"], dw.phase(s, 7.4), dw.phase(s, 7.5), dw.phase(s, 7.5625)])
	# 세우기와 미끄러짐(t 7.5 부터 2초, 1/16 틱, 몸은 끝 392 에): 1틱 k 0.96875 각 0.04909 dist 111.0800 x 390.9462 y 705.4504 on x 279 w 113.8651 slide 1 tilt 0.04909; 8틱 x 353.3027 y 730.3630 w 105.4745; 15틱 x 285.0197 y 704.5496; 16틱 off — x 269 y 700, 메타는 지워진다; 세워지는 널엔 못 올라선다(t 8.0)
	var on := ld.duplicate(); var x := 392.0
	var got2: Dictionary = {}
	for i in 16:
		dw.sync(7.5 + float(i + 1) * dt)
		var r := dw.stand(on, x, dt, fig)
		x = float(r["x"])
		if (i + 1) in [1, 8, 15, 16]: got2[i + 1] = { "r": r, "onx": float(on["x"]), "onw": float(on["w"]), "sl": float(fig.get_meta("crank_slide", 9.0)), "tilt": float(fig.get_meta("crank_tilt", 9.0)), "has": fig.has_meta("crank_slide") }
		if (i + 1) == 8: got2["noland"] = dw.land(340.0, 700.0, 699.0, z).is_empty()
	var shows := func(k: int) -> String: var e: Dictionary = got2[k]; var r: Dictionary = e["r"]; return "%d: x=%.4f y=%.4f off=%s slide=%s on.x=%.4f on.w=%.4f meta slide=%.0f tilt=%.5f" % [k, float(r["x"]), float(r["y"]), r["off"], r["slide"], float(e["onx"]), float(e["onw"]), float(e["sl"]), float(e["tilt"])]
	print("SLIDE ", shows.call(1), " (want 390.9462 705.4504 false true 279.0000 113.8651 1 0.04909) | ", shows.call(8), " (want 353.3027 730.3630 false true 279.0000 105.4745 1 0.39270) | ", shows.call(15), " (want 285.0197 704.5496 false true) | ", shows.call(16), " (want 269.0000 700.0000 true false … meta gone) metas gone=%s (want true) noland@8.0=%s (want true) phase@9.5=%s (want up)" % [not (got2[16] as Dictionary)["has"], got2["noland"], dw.phase(s, 9.5)])
	# 일찍 놓기(t 10.0 부터 8틱: k 0.333333 clicks 2; 10.9 에 틱이 0.4초 끊겨 손을 뗀 것 — back, k_rel 0.333333, creak; 11.4 에 k 0.083333 raising; 11.2 에 다시 쥐면 0.183333 에서 이어 0.225, lowering, click 없음); 모르는 널은 off
	dw.sync(9.6); dw._process(0.0); var up_state := String(s["state"])
	for i in 8:
		dw.sync(10.0 + float(i + 1) * dt)
		dw.crank(a, 240.0, z, 0.0, true, dt, fig)
	var k8 := float(s["k"]); var c8 := int(s["clicks"])
	var creak: AudioStreamPlayer3D = s["creak"]; creak.stop()
	dw.sync(10.9); var st_rel := String(s["state"]); var k_rel := float(s["k_rel"]); var creak_on := creak.playing; var cranking_rel := bool(s["cranking"])
	var k114 := dw.k_at(s, 11.4); var ph114 := dw.phase(s, 11.4)
	dw.sync(11.2); click.stop(); var again := dw.crank(a, 240.0, z, 0.0, true, dt, fig); var k_again := float(s["k"]); var st_again := String(s["state"]); var click_again := click.playing; var clicks_again := int(s["clicks"])
	var lost := dw.stand({ "id": "nope", "x": 5.0, "y": 7.0 }, 50.0, dt)
	print("RELEASE up@9.6=%s (want up) | 8 ticks k=%.6f clicks=%d (want 0.333333 2) | let go: state=%s k_rel=%.6f creak=%s cranking=%s (want back 0.333333 true false) | 11.4: k=%.6f phase=%s (want 0.083333 raising) | regrip 11.2: cranking=%s k=%.6f state=%s click=%s clicks=%d (want true 0.225000 lowering false 1) | unknown: off=%s x=%.0f y=%.0f (want true 50 7)" % [up_state, k8, c8, st_rel, k_rel, creak_on, cranking_rel, k114, ph114, again["cranking"], k_again, st_again, click_again, clicks_again, lost["off"], float(lost["x"]), float(lost["y"])])
	# 그림: 노드 아이 9(축·받침·기둥·북·추·사슬·소리 3), 축 아이 4(널·가로장 2·띠), 북 아이 1(손잡이); 노드 자리 −5.5556 19.4444 −1.3333; 선 널(t 20) 축 z 1.5708 사슬 1.9534 추 y 0.9111; 누운 널(감아서) 축 z 0 사슬 4.0109 추 y 0.2000
	dw.sync(12.0); dw.sync(20.0); dw._process(0.0)   # 12.0 에 틱이 끊겨 놓인 널(back, 0.225)은 20.0 엔 다 섰다
	var node: Node3D = s["node"]; var pivot: Node3D = s["pivot"]; var chain: Node3D = s["chain"]; var weight: Node3D = s["weight"]; var drum: Node3D = s["drum"]
	var up_rz := pivot.rotation.z; var up_chain := chain.scale.y; var up_wy := weight.position.y
	for i in 24:
		dw.sync(20.0 + float(i + 1) * dt)
		dw.crank(a, 240.0, z, 0.0, true, dt)
	dw._process(0.0)
	print("VISUAL node children=%d (want 9) pivot children=%d (want 4) drum children=%d (want 1) node pos=%.4f %.4f %.4f (want −5.5556 19.4444 −1.3333) | up: pivot rz=%.4f (want 1.5708) chain=%.4f (want 1.9534) weight y=%.4f (want 0.9111) | down: pivot rz=%.4f (want 0.0000) chain=%.4f (want 4.0109) weight y=%.4f (want 0.2000) state=%s (want down)" % [node.get_child_count(), pivot.get_child_count(), drum.get_child_count(), node.position.x, node.position.y, node.position.z, up_rz, up_chain, up_wy, pivot.rotation.z, chain.scale.y, weight.position.y, String(s["state"])])
	# 자세: 감기(ph 0.25 — 손이 원의 꼭대기): 어깨 −1.10 (ARM, cos 0) 어깨 z ∓0.12 팔꿈치 −0.55 (0.9 − 0.35), 오른 엉덩이 0.36 (앞으로 버틴 발 + 흔들림 0.04) 왼 −0.29, 오른 무릎 0.50, 골반 0.370 (0.42 − 0.05), 몸통 0.135 (lean 0.30 × 0.45);
	# 미끄러짐(slide 1, tilt π/4): 어깨 −0.60 어깨 z ∓1.25 팔꿈치 −0.40 엉덩이 0.75 무릎 0.15 골반 0.300 몸통 −0.180 (lean −0.40 × 0.45)
	fig.pose_request = "crank"
	fig.set_meta("crank_ph", 0.25); fig.set_meta("crank_slide", 0.0)
	await process_frame; await process_frame; await process_frame
	var early_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	for i in 60: await process_frame
	var sh_a: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz_a: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shz_b: float = (fig.shoulders[-1.0] as Node3D).rotation.z
	var el_a: float = (fig.elbows[1.0] as Node3D).rotation.x; var hip_a: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_b: float = (fig.hips[-1.0] as Node3D).rotation.x; var knee_a: float = (fig.knees[1.0] as Node3D).rotation.x; var pel_c := fig.pelvis.position.y; var torso_c := fig.torso.rotation.x
	fig.set_meta("crank_slide", 1.0); fig.set_meta("crank_tilt", PI / 4.0)
	for i in 40: await process_frame
	var sh_s: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz_s: float = (fig.shoulders[1.0] as Node3D).rotation.z; var el_s: float = (fig.elbows[1.0] as Node3D).rotation.x; var hip_s: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_s: float = (fig.knees[1.0] as Node3D).rotation.x; var pel_s := fig.pelvis.position.y; var torso_s := fig.torso.rotation.x
	print("POSE early=%.2f (want > −1.0: the reach has only begun) cranking: shoulder=%.2f (want −1.10) z=%.2f %.2f (want −0.12 0.12) elbow=%.2f (want −0.55) hips=%.2f %.2f (want 0.36 −0.29: the right foot braced ahead) knee=%.2f (want 0.50) pelvis=%.3f (want 0.370) torso=%.3f (want 0.135) | slide: shoulder=%.2f (want −0.60) z=%.2f (want −1.25) elbow=%.2f (want −0.40) hip=%.2f (want 0.75) knee=%.2f (want 0.15) pelvis=%.3f (want 0.300) torso=%.3f (want −0.180)" % [early_sh, sh_a, shz_a, shz_b, el_a, hip_a, hip_b, knee_a, pel_c, torso_c, sh_s, shz_s, el_s, hip_s, knee_s, pel_s, torso_s])
	# 진짜 탑: 1..60층에 plan 이 찾는 도개교 — 옛 회관 층 1..4, 35..39 중 바람구멍 층(3, 35, 39)을 뺀, 종 줄·회전문·빨랫줄(taken)이 안 든 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var bl: Array = cb.plan(n, pl); var dr: Array = cr.plan(n, pl, bl)
		var out2 := dw.plan(n, pl, bl + dr + cl.plan(n, pl, bl + dr))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f len %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["len"])])]); count += out2.size()
	print("TOWER floors=", bands, " drawbridges=", count, " (want a subset of 1, 2, 4, 36, 37, 38 — one each, never 3, 35 or 39)")
	quit()
