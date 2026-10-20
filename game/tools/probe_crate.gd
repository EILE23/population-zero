extends SceneTree
## 이삿짐 상자 팩 점검(헤드리스): 자료가 읽히나, 옛 홀 층의 150 px 넘는 std 발판 가운데 다음 발판이 가장 높이 오르는 것(2.1, 오름 130)의 틈 반대쪽 끝에만 더미가 서나(통나무가 선 발판·상자에 지름길 판이 든 발판·튀는 발판은 비켜 가 2.2 로, 다른 테마 층(5·10)은 없다),
## 더미 곁의 C 가 맨 위 상자를 들고(busy, lug_t 0, 상자가 몸의 자식, creak) C 없는 몸·먼 x·먼 z·다른 발판·제가 선 더미는 아무것도 아니나(평이 100%), 0.5 s 에 안기로 넘어가나(lug, lug_t 1),
## 안고 걸으면 lug_v 가 속도를 읽나, 앞에 내려놓으면(0.4 s, lug_t 1 → 0) 새 더미가 서고(x 369, 상자가 더미 노드로, thud) 메타가 걷히나, 떨어지는 몸이 더미 꼭대기에 올라서나(land: 1420 과 1440, 먼 z·옆·밑은 아니다),
## 둘째·셋째 상자가 닿은 더미 위에 맞춰 쌓이나(n 2 → 3, 꽉 참: day 0·me_t·판의 줄), 꽉 찬 더미·발판 밖엔 안 놓이나(안은 채), 분필 자리에 도로 놓이나, 공중에 뜨거나 다른 발판에 내려서면 상자가 미끄러져(slip 0.3 s, lug_x, roll) 0.6 s 에 분필 자리로 굴러 돌아오나(thud), 안은 몸이 사라지면(step 끊김 0.25 s) 상자가 굴러 돌아오나,
## 다음 날 다른 몸(tally 거짓)의 꽉 참은 판의 날을 안 바꾸나(0 of 1), 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 세나, 분필 선 넷·상자 셋(각 여섯 조각)·소리 셋이 그려지나, 노드 자리,
## lug 자세가 안고(t 1·v 0) 골반 0.39..0.41·상체 −0.054·어깨 −0.94±0.02/z ∓0.75·팔꿈치 −0.1±0.02·무릎 0.08±0.03 이고, 쪼그려(t 0.5) 골반 0.17·상체 0.315·엉덩이 −1.1·무릎 1.5·어깨 −0.5/z ∓0.1·팔꿈치 −0.15 이고, 걸으며(v 1) 엉덩이가 움직이고, 미끄러져(x 0.5) 어깨 −0.97±0.02/z ∓0.375·상체 0.063 이고, 메타 없이 2.9 에 done 인가,
## 짐꾼(PORTER, run 183): 집(틈 쪽 끝 안 20 px)에서 차례가 오면 가장 먼 더미 곁으로 걸어가 맨 위 상자를 재 보고(heft 0.8 s, 손잡이 높이를 heft_h 로) 같은 step(tally 거짓)·lug 로 들어 분필 자리 곁으로 안고 걸어가 분필 더미 위에 놓나 — 더미가 다 돌아올 때까지 셋, 그 뒤 집으로(day·me_t 는 그대로, 판은 'the porter put 3 back'); 플레이어가 더미 60 px 안이거나 안고 있으면 제 분을 넘기고 걸어가던 중이면 돌아와 플레이어의 더미를 두나; 플레이어가 다 쌓은 2 s 뒤 따라 나르나,
## heft 자세가 숙여(0.15, 높이 0.3) 골반·상체·오른 어깨·왼 어깨 z·엉덩이·무릎·고개가 제 값이고, 당기며(0.4) 팔꿈치가 움직이고, 끄덕이며(0.68) 고개가 더 숙고, 높은 상자(높이 1)엔 덜 숙이고, 메타 없이 0.8 에 done 인가,
## 진짜 탑의 1..70층에서 plan 이 옛 홀 층(1..4, 35..39, 70)에만 더미를 찾나
const C = preload("res://scripts/games/climb.gd")
const DT := 1.0 / 60.0

