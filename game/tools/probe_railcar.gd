extends SceneTree
## 톱니 궤도차 팩 점검(헤드리스): 자료가 읽히나, 태엽 층의 잇단 두 발판 중 틈 60..260·오름 60..160 이고 상자가 비고 taken 이 없는 가장 넓은 틈에만 궤도가 서나(풀무가 선 틈은 비켜 가고, 상자에 지름길 판이 든 틈도 비켜 가고, 위가 튀는 발판이면 비켜 가고, 오름이 160 을 넘는 틈도 비켜 가고, 바람구멍 층(15·19·51)과 다른 테마 층(20)은 없다),
## 아랫역 곁의 C 가 차에 올리고(안장 사전, mount, pedal_m 0, riding 1) C 없는 몸·먼 x·먼 z·다른 발판·남이 탄 차는 아무것도 아니나(평이 100%), 0.45 s 에 타기로 넘어가나, (띠가 깔린 발판에도 역이 서나)
## C 를 쥐면 0.6 s 에 70 px/s 가 되어 223 px 궤도를 약 3.5 s 에 오르며 톱니 18 개가 딸깍이고(clicks — 소리의 playing 은 틱을 안 돌리는 점검에선 안 꺼진다) 꼭대기에서 걸어(clack, day 0, rides 1, me_t) 0.45 s 에 b 로 내려서나(off, x 416, y 10030, 메타 없음, riding 0),
## 빈 차는 3 s 기다렸다 굴러 내려와 약 5.3 s 에 바닥에 멎나(bump), 그동안 아랫역 곁 C 는 아무것도 아니나, 다시 오른 몸이 1.5 s 밟고 놓으면 0.82 s 에 걸쳐 늦춰져 다리가 멎은 채(0.5 s 에 pedal_k 0·pedal_b 0.36, 각은 그 뒤 그대로) 1.45 s 에 굴러 내려와 멎고 C 를 1 s 놓으면 a 로 내려서나(x 194, y 9920),
## 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 세나, 다음 날 다른 몸(count 거짓)의 꼭대기는 세지 않나(0 of 1, 1 ride), 궤도(봉·톱니 18·받침 둘·역판 둘·멈춤쇠)·차(틀·바퀴·안장·손잡이·크랭크)·소리 셋이 그려지나, 노드 자리, 꼭대기의 차 자리,
## pedal 자세가 앉아(m 1·k 1·a 0) 오른 엉덩이 −1.686·무릎 1.679·왼 엉덩이 −0.929·무릎 0.712·골반 0.31..0.33·상체 0.2025·어깨 −0.95±0.02/z ∓0.12·팔꿈치 −0.35·고개 < −0.5 이고, 버티며(b 1·k 0) 상체 0.045·팔꿈치 −0.85·어깨 −1.05±0.02 이고, 반쯤 올라(m 0.5) 넘기는 다리 −1.743/2.040·다른 다리 −0.465/0.356·골반 0.37 이고, 메타 없이 3.9 에 done 인가,
## 진짜 탑의 1..70층에서 plan 이 태엽 층(16·17·18, 50·52·53·54)에만 궤도를 찾나
## 선로지기(LINESMAN, run 181): 집(아랫역 뒤 40 px)에서 차례가 오면 역 곁으로 걸어가 바짓단을 집고(clip 1.0 s) 같은 mount(count 거짓)·pedal 로 쉬지 않고 꼭대기까지 올라 윗역에 내려서고, 차가 3 s 뒤 굴러가기 시작하면 틈 끝으로 걸어가 맞춘 뜀으로 역 곁에 내려 집으로 걷나(day·me_t 는 그대로 — 판은 0 of 1, 2 rides), 플레이어가 역 60 px 안이면 제 분을 넘기고 걸어가던 중이면 돌아오나, 플레이어가 꼭대기에 닿은 1.5 s 뒤 따라가 차를 기다려 타나,
## clip 자세가 숙여(0.25) 상체 0.4275·오른팔 −0.55/z −0.1/팔꿈치 −0.25±0.05·왼팔 0.35/−0.2·엉덩이 −0.35·무릎 0.45·골반 0.36·고개 +0.55 이고, 털며(0.55) 상체 0.2025·오른 엉덩이 −0.5·무릎 0.6±0.25 가 흔들리고·골반 0.40 이고, 끝(1.0)에 다 0 이고 done 인가
const C = preload("res://scripts/games/climb.gd")
const DT := 1.0 / 60.0

