extends SceneTree
## 카드 목록함 팩 점검(헤드리스): 자료가 읽히나, 서재 층의 잇단 still 발판 짝(70..220 px 틈, 위 발판이 40..150 px 높다) 중 가장 넓은 틈에만 목록함이 서나(틈이 좁은 짝은 지고, taken 조각(두루마리 선반)이 든 틈은 비켜 가며, 진폭째 상자에 드는 움직이는 발판도, 다른 테마 층은 아니다, 거울 층은 반대로, 서랍 수는 높이차에서),
## 아래 발판의 앞면 옆에서 C 를 누를 때만 당기나(다른 발판·멀리·앞·C 없이·나오는 중엔 아니다), 0.3초에 나오고 3초 머물고 0.5초에 들어가며 탁 소리가 나나(k·phase), 나와 있는 동안만 윗면에 올라서나(x 밖·위·앞·아래는 아니다),
## 서랍 위에서 C 면 바로 위 서랍이 열리고 맨 위에선 아니나, 들어가는 서랍이 몸을 절벽 쪽으로 싣고(등이 절벽에 닿으면 거기서) 다 들어가면 off 인가, 두 번의 홱이 1초 안이면 카드가 빠져 60 px/s 로 아래 발판에 눕고 C 로 집어 읽나(1.5초 뒤의 홱엔 아니다, 12초 뒤엔 치워진다),
## 틀·서랍 slot(앞판·손잡이·라벨)·카드·소리 셋이 그려지고 서랍 slot 이 나온 만큼 z 로 밀리나, yank 자세가 뻗고 당기고 놓고 서나, 진짜 탑의 1..60층에서 plan 이 서재 층에만 목록함을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cc := ClimbCatalogue.new(); root.add_child(cc)
	var cl := ClimbLadder.new(); root.add_child(cl)
	var cd := ClimbDumbwaiter.new(); root.add_child(cd)
	var cs := ClimbBookcase.new(); root.add_child(cs)
	var pn := ClimbPaternoster.new(); root.add_child(pn)
	var sc := ClimbScroll.new(); root.add_child(sc)
	await process_frame
	print("PACK id=", cc.pack.get("id"), " kind=", cc.kind.size() > 0, " pose=", cc.pack.get("pose"), " themes=", cc.pack.get("themes"), " cards=", cc.cards_txt.size(), " near=%.0f cab_w=%.0f step=%.0f draw_h=%.0f draw_out=%.0f reach=%.0f pull=%.2f hold=%.1f slide=%.2f card_s=%.1f card_v=%.0f lie=%.1f (want 6 12 48 24 18 40 18 0.30 3.0 0.50 1.0 60 12.0)" % [cc.near(), cc.cab_w(), cc.step(), cc.draw_h(), cc.draw_out(), cc.reach(), cc.pull_s(), cc.hold_s(), cc.slide_s(), cc.card_s(), cc.card_v(), cc.card_lie_s()])
	var plats: Array = [
		{ "id": "11.0", "x": 100.0, "y": 700.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "11.1", "x": 400.0, "y": 790.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "11.2", "x": 150.0, "y": 885.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "11.3", "x": 420.0, "y": 1010.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "11.4", "x": 600.0, "y": 1100.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "11s", "x": 560.0, "y": 1028.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cc.plan(11, plats)
	var racked := cc.plan(11, plats, [{ "id": "11.S0", "kind": "scroll", "x": 280.0, "w": 112.0, "y": 700.0 }])   # 두루마리 선반이 11.0↔11.1 의 틈(270..402, 690..920 — 꼭대기 없는 조각은 220 위까지) — 이 층의 세 상자(701..798, 791..912, 886..1031)를 다 가른다: 목록함 없음
	var racked_far := cc.plan(11, plats, [{ "id": "11.S0", "kind": "scroll", "x": 280.0, "w": 112.0, "y": 500.0 }])   # 선반이 더 아래(490..720)면 11.0↔11.1 의 상자(701..)만 가른다; 11.2↔11.3 (110) 이 11.1↔11.2 (90) 을 이긴다
	var moved := plats.duplicate(true); moved.append({ "id": "11m", "x": 330.0, "y": 740.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째(240..480, 740) 11.0↔11.1 의 상자(701..798)에 든다
	var movep := cc.plan(11, moved)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := cc.plan(11, mirror)
	var garden := cc.plan(9, plats); var clock := cc.plan(15, plats); var f10 := cc.plan(10, plats); var f14 := cc.plan(14, plats); var f45 := cc.plan(45, plats); var f44 := cc.plan(44, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cc.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s hinge %.0f near %.0f far %.0f nd %d x %.0f w %.0f y %.0f y_top %.0f z %.0f d %.0f" % [float(v["dir"]), float(v["gap"]), String(v["a_id"]), String(v["b_id"]), float(v["hinge_x"]), float(v["near_x"]), float(v["far_x"]), int(v["nd"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	print("PLAN free=", free.map(show), " (want 1: 11.C0 dir 1 gap 120 11.0→11.1 wins over 11.2↔11.3 gap 110 and 11.1↔11.2 gap 90; 11.3↔11.4 gap 60 < 70 out: hinge 280 near 292 far 340 nd 2 x 292 w 48 y 700 y_top 766 z −50 d 40)")
	print("PLAN racked=", racked.size(), " (want 0: every gap of this floor lies in the 220 px band over the rack) racked_far=", racked_far.map(show), " (want 11.C0 dir 1 gap 110 11.2→11.3 hinge 310 near 322 far 370 nd 4 x 322 y 885 y_top 999) moved=", movep.map(func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f hinge %.0f" % [float(v["gap"]), float(v["hinge_x"])]), " (want 11.C0 gap 110 hinge 310) right=", right.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f hinge %.0f near %.0f far %.0f x %.0f" % [float(v["dir"]), float(v["gap"]), float(v["hinge_x"]), float(v["near_x"]), float(v["far_x"]), float(v["x"])]), " (want 11.C0 dir −1 gap 120 hinge 680 near 668 far 620 x 620) garden=", garden.size(), " clock=", clock.size(), " f10=", f10.size(), " f14=", f14.size(), " f45=", f45.size(), " f44=", f44.size(), " (want 0 0 1 1 1 0)")
	var c: Dictionary = cc.cabs[0]
	var d1: Dictionary = (c["drawers"] as Array)[0]; var d2: Dictionary = (c["drawers"] as Array)[1]
	var z := C.PLAYER_Z
	var a: Dictionary = plats[0]; var b: Dictionary = plats[1]
	var fig := Stick3D.new(); root.add_child(fig)
	# 닿는 거리(앞면 292, 몸은 HW + reach = 28 안): 다른 발판(11.1)·x 250 (42)·앞 z −20·C 없이는 아니다; x 270 에서 C 는 당긴다(side 1, 카드 없음), 바로 다시 누르면 아니다(나오는 중)
	cc.sync(0.0)
	var wrong := cc.yank(b, 270.0, z, 1.0, true); var far := cc.yank(a, 250.0, z, 1.0, true); var front := cc.yank(a, 270.0, -20.0, 1.0, true); var unpressed := cc.yank(a, 270.0, z, 1.0, false)
	var ok := cc.yank(a, 270.0, z, 1.0, true, fig); var again := cc.yank(a, 270.0, z, 1.0, true)
	print("REACH wrong=%s far=%s front=%s unpressed=%s (want false ×4) ok=%s side=%.0f card=%s drawer=%s meta=%.0f (want true 1 false 11.C0.d1 1) again=%s (want false: a drawer on its way out is not pulled)" % [wrong["yanked"], far["yanked"], front["yanked"], unpressed["yanked"], ok["yanked"], float(ok["side"]), ok["card"], String(ok["drawer"]), float(fig.get_meta("yank_side", 0.0)), again["yanked"]])
	# 시계(0 에 당김): 0.15 pulling k 0.5 z_front −50; 0.3 open k 1 z_front −30; 3.29 open; 3.3 sliding k 1; 3.55 sliding k 0.5; 3.8 shut k 0 clack
	var clack: AudioStreamPlayer3D = c["clack_snd"]; clack.stop()
	var k015 := cc.k_at(d1, 0.15); var ph015 := cc.phase(d1, 0.15); var zf015 := cc.z_front(d1, 0.15)
	var ph03 := cc.phase(d1, 0.3); var zf03 := cc.z_front(d1, 0.3); var ph329 := cc.phase(d1, 3.29); var ph33 := cc.phase(d1, 3.3); var k33 := cc.k_at(d1, 3.3); var k355 := cc.k_at(d1, 3.55); var ph355 := cc.phase(d1, 3.55); var ph38 := cc.phase(d1, 3.8); var k38 := cc.k_at(d1, 3.8)
	cc.sync(3.8); var clacked := clack.playing; var tp := float(d1["t_pull"])
	print("CLOCK 0.15: k=%.2f %s z_front=%.0f (want 0.50 pulling −50) 0.3: %s z_front=%.0f (want open −30) 3.29: %s (want open) 3.3: %s k=%.2f (want sliding 1.00) 3.55: %s k=%.2f (want sliding 0.50) 3.8: %s k=%.2f (want shut 0.00) clack=%s t_pull=%.0f (want true −9)" % [k015, ph015, zf015, ph03, zf03, ph329, ph33, k33, ph355, k355, ph38, k38, clacked, tp])
	# 발판(10 에 당김, 10.5 열림): 떨어지는 몸(y 724 → 723)이 x 300 에서 올라선다 — kind drawer 11.C0.d1 cab 11.C0 x 292 y 724 w 48 z −50 d 40; x 285 도(295 > 292), x 282 는 아니다; x 345 도(335 < 340), x 350 은 아니다; 앞 z −20·아래 y 700·위 y 760 은 아니다; 10.2(나오는 중)엔 아니다
	cc.sync(10.0); cc.yank(a, 270.0, z, 1.0, true)
	cc.sync(10.2); var early := cc.land(300.0, 724.0, 723.0, z)
	cc.sync(10.5)
	var ld := cc.land(300.0, 724.0, 723.0, z); var e1 := cc.land(285.0, 724.0, 723.0, z); var e2 := cc.land(282.0, 724.0, 723.0, z); var e3 := cc.land(345.0, 724.0, 723.0, z); var e4 := cc.land(350.0, 724.0, 723.0, z)
	var fr := cc.land(300.0, 724.0, 723.0, -20.0); var low := cc.land(300.0, 700.0, 699.0, z); var high := cc.land(300.0, 760.0, 759.0, z)
	print("DECK early=%s (want true) land=%s id=%s cab=%s x=%.0f y=%.0f w=%.0f z=%.0f d=%.0f (want drawer 11.C0.d1 11.C0 292 724 48 −50 40) edges=%s %s %s %s (want 11.C0.d1 - 11.C0.d1 -) front=%s low=%s high=%s (want empty ×3)" % [early.is_empty(), String(ld.get("kind", "-")), String(ld.get("id", "-")), String(ld.get("cab", "-")), float(ld.get("x", 0.0)), float(ld.get("y", 0.0)), float(ld.get("w", 0.0)), float(ld.get("z", 0.0)), float(ld.get("d", 0.0)), String(e1.get("id", "-")), String(e2.get("id", "-")), String(e3.get("id", "-")), String(e4.get("id", "-")), fr.is_empty(), low.is_empty(), high.is_empty()])
	# 서랍 위에서(10.6) C: 둘째 서랍이 열린다(0.6 ≤ 1.0 — 카드도 빠진다); 서 있기(10.7): x 300 y 724 z −48 off false
	cc.sync(10.6); var up := cc.yank(ld, 300.0, z, 1.0, true)
	cc.sync(10.7); var st := cc.stand(ld, 300.0, z, 0.0625)
	print("LADDER up=%s drawer=%s card=%s (want true 11.C0.d2 true) stand x=%.0f y=%.0f z=%.0f off=%s (want 300 724 −48 false)" % [up["yanked"], String(up["drawer"]), up["card"], float(st["x"]), float(st["y"]), float(st["z"]), st["off"]])
	# 카드(10.6 에 빠졌다): x 276, y0 748, 60 px/s 로 700 까지 0.8초 → 11.4 눕는다; 10.9 falling y 730; 11.5 lying; 집기: 11.1(날고 있다) 아니다, 11.5 x 270 took text "Drawer 2 · Ledgers, unpaid — do not lend."(cards[(11 + 2) % 6]); 다시는 아니다; 다른 발판·멀리는 아니다
	var card: Dictionary = c["card"]
	cc.sync(10.9); var y109 := cc._card_y(c, 10.9); var st109 := String(card["state"]); var fly := cc.take(a, 270.0, z, true)
	cc.sync(11.5); var st115 := String(card["state"]); var wrongp := cc.take(b, 270.0, z, true); var farp := cc.take(a, 240.0, z, true); var took := cc.take(a, 270.0, z, true); var twice := cc.take(a, 270.0, z, true)
	cc.sync(11.6); var ld2 := cc.land(300.0, 748.0, 747.0, z); var top := cc.yank(ld2, 300.0, z, 1.0, true)   # 둘째(맨 위) 서랍 위에서 C 는 아니다
	print("CARD x=%.0f y0=%.0f (want 276 748) 10.9: %s y=%.0f (want falling 730) fly=%s (want false) 11.5: %s (want lying) wrong=%s far=%s (want false false) took=%s text=\"%s\" (want true \"Drawer 2 · Ledgers, unpaid — do not lend.\") twice=%s (want false) taken=%d (want 1) | top@11.6=%s (want false: no drawer above the top one)" % [float(card["x"]), float(card["y0"]), st109, y109, fly["took"], st115, wrongp["took"], farp["took"], took["took"], String(took["text"]), twice["took"], int(c["cards_taken"]), top["yanked"]])
	# 실려 감(d1: 10 에 당김 → 13.3 부터 들어간다): 13.3 z −48 off false; 13.4 k 0.8 z_front −38 → z −56; 13.5 k 0.6 z_front −46 → z −62 (−64 를 등이 막는다); 13.7 z −62 off false(앞면 −54 > −70); 13.8 shut → off true; 13.8 에 땅 판정도 비고 d2 는 아직 나와 있다(14.3 까지)
	var zz := z; var got: Dictionary = {}
	for tt in [13.3, 13.4, 13.5, 13.7, 13.8]:
		cc.sync(float(tt)); var r := cc.stand(ld, 300.0, zz, 0.1); zz = float(r["z"]); got[tt] = r
	var showr := func(tt: float) -> String: var r: Dictionary = got[tt]; return "%.1f: z=%.0f off=%s" % [tt, float(r["z"]), r["off"]]
	var noland := cc.land(300.0, 724.0, 723.0, -62.0).is_empty(); var below := cc.land(300.0, 748.0, 747.0, -62.0)
	print("RIDE ", showr.call(13.3), " (want −48 false) | ", showr.call(13.4), " (want −56 false) | ", showr.call(13.5), " (want −62 false) | ", showr.call(13.7), " (want −62 false) | ", showr.call(13.8), " (want −62 true) noland=%s (want true) below=%s (want 11.C0.d2: the drawer above is still out at 13.8)" % [noland, String(below.get("id", "-"))])
	# 느린 홱(20 에 d1, 21.5 에 d2 — 1.5 > 1.0): 카드 없음; 치움(30 에 d1, 30.5 에 d2 → 카드, 31.3 눕는다, 43.3 까지; 43.4 none, 집기 아니다)
	cc.sync(20.0); cc.yank(a, 270.0, z, 1.0, true); cc.sync(20.5); var l1 := cc.land(300.0, 724.0, 723.0, z); cc.sync(21.5); var slow := cc.yank(l1, 300.0, z, 1.0, true)
	cc.sync(30.0); cc.yank(a, 270.0, z, 1.0, true); cc.sync(30.5); var l2 := cc.land(300.0, 724.0, 723.0, z); var fast := cc.yank(l2, 300.0, z, 1.0, true)
	cc.sync(31.4); var st314 := String(card["state"]); var tlie := float(card["t_lie"])
	cc.sync(43.2); var st432 := String(card["state"]); cc.sync(43.4); var st434 := String(card["state"]); var gone := cc.take(a, 270.0, z, true)
	print("SLOW slow: yanked=%s card=%s (want true false) fast: yanked=%s card=%s (want true true) 31.4: %s t_lie=%.1f (want lying 31.3) 43.2: %s 43.4: %s (want lying none) gone=%s (want false)" % [slow["yanked"], slow["card"], fast["yanked"], fast["card"], st314, tlie, st432, st434, gone["took"]])
	# 그림(t 50, 다 닫힘): 노드 아이 7(틀·slot 둘·카드·소리 셋), slot 아이 3, 카드 아이 2; 노드 자리 −5.2222 19.4444 −1.9444; slot 1 자리 (0.6667 0.4167 0); 당겨(50) 50.5 에 slot z 1.1111, 카드 숨김; 50.6 둘째 홱 → 50.9 카드 보임 x −0.44.. y (730−700)/36+0.0083 = 0.8417 z 0.6111
	cc.sync(50.0); cc._process(0.0)
	var node: Node3D = c["node"]; var slot1: Node3D = d1["slot"]; var cn: Node3D = c["card_node"]
	var shut_z := slot1.position.z; var slot_pos := slot1.position; var hidden := not cn.visible
	cc.yank(a, 270.0, z, 1.0, true); cc.sync(50.5); cc._process(0.0); var open_z := slot1.position.z
	var l3 := cc.land(300.0, 724.0, 723.0, z); cc.sync(50.6); cc.yank(l3, 300.0, z, 1.0, true)
	cc.sync(50.9); cc._process(0.0); var shown := cn.visible; var cpos := cn.position
	print("VISUAL node children=%d (want 7) slot children=%d (want 3) card children=%d (want 2) node pos=%.4f %.4f %.4f (want −5.2222 19.4444 −1.9444) slot1=%.4f %.4f %.4f (want 0.6667 0.4167 0.0000) shut z=%.4f (want 0) open z=%.4f (want 1.1111) card hidden=%s (want true) shown=%s (want true) card pos y=%.4f z=%.4f (want 0.8417 0.6111) x=%.3f (want −0.444 ± 0.167 wobble)" % [node.get_child_count(), slot1.get_child_count(), cn.get_child_count(), node.position.x, node.position.y, node.position.z, slot_pos.x, slot_pos.y, slot_pos.z, shut_z, open_z, hidden, shown, cpos.y, cpos.z, cpos.x])
	# 자세(yank_side 1 — 절벽은 local +x, shoulders[1.0] 이 가까운 팔): 뻗기(yank_t 0.12): 어깨 z 1.25/1.10 어깨 x −0.50 팔꿈치 −0.45 엉덩이 −0.10/−0.10 무릎 0.15/0.15 골반 0.39;
	# 당김(0.42): 어깨 z 0.75/0.95 어깨 x −0.35 팔꿈치 −1.80 엉덩이 −0.10/−0.25 무릎 0.30/0.55 엉덩이 z 0.06/−0.10 골반 0.36; 놓기(0.57): 어깨 z 0.25/0.30 팔꿈치 −0.40 엉덩이 z 0.06/−0.32 골반 0.36; 끝(0.9) done
	fig.pose_request = "yank"; fig.set_meta("yank_side", 1.0); fig.set_meta("yank_t", 0.12)
	for i in 90: await process_frame
	var r_sh: float = (fig.shoulders[1.0] as Node3D).rotation.z; var r_shf: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var r_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var r_el: float = (fig.elbows[1.0] as Node3D).rotation.x
	var r_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var r_hipf: float = (fig.hips[-1.0] as Node3D).rotation.x; var r_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var r_pel := fig.pelvis.position.y; var r_done := YankPoses.done(fig)
	fig.set_meta("yank_t", 0.42)
	for i in 90: await process_frame
	var p_sh: float = (fig.shoulders[1.0] as Node3D).rotation.z; var p_shf: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var p_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var p_el: float = (fig.elbows[1.0] as Node3D).rotation.x
	var p_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var p_hipf: float = (fig.hips[-1.0] as Node3D).rotation.x; var p_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var p_kneef: float = (fig.knees[-1.0] as Node3D).rotation.x; var p_hz: float = (fig.hips[1.0] as Node3D).rotation.z; var p_hzf: float = (fig.hips[-1.0] as Node3D).rotation.z; var p_pel := fig.pelvis.position.y
	fig.set_meta("yank_t", 0.57)
	for i in 90: await process_frame
	var d_sh: float = (fig.shoulders[1.0] as Node3D).rotation.z; var d_shf: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var d_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var d_hz: float = (fig.hips[1.0] as Node3D).rotation.z; var d_hzf: float = (fig.hips[-1.0] as Node3D).rotation.z; var d_pel := fig.pelvis.position.y
	var elx: float = (fig.elbows[1.0] as Node3D).global_position.x - (fig.shoulders[1.0] as Node3D).global_position.x
	fig.set_meta("yank_t", 0.9); var e_done := YankPoses.done(fig)
	print("POSE reach: shoulder z=%.3f %.3f (want 1.250 1.100: both arms to the cliff side) x=%.3f (want −0.500) elbow=%.3f (want −0.450) hips=%.3f %.3f (want −0.100 −0.100) knee=%.3f (want 0.150) pelvis=%.3f (want 0.390) done=%s (want false) | pull: shoulder z=%.3f %.3f (want 0.750 0.950) x=%.3f (want −0.350) elbow=%.3f (want −1.800) hips=%.3f %.3f (want −0.100 −0.250: the weight on the back foot) knees=%.3f %.3f (want 0.300 0.550) hip z=%.3f %.3f (want 0.060 −0.100) pelvis=%.3f (want 0.360) | drop: shoulder z=%.3f %.3f (want 0.250 0.300) elbow=%.3f (want −0.400) hip z=%.3f %.3f (want 0.060 −0.320: the half step away) pelvis=%.3f (want 0.360) elbow dx=%.3f (want > 0: the near hand is on the cliff side) | done@0.9=%s (want true)" % [r_sh, r_shf, r_shx, r_el, r_hip, r_hipf, r_knee, r_pel, r_done, p_sh, p_shf, p_shx, p_el, p_hip, p_hipf, p_knee, p_kneef, p_hz, p_hzf, p_pel, d_sh, d_shf, d_el, d_hz, d_hzf, d_pel, elx, e_done])
	# 진짜 탑: 1..60층에 plan 이 찾는 목록함 — 서재 층 10..14, 45..49 중 사다리·덤웨이터·서가·파터노스터·두루마리 선반(taken)이 안 든 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var lp: Array = cl.plan(n, pl); var dp: Array = cd.plan(n, pl); var bp: Array = cs.plan(n, pl, lp + dp); var np: Array = pn.plan(n, pl, lp + dp + bp); var sp: Array = sc.plan(n, pl, lp + dp + bp + np)
		var out2 := cc.plan(n, pl, lp + dp + bp + np + sp)
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f nd %d" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), int(v["nd"])])]); count += out2.size()
	print("TOWER floors=", bands, " cabinets=", count, " (want a subset of 10..14 and 45..49 — one each, never another theme)")
	quit()