func _init() -> void:
	var cc := ClimbCrate.new(); root.add_child(cc)
	var cb := ClimbBell.new(); root.add_child(cb)
	var cr := ClimbDoor.new(); root.add_child(cr)
	var cl := ClimbLaundry.new(); root.add_child(cl)
	var dw := ClimbDrawbridge.new(); root.add_child(dw)
	var tp := ClimbTapestry.new(); root.add_child(tp)
	var lg := ClimbLog.new(); root.add_child(lg)
	await process_frame
	print("PACK id=", cc.pack.get("id"), " kind=", cc.kind.size() > 0, " pose=", cc.pack.get("pose"), " themes=", cc.pack.get("themes"), " w=%.0f h=%.0f d=%.0f count=%d min_w=%.0f pile_in=%.0f reach=%.0f lift=%.2f set=%.2f slow=%.2f max=%d tumble=%.1f day=%.0f (want crate true lug [Old hall] 26 20 16 3 150 30 14 0.50 0.40 0.60 3 0.6 600)" % [cc.w(), cc.h(), cc.deck_d(), cc.count(), cc.min_w(), cc.pile_in(), cc.reach(), cc.lift_s(), cc.set_s(), cc.slow(), cc.max_stack(), cc.tumble_s(), cc.day_s()])
	var plats: Array = [
		{ "id": "2.0", "x": 60.0, "y": 1300.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.1", "x": 330.0, "y": 1400.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.2", "x": 80.0, "y": 1530.0, "w": 170.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.3", "x": 360.0, "y": 1640.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.4", "x": 120.0, "y": 1750.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "2.5", "x": 400.0, "y": 1860.0, "w": 140.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "2s", "x": 700.0, "y": 1690.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cc.plan(2, plats)
	var taken := cc.plan(2, plats, [{ "id": "2.L0", "kind": "log", "x": 346.0, "w": 128.0, "y": 1400.0, "y_top": 1416.0 }])   # 통나무가 2.1 에 섰다 — 2.2 로(오름 110 의 둘 중 낮은 것)
	var cut := plats.duplicate(true); cut.append({ "id": "2c", "x": 430.0, "y": 1440.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 })   # 더미 상자에 지름길 판 — 2.2 로
	var cutp := cc.plan(2, cut)
	var spring := plats.duplicate(true); (spring[1] as Dictionary)["kind"] = "spring"   # 튀는 발판 — 2.2 로
	var springp := cc.plan(2, spring)
	var f1 := cc.plan(1, plats); var f5 := cc.plan(5, plats); var f10 := cc.plan(10, plats); var f35 := cc.plan(35, plats)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " a %s b %s dy %.0f dir %.0f px %.0f x %.0f w %.0f y %.0f y_top %.0f z %.0f d %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dy"]), float(v["dir"]), float(v["px"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	var brief := func(v: Dictionary) -> String: return "%s dy %.0f px %.0f" % [String(v["a_id"]), float(v["dy"]), float(v["px"])]
	print("PLAN free=", free.map(show), " (want 1: 2.K0 a 2.1 b 2.2 dy 130 dir −1 px 447 x 424 w 46 y 1400 y_top 1460 z −48 d 16)")
	print("PLAN taken=", taken.map(brief), " cut=", cutp.map(brief), " spring=", springp.map(brief), " (want [2.2 dy 110 px 123] ×3) floors 1/5/10/35=", [f1.size(), f5.size(), f10.size(), f35.size()], " (want 1 0 0 1)")
	var band_root := Node3D.new(); root.add_child(band_root)
	cc.build(band_root, free)
	var s: Dictionary = cc.piles[0]
	var node: Node3D = s["node"]; var pile: Dictionary = (s["stacks"] as Array)[0]
	var c0 := (pile["crates"] as Array)[0] as Node3D
	var pt: ClimbPorter = s["porter"]; pt.next_at = 1e9; pt.seen_me = 1e9   # 짐꾼은 뒤에(PORTER) — 그때까지 집에 선 채 차례도 플레이어의 쌓기도 보지 않는다
	print("VISUAL node=%s (want %s) children=%d (want 11: 4 chalk + 3 crates + 3 sounds + the porter) crate parts=%d (want 6) crate 0/1/2 y=%.3f/%.3f/%.3f (want 0.278 0.833 1.389) pile n=%d id=%s x=%.0f (want 3 2.K0.0 447)" % [node.position, C.to3(447.0, 1400.0, C.PLAYER_Z * C.K), node.get_child_count(), c0.get_child_count(), c0.position.y, ((pile["crates"] as Array)[1] as Node3D).position.y, ((pile["crates"] as Array)[2] as Node3D).position.y, int(pile["n"]), String(pile["id"]), float(pile["x"])])
	var fig := Stick3D.new(); root.add_child(fig)
	var fig2 := Stick3D.new(); root.add_child(fig2)
	await process_frame
	var on: Dictionary = plats[1]; var z := C.PLAYER_Z
	var creak: AudioStreamPlayer3D = s["creak"]; var thud: AudioStreamPlayer3D = s["thud"]; var roll: AudioStreamPlayer3D = s["roll"]
	# 들기(t 10, 몸 420 — 더미 447 곁 27 ≤ 37): busy, lift, lug_t 0, 더미 n 2, 상자가 몸의 자식; C 없음·먼 x·먼 z·다른 발판·제가 선 더미는 아무것도 아니다
	cc.sync(10.0)
	var r0 := cc.step(on, 420.0, z, -1.0, true, DT, fig)
	var top := s["held"] as Node3D
	var l0 := "busy=%s lug=%s sw=%s t=%.1f n=%d held parent is torso=%s holder=%s lugging=%s creak=%s" % [r0["busy"], r0["lug"], String(s["sw"]), float(fig.get_meta("lug_t", 9.0)), int(pile["n"]), top.get_parent() == fig.torso, s["holder"] == fig, cc.lugging(fig), creak.playing]
	var no_c := cc.step(on, 420.0, z, -1.0, false, DT, fig2); var far_x := cc.step(on, 380.0, z, -1.0, true, DT, fig2); var far_z := cc.step(on, 420.0, z + 40.0, -1.0, true, DT, fig2); var other := cc.step(plats[0], 420.0, z, -1.0, true, DT, fig2)
	var on_pile := cc.step({ "kind": "crate", "id": "2.K0.0", "x": 434.0, "y": 1440.0, "w": 26.0, "z": z, "d": 16.0 }, 447.0, z, -1.0, true, DT, fig2)
	var none := func(r: Dictionary) -> bool: return not bool(r["busy"]) and not bool(r["lug"])
	print("LIFT ", l0, " (want true false lift 0.0 2 true true true true) | no C=%s far x=%s far z=%s other hop=%s on the pile=%s n=%d lugging fig2=%s (want true ×5 2 false)" % [none.call(no_c), none.call(far_x), none.call(far_z), none.call(other), none.call(on_pile), int(pile["n"]), cc.lugging(fig2)])
	cc.sync(10.25); var r1 := cc.step(on, 420.0, z, -1.0, false, DT, fig); var p1 := "busy=%s t=%.2f" % [r1["busy"], float(fig.get_meta("lug_t", 9.0))]
	cc.sync(10.52); var r2 := cc.step(on, 420.0, z, -1.0, false, DT, fig); var p2 := "busy=%s lug=%s sw=%s t=%.1f" % [r2["busy"], r2["lug"], String(s["sw"]), float(fig.get_meta("lug_t", 9.0))]
	# 안고 걷기: 틱마다 2.6 px(156 px/s = 0.6 × 260) 왼쪽으로 열 틱 → lug_v 1.0, 394 에 선다
	var xw := 420.0; var vmax := 0.0
	for i in 10:
		xw -= 2.6; cc.sync(cc.t + DT); cc.step(on, xw, z, -1.0, false, DT, fig); vmax = maxf(vmax, float(fig.get_meta("lug_v", 0.0)))
	var r3 := cc.step(on, 394.0, z, -1.0, true, DT, fig)
	var p3 := "busy=%s sw=%s set_x=%.0f set_i=%d" % [r3["busy"], String(s["sw"]), float(s["set_x"]), int(s["set_i"])]
	cc.sync(cc.t + 0.2); var r4 := cc.step(on, 394.0, z, -1.0, false, DT, fig); var p4 := "busy=%s t=%.2f" % [r4["busy"], float(fig.get_meta("lug_t", 9.0))]
	cc.sync(cc.t + 0.22); var r5 := cc.step(on, 394.0, z, -1.0, false, DT, fig)
	var st1: Dictionary = (s["stacks"] as Array)[1]
	var p5 := "busy=%s lug=%s sw='%s' stacks=%d new id=%s x=%.0f n=%d crate parent is node=%s at=%s holder null=%s metas=%s/%s/%s thud=%s" % [r5["busy"], r5["lug"], String(s["sw"]), (s["stacks"] as Array).size(), String(st1["id"]), float(st1["x"]), int(st1["n"]), top.get_parent() == node, top.position, s["holder"] == null, fig.has_meta("lug_t"), fig.has_meta("lug_v"), fig.has_meta("lug_x"), thud.playing]
	print("LUG 0.25 s: %s (want busy=true t=0.50) | 0.52 s: %s (want busy=false lug=true sw=lug t=1.0) | walk v_max=%.2f (want 1.00) | set: %s (want busy=true sw=set set_x=369 set_i=−1) | 0.2 s: %s (want busy=true t=0.50) | 0.42 s: %s (want false false '' 2 2.K0.1 369 1 true (−2.167, 0.278, 0) true false ×3 true)" % [p1, p2, vmax, p3, p4, p5])
	# 디딤: 떨어지는 몸이 더미 꼭대기를 지나면 올라선다 — 새 더미 1420(n 1), 분필 자리 1440(n 2); 먼 z·옆·꼭대기 밑은 아니다
	var ld1 := cc.land(369.0, 1430.0, 1415.0, z); var ld2 := cc.land(447.0, 1450.0, 1435.0, z)
	var ldz := cc.land(369.0, 1430.0, 1415.0, z + 30.0); var ldx := cc.land(300.0, 1430.0, 1415.0, z); var ldu := cc.land(369.0, 1410.0, 1395.0, z)
	print("LAND new=%s %s x=%.0f y=%.0f w=%.0f d=%.0f (want crate 2.K0.1 356 1420 26 16) pile=%s y=%.0f (want 2.K0.0 1440) far z=%s beside=%s under=%s (want true ×3 — empty)" % [String(ld1.get("kind", "-")), String(ld1.get("id", "-")), float(ld1.get("x", 0.0)), float(ld1.get("y", 0.0)), float(ld1.get("w", 0.0)), float(ld1.get("d", 0.0)), String(ld2.get("id", "-")), float(ld2.get("y", 0.0)), ldz.is_empty(), ldx.is_empty(), ldu.is_empty()])
	# 쌓기(t 20): 둘째 상자를 같은 자리에 → 더미 위에 맞춰 n 2; 셋째 → n 3 꽉 참(day 0, me_t, fulls 1, 판의 줄); 분필 자리는 n 0 으로 남는다
	cc.sync(20.0); _move(cc, on, 420.0, 394.0, -1.0, fig)
	var n2 := int(st1["n"]); var y2 := ((st1["crates"] as Array)[1] as Node3D).position.y
	_move(cc, on, 420.0, 394.0, -1.0, fig)
	print("STACK second: n=%d crate y=%.3f (want 2 0.833) | third: n=%d stacks=%d pile n=%d fulls=%d day=%d me_t=%.1f day_fulls=%d (want 3 2 0 1 0 >20 1) note 2=\"%s\" (want 'Removal crates, floors 2–6: 1 of 1 pile stacked 3 high today, 3 of 3 crates off the pile, the porter put 0 back.')" % [n2, y2, int(st1["n"]), (s["stacks"] as Array).size(), int(pile["n"]), int(s["fulls"]), int(s["day"]), float(s["me_t"]), int(s["day_fulls"]), cc.note(2)])
	# 거절(안은 채): 꽉 찬 더미 위(max_stack 을 잠깐 2 로)·발판 밖(340 에서 왼쪽: 302 < 330)은 아무것도 아니다; 분필 자리에 도로 놓인다(430 에서 오른쪽: 455 — 447 의 더미에)
	_lift(cc, on, 394.0, -1.0, fig)   # 더미 꼭대기에서 하나(n 2)
	cc.kind["max_stack"] = 2; var full := cc.step(on, 394.0, z, -1.0, true, DT, fig); var full_sw := String(s["sw"]); cc.kind["max_stack"] = 3
	var out := cc.step(on, 340.0, z, -1.0, true, DT, fig); var out_sw := String(s["sw"])
	var back := cc.step(on, 430.0, z, 1.0, true, DT, fig); var back_i := int(s["set_i"])
	cc.sync(cc.t + 0.42); var rb := cc.step(on, 430.0, z, 1.0, false, DT, fig)
	print("REFUSE full: busy=%s lug=%s sw=%s (want false true lug) | off the hop: busy=%s lug=%s sw=%s (want false true lug) | back on the chalk: busy=%s set_i=%d (want true 0) → pile n=%d stack n=%d off=%d (want 1 2 2) r=%s/%s (want false false)" % [full["busy"], full["lug"], full_sw, out["busy"], out["lug"], out_sw, back["busy"], back_i, int(pile["n"]), int(st1["n"]), int(cc.top_today(2, 2)["off"]), rb["busy"], rb["lug"]])
	# 미끄러짐(t 30): 분필 자리에서 하나 들고(n 0) 공중에 뜨면 — slip 0.3 s(lug_x, lug_t 1), roll, 상자가 더미 노드 아래로 굴러 0.6 s 에 분필 자리에(thud, n 1)
	cc.sync(30.0); fig.position = C.to3(430.0, 1400.0, C.PLAYER_Z * C.K); _lift(cc, on, 430.0, 1.0, fig)   # 몸을 발판 위 430 에 — 상자는 거기서 굴러 돌아온다
	var sl := cc.step({}, 430.0, z, 1.0, false, DT, fig)
	var sl0 := "busy=%s lug=%s sw=%s x=%.1f t=%.1f roll=%s tumbles=%d held null=%s pile n=%d crate parent is node=%s" % [sl["busy"], sl["lug"], String(s["sw"]), float(fig.get_meta("lug_x", 9.0)), float(fig.get_meta("lug_t", 9.0)), roll.playing, (s["tumbles"] as Array).size(), s["held"] == null, int(pile["n"]), top.get_parent() == node]
	var t_sl := cc.t; var x_mid := -1.0; var rel_at := -1.0; var home_at := -1.0; var peak := 0.0
	while cc.t - t_sl < 1.0:
		cc._process(DT); var rr := cc.step({}, 430.0, z, 1.0, false, DT, fig)
		if x_mid < 0.0 and cc.t - t_sl >= 0.15: x_mid = float(fig.get_meta("lug_x", 9.0))
		if rel_at < 0.0 and not bool(rr["lug"]): rel_at = cc.t - t_sl
		if home_at < 0.0 and int(pile["n"]) == 1: home_at = cc.t - t_sl
		if (s["tumbles"] as Array).size() > 0: peak = maxf(peak, (((s["tumbles"] as Array)[0] as Dictionary)["node"] as Node3D).position.y)
	print("SLIP in the air: ", sl0, " (want false true slip 0.0 1.0 true 1 true 0 true) | x at 0.15 s=%.2f (want 0.50..0.56 — the tick after) released at=%.2f s (want 0.30..0.32) metas gone=%s (want true) | home at=%.2f s (want 0.60..0.62) pile n=%d rot=%.2f y=%.3f peak=%.2f thud=%s (want 1 0.00 0.278 0.6..0.8 true — the arc from the hands at 430)" % [x_mid, rel_at, not fig.has_meta("lug_t"), home_at, int(pile["n"]), (((pile["crates"] as Array)[0] as Node3D).rotation.z), (((pile["crates"] as Array)[0] as Node3D).position.y), peak, thud.playing])
	# 다른 발판에 내려서도 미끄러진다; 안은 몸이 step 을 끊으면(0.25 s) 상자가 굴러 돌아온다(sw 는 바로 비고 lugging 은 거짓)
	_lift(cc, on, 430.0, 1.0, fig); var sl2 := cc.step(plats[0], 430.0, z, 1.0, false, DT, fig); var sl2_sw := String(s["sw"])
	for i in 60: cc._process(DT); cc.step(plats[0], 430.0, z, 1.0, false, DT, fig)
	var n_after := int(pile["n"])
	_lift(cc, on, 430.0, 1.0, fig); var t_lost := cc.t; var lost_at := -1.0
	while cc.t - t_lost < 1.0:
		cc._process(DT)
		if lost_at < 0.0 and String(s["sw"]) == "": lost_at = cc.t - t_lost
	print("SLIP on another hop: lug=%s sw=%s (want true slip) → pile n=%d (want 1) | holder gone: released at=%.2f s (want 0.27..0.29) lugging=%s metas=%s pile n=%d slips=%d (want false false 1 3)" % [sl2["lug"], sl2_sw, n_after, lost_at, cc.lugging(fig), fig.has_meta("lug_t"), int(pile["n"]), int(s["slips"])])
	# 다음 날(t 610) 다른 몸(tally 거짓)이 꽉 채운다: fulls 2, day 는 0 그대로 — 판은 0 of 1
	cc.sync(610.0); _move(cc, on, 430.0, 394.0, -1.0, fig2, false)
	print("OTHER next day: stack n=%d fulls=%d day=%d full_day=%d day_fulls=%d (want 3 2 0 1 1) note 2=\"%s\" (want '… 0 of 1 pile stacked 3 high today, 3 of 3 crates off the pile, the porter put 0 back.') | note 1=\"%s\" 7=\"%s\" 20=\"%s\" (want 'floors 1–5: …' / 'floors 2–6: …' / '') children=%d (want 11 — every crate back under the node)" % [int(st1["n"]), int(s["fulls"]), int(s["day"]), int(s["full_day"]), int(s["day_fulls"]), cc.note(2), cc.note(1), cc.note(7), cc.note(20), node.get_child_count()])
	await _pose(fig)
	# 짐꾼(t 700; 369 의 더미에 셋, 분필 자리는 비었다): 집(360)에서 차례가 오면 가장 먼 더미(369) 곁(396)으로 걸어가(36 px, 0.14 s) 재 보고(heft 0.8 s — 손잡이 1.19 m → heft_h 1.0) 같은 step(tally 거짓)으로 들어(0.5 s) 분필 자리 곁(422)으로 안고 걸어가(26 px, 156 px/s, 0.17 s) 내려놓는다(0.4 s) — 세 번(둘째·셋째는 더미가 낮아 heft_h 0.64·0.08), 더미가 다 돌아오면(pile n 3, 369 의 더미는 지운다) 집으로(62 px, 0.24 s); day 0·me_t 는 그대로, 판은 'the porter put 3 back'
	cc.sync(700.0); var day0 := int(s["day"]); var me0 := float(s["me_t"])
	var p0 := "%s x=%.0f home=%.0f lugs=%s" % [pt.phase, pt.x, pt.home_x, cc.lugging(pt.fig)]
	pt.seen_me = me0; pt.next_at = cc.t
	var t0 := cc.t; var at := { "walk": -1.0, "heft": -1.0, "lift": -1.0, "carry": -1.0, "set": -1.0, "back": -1.0, "idle": -1.0 }
	var heft_m := -1.0; var heft_pose := false; var lug_pose := false; var lug_v := 0.0; var lift_s := ""
	while cc.t - t0 < 20.0:
		cc._process(DT)
		if at.has(pt.phase) and float(at[pt.phase]) < 0.0:
			at[pt.phase] = cc.t - t0
			if pt.phase == "lift": lift_s = "sw=%s count=%s holder=%s" % [String(s["sw"]), s["count"], s["holder"] == pt.fig]
		if pt.phase == "heft": heft_m = float(pt.fig.get_meta("heft_t", -1.0)); heft_pose = heft_pose or pt.fig.pose_request == "heft"
		if pt.phase == "carry": lug_pose = lug_pose or pt.fig.pose_request == "lug"; lug_v = maxf(lug_v, float(pt.fig.get_meta("lug_v", 0.0)))
		if pt.phase == "idle" and cc.t - t0 > 1.0: break
	print("PORTER start: ", p0, " (want idle 360 360 false) | walk at %.2f heft at %.2f (want 0.00..0.02 and 0.15..0.18: 36 px at 260) heft_t last=%.3f pose=%s (want 0.78..0.80 true) | lift at %.2f %s (want heft + 0.80..0.82 sw=lift count=false holder=true) carry at %.2f (want lift + 0.50..0.52) lug=%s v=%.2f (want true 1.00) set at %.2f (want carry + 0.17..0.19) | back at %.2f idle at %.2f x=%.0f (want 5.6..6.2, back + 0.24..0.26 360) | trips/puts/skips=%d/%d/%d hefts=%s (want 3 3 0 [1.0, 0.64, 0.08]) pile n=%d stacks=%d off=%d (want 3 1 0) day=%d me_t same=%s (want %d true) note 2=\"%s\" (want '… 0 of 1 pile stacked 3 high today, 0 of 3 crates off the pile, the porter put 3 back.') children=%d (want 11) next=%.1f s (want 60.0)" % [float(at["walk"]), float(at["heft"]), heft_m, heft_pose, float(at["lift"]), lift_s, float(at["carry"]), lug_pose, lug_v, float(at["set"]), float(at["back"]), float(at["idle"]), pt.x, pt.trips, pt.puts, pt.skips, pt.hefts.map(func(v: float) -> float: return snappedf(v, 0.01)), int(pile["n"]), (s["stacks"] as Array).size(), int(cc.top_today(2, 2)["off"]), int(s["day"]), absf(float(s["me_t"]) - me0) < 0.001, day0, cc.note(2), node.get_child_count(), pt.next_at - cc.t])
	# 배려: 플레이어가 분필 자리 60 px 안에 선 틱(C 없는 step 이 near_t 에 적는다)이면 제 분을 넘기고(skips 1), 안고 있으면도 넘기고(skips 2), 걸어가던 중이면 돌아와 플레이어의 더미(369)를 둔다; 67 px 밖은 가깝지 않다
	pt.next_at = cc.t; cc.step(on, 420.0, z, -1.0, false, DT, fig2); cc._process(DT)
	var w1 := "%s skips=%d next=%.1f" % [pt.phase, pt.skips, pt.next_at - cc.t]
	for i in 15: cc._process(DT)   # near_t 가 0.2 s 식는다
	var nt0 := float(s["near_t"]); cc.step(on, 380.0, z, -1.0, false, DT, fig2); var far_near := float(s["near_t"]) == nt0
	_lift(cc, on, 420.0, 1.0, fig2, false); pt.next_at = cc.t; cc._process(DT)   # 플레이어가 안고 있다(near 는 식었다)
	var w2 := "%s skips=%d lugs=%s" % [pt.phase, pt.skips, pt.player_lugs()]
	cc.step(on, 420.0, z, 1.0, true, DT, fig2, false)   # 분필 자리에 도로(445 → 447)
	for i in 30: cc._process(DT); cc.step(on, 420.0, z, 1.0, false, DT, fig2, false)
	_move(cc, on, 420.0, 394.0, -1.0, fig2, false)   # 플레이어의 더미를 369 에 하나
	for i in 15: cc._process(DT)
	pt.next_at = cc.t; cc._process(DT); var w3 := pt.phase
	cc.step(on, 380.0, z, -1.0, false, DT, fig2); cc._process(DT); var w4 := pt.phase
	var t1 := cc.t
	while pt.phase != "idle" and cc.t - t1 < 5.0: cc._process(DT)
	var st369 := (s["stacks"] as Array).size()
	print("PORTER courtesy: you near → %s (want idle skips=1 next=60.0) | 67 px off is not near=%s (want true) | you lug → %s (want idle skips=2 lugs=true) | your minute passes, you gone → %s (want walk) | you step up → %s (want back) → %s x=%.0f at %.2f s (want idle 360 0.02..0.05: one tick out, one tick back) your stack kept=%s (want true: 2 stacks)" % [w1, far_near, w2, w3, w4, pt.phase, pt.x, cc.t - t1, st369 == 2])
	# 플레이어를 따라(t 800): 플레이어(tally 참)가 셋을 369 에 쌓으면(me_t, day 1) 2 s 뒤 걸어가 셋을 되돌린다; day·me_t 는 플레이어의 것 그대로
	for i in 15: cc._process(DT)
	pt.next_at = cc.t; var t2 := cc.t
	while (pt.phase != "idle" or pt.puts < 4) and cc.t - t2 < 10.0: cc._process(DT)   # 369 의 하나를 먼저 되돌린다
	cc.sync(800.0); pt.next_at = 1e9; pt.seen_me = float(s["me_t"])
	for i in 3: _move(cc, on, 420.0, 394.0, -1.0, fig)
	var me5 := float(s["me_t"]); var day5 := int(s["day"]); var idle5 := pt.phase
	while pt.phase == "idle" and cc.t - me5 < 3.0: cc._process(DT)
	var walk5 := cc.t - me5
	while pt.phase != "idle" and cc.t - me5 < 20.0: cc._process(DT)
	print("PORTER follows you: idle while you stack=%s (want idle) me_t=%.2f day=%d (want >800 1) | walks at %.2f s after your third crate (want 2.00..2.02) | after: puts=%d trips=%d (want 7 8 — the courtesy's turned-back walk was a trip) pile n=%d stacks=%d (want 3 1) day=%d me_t same=%s (want 1 true) %s x=%.0f (want idle 360) note 2=\"%s\" (want '… 1 of 1 pile stacked 3 high today, 0 of 3 crates off the pile, the porter put 7 back.')" % [idle5, me5, day5, walk5, pt.puts, pt.trips, int(pile["n"]), (s["stacks"] as Array).size(), int(s["day"]), absf(float(s["me_t"]) - me5) < 0.001, pt.phase, pt.x, cc.note(2)])
	await _heft_pose(fig)
	# 진짜 탑: 1..70층에 plan 이 찾는 더미 — 옛 홀 층 1..4, 35..39, 70 중 종 줄·회전문·빨랫줄·도개교·태피스트리·통나무가 안 쓴 넓은 std 발판이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var bl: Array = cb.plan(n, pl); var dr: Array = cr.plan(n, pl, bl); var ll: Array = cl.plan(n, pl, bl + dr); var db: Array = dw.plan(n, pl, bl + dr + ll)
		var out2 := cc.plan(n, pl, bl + dr + ll + db + tp.plan(n, pl, bl + dr + ll + db, gm.wind_of(n)) + lg.plan(n, pl, bl + dr))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s dy %.0f px %.0f" % [String(v["a_id"]), float(v["dy"]), float(v["px"])])])
	print("TOWER floors=", bands, " (want a subset of 1..4, 35..39 and 70 — one pile each on the free std hop under the biggest rise, never another theme)")
	quit()

## 더미 곁 x0 에서 들고(0.5 s) x1 로 걸어가(틱마다 2.6 px) face 쪽에 내려놓는다(0.4 s) — 한 상자의 한 길
func _move(cc: ClimbCrate, on: Dictionary, x0: float, x1: float, face: float, fig: Stick3D, tally := true) -> void:
	_lift(cc, on, x0, face, fig, tally)
	var xw := x0
	while absf(xw - x1) > 0.01:
		xw = move_toward(xw, x1, 2.6); cc.sync(cc.t + DT); cc.step(on, xw, C.PLAYER_Z, face, false, DT, fig, tally)
	cc.step(on, x1, C.PLAYER_Z, face, true, DT, fig, tally)
	var t0 := cc.t
	while cc.t - t0 < 0.45:
		cc.sync(cc.t + DT); cc.step(on, x1, C.PLAYER_Z, face, false, DT, fig, tally)

## 더미 곁 x 에서 들고 0.5 s 기다린다 — 안은 채
func _lift(cc: ClimbCrate, on: Dictionary, x: float, face: float, fig: Stick3D, tally := true) -> void:
	cc.step(on, x, C.PLAYER_Z, face, true, DT, fig, tally)
	var t0 := cc.t
	while cc.t - t0 < 0.55:
		cc.sync(cc.t + DT); cc.step(on, x, C.PLAYER_Z, face, false, DT, fig, tally)

## lug 자세(메타로 세운다) — 안고(t 1·v 0), 쪼그려(t 0.5), 걸으며(v 1, 두 틱 떨어져 엉덩이가 움직이나), 미끄러져(x 0.5); 메타 없이 2.9 에 done
func _pose(fig: Stick3D) -> void:
	fig.pose_request = "lug"; fig.set_meta("lug_t", 1.0); fig.set_meta("lug_v", 0.0); fig.set_meta("lug_x", 0.0)
	for i in 45: await process_frame
	var r_sh: Node3D = fig.shoulders[1.0]; var l_sh: Node3D = fig.shoulders[-1.0]; var r_el: Node3D = fig.elbows[1.0]
	var r_hip: Node3D = fig.hips[1.0]; var r_knee: Node3D = fig.knees[1.0]
	var a := "pelvis=%.3f torso=%.4f shoulder=%.2f z=%.2f/%.2f elbow=%.2f hip=%.2f knee=%.2f neck=%.2f" % [fig.pelvis.position.y, fig.torso.rotation.x, r_sh.rotation.x, r_sh.rotation.z, l_sh.rotation.z, r_el.rotation.x, r_hip.rotation.x, r_knee.rotation.x, fig.neck.rotation.x]
	fig.set_meta("lug_t", 0.5)
	for i in 45: await process_frame
	var b := "pelvis=%.2f torso=%.3f hip=%.2f knee=%.2f shoulder=%.2f z=%.2f/%.2f elbow=%.2f neck=%.2f" % [fig.pelvis.position.y, fig.torso.rotation.x, r_hip.rotation.x, r_knee.rotation.x, r_sh.rotation.x, r_sh.rotation.z, l_sh.rotation.z, r_el.rotation.x, fig.neck.rotation.x]
	fig.set_meta("lug_t", 1.0); fig.set_meta("lug_v", 1.0)
	for i in 45: await process_frame
	var h1 := r_hip.rotation.x
	for i in 3: await process_frame
	var c := "hip=%.2f→%.2f moves=%s knee=%.2f" % [h1, r_hip.rotation.x, absf(r_hip.rotation.x - h1) > 0.01, r_knee.rotation.x]
	fig.set_meta("lug_v", 0.0); fig.set_meta("lug_x", 0.5)
	for i in 45: await process_frame
	var d := "shoulder=%.2f z=%.2f/%.2f torso=%.3f elbow=%.2f" % [r_sh.rotation.x, r_sh.rotation.z, l_sh.rotation.z, fig.torso.rotation.x, r_el.rotation.x]
	for key: String in ["lug_t", "lug_v", "lug_x"]: fig.remove_meta(key)
	fig.pose_t = LugPoses.LAP - 0.01; var before := LugPoses.done(fig)
	fig.pose_t = LugPoses.LAP + 0.001; var after := LugPoses.done(fig)
	print("LUG pose hold: ", a, " (want 0.39..0.41 −0.054 −0.94±0.02 −0.75/0.75 −0.10±0.02 0.00 0.08±0.03 <0.1) | squat: ", b, " (want 0.17 0.315 −1.10 1.50 −0.50 −0.10/0.10 −0.15 >0) | walk: ", c, " (want true) | slip 0.5: ", d, " (want −0.97±0.02 −0.375/0.375 0.063 −0.05±0.02) | done(2.89 → 2.901)=%s LAP=%.1f (want true 2.9)" % [(not before) and after, LugPoses.LAP])
	fig.pose_request = ""

## heft 자세(메타로 세운다) — 숙여(0.15, 높이 0.3), 당기며(0.4 — 두 틱 떨어져 팔꿈치가 움직이나), 끄덕이며(0.68 — 고개가 더 숙나), 높은 상자(높이 1)엔 덜 숙이나; 메타 없이 0.8 에 done
func _heft_pose(fig: Stick3D) -> void:
	fig.pose_request = "heft"; fig.set_meta("heft_t", 0.15); fig.set_meta("heft_h", 0.3)
	for i in 45: await process_frame
	var r_sh: Node3D = fig.shoulders[1.0]; var l_sh: Node3D = fig.shoulders[-1.0]; var r_el: Node3D = fig.elbows[1.0]; var l_el: Node3D = fig.elbows[-1.0]
	var r_hip: Node3D = fig.hips[1.0]; var r_knee: Node3D = fig.knees[1.0]
	var a := "pelvis=%.4f torso=%.3f shoulder=%.2f elbow=%.2f | left z=%.2f elbow=%.2f | hip=%.2f knee=%.2f neck=%.2f" % [fig.pelvis.position.y, fig.torso.rotation.x, r_sh.rotation.x, r_el.rotation.x, l_sh.rotation.z, l_el.rotation.x, r_hip.rotation.x, r_knee.rotation.x, fig.neck.rotation.x]
	var neck_bend := fig.neck.rotation.x
	fig.set_meta("heft_t", 0.4)
	for i in 45: await process_frame
	var e1 := r_el.rotation.x
	for i in 3: await process_frame
	var b := "elbow=%.2f→%.2f moves=%s torso=%.3f" % [e1, r_el.rotation.x, absf(r_el.rotation.x - e1) > 0.01, fig.torso.rotation.x]
	fig.set_meta("heft_t", 0.68)
	for i in 45: await process_frame
	var c := "neck=%.2f deeper=%s torso=%.3f" % [fig.neck.rotation.x, fig.neck.rotation.x > neck_bend + 0.05, fig.torso.rotation.x]
	fig.set_meta("heft_t", 0.15); fig.set_meta("heft_h", 1.0)
	for i in 45: await process_frame
	var d := "torso=%.3f shoulder=%.2f pelvis=%.4f" % [fig.torso.rotation.x, r_sh.rotation.x, fig.pelvis.position.y]
	for key: String in ["heft_t", "heft_h"]: fig.remove_meta(key)
	fig.pose_t = HeftPoses.TOTAL - 0.01; var before := HeftPoses.done(fig)
	fig.pose_t = HeftPoses.TOTAL + 0.001; var after := HeftPoses.done(fig)
	print("HEFT pose bend 0.15: ", a, " (want 0.3425 0.314 −0.74 −0.20 | 0.45 −1.30 | −0.27 0.39 ≈−0.11: 0.38 over the base −(torso + chest)·0.7) | pull 0.4: ", b, " (want true 0.27..0.32) | nod 0.68: ", c, " (want true, torso under 0.314) | high crate: ", d, " (want 0.101 −1.30 0.3950) | done(0.79 → 0.801)=%s TOTAL=%.1f (want true 0.8)" % [(not before) and after, HeftPoses.TOTAL])
	fig.pose_request = ""