func _init() -> void:
	var cr := ClimbRailcar.new(); root.add_child(cr)
	var cg := ClimbGears.new(); root.add_child(cg)
	var cpn := ClimbPendulum.new(); root.add_child(cpn)
	var pk := ClimbPerch.new(); root.add_child(pk)
	var cl := ClimbBellows.new(); root.add_child(cl)
	var ew := ClimbEscape.new(); root.add_child(ew)
	var cw := ClimbWeight.new(); root.add_child(cw)
	await process_frame
	print("PACK id=", cr.pack.get("id"), " kind=", cr.kind.size() > 0, " pose=", cr.pack.get("pose"), " themes=", cr.pack.get("themes"), " gap=%.0f..%.0f dy=%.0f..%.0f grade=%.1f dock=%.0f reach=%.0f ride_dy=%.0f v_up=%.0f spin=%.1f v_back=%.0f roll=%.1f tooth=%.0f mount=%.2f off=%.2f idle=%.1f hold=%.0f step=%.0f deck=%.0f day=%.0f cad=%.1f (want railcar true pedal [Clockwork] 60..260 60..160 1.6 22 14 8 70 0.6 110 0.5 12 0.45 0.45 1.0 3 14 28 600 1.4)" % [cr.min_gap(), cr.max_gap(), cr.min_dy(), cr.max_dy(), cr.grade_max(), cr.dock_in(), cr.reach(), cr.ride_dy(), cr.v_up(), cr.spin_s(), cr.v_back(), cr.roll_s(), cr.tooth(), cr.mount_s(), cr.off_s(), cr.idle_s(), cr.hold_s(), cr.step_out(), cr.deck_d(), cr.day_s(), cr.cad_hz()])
	var plats: Array = [
		{ "id": "16.0", "x": 60.0, "y": 9700.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.1", "x": 320.0, "y": 9810.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.2", "x": 100.0, "y": 9920.0, "w": 130.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "16.3", "x": 380.0, "y": 10030.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.4", "x": 150.0, "y": 10140.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.5", "x": 450.0, "y": 10250.0, "w": 130.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16s", "x": 700.0, "y": 10190.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cr.plan(16, plats)
	var taken := cr.plan(16, plats, [{ "id": "16.B0", "kind": "bellows", "x": 230.0, "w": 160.0, "y": 9920.0 }])   # 풀무가 16.2→16.3 의 틈에 섰다 — 16.4→16.5 로(조각의 몸은 9900..9980 — 위 짝의 상자엔 안 닿는다)
	var belted := cr.plan(16, plats, [{ "id": "16.g0", "kind": "gears", "x": 100.0, "w": 130.0, "y": 9920.0 }, { "id": "16.g1", "kind": "gears", "x": 380.0, "w": 120.0, "y": 10030.0 }])   # 띠가 16.2 와 16.3 에 깔렸다 — 그래도 16.2→16.3(역이 띠 위에 선다)
	var cut := plats.duplicate(true); cut.append({ "id": "16c", "x": 300.0, "y": 10000.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 })   # 상자에 지름길 판 — 16.4→16.5 로
	var cutp := cr.plan(16, cut)
	var spring := plats.duplicate(true); (spring[3] as Dictionary)["kind"] = "spring"   # 위가 튀는 발판 — 16.4→16.5 로
	var springp := cr.plan(16, spring)
	var steep := plats.duplicate(true); (steep[3] as Dictionary)["y"] = 10090.0   # 오름 170 — 16.3→16.4 는 60 이라 틈 70 의 짝으로; 가장 넓은 건 16.4→16.5
	var steepp := cr.plan(16, steep)
	var f15 := cr.plan(15, plats); var f19 := cr.plan(19, plats); var f20 := cr.plan(20, plats); var f50 := cr.plan(50, plats); var f51 := cr.plan(51, plats)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " %s→%s dir %.0f gap %.0f dy %.0f x0 %.0f x1 %.0f run %.0f len %.1f grade %.3f x %.0f w %.0f y %.0f y_top %.0f z %.0f d %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["dy"]), float(v["x0"]), float(v["x1"]), float(v["run"]), float(v["rail_len"]), float(v["grade"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	var brief := func(v: Dictionary) -> String: return "%s→%s gap %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"])]
	print("PLAN free=", free.map(show), " (want 1: 16.R0 16.2→16.3 dir 1 gap 150 dy 110 x0 208 x1 402 run 194 len 223.0 grade 0.567 x 198 w 214 y 9920 y_top 10030 z −48 d 28)")
	print("PLAN taken=", taken.map(brief), " cut=", cutp.map(brief), " spring=", springp.map(brief), " steep=", steepp.map(brief), " (want [16.4→16.5 gap 140] ×4) belted=", belted.map(brief), " (want [16.2→16.3 gap 150]) floors 15/19/20/50/51=", [f15.size(), f19.size(), f20.size(), f50.size(), f51.size()], " (want 0 0 0 1 0)")
	var band_root := Node3D.new(); root.add_child(band_root)
	cr.build(band_root, free)
	var s: Dictionary = cr.cars[0]
	var lm: ClimbLinesman = s["linesman"]; lm.phase = "gone"; lm.next_at = 1e9   # 선로지기는 뒤에(LINESMAN) — 그때까지 층을 떠나 있다(차례가 오면 위 want 가 어긋난다)
	var fig := Stick3D.new(); root.add_child(fig)
	var fig2 := Stick3D.new(); root.add_child(fig2)
	var on: Dictionary = plats[2]; var z := C.PLAYER_Z
	var clack: AudioStreamPlayer3D = s["clack"]; var bump: AudioStreamPlayer3D = s["bump"]
	# 오름(t 10, 몸 228 — 아랫역 208 곁): 안장 사전, mount, pedal_m 0, riding 1; C 없음·먼 x·먼 z·다른 발판·남이 탄 차는 빈 사전
	cr.sync(10.0)
	var seat := cr.mount(on, 228.0, z, true, fig)
	var m_state := "%s/%.1f/%.0f/%s" % [String(s["sw"]), float(fig.get_meta("pedal_m", 9.0)), cr.riding(fig), s["rider"] == fig]
	var no_c := cr.mount(on, 228.0, z, false, fig2); var far_x := cr.mount(on, 260.0, z, true, fig2); var far_z := cr.mount(on, 228.0, z + 40.0, true, fig2); var other := cr.mount(plats[3], 228.0, z, true, fig2); var busy := cr.mount(on, 228.0, z, true, fig2)
	print("MOUNT seat=%s x=%.0f w=%.0f y=%.0f z=%.0f d=%.0f (want 16.R0.c 192 32 9928 −48 28) sw/m/riding/rider=%s (want mount/0.0/1/true) | no C=%s far x=%s far z=%s other hop=%s taken=%s (want true ×5 — empty)" % [String(seat.get("id", "-")), float(seat.get("x", 0.0)), float(seat.get("w", 0.0)), float(seat.get("y", 0.0)), float(seat.get("z", 0.0)), float(seat.get("d", 0.0)), m_state, no_c.is_empty(), far_x.is_empty(), far_z.is_empty(), other.is_empty(), busy.is_empty()])
	cr.sync(10.2); var r1 := cr.stand(seat, false, DT, fig); var p1 := "%s m=%.3f x=%.0f y=%.0f off=%s busy=%s" % [String(s["sw"]), float(fig.get_meta("pedal_m", 9.0)), float(r1["x"]), float(r1["y"]), r1["off"], r1["busy"]]
	cr.sync(10.46); cr.stand(seat, false, DT, fig); var p2 := "%s m=%.1f" % [String(s["sw"]), float(fig.get_meta("pedal_m", 9.0))]
	# 밟는다(t 10.46 부터 C 쥐고): 0.6 s 에 70 px/s, 톱니 18, 꼭대기에서 clack·day 0·rides 1·me_t, off 로; 0.45 s 뒤 내려선다
	var clicks0 := int(s["clicks"]); var ride := _ride(cr, seat, fig, true, 6.0, "off")
	var p3 := "%s at=%.2f s v=%.0f u=%.2f ticks=%d clack=%s day=%d rides=%d day_rides=%d me_t=%.2f top=%s k=%.2f" % [String(s["sw"]), float(ride["secs"]), float(ride["v_max"]), float(s["u"]), int(s["clicks"]) - clicks0, clack.playing, int(s["day"]), int(s["rides"]), int(s["day_rides"]), float(s["me_t"]), s["top"], float(fig.get_meta("pedal_k", 9.0))]
	cr.sync(cr.t + 0.2); var r4 := cr.stand(seat, false, DT, fig); var p4 := "m=%.3f off=%s x=%.0f y=%.0f" % [float(fig.get_meta("pedal_m", 9.0)), r4["off"], float(r4["x"]), float(r4["y"])]
	cr.sync(cr.t + 0.26); var r5 := cr.stand(seat, false, DT, fig); var p5 := "off=%s x=%.0f y=%.0f sw='%s' rider=%s u=%.0f metas=%s/%s/%s/%s riding=%.0f" % [r5["off"], float(r5["x"]), float(r5["y"]), String(s["sw"]), s["rider"] == null, float(s["u"]), fig.has_meta("pedal_m"), fig.has_meta("pedal_k"), fig.has_meta("pedal_a"), fig.has_meta("pedal_b"), cr.riding(fig)]
	print("RIDE 0.2 s: %s (want mount m=0.444 x=208 y=9928 off=false busy=true) | 0.46 s: %s (want ride m=1.0) | top: %s (want off at=3.4..3.6 v=70 u=1.00 ticks=18 clack=true day=0 rides=1 day_rides=1 me_t>0 top=true k=0.00 — the latch zeroes the speed before the meta) | off 0.2: %s (want m=0.556 off=false x=402 y=10038) | off 0.46: %s (want off=true x=416 y=10030 sw='' rider=true u=1 metas=false ×4 riding=0)" % [p1, p2, p3, p4, p5])
	# 빈 차(꼭대기): 3 s 기다렸다 굴러 내려와 약 5.3 s 에 바닥(bump); 그동안 아랫역 곁 C 는 아무것도 아니다
	var away := cr.mount(on, 228.0, z, true, fig)
	var t_ret := cr.t; var held := 0.0; var clicks1 := int(s["clicks"])
	while float(s["u"]) > 0.0 and cr.t - t_ret < 12.0:
		cr._process(DT)
		if float(s["u"]) >= 1.0: held = cr.t - t_ret
	var note1 := cr.note(16)
	print("RETURN away mount=%s (want true — empty) held=%.2f s (want 2.95..3.05) home at=%.2f s (want 5.2..5.4) u=%.0f v=%.0f bump=%s ticks=%d (want 0 0 true 18..19 — the ride left 7 px in the tooth count) | note 16=\"%s\" 15=\"%s\" 21=\"%s\" 30=\"%s\" (want 'Rack cars, floors 16–20: 1 of 1 car ridden to the top today, 1 ride today.' / 'floors 15–19: …' / 'floors 16–20: …' / '')" % [away.is_empty(), held, cr.t - t_ret, float(s["u"]), float(s["v"]), bump.playing, int(s["clicks"]) - clicks1, note1, cr.note(15), cr.note(21), cr.note(30)])
	# 자유바퀴(t 30): 1.5 s 밟고 놓는다 — 70 에서 −110 까지 0.82 s 에 늦춰지며(그동안 11 px 더 올랐다 내려온다 — 크랭크는 v > 0 인 0.32 s 더 돈다) 0.5 s 엔 v −40(k 0, b 0.36)이고 각은 그 뒤 그대로, 86 px 를 1.45 s 에 굴러 내려와 멎고(bump), C 를 1 s 놓으면 a 로 내려선다(194, 9920)
	cr.sync(30.0); var seat2 := cr.mount(on, 228.0, z, true, fig)
	_ride(cr, seat2, fig, false, 0.46, "ride")
	var up := _ride(cr, seat2, fig, true, 1.5, "")
	var ang0 := float(s["ang"]); var u0 := float(s["u"])
	var down := _ride(cr, seat2, fig, false, 3.0, "stop")
	var c1 := "u=%.3f ang=%.2f (want 0.37..0.39 >6) | coasting 0.5 s: k=%.2f b=%.2f ang=%.2f then same=%s | stopped at=%.2f s u=%.0f bump=%s (want 0.00 0.35..0.42 ang0+0.1..0.4 true 1.40..1.50 0 true)" % [u0, ang0, float(down["k_mid"]), float(down["b_mid"]), float(down["ang_mid"]), absf(float(s["ang"]) - float(down["ang_mid"])) < 0.001, float(down["secs"]), float(s["u"]), bump.playing]
	var idle := _ride(cr, seat2, fig, false, 1.0, "off")
	var r6 := _ride(cr, seat2, fig, false, 0.46, "gone")
	var c2 := "idle→off at=%.2f s (want 1.00..1.02) | stepped off=%s x=%.0f y=%.0f rider=%s u=%.0f (want true 194 9920 true 0)" % [float(idle["secs"]), (r6["last"] as Dictionary)["off"], float((r6["last"] as Dictionary)["x"]), float((r6["last"] as Dictionary)["y"]), s["rider"] == null, float(s["u"])]
	print("COAST up 1.5 s: ", c1, " | ", c2, " | rides=%d (want 1 — a coast is not a top)" % int(s["rides"]), " up v_max=%.0f (want 70)" % float(up["v_max"]))
	# 다음 날(t 610) 다른 몸(count 거짓)이 꼭대기까지: rides 2, day 는 0 그대로 — 판은 0 of 1, 1 ride
	cr.sync(610.0); var seat3 := cr.mount(on, 228.0, z, true, fig2, false)
	_ride(cr, seat3, fig2, true, 0.46, "ride"); _ride(cr, seat3, fig2, true, 6.0, "off"); _ride(cr, seat3, fig2, false, 0.5, "gone")
	print("OTHER next day: rides=%d day=%d ride_day=%d day_rides=%d (want 2 0 1 1) note 16=\"%s\" (want '… 0 of 1 car ridden to the top today, 1 ride today.')" % [int(s["rides"]), int(s["day"]), int(s["ride_day"]), int(s["day_rides"]), cr.note(16)])
	# 그림: 노드 자리, 궤도(봉 + 톱니 18)·받침 둘·역판 둘·멈춤쇠·차·소리 셋, 차(틀·바퀴·기둥·안장·기둥·손잡이·크랭크)·바퀴(원판 + 살 6)·크랭크(팔 둘·페달 둘), 꼭대기의 차 자리
	var node: Node3D = s["node"]; var car: Node3D = s["car"]; var cog: Node3D = s["cog"]; var cranks: Node3D = s["cranks"]; var rail: Node3D = node.get_child(0)
	cr._process(0.0)
	print("VISUAL node=%s (want %s) children=%d (want 11 — the linesman) rail parts=%d (want 19) car parts=%d (want 7) cog parts=%d (want 7) crank parts=%d (want 4) car at top=%s (want (5.389, 3.056, 0)) cog turn=%.2f (want −51.6)" % [node.position, C.to3(208.0, 9920.0, C.PLAYER_Z * C.K), node.get_child_count(), rail.get_child_count(), car.get_child_count(), cog.get_child_count(), cranks.get_child_count(), car.position, cog.rotation.z])
	await _pose(fig)
	# 선로지기(t 700, 차는 집에): 집(168)에서 차례가 오면 역 곁(192)으로 걸어가(0.09 s) 바로 바짓단을 집고(clip 1.0 s) 같은 mount(count 거짓, pedal_m 0)·pedal 로 쉬지 않고 꼭대기까지(0.45 + 0.6 + 202/70 ≈ 3.9 s) 올라 윗역(416)에 내려서고(pause), 차가 3 s 뒤 굴러가기 시작하면 틈 끝(376)으로 걸어가(0.15 s) 맞춘 뜀(vy 676 → 웅크림 0.40 s, vx −270, 0.68 s)으로 역 곁(≈192)에 내려 집(168)으로 걷는다; day 0·me_t 는 그대로(판은 0 of 1, 2 rides)
	while float(s["u"]) > 0.0: cr._process(DT)   # fig2 가 두고 간 차를 먼저 집으로
	cr.sync(700.0); var day0 := int(s["day"]); var me0 := float(s["me_t"]); var rides0 := int(s["rides"])
	lm._home(); var l0 := "%s x=%.0f y=%.0f home=%.0f dock=%.0f jump=%.0f" % [lm.phase, lm.x, lm.y, lm.home_x, lm.dock_x, lm.jump_x]
	var t0 := cr.t; var at := { "wait": -1.0, "clip": -1.0, "ride": -1.0, "pause": -1.0, "step": -1.0, "down": -1.0, "back": -1.0, "idle": -1.0 }
	var clip_m := -1.0; var mnt := ""; var top_x := 0.0; var jv := Vector2.ZERO; var ch := -1.0; var pedal_on := false
	while cr.t - t0 < 30.0:
		cr._process(DT)
		if at.has(lm.phase) and float(at[lm.phase]) < 0.0:
			at[lm.phase] = cr.t - t0
			if lm.phase == "ride": mnt = "m=%.1f count=%s rider=%s riding=%.0f" % [float(lm.fig.get_meta("pedal_m", 9.0)), s["count"], s["rider"] == lm.fig, cr.riding(lm.fig)]
			if lm.phase == "pause": top_x = lm.x
			if lm.phase == "down": jv = lm.jump; ch = lm.charge_s
		if lm.phase == "clip": clip_m = float(lm.fig.get_meta("clip_t", -1.0))
		if lm.phase == "ride" and cr.t - t0 > 2.0 and not pedal_on: pedal_on = lm.fig.pose_request == "pedal"
		if lm.phase == "idle" and cr.t - t0 > 1.0: break
	print("LINESMAN start: ", l0, " (want idle 168 9920 168 192 376) | wait at %.2f clip at %.2f (want 0.10..0.13 and the tick after: wait sees the car home) clip_t last=%.3f (want 0.98..1.00) | ride at %.2f (want 1.10..1.13) %s (want m=0.0 count=false rider=true riding=1) pedal=%s (want true) | top at %.2f x=%.0f (want 5.4..5.6 416) step at %.2f (want top + 3.0..3.1) down at %.2f (want step + 0.55..0.58: 0.15 walk + 0.40 crouch) jump=(%.0f, %.0f) charge=%.2f (want (−270, 676) 0.40) | landed at %.2f x=%.1f y=%.0f (want down + 0.68..0.70 ≈192 ±5 9920) home at %.2f x=%.0f (want landed + 0.09..0.11 168) | rides/tops/drops/falls=%d/%d/%d/%d (want 1 1 1 0) car rides=%d (want %d + 1) day=%d me_t same=%s (want %d true) note=\"%s\" (want '… 0 of 1 car ridden to the top today, 2 rides today.') next=%.1f s (want 60.0)" % [float(at["wait"]), float(at["clip"]), clip_m, float(at["ride"]), mnt, pedal_on, float(at["pause"]), top_x, float(at["step"]), float(at["down"]), jv.x, jv.y, ch, float(at["back"]), lm.at_land.x, lm.at_land.y, float(at["idle"]), lm.x, lm.rides, lm.tops, lm.drops, lm.falls, int(s["rides"]), rides0, int(s["day"]), absf(float(s["me_t"]) - me0) < 0.001, day0, cr.note(16), lm.next_at - cr.t])
	# 배려: 플레이어가 역 60 px 안에 선 틱(C 없는 mount 가 near_t 에 적는다)이면 집에서 제 분을 넘기고(skips), 걸어가던 중이면 돌아온다; 82 px 밖은 가깝지 않다
	lm.next_at = cr.t; cr.mount(on, 240.0, z, false, fig2); cr._process(DT)
	var w1 := "%s skips=%d next=%.1f" % [lm.phase, lm.skips, lm.next_at - cr.t]
	for i in 15: cr._process(DT)   # near_t 가 0.2 s 식는다
	var nt0 := float(s["near_t"]); cr.mount(on, 290.0, z, false, fig2); var far_near := float(s["near_t"]) == nt0
	lm.next_at = cr.t; cr._process(DT); var w2 := lm.phase
	cr.mount(on, 240.0, z, false, fig2); cr._process(DT); var w3 := lm.phase
	var t1 := cr.t
	while lm.phase != "idle" and cr.t - t1 < 5.0: cr._process(DT)
	print("LINESMAN courtesy: you near → %s (want idle skips=1 next=60.0) | 82 px off is not near=%s (want true) | your minute passes, you gone → %s (want walk) | you step up → %s (want back) → %s x=%.0f at %.2f s (want idle 168 0.02..0.05: one tick out, one tick back)" % [w1, far_near, w2, w3, lm.phase, lm.x, cr.t - t1])
	# 플레이어를 따라(t 800): 플레이어가 꼭대기에 닿은(me_t, day 1) 1.5 s 뒤 역으로 가 차가 돌아오길 기다려(내려섬 0.45 + 기다림 3 + 굴러옴 ≈2.3) 타고, 다 돈 뒤 day·me_t 는 플레이어의 것 그대로
	while float(s["u"]) > 0.0: cr._process(DT)   # 선로지기가 두고 간 차를 먼저 집으로(굴러오는 데 2.3 s — 집에 걸어 돌아온 뒤에도 구른다)
	cr.sync(800.0); lm.next_at = 1e9
	var seat4 := cr.mount(on, 228.0, z, true, fig)
	var held4 := lm.phase
	while String(s["sw"]) != "off" and cr.t < 806.0:
		cr.sync(cr.t + DT); cr.stand(seat4, true, DT, fig); lm.step(DT)
	var me4 := float(s["me_t"]); var day4 := int(s["day"]); var idle4 := lm.phase
	var last4: Dictionary = {}
	while not bool(last4.get("off", false)) and cr.t < 808.0:
		cr.sync(cr.t + DT); last4 = cr.stand(seat4, false, DT, fig); lm.step(DT)
	while lm.phase == "idle" and cr.t - me4 < 3.0: cr._process(DT)
	var walk4 := cr.t - me4
	while lm.phase != "clip" and cr.t - me4 < 14.0: cr._process(DT)
	var clip4 := cr.t - me4; var tops4 := lm.tops
	while lm.phase != "idle" and cr.t - me4 < 30.0: cr._process(DT)
	print("LINESMAN follows you: idle while you ride=%s/%s (want idle idle) me_t=%.2f day=%d (want >800 1) | walks at %.2f s after your latch (want 1.50..1.52) | clips at %.2f s (want 5.6..6.0: your step-off 0.45 + hold 3 + the roll home) | after: tops=%d→%d rides=%d skips=%d (want %d→%d 2 1) day=%d me_t same=%s (want 1 true) %s (want idle)" % [held4, idle4, me4, day4, walk4, clip4, tops4, lm.tops, lm.rides, lm.skips, tops4, tops4 + 1, int(s["day"]), absf(float(s["me_t"]) - me4) < 0.001, lm.phase])
	await _clip_pose(fig)
	# 진짜 탑: 1..70층에 plan 이 찾는 궤도 — 태엽 층 15..19, 50..54 중 바람구멍 층(15·19·51)이 아니고 톱니 띠·추·뻐꾸기 집·풀무·핀 바퀴·시계추가 안 쓴 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var ck: Array = cg.plan(n, pl) + cpn.plan(n, pl) + pk.plan(n, pl); var bl: Array = cl.plan(n, pl, ck); var ep: Array = ew.plan(n, pl, ck + bl)
		var out2 := cr.plan(n, pl, ck + bl + ep + cw.plan(n, pl, ck + bl + ep))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s gap %.0f dy %.0f grade %.2f" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"]), float(v["dy"]), float(v["grade"])])])
	print("TOWER floors=", bands, " (want a subset of 16, 17, 18, 50, 52, 53, 54 — one rail each on the widest gap no other Clockwork pack took, never a vent floor, never another theme)")
	quit()

