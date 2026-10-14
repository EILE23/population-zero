extends SceneTree
## 허들 줄 팩 점검(헤드리스): 자료가 읽히나, 바람 절벽 층의 가장 넓은 still 발판에만 줄이 서나(세 개가 안 들어가면 둘, 통풍구가 선 발판·고드름이 턱에 걸린 발판·진폭째 상자에 드는 움직이는 발판은 비켜 가고, 위 발판 높이의 조각은 위 발판의 것, 다른 테마 층은 아니다),
## 걷다 가로대를 사이에 둔 틱에 속도가 있으면 넘고(vault — 같은 날 두 번은 한 번으로, 다음 날은 다시) 느리면 부딪혀 물러서나(bump — 가로대가 흔들리다 선다), 줄 안에서만 in_row 와 자리 k 가 나오고 메타에 적히나, 다른 발판·앞쪽 깊이·막 내려선 발판은 아니다,
## 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 세나, 가로대마다 기둥 둘·발 둘·가로대 하나가 그려지나, hurdle 자세가 디디고 뛰고 내려서나, 진짜 탑의 1..70층에서 plan 이 바람 절벽 층에만 줄을 찾나,
## 허들러(run 156)가 집 쪽 끝에 서서 플레이어의 vault 뒤 0.8 s 에 같은 자세로 줄을 뛰고(세지 않고) 끝에서 wheel 로 돌아서 앞길로 돌아오나, 얼음에선 플레이어처럼 첫 가로대에 부딪히고 집으로 가나, wheel 자세가 디디고 휘돌고 끝나나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var ch := ClimbHurdle.new(); root.add_child(ch)
	var cu := ClimbUpdraft.new(); root.add_child(cu)
	var ci := ClimbIcicle.new(); root.add_child(ci)
	var ck := ClimbKite.new(); root.add_child(ck)
	await process_frame
	print("PACK id=", ch.pack.get("id"), " kind=", ch.kind.size() > 0, " pose=", ch.pack.get("pose"), " themes=", ch.pack.get("themes"), " h=%.0f spacing=%.0f count=%d/%d margin=%.0f rail_d=%.0f vault_v=%.0f bump=%.2f back=%.0f day=%.0f need=%.0f/%.0f (want 20 60 3/2 24 30 180 0.40 12 600 168/108)" % [ch.h(), ch.spacing(), ch.count(), ch.min_count(), ch.margin(), ch.rail_d(), ch.vault_v(), ch.bump_s(), ch.step_back(), ch.day_s(), ch.need_w(3), ch.need_w(2)])
	var plats: Array = [
		{ "id": "22.0", "x": 60.0, "y": 13300.0, "w": 170.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "22.1", "x": 420.0, "y": 13400.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "22.2", "x": 180.0, "y": 13500.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "22.3", "x": 540.0, "y": 13600.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "22.4", "x": 300.0, "y": 13700.0, "w": 176.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "22s", "x": 700.0, "y": 13650.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var vent := { "id": "22.v0", "kind": "vent", "x": 388.0, "y": 13700.0 }
	var free := ch.plan(22, plats)
	var vented := ch.plan(22, plats, [vent])   # 통풍구가 22.4 가운데 — 22.0 (170, 셋) 으로
	var iced := ch.plan(22, plats, [vent, { "id": "22.i0.0", "kind": "icicle", "x": 230.0, "y": 13300.0 }])   # 고드름이 22.0 의 오른 턱(230; 줄의 상자 65..225 와 겹친다) — 22.2 (얼음, 160, 둘) 로
	var kited := ch.plan(22, plats, [{ "id": "22.K0", "kind": "kite", "x": 570.0, "w": 100.0, "y": 13400.0 }])   # 연은 22.1 의 틈 — 22.4 그대로
	var above := ch.plan(22, plats, [{ "id": "22.x", "kind": "vent", "x": 388.0, "y": 13800.0 }])   # 위 발판 높이의 조각은 위 발판의 것 — 22.4 그대로
	var moved := plats.duplicate(true); moved.append({ "id": "22m", "x": 350.0, "y": 13720.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째(260..500, 13720) 22.4 의 상자에 든다 — 22.0 으로
	var movep := ch.plan(22, moved)
	var narrow: Array = [
		{ "id": "57.0", "x": 100.0, "y": 34300.0, "w": 130.0, "kind": "std", "z": -29.0, "d": 60.0 },
		{ "id": "57.1", "x": 400.0, "y": 34400.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 60.0 },
		{ "id": "57.2", "x": 200.0, "y": 34500.0, "w": 100.0, "kind": "ice", "z": -29.0, "d": 60.0 },
	]
	var two := ch.plan(57, narrow)
	var f19 := ch.plan(19, plats); var f20 := ch.plan(20, plats); var f24 := ch.plan(24, plats); var f25 := ch.plan(25, plats); var f55 := ch.plan(55, plats); var f59 := ch.plan(59, plats)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " on %s w %.0f count %d rails %s x %.0f w %.0f y %.0f y_top %.0f z %.0f d %.0f" % [String(v["hop_id"]), float(v["w"]), int(v["count"]), str(v["rails"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	var brief := func(v: Dictionary) -> String: return String(v["hop_id"]) + " ×%d" % int(v["count"])
	print("PLAN free=", free.map(show), " (want 1: 22.H0 on 22.4 w 140 count 3 rails [328, 388, 448] x 318 w 140 y 13700 y_top 13720 z −55 d 30)")
	print("PLAN vented=", vented.map(brief), " (want 22.0 ×3) iced=", iced.map(brief), " (want 22.2 ×2) kited=", kited.map(brief), " (want 22.4 ×3) above=", above.map(brief), " (want 22.4 ×3) moved=", movep.map(brief), " (want 22.0 ×3) narrow=", two.map(show), " (want 57.H0 on 57.0 count 2 rails [135, 195]) floors 19/20/24/25/55/59=", [f19.size(), f20.size(), f24.size(), f25.size(), f55.size(), f59.size()], " (want 0 1 1 0 1 1)")
	var band_root := Node3D.new(); root.add_child(band_root)
	ch.build(band_root, free)
	var r: Dictionary = ch.rows[0]
	var on: Dictionary = plats[4]; var other: Dictionary = plats[3]
	var fig := Stick3D.new(); root.add_child(fig)
	# 걸음(10.0, 가로대 328/388/448): 290 은 줄 밖(lo 298), 300 안 k 0.033, 320 k 0.367, 330 은 328 을 넘는다(vault 0, k 0.533), 386 k 0.467, 392 넘는다(1), 452 넘는다(2) → 3/3; 478 k 1.0 안, 480 밖(메타 지움); 되돌아 440 은 448 을 다시 넘지만 같은 날 — 3/3 그대로
	ch.sync(10.0)
	var s290 := ch.stride(on, 290.0, C.PLAYER_Z, 260.0, fig); var s300 := ch.stride(on, 300.0, C.PLAYER_Z, 260.0, fig); var m300 := float(fig.get_meta("hurdle_k", 9.0))
	var s320 := ch.stride(on, 320.0, C.PLAYER_Z, 260.0, fig); var s330 := ch.stride(on, 330.0, C.PLAYER_Z, 260.0, fig); var v1 := ch.vaulted_today(22, 22)
	var s386 := ch.stride(on, 386.0, C.PLAYER_Z, 260.0, fig); var s392 := ch.stride(on, 392.0, C.PLAYER_Z, 260.0, fig); var s452 := ch.stride(on, 452.0, C.PLAYER_Z, 260.0, fig); var v3 := ch.vaulted_today(22, 22)
	var s478 := ch.stride(on, 478.0, C.PLAYER_Z, 260.0, fig); var s480 := ch.stride(on, 480.0, C.PLAYER_Z, 260.0, fig); var m480 := fig.has_meta("hurdle_k")
	var back := ch.stride(on, 440.0, C.PLAYER_Z, -260.0, fig); var v3b := ch.vaulted_today(22, 22)
	print("STRIDE 290=%s 300=%s k=%.3f meta=%.3f (want false true 0.033 0.033) 320 k=%.3f (want 0.367) 330 vault=%s rail=%d k=%.3f (want true 0 0.533) today=%d/%d (want 1/3) 386 k=%.3f (want 0.467) 392 vault=%s rail=%d 452 vault=%s rail=%d (want true 1 true 2) today=%d/%d (want 3/3) 478 in=%s k=%.3f (want true 1.000) 480 in=%s meta=%s (want false false) back: vault=%s today=%d/%d (want true 3/3: once a day)" % [s290["in_row"], s300["in_row"], float(s300["k"]), m300, float(s320["k"]), s330["vault"], int(s330["rail"]), float(s330["k"]), int(v1["done"]), int(v1["total"]), float(s386["k"]), s392["vault"], int(s392["rail"]), s452["vault"], int(s452["rail"]), int(v3["done"]), int(v3["total"]), s478["in_row"], float(s478["k"]), s480["in_row"], m480, back["vault"], int(v3b["done"]), int(v3b["total"])])
	# 다음 날(610.0): 0/3; 느린 걸음(−100): 430 은 줄 안이지만 느려 in_row 거짓, 380 은 388 을 사이에 두고 느리다 → bump, x 412 (388 + 10 + 2 + 12), 아직 0/3; 가로대 1 이 흔들리다(610.1) 선다(611.0); 다른 발판·앞 깊이·막 내려선 발판은 아무것도 아니다; 그 뒤 빠른 걸음으로 388 을 넘으면 1/3
	ch.sync(610.0); var v0 := ch.vaulted_today(22, 22)
	var s430 := ch.stride(on, 430.0, C.PLAYER_Z, -100.0, fig); var bump := ch.stride(on, 380.0, C.PLAYER_Z, -100.0, fig); var vb := ch.vaulted_today(22, 22)
	ch.sync(610.1); ch._process(0.0); var rot1: float = ((r["bars"] as Array)[1] as Node3D).rotation.x; var rot0: float = ((r["bars"] as Array)[0] as Node3D).rotation.x
	ch.sync(611.0); ch._process(0.0); var rot1b: float = ((r["bars"] as Array)[1] as Node3D).rotation.x
	var front := ch.stride(on, 380.0, -20.0, 260.0, fig); var wrong := ch.stride(other, 380.0, C.PLAYER_Z, 260.0, fig); var fresh := ch.stride(on, 395.0, C.PLAYER_Z, 260.0, fig)   # 발판이 바뀌어 앞 틱의 자리가 새로 잡힌다 — 395 는 건넌 게 아니다
	var again := ch.stride(on, 400.0, C.PLAYER_Z, 260.0, fig); var cross := ch.stride(on, 384.0, C.PLAYER_Z, -260.0, fig); var v1b := ch.vaulted_today(22, 22)
	print("BUMP day1=%d/%d (want 0/3) 430 in=%s bump=%s (want false false) 380 bump=%s x=%.0f rail=%d in=%s (want true 412 1 false) today=%d/%d (want 0/3) rail1 rot@0.1=%.3f rail0=%.3f (want ≠0 0) @1.0=%.3f (want 0.000) wrong=%s front=%s fresh=%s (want false ×3) again in=%s (want true) cross vault=%s (want true) today=%d/%d (want 1/3)" % [int(v0["done"]), int(v0["total"]), s430["in_row"], s430["bump"], bump["bump"], float(bump["x"]), int(bump["rail"]), bump["in_row"], int(vb["done"]), int(vb["total"]), rot1, rot0, rot1b, wrong["vault"] or wrong["bump"] or wrong["in_row"], front["vault"] or front["bump"] or front["in_row"], fresh["vault"] or fresh["bump"], again["in_row"], cross["vault"], int(v1b["done"]), int(v1b["total"])])
	print("NOTE 20=\"%s\" (want Hurdles, floors 20–24: 1 of 3 vaulted today.) 25=\"%s\" (want the same: nothing on 25..29, so the floors below) 40=\"%s\" (want empty)" % [ch.note(20), ch.note(25), ch.note(40)])
	# 그림: 노드 아이 5(가로대 셋·소리 둘), 가로대 아이 5(기둥 둘·발 둘·가로대); 노드 자리 (388 − 480)/36 = −2.5556, 13700/36 = 380.5556, −70/36 = −1.9444; 가로대 0 x (328 − 388)/36 = −1.6667; 가로대 막대 y 20/36 − 3/36 × 0.4 = 0.5222, z 15/36 = 0.4167
	var node: Node3D = r["node"]; var bar0: Node3D = (r["bars"] as Array)[0]; var rail: Node3D = bar0.get_child(4)
	print("VISUAL node children=%d bar=%d (want 5 5) node pos=%.4f %.4f %.4f (want −2.5556 380.5556 −1.9444) bar0 x=%.4f (want −1.6667) rail y=%.4f z=%.4f (want 0.5222 0.4167)" % [node.get_child_count(), bar0.get_child_count(), node.position.x, node.position.y, node.position.z, bar0.position.x, rail.position.y, rail.position.z])
	# 자세(hurdle_k 0.15 디딤: 오른 엉덩이 −0.250 무릎 0.550 왼 엉덩이 −0.100 무릎 0.450 골반 0.360 | 0.5 도약: 오른 엉덩이 −1.350 무릎 0.120 팔꿈치 −0.500 왼 엉덩이 −0.550 벌림 1.150 무릎 1.650 팔꿈치 −0.700 골반 0.720, 오른 어깨 ≈ 0.95 뒤·왼 어깨 ≈ −1.40 앞(±0.06 잔떨림) | 0.85 착지: 오른 엉덩이 0.237 무릎 1.006 왼 엉덩이 −0.626 무릎 0.427 골반 0.354; 메타가 있는 동안 done 거짓)
	fig.pose_request = "hurdle"; fig.set_meta("hurdle_k", 0.15)
	for i in 90: await process_frame
	var c_rhip: float = (fig.hips[1.0] as Node3D).rotation.x; var c_rknee: float = (fig.knees[1.0] as Node3D).rotation.x; var c_lhip: float = (fig.hips[-1.0] as Node3D).rotation.x; var c_lknee: float = (fig.knees[-1.0] as Node3D).rotation.x; var c_pel := fig.pelvis.position.y
	fig.set_meta("hurdle_k", 0.5)
	for i in 90: await process_frame
	var d_rhip: float = (fig.hips[1.0] as Node3D).rotation.x; var d_rknee: float = (fig.knees[1.0] as Node3D).rotation.x; var d_rel: float = (fig.elbows[1.0] as Node3D).rotation.x; var d_rsh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	var d_lhip: float = (fig.hips[-1.0] as Node3D).rotation.x; var d_lhz: float = (fig.hips[-1.0] as Node3D).rotation.z; var d_lknee: float = (fig.knees[-1.0] as Node3D).rotation.x; var d_lel: float = (fig.elbows[-1.0] as Node3D).rotation.x; var d_lsh: float = (fig.shoulders[-1.0] as Node3D).rotation.x
	var d_pel := fig.pelvis.position.y; var d_done := HurdlePoses.done(fig)
	fig.set_meta("hurdle_k", 0.85)
	for i in 90: await process_frame
	var l_rhip: float = (fig.hips[1.0] as Node3D).rotation.x; var l_rknee: float = (fig.knees[1.0] as Node3D).rotation.x; var l_lhip: float = (fig.hips[-1.0] as Node3D).rotation.x; var l_lknee: float = (fig.knees[-1.0] as Node3D).rotation.x; var l_pel := fig.pelvis.position.y
	print("POSE crouch: R hip=%.3f knee=%.3f L hip=%.3f knee=%.3f pelvis=%.3f (want −0.250 0.550 −0.100 0.450 0.360) | drive: R hip=%.3f knee=%.3f el=%.3f sh=%.2f L hip=%.3f z=%.3f knee=%.3f el=%.3f sh=%.2f pelvis=%.3f done=%s (want −1.350 0.120 −0.500 0.95±0.06 −0.550 1.150 1.650 −0.700 −1.40±0.06 0.720 false) | land: R hip=%.3f knee=%.3f L hip=%.3f knee=%.3f pelvis=%.3f (want 0.237 1.006 −0.626 0.427 0.354)" % [c_rhip, c_rknee, c_lhip, c_lknee, c_pel, d_rhip, d_rknee, d_rel, d_rsh, d_lhip, d_lhz, d_lknee, d_lel, d_lsh, d_pel, d_done, l_rhip, l_rknee, l_lhip, l_lknee, l_pel])
	# 허들러(run 156, 주민 반쪽): 줄마다 집 쪽 끝(476 − 14 = 462, 가로대 z −55)에 선 주민 — 세워 두고(next_at 먼 뒤) 플레이어가 이 줄을 넘으면 0.8 s 뒤 뛴다(run): 148 px 를 260 px/s 로, 줄 안에선 hurdle, 제 vault 는 세지 않는다(그날의 수 그대로);
	# 먼 끝(300 + 14 = 314)에서 wheel 0.5 s 로 돌아서며 앞길(z = −70 + 82 − 8 − 2 = 2)로 옮겨 서고, back 으로 집까지 걸어(띠 밖 — stride 는 아무것도 아니다), wheel2 로 돌아서 z −55 로 돌아와 idle, next_at = t + 60. 다 해서 0.8 + 0.57 + 0.5 + 0.57 + 0.5 ≈ 2.9 s
	var ru: ClimbHurdler = r["runner"]
	ru._rest(); ru.next_at = 9.0e9
	ch.sync(1300.0)   # 셋째 날
	var h0 := "%s x=%.0f z=%.0f lane=%.0f home=%.0f far=%.0f pos=%.4f %.4f %.4f" % [ru.phase, ru.x, ru.z, ru.lane_z, ru.home_x, ru.far_x, ru.fig.position.x, ru.fig.position.y, ru.fig.position.z]
	ch.stride(on, 470.0, -20.0, 0.0, fig); ch.stride(on, 440.0, C.PLAYER_Z, -260.0, fig)   # 플레이어가 앞길에서 470 으로 와 448 을 넘는다 → poke 1300, 오늘 1/3
	var poke: float = r["poke"]; var before := ch.vaulted_today(22, 22)
	var tt := 1300.0; var seen: Array = []; var at: Dictionary = {}; var hurdled := false; var wheeled := false; var lane_ok := false; var low := 9.0e9; var steps := 0
	while steps < 600:
		tt += 1.0 / 60.0; ch.sync(tt); ru.step(1.0 / 60.0); steps += 1
		if seen.is_empty() or String(seen[seen.size() - 1]) != ru.phase: seen.append(ru.phase); at[ru.phase] = tt - 1300.0
		hurdled = hurdled or (ru.phase == "run" and ru.fig.pose_request == "hurdle" and ru.fig.has_meta("hurdle_k"))
		wheeled = wheeled or (ru.phase == "wheel" and ru.fig.pose_request == "wheel")
		lane_ok = lane_ok or (ru.phase == "back" and absf(ru.z - ru.lane_z) < 1.0 and ru.fig.pose_request == "")
		if ru.phase == "run": low = minf(low, ru.x)
		if seen.size() > 1 and ru.phase == "idle": break
	var after := ch.vaulted_today(22, 22)
	print("RUNNER start: ", h0, " (want idle 462 −55 2 462 314 2.0556 0.0000 0.4167) poke=%.0f (want 1300) phases=%s (want [idle, run, wheel, back, wheel2, idle]) run@%.2f wheel@%.2f back@%.2f wheel2@%.2f idle@%.2f (want ≈0.82 1.40 1.92 2.50 3.02) hurdled=%s wheeled=%s lane=%s (want true ×3) low=%.0f (want ≤ 316 — the last run tick before the turn) today %d/%d → %d/%d (want 1/3 → 1/3: the hurdler's vaults do not count) end x=%.0f z=%.0f pose=\"%s\" next=+%.0f (want 462 −55 \"\" 60)" % [poke, str(seen), float(at.get("run", -1.0)), float(at.get("wheel", -1.0)), float(at.get("back", -1.0)), float(at.get("wheel2", -1.0)), float(at.get("idle", -1.0)), hurdled, wheeled, lane_ok, low, int(before["done"]), int(before["total"]), int(after["done"]), int(after["total"]), ru.x, ru.z, ru.fig.pose_request, ru.next_at - tt])
	# 얼음(22.2: x 180 w 160, 가로대 230·290, 집 326): 선 채 출발해 climb.gd 의 가속으로 — 36 px 앞의 290 에 0.47 s 쯤 137 px/s 로 닿는다 → 부딪힌다(teeter 0.4 s, x 314, 가로대 1 이 흔들린다) → 집으로(home) → wheel2 → idle; 혼자 뛰는 때(next_at)로도 시작한다
	var ice_root := Node3D.new(); root.add_child(ice_root)
	ch.build(ice_root, iced)
	var r2: Dictionary = ch.rows[1]; var ru2: ClimbHurdler = r2["runner"]
	ru2.next_at = tt + 1.0; var before2 := ch.vaulted_today(22, 22)
	var seen2: Array = []; var at2: Dictionary = {}; var bump_x := 0.0; var bump_v := 0.0; var steps2 := 0; var t_ice := tt
	while steps2 < 600:
		tt += 1.0 / 60.0; ch.sync(tt); ru2.step(1.0 / 60.0); steps2 += 1
		if seen2.is_empty() or String(seen2[seen2.size() - 1]) != ru2.phase:
			seen2.append(ru2.phase); at2[ru2.phase] = tt - t_ice
			if ru2.phase == "teeter": bump_x = ru2.x
		if ru2.phase == "run": bump_v = absf(ru2.vx)
		if seen2.size() > 1 and ru2.phase == "idle": break
	print("ICE kind=%s home=%.0f phases=%s (want ice 326 [idle, run, teeter, home, wheel2, idle]) run@%.2f teeter@%.2f (want 1.02 ≈1.50 — within 0.7 s of the start) last v=%.0f (want < 180) bump x=%.0f (want 314) rail1 hit=%s (want true) today %d/%d → %d/%d (want 1/5 → 1/5: two rails more in the total, nothing counted by the runner) end x=%.0f pose=\"%s\"" % [ru2.hop_kind, ru2.home_x, str(seen2), float(at2.get("run", -1.0)), float(at2.get("teeter", -1.0)), bump_v, bump_x, float((r2["hits"] as Array)[1]) > 0.0, int(before2["done"]), int(before2["total"]), int(ch.vaulted_today(22, 22)["done"]), int(ch.vaulted_today(22, 22)["total"]), ru2.x, ru2.fig.pose_request])
	# wheel 자세(헤드리스의 프레임은 60 fps 가 아니라 pose_t 로 기다린다; Stick3D 가 앞 각도와 섞으니 값은 목표보다 작다): 0.12 s(디딤) 에 두 팔이 옆으로 벌어지고(어깨 z 가 −s 쪽) 골반이 내려앉는다, 0.27 s(휘돌기) 에 왼다리가 앞으로(왼 엉덩이 x < 0) 고개가 돈다(look_yaw < 0), 0.5 s 에 done
	fig.pose_request = ""; fig.set_meta("hurdle_k", 0.0); fig.remove_meta("hurdle_k")
	for i in 3: await process_frame
	fig.pose_request = "wheel"
	while fig.pose_t < 0.12: await process_frame
	var w_pt := fig.pose_t; var w_ph := WheelPoses.phases(fig); var w_rshz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var w_lshz: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var w_pel := fig.pelvis.position.y
	while fig.pose_t < 0.27: await process_frame
	var s_pt := fig.pose_t; var s_ph := WheelPoses.phases(fig); var s_lhip: float = (fig.hips[-1.0] as Node3D).rotation.x; var s_look := fig.look_yaw; var s_lsh: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var s_rsh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	while fig.pose_t < 0.5: await process_frame
	print("WHEEL plant@%.2f plant=%.2f (want > 0.5) R sh z=%.2f L sh z=%.2f (want < −0.3, > 0.3) pelvis=%.3f (want < 0.42) | swing@%.2f swing=%.2f (want > 0.3) L hip=%.2f (want < −0.1) look=%.2f (want < −0.1) L sh x=%.2f R sh x=%.2f (want < 0, > 0) | done=%s at %.2f (want true ≥ 0.5)" % [w_pt, float(w_ph[0]), w_rshz, w_lshz, w_pel, s_pt, float(s_ph[1]), s_lhip, s_look, s_lsh, s_rsh, WheelPoses.done(fig), fig.pose_t])
	# 진짜 탑: 1..70층에 plan 이 찾는 줄 — 바람 절벽 층 20..24, 55..59 중 통풍구·고드름·연(taken)이 비켜 가고 남는 발판이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []; var rails := 0
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var out2 := ch.plan(n, pl, cu.plan(n, pl) + ci.plan(n, pl) + ck.plan(n, pl, gm.wind_of(n)))
		if out2.size() > 0:
			bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s ×%d w %.0f" % [String(v["hop_id"]), int(v["count"]), float(v["w"])])]); count += out2.size()
			for v in out2: rails += int(v["count"])
	print("TOWER floors=", bands, " rows=", count, " rails=", rails, " (want a subset of 20..24 and 55..59 — one row each, three rails on the wide low hops, two on the upper floors, never another theme)")
	quit()
