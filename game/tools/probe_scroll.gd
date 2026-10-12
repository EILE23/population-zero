extends SceneTree
## 두루마리 선반 팩 점검(헤드리스): 자료가 읽히나, 서재 층의 잇단 still 발판 짝(70..220 px 틈, 위 발판이 40..150 px 높다) 중 가장 넓은 틈 옆에만 선반이 서나(틈이 좁은 짝은 지고, 진폭째 상자에 드는 움직이는 발판·taken 조각(서가·덤웨이터)이 든 틈은 비켜 가며 벽 쪽 파터노스터는 안 닿고, 다른 테마 층은 아니다, 거울 층은 반대로),
## 아래 발판의 선반 옆에서 C 를 누를 때만 당기나(다른 발판·멀리·앞·C 없이는 아니다), 1/16 틱으로 0.8초에 펼쳐지며 몸이 12 px 물러서고 메타(unroll_k)가 적히나, 눕는 틱에 flop 이 울리고 손이 풀리나, 누운 지도는 더 안 당겨지나,
## 누운 동안만 지도 윗면(발판 높이)에 올라서나(x 밖·위·앞은 아니다), 선 시간이 2초 차면 찢겨 off 이고(rip, 0.6 에서 말려 돌아간다) 그 뒤엔 못 올라서나, 아무도 안 서면 8초 뒤 저절로 말리나(rip 없이 wind), 당기는 틱이 0.35초 끊기면 몸만 풀리고 종이는 계속 펼쳐지나, 모르는 지도는 off 인가,
## 선반(받침·기둥 둘·지도 셋·띠)·종이(장·먹선 둘)·두루마리·조각·소리 넷이 그려지고 말린 두루마리는 선반 꼭대기에, 펼친 종이는 틈 길이로 두루마리가 끝에 가며 찢기면 종이가 0.6 으로 줄고 조각이 떨어져 사라지나, unroll 자세가 가슴에서 종이만큼 벌리며 왼발이 물러서고 다 펼치면 쉬나, 진짜 탑의 1..60층에서 plan 이 서재 층에만 선반을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var sc := ClimbScroll.new(); root.add_child(sc)
	var cl := ClimbLadder.new(); root.add_child(cl)
	var cd := ClimbDumbwaiter.new(); root.add_child(cd)
	var cs := ClimbBookcase.new(); root.add_child(cs)
	var pn := ClimbPaternoster.new(); root.add_child(pn)
	await process_frame
	print("PACK id=", sc.pack.get("id"), " kind=", sc.kind.size() > 0, " pose=", sc.pack.get("pose"), " themes=", sc.pack.get("themes"), " inset=%.0f reach=%.0f clear=%.0f th=%.0f deck_d=%.0f unroll=%.2f hold=%.1f tear_at=%.2f idle=%.1f roll=%.1f step=%.0f (want 24 18 8 2 24 0.80 2.0 0.60 8.0 4.0 12)" % [sc.inset(), sc.reach(), sc.clear_px(), sc.sheet_th(), sc.deck_d(), sc.unroll_s(), sc.hold_s(), sc.tear_at(), sc.idle_s(), sc.roll_s(), sc.step()])
	var plats: Array = [
		{ "id": "11.0", "x": 100.0, "y": 700.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "11.1", "x": 400.0, "y": 790.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "11.2", "x": 150.0, "y": 885.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "11.3", "x": 420.0, "y": 1010.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "11.4", "x": 600.0, "y": 1100.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "11s", "x": 560.0, "y": 1028.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := sc.plan(11, plats)
	var cased := sc.plan(11, plats, [{ "id": "11.B0", "kind": "bookcase", "x": 230.0, "w": 40.0, "y": 700.0 }])   # 서가가 11.0 위(220..280, 690..920) — 11.0↔11.1 의 상자(224..396)도, 11.2↔11.3 의 상자(254..416, 886..935)도 가른다; 11.1↔11.2 (90) 가 남는다
	var dumbed := sc.plan(11, plats, [{ "id": "11.D0", "kind": "dumbwaiter", "x": 190.0, "w": 44.0, "y": 700.0, "beam_y": 981.0 }])   # 덤웨이터 기둥(180..244, 690..1041) — 11.0↔11.1 의 상자만 가른다; 11.2↔11.3 (110) 이 11.1↔11.2 (90) 을 이긴다
	var chained := sc.plan(11, plats, [{ "id": "11.N0", "kind": "paternoster", "x": 14.0, "w": 104.0, "y": 530.0, "y_top": 1000.0 }])   # 벽 쪽 레인(4..128) — 어느 상자에도 안 닿는다
	var moved := plats.duplicate(true); moved.append({ "id": "11m", "x": 330.0, "y": 740.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째(240..480, 740) 11.0↔11.1 의 상자(701..750)에 든다 — 11.1↔11.2·11.2↔11.3 의 상자(791.., 886..)엔 아니다
	var movep := sc.plan(11, moved)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := sc.plan(11, mirror)
	var garden := sc.plan(9, plats); var clock := sc.plan(15, plats); var f10 := sc.plan(10, plats); var f14 := sc.plan(14, plats); var f45 := sc.plan(45, plats); var f44 := sc.plan(44, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	sc.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s hinge %.0f tip %.0f post %.0f len %.0f x %.0f w %.0f y %.0f z %.0f d %.0f" % [float(v["dir"]), float(v["gap"]), String(v["a_id"]), String(v["b_id"]), float(v["hinge_x"]), float(v["tip_x"]), float(v["post_x"]), float(v["len"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["z"]), float(v["d"])]
	print("PLAN free=", free.map(show), " (want 1: 11.S0 dir 1 gap 120 11.0→11.1 wins over 11.2↔11.3 gap 110 and 11.1↔11.2 gap 90; 11.3↔11.4 gap 60 < 70 out: hinge 280 tip 392 post 256 len 112 x 280 w 112 y 700 z −48 d 24)")
	print("PLAN cased=", cased.map(show), " (want 11.S0 dir −1 gap 90 11.1→11.2 hinge 400 tip 318 post 424 len 82 x 318 w 82 y 790) dumbed=", dumbed.map(show), " (want 11.S0 dir 1 gap 110 11.2→11.3 hinge 310 tip 412 post 286 len 102 x 310 y 885) chained=", chained.map(func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f" % float(v["gap"])), " (want 11.S0 gap 120: the wall lane never meets) moved=", movep.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f hinge %.0f" % [float(v["dir"]), float(v["gap"]), float(v["hinge_x"])]), " (want 11.S0 dir 1 gap 110 hinge 310) right=", right.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f hinge %.0f tip %.0f post %.0f x %.0f" % [float(v["dir"]), float(v["gap"]), float(v["hinge_x"]), float(v["tip_x"]), float(v["post_x"]), float(v["x"])]), " (want 11.S0 dir −1 gap 120 hinge 680 tip 568 post 704 x 568) garden=", garden.size(), " clock=", clock.size(), " f10=", f10.size(), " f14=", f14.size(), " f45=", f45.size(), " f44=", f44.size(), " (want 0 0 1 1 1 0)")
	var s: Dictionary = sc.racks[0]
	var z := C.PLAYER_Z
	var a: Dictionary = plats[0]; var b: Dictionary = plats[1]
	var fig := Stick3D.new(); root.add_child(fig)
	var dt := 0.0625
	# 닿는 거리(선반 256, 몸은 HW + reach = 28 안): 다른 발판(11.1)·x 300 (44)·앞 z −20·C 없이는 아니다; x 240 에서 C 는 당긴다
	sc.sync(0.0)
	var wrong := sc.pull(b, 240.0, z, true); var far := sc.pull(a, 300.0, z, true); var front := sc.pull(a, 240.0, -20.0, true); var unpressed := sc.pull(a, 240.0, z, false)
	print("REACH wrong=%s far=%s front=%s unpressed=%s (want false ×4) state=%s (want rolled: a refused pull never starts)" % [wrong["pulling"], far["pulling"], front["pulling"], unpressed["pulling"], String(s["state"])])
	# 당기기(1/16 틱, 0.8초): 1틱 pulling x 240 k 0 pull 소리; 5틱 k 0.3125 x 236.25; 13틱 k 0.9375 x 228.75 unrolling; 14틱(0.875 ≥ 0.8625) 안 당긴다, open, flop, 메타 지워짐; 16틱에 다시 누르면 안 당긴다
	var pullp: AudioStreamPlayer3D = s["pull"]; var flop: AudioStreamPlayer3D = s["flop"]
	var got: Dictionary = {}
	var x := 240.0
	for i in 16:
		sc.sync(float(i + 1) * dt)
		if i > 0: pullp.stop()
		var r := sc.pull(a, x, z, i == 0 or i == 15, fig)
		x = float(r["x"])
		if (i + 1) in [1, 5, 13, 14, 16]: got[i + 1] = { "r": r, "k": float(fig.get_meta("unroll_k", 9.0)), "has": fig.has_meta("unroll_k"), "pull": pullp.playing, "flop": flop.playing, "ph": sc.phase(s, float(i + 1) * dt), "puller": bool(s["puller"]) }
	var showp := func(k: int) -> String: var e: Dictionary = got[k]; var r: Dictionary = e["r"]; return "%d: pulling=%s x=%.2f k=%.4f meta=%s pull=%s flop=%s phase=%s puller=%s" % [k, r["pulling"], float(r["x"]), float(e["k"]), e["has"], e["pull"], e["flop"], String(e["ph"]), e["puller"]]
	print("PULL ", showp.call(1), " (want true 240.00 0.0000 true true false unrolling true) | ", showp.call(5), " (want true 236.25 0.3125 true false false unrolling true) | ", showp.call(13), " (want true 228.75 0.9375 true false false unrolling true) | ", showp.call(14), " (want false 228.75 … false false true open true) | ", showp.call(16), " (want false 228.75 … false false … open: the flat chart is not pulled again)")
	# 발판(t 2.0, 누움): 떨어지는 몸(y 700 → 699)이 x 340 에서 올라선다 — kind scroll x 280 y 700 w 112 z −48 d 24; x 395 도(몸의 왼끝 385 < 392), x 403 은 아니다(393 ≥ 392); y 650·앞 z −20 은 아니다; 서서(t 3.0, x 380) 그대로, stood 0.0625
	sc.sync(2.0)
	var ld := sc.land(340.0, 700.0, 699.0, z); var edge := sc.land(395.0, 700.0, 699.0, z); var past := sc.land(403.0, 700.0, 699.0, z); var low := sc.land(340.0, 650.0, 649.0, z); var fr := sc.land(340.0, 700.0, 699.0, -20.0)
	sc.sync(3.0)
	var st := sc.stand(ld, 380.0, dt, fig)
	print("DECK land=%s x=%.0f y=%.0f w=%.0f z=%.0f d=%.0f (want scroll 280 700 112 −48 24) edge=%s (want 11.S0) past=%s low=%s front=%s (want empty ×3) | stand x=%.0f y=%.0f off=%s tear=%s stood=%.4f (want 380 700 false false 0.0625)" % [String(ld.get("kind", "-")), float(ld.get("x", 0.0)), float(ld.get("y", 0.0)), float(ld.get("w", 0.0)), float(ld.get("z", 0.0)), float(ld.get("d", 0.0)), String(edge.get("id", "-")), past.is_empty(), low.is_empty(), fr.is_empty(), float(st["x"]), float(st["y"]), st["off"], st["tear"], float(s["stood"])])
	# 찢김(3.0625 부터 1/16 틱으로 서 있기): 31째 틱(t 4.9375, stood 2.0)에 tear·off, back, torn, k_back 0.6, rip; 5.0 엔 못 올라서고 서면 off; k(5.9375) 0.45 back; 8.9375 rolled
	var rip: AudioStreamPlayer3D = s["rip"]; rip.stop()
	var tear_tick := -1; var tear_r: Dictionary = {}
	for i in 40:
		sc.sync(3.0 + float(i + 1) * dt)
		var r := sc.stand(ld, 380.0, dt, fig)
		if bool(r["tear"]) and tear_tick < 0: tear_tick = i + 1; tear_r = r
	var t_tear := 3.0 + float(tear_tick) * dt
	var rip_on := rip.playing; var st_t := String(s["state"]); var torn := bool(s["torn"]); var kb := float(s["k_back"]); var stood := float(s["stood"])
	sc.sync(5.0); var noland := sc.land(340.0, 700.0, 699.0, z).is_empty(); var after := sc.stand(ld, 380.0, dt, fig)
	print("TEAR tick=%d (want 31) t=%.4f (want 4.9375) off=%s tear=%s (want true true) state=%s torn=%s k_back=%.2f stood=%.4f rip=%s (want back true 0.60 2.0000 true) | 5.0: noland=%s stand off=%s tear=%s (want true true false) k@5.9375=%.4f (want 0.4500) phase@5.9375=%s @8.9375=%s (want back rolled)" % [tear_tick, t_tear, tear_r.get("off", "-"), tear_r.get("tear", "-"), st_t, torn, kb, stood, rip_on, noland, after["off"], after["tear"], sc.k_at(s, 5.9375), sc.phase(s, 5.9375), sc.phase(s, 8.9375)])
	# 저절로 말리기(10.0 에 당김, 10.8 눕고 아무도 안 선다): 12.0 에 누르면 안 당긴다; phase 10.8 open, 18.7 open, 18.9 back k 0.975 wind, rip 아님, torn 아님; 19.0 에 누르면 안 당긴다; 22.9 rolled
	var wind: AudioStreamPlayer3D = s["wind"]; wind.stop(); rip.stop()
	sc.sync(10.0); var again := sc.pull(a, 240.0, z, true, fig)
	sc.sync(12.0); var mid := sc.pull(a, 240.0, z, true, fig)
	var ph108 := sc.phase(s, 10.8); var ph187 := sc.phase(s, 18.7)
	sc.sync(18.9); sc._process(0.0); var ph189 := sc.phase(s, 18.9); var k189 := sc.k_at(s, 18.9); var wind_on := wind.playing; var rip_idle := rip.playing; var torn_idle := bool(s["torn"])
	sc.sync(19.0); var late := sc.pull(a, 240.0, z, true, fig)
	var ph229 := sc.phase(s, 22.9)
	print("IDLE again=%s (want true) mid@12=%s (want false) phase@10.8=%s @18.7=%s @18.9=%s (want open open back) k@18.9=%.4f (want 0.9750) wind=%s rip=%s torn=%s (want true false false) late@19=%s (want false) phase@22.9=%s (want rolled)" % [again["pulling"], mid["pulling"], ph108, ph187, ph189, k189, wind_on, rip_idle, torn_idle, late["pulling"], ph229])
	# 손 풀림(24.0 에 당김, 24.5 까지 틱이 끊긴다): 24.5 에 누르지 않고 물으면 안 당긴다(puller false) — 종이는 계속(phase unrolling, k 0.625); 24.8 open; 모르는 지도는 off
	sc.sync(24.0); var p24 := sc.pull(a, 240.0, z, true, fig)
	sc.sync(24.5); var p245 := sc.pull(a, 240.0, z, false, fig); var ph245 := sc.phase(s, 24.5); var k245 := sc.k_at(s, 24.5); var has245 := fig.has_meta("unroll_k")
	var ph248 := sc.phase(s, 24.8)
	var lost := sc.stand({ "id": "nope", "x": 5.0, "y": 7.0 }, 50.0, dt)
	print("LETGO 24.0=%s (want true) 24.5=%s puller=%s (want false false) phase@24.5=%s k=%.4f (want unrolling 0.6250) meta=%s (want false) phase@24.8=%s (want open) | unknown: off=%s x=%.0f y=%.0f (want true 50 7)" % [p24["pulling"], p245["pulling"], bool(s["puller"]), ph245, k245, has245, ph248, lost["off"], float(lost["x"]), float(lost["y"])])
	# 그림(t 40 말림): 노드 아이 8(선반·종이·두루마리·조각·소리 4), 선반 아이 7, 종이 아이 3; 노드 자리 −5.5556 19.4444 −1.3333; 말린 종이 보이지 않고 두루마리는 선반 꼭대기(−0.6667 1.4722 −0.3333);
	# 펼침(40 에 당겨 41): 종이 scale.x 3.1111 x 1.5556 보임, 두루마리 (3.1111 0.0833 0); 찢김(41.0625 부터 32틱 → 43.0): 종이 scale.x 1.8667, 조각 보임 x 2.4889; 43.3: 조각 y −0.5278, k 0.5550; 43.7: 조각 안 보임
	sc.sync(40.0); sc._process(0.0)
	var node: Node3D = s["node"]; var rack: Node3D = s["rack"]; var page: Node3D = s["page"]; var roll: Node3D = s["roll"]; var scrap: Node3D = s["scrap"]
	var rolled_vis := page.visible; var roll_up := roll.position
	sc.pull(a, 240.0, z, true, fig)
	sc.sync(41.0); sc._process(0.0)
	var flat_vis := page.visible; var flat_sx := page.scale.x; var flat_px := page.position.x; var roll_flat := roll.position
	var ld2 := sc.land(340.0, 700.0, 699.0, z)
	var tear2 := -1
	for i in 32:
		sc.sync(41.0 + float(i + 1) * dt)
		var r := sc.stand(ld2, 380.0, dt, fig)
		if bool(r["tear"]) and tear2 < 0: tear2 = i + 1
	sc._process(0.0)
	var torn_sx := page.scale.x; var scrap_vis := scrap.visible; var scrap_x := scrap.position.x
	sc.sync(43.3); sc._process(0.0); var scrap_y := scrap.position.y; var k433 := sc.k_at(s, 43.3)
	sc.sync(43.7); sc._process(0.0); var scrap_gone := not scrap.visible
	print("VISUAL node children=%d (want 8) rack children=%d (want 7) page children=%d (want 3) node pos=%.4f %.4f %.4f (want −5.5556 19.4444 −1.3333) | rolled: page visible=%s (want false) roll=%.4f %.4f %.4f (want −0.6667 1.4722 −0.3333) | flat: visible=%s scale.x=%.4f x=%.4f (want true 3.1111 1.5556) roll=%.4f %.4f %.4f (want 3.1111 0.0833 0.0000) | torn@%d (want 32): scale.x=%.4f (want 1.8667) scrap=%s x=%.4f (want true 2.4889) 43.3: y=%.4f (want −0.5278) k=%.4f (want 0.5550) 43.7 gone=%s (want true)" % [node.get_child_count(), rack.get_child_count(), page.get_child_count(), node.position.x, node.position.y, node.position.z, rolled_vis, roll_up.x, roll_up.y, roll_up.z, flat_vis, flat_sx, flat_px, roll_flat.x, roll_flat.y, roll_flat.z, tear2, torn_sx, scrap_vis, scrap_x, scrap_y, k433, scrap_gone])
	# 자세: 반쯤(unroll_k 0.5, 쥐기 끝): 어깨 −1.150 (1.35→0.95 의 가운데) 어깨 z ∓0.550 팔꿈치 −1.125 오른 엉덩이 0.060 (조금 앞) 왼 −0.250 (물러선다) 오른 무릎 0.090 왼 0.200 골반 0.365 (0.42 − 0.055) 몸통 0.036 (lean 0.08 × 0.45);
	# 다 펼침(unroll_k 1): 어깨 z ∓0.950 팔꿈치 −0.350 엉덩이 0.120/−0.500 무릎 0.180/0.400 골반 0.350 몸통 −0.054, 어깨 −0.95 에서 쉬며 −0.70 으로(pose_t 가 1.2 를 넘으면)
	fig.pose_request = "unroll"
	fig.set_meta("unroll_k", 0.5)
	await process_frame; await process_frame; await process_frame
	var early_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	for i in 60: await process_frame
	var sh_h: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz_h: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shz_hb: float = (fig.shoulders[-1.0] as Node3D).rotation.z
	var el_h: float = (fig.elbows[1.0] as Node3D).rotation.x; var hip_h: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_hb: float = (fig.hips[-1.0] as Node3D).rotation.x; var knee_h: float = (fig.knees[1.0] as Node3D).rotation.x; var knee_hb: float = (fig.knees[-1.0] as Node3D).rotation.x; var pel_h := fig.pelvis.position.y; var torso_h := fig.torso.rotation.x
	fig.set_meta("unroll_k", 1.0)
	for i in 100: await process_frame
	var sh_f: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz_f: float = (fig.shoulders[1.0] as Node3D).rotation.z; var el_f: float = (fig.elbows[1.0] as Node3D).rotation.x; var hip_f: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_fb: float = (fig.hips[-1.0] as Node3D).rotation.x; var knee_f: float = (fig.knees[1.0] as Node3D).rotation.x; var knee_fb: float = (fig.knees[-1.0] as Node3D).rotation.x; var pel_f := fig.pelvis.position.y; var torso_f := fig.torso.rotation.x
	print("POSE early=%.2f (want > −1.0: the grasp has only begun) half: shoulder=%.3f (want −1.150) z=%.3f %.3f (want −0.550 0.550) elbow=%.3f (want −1.125) hips=%.3f %.3f (want 0.060 −0.250: the left foot steps back) knees=%.3f %.3f (want 0.090 0.200) pelvis=%.3f (want 0.365) torso=%.3f (want 0.036) | full: shoulder=%.3f (want −0.950 settling to −0.700) z=%.3f (want −0.950) elbow=%.3f (want −0.350) hips=%.3f %.3f (want 0.120 −0.500) knees=%.3f %.3f (want 0.180 0.400) pelvis=%.3f (want 0.350) torso=%.3f (want −0.054) pose_t=%.2f" % [early_sh, sh_h, shz_h, shz_hb, el_h, hip_h, hip_hb, knee_h, knee_hb, pel_h, torso_h, sh_f, shz_f, el_f, hip_f, hip_fb, knee_f, knee_fb, pel_f, torso_f, fig.pose_t])
	# 진짜 탑: 1..60층에 plan 이 찾는 선반 — 서재 층 10..14, 45..49 중 사다리·덤웨이터·서가·파터노스터(taken)가 안 든 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var lp: Array = cl.plan(n, pl); var dp: Array = cd.plan(n, pl); var bp: Array = cs.plan(n, pl, lp + dp); var np: Array = pn.plan(n, pl, lp + dp + bp)
		var out2 := sc.plan(n, pl, lp + dp + bp + np)
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f len %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["len"])])]); count += out2.size()
	print("TOWER floors=", bands, " racks=", count, " (want a subset of 10..14 and 45..49 — one each, never another theme)")
	quit()