## 안장 위의 틱들 — secs 동안, 또는 sw 가 until 이 될 때까지(""·"stop": 차가 멎을 때까지, "gone": 내려설 때까지); 0.5 s 에 자세 메타를 읽는다; {secs, v_max, k_mid, b_mid, ang_mid, last}
func _ride(cr: ClimbRailcar, seat: Dictionary, fig: Stick3D, pressed: bool, secs: float, until: String) -> Dictionary:
	var s: Dictionary = cr.cars[0]; var t0 := cr.t; var v_max := 0.0; var last: Dictionary = {}; var k_mid := -1.0; var b_mid := -1.0; var ang_mid := 0.0
	while cr.t - t0 < secs:
		cr.sync(cr.t + DT); last = cr.stand(seat, pressed, DT, fig)
		v_max = maxf(v_max, float(s["v"]))
		if k_mid < 0.0 and cr.t - t0 >= 0.5: k_mid = float(fig.get_meta("pedal_k", 9.0)); b_mid = float(fig.get_meta("pedal_b", 9.0)); ang_mid = float(s["ang"])
		if until == "gone" and bool(last["off"]): break
		if until == "stop" and float(s["u"]) <= 0.0 and float(s["v"]) <= 0.0 and cr.t - t0 > 0.1: break
		if until != "" and until != "gone" and until != "stop" and String(s["sw"]) == until: break
	return { "secs": cr.t - t0, "v_max": v_max, "k_mid": k_mid, "b_mid": b_mid, "ang_mid": ang_mid, "last": last }

## pedal 자세(메타로 세운다) — 앉아 밟기(m 1·k 1·a 0), 버티기(b 1·k 0), 반쯤 오름(m 0.5); 메타 없이 3.9 에 done
func _pose(fig: Stick3D) -> void:
	fig.pose_request = "pedal"; fig.set_meta("pedal_m", 1.0); fig.set_meta("pedal_k", 1.0); fig.set_meta("pedal_b", 0.0); fig.set_meta("pedal_a", 0.0)
	for i in 45: await process_frame
	var r_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var r_knee: float = (fig.knees[1.0] as Node3D).rotation.x
	var l_hip: float = (fig.hips[-1.0] as Node3D).rotation.x; var l_knee: float = (fig.knees[-1.0] as Node3D).rotation.x
	var pel := fig.pelvis.position.y; var tx := fig.torso.rotation.x
	var shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shz2: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var el: float = (fig.elbows[1.0] as Node3D).rotation.x
	var neck := fig.neck.rotation.x
	fig.set_meta("pedal_k", 0.0); fig.set_meta("pedal_b", 1.0)
	for i in 45: await process_frame
	var b_tx := fig.torso.rotation.x; var b_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var b_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x
	fig.set_meta("pedal_m", 0.5); fig.set_meta("pedal_b", 0.0)
	for i in 45: await process_frame
	var h_rhip: float = (fig.hips[1.0] as Node3D).rotation.x; var h_rknee: float = (fig.knees[1.0] as Node3D).rotation.x; var h_lhip: float = (fig.hips[-1.0] as Node3D).rotation.x; var h_lknee: float = (fig.knees[-1.0] as Node3D).rotation.x; var h_pel := fig.pelvis.position.y
	for key: String in ["pedal_m", "pedal_k", "pedal_b", "pedal_a"]: fig.remove_meta(key)
	fig.pose_t = PedalPoses.LAP - 0.01; var before := PedalPoses.done(fig)
	fig.pose_t = PedalPoses.LAP + 0.001; var after := PedalPoses.done(fig)
	var lg0 := PedalPoses.leg(0.0); var lg1 := PedalPoses.leg(PI)
	print("PEDAL pose seated: R hip=%.3f knee=%.3f L hip=%.3f knee=%.3f (want −1.686 1.679 −0.929 0.712 = leg(0) %.3f/%.3f leg(π) %.3f/%.3f) pelvis=%.3f (want 0.31..0.33) torso=%.4f (want 0.2025) shoulder=%.2f z=%.2f/%.2f elbow=%.2f neck=%.2f (want −0.95±0.02 −0.12/0.12 −0.35 < −0.5) | brace: torso=%.3f elbow=%.2f shoulder=%.2f (want 0.045 −0.85 −1.05±0.02) | half mount: swing leg=%.3f/%.3f other=%.3f/%.3f pelvis=%.2f (want −1.743/2.040±0.015 −0.465/0.356±0.015 0.37 — the knees breathe) | done(3.89 → 3.901)=%s LAP=%.1f (want true 3.9)" % [r_hip, r_knee, l_hip, l_knee, float(lg0[0]), float(lg0[1]), float(lg1[0]), float(lg1[1]), pel, tx, shx, shz, shz2, el, neck, b_tx, b_el, b_shx, h_rhip, h_rknee, h_lhip, h_lknee, h_pel, (not before) and after, PedalPoses.LAP])
	fig.pose_request = ""

## clip 자세(메타로 세운다) — 숙여 집기(0.25), 털기(0.55, 두 틱 떨어져 정강이가 움직이나), 끝(1.0); 메타 없이 1.0 에 done
func _clip_pose(fig: Stick3D) -> void:
	fig.pose_request = "clip"; fig.set_meta("clip_t", 0.25)
	for i in 45: await process_frame
	var r_sh: Node3D = fig.shoulders[1.0]; var l_sh: Node3D = fig.shoulders[-1.0]; var r_el: Node3D = fig.elbows[1.0]; var l_el: Node3D = fig.elbows[-1.0]
	var r_hip: Node3D = fig.hips[1.0]; var r_knee: Node3D = fig.knees[1.0]; var l_hip: Node3D = fig.hips[-1.0]; var l_knee: Node3D = fig.knees[-1.0]
	var a := "torso=%.4f R arm=%.2f z=%.2f elbow=%.2f L arm=%.2f elbow=%.2f hips=%.2f/%.2f knees=%.2f/%.2f pelvis=%.2f neck+=%.2f" % [fig.torso.rotation.x, r_sh.rotation.x, r_sh.rotation.z, r_el.rotation.x, l_sh.rotation.x, l_el.rotation.x, r_hip.rotation.x, l_hip.rotation.x, r_knee.rotation.x, l_knee.rotation.x, fig.pelvis.position.y, fig.neck.rotation.x + (fig.torso.rotation.x + fig.chest.rotation.x) * 0.7]
	fig.set_meta("clip_t", 0.55)
	for i in 45: await process_frame
	var k1 := r_knee.rotation.x
	for i in 2: await process_frame
	var b := "torso=%.4f R arm=%.2f hip=%.2f knee=%.2f→%.2f moves=%s L hip=%.2f pelvis=%.2f" % [fig.torso.rotation.x, r_sh.rotation.x, r_hip.rotation.x, k1, r_knee.rotation.x, absf(r_knee.rotation.x - k1) > 0.01, l_hip.rotation.x, fig.pelvis.position.y]
	fig.set_meta("clip_t", 1.0)
	for i in 45: await process_frame
	var c := "torso=%.2f R arm=%.2f elbow=%.2f hip=%.2f knee=%.2f pelvis=%.2f done=%s" % [fig.torso.rotation.x, r_sh.rotation.x, r_el.rotation.x, r_hip.rotation.x, r_knee.rotation.x, fig.pelvis.position.y, ClipPoses.done(fig)]
	fig.remove_meta("clip_t")
	fig.pose_t = ClipPoses.TOTAL - 0.01; var before := ClipPoses.done(fig)
	fig.pose_t = ClipPoses.TOTAL + 0.001; var after := ClipPoses.done(fig)
	print("CLIP pose stoop 0.25: ", a, " (want 0.4275 −0.55 −0.10 −0.25±0.05 0.35 −0.20 −0.35/−0.35 0.45/0.45±0.03 0.36 0.55 over the forward-looking base) | shake 0.55: ", b, " (want 0.2025 −0.15 −0.50 0.60±0.25 true 0.00 0.40) | end 1.0: ", c, " (want 0.00 0.00 0.00 0.00 0.00 0.42 true) demo done(0.99 → 1.001)=%s TOTAL=%.1f (want true 1.0)" % [(not before) and after, ClipPoses.TOTAL])
	fig.pose_request = ""
