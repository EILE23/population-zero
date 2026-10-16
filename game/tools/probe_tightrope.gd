extends SceneTree
## 외줄 팩 점검(헤드리스): 자료가 읽히나, 별밤 층의 잇단 still 발판 짝(100..200 px 틈, 높이차 150 안) 중 가장 넓은 틈 하나에만 밧줄이 걸리나(지름길 판이 상자를 가르는 틈·높이차가 큰 짝·taken 조각(등롱 장대·그네)이 든 틈은 지고 다음 틈으로, 다른 테마 층은 아니다),
## 밧줄이 두 턱 끝 높이를 잇고 가운데 4 px 처지나, 밧줄을 지나는 몸과 catch 안에서 내려오는 몸(위에서든 아래에서든)만 land 가 받나(멀리 위·옆·앞뒤 밖은 아니다), 가만히 서면 진폭이 1.2 로 차 떨어지지 않나, 걸으면 22 틱(0.37 s, 95 px)에 떨어지나(twang),
## 떨어진 뒤 1.2 s 동안 받지 않다가 다시 받나, 바람 120 에 서면 2.4 로 차도 떨어지지 않나, 메타(tiptoe_k)가 적히나, 밧줄 토막·고리 둘·꼬리 둘·별 셋·매듭·소리 둘이 그려지나, tiptoe 자세가 팔을 수평으로 벌리고 발을 한 줄에 두고 골반이 벗어남을 따라 기우나,
## 진짜 탑의 1..70층에서 plan 이 별밤 층에만 밧줄을 찾나(고드름·등롱·그네·망원경을 taken 으로)
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var tr := ClimbTightrope.new(); root.add_child(tr)
	var ci := ClimbIcicle.new(); root.add_child(ci)
	var cn := ClimbLantern.new(); root.add_child(cn)
	var ct := ClimbTrapeze.new(); root.add_child(ct)
	var ts := ClimbTelescope.new(); root.add_child(ts)
	await process_frame
	print("PACK id=", tr.pack.get("id"), " kind=", tr.kind.size() > 0, " pose=", tr.pack.get("pose"), " themes=", tr.pack.get("themes"), " sag=%.0f catch=%.0f ring_in=%.0f max_dy=%.0f period=%.1f base=%.1f wind=%.1f speed=%.1f amp_t=%.2f fall=%.1f shake=%.1f (want 4 24 6 150 1.6 1.2 1.2 3.0 0.35 3.0 1.2)" % [tr.sag(), tr.catch(), tr.ring_in(), float(tr.kind.get("max_dy", 0.0)), tr.period(), tr.base_amp(), tr.wind_amp(), tr.speed_amp(), tr.amp_t(), tr.fall_px(), tr.shake_s()])
	# 32층(별밤): A 32.0→32.1 틈 100(200..300, 19300→19330), B 32.1→32.2 틈 170(450..620, 19330→19360), C 32.2→32.3 틈 105(760..865, 19360→19380), 32.3→32.4 틈 555(길다), 32.4→32.5 틈 250(길다)
	var plats: Array = [
		{ "id": "32.0", "x": 40.0, "y": 19300.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "32.1", "x": 300.0, "y": 19330.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "32.2", "x": 620.0, "y": 19360.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "32.3", "x": 865.0, "y": 19380.0, "w": 80.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "32.4", "x": 160.0, "y": 19450.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "32.5", "x": 560.0, "y": 19560.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
	]
	var free := tr.plan(32, plats)
	var slabbed := plats.duplicate(true); slabbed.append({ "id": "32s", "x": 455.0, "y": 19350.0, "w": 55.0, "kind": "short", "z": -29.0, "d": 60.0 })   # 지름길 판이 B 의 상자(450..620) 안 — C(760..865) 는 비켜 간다
	var slab := tr.plan(32, slabbed)
	var steep := plats.duplicate(true); (steep[2] as Dictionary)["y"] = 19490.0   # 32.2 가 160 높다 — B 는 지고 C(높이차 110)가 남는다
	var st := tr.plan(32, steep)
	var lant := tr.plan(32, plats, [{ "id": "32.L0", "kind": "lantern", "x": 442.0, "w": 180.0, "y": 19330.0, "len": 300.0 }])   # 등롱 장대가 B 의 틈에
	var trap := tr.plan(32, plats, [{ "id": "32.T0", "kind": "trapeze", "x": 480.0, "w": 110.0, "y": 19345.0, "hp": 19530.0 }])   # 그네가 B 의 틈에
	var far := tr.plan(32, plats, [{ "id": "32.T0", "kind": "trapeze", "x": 480.0, "w": 110.0, "y": 19520.0, "hp": 19700.0 }])   # 위 틈의 그네 — B 그대로
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " %s→%s dir %.0f %.0f,%.0f→%.0f,%.0f w %.0f y %.1f y_top %.0f z %.0f d %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["x0"]), float(v["y0"]), float(v["x1"]), float(v["y1"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	var brief := func(v: Dictionary) -> String: return "%s→%s %.0f..%.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["x0"]), float(v["x1"])]
	print("PLAN free=", free.map(show), " (want 1: 32.R0 32.1→32.2 dir 1 450,19330→620,19360 w 170 y 19341.0 y_top 19410 z −29 d 82)")
	print("PLAN slab=", slab.map(brief), " (want 32.2→32.3 760..865) steep=", st.map(brief), " (want 32.2→32.3 760..865) lantern=", lant.map(brief), " (want 32.2→32.3) trapeze=", trap.map(brief), " (want 32.2→32.3) far=", far.map(brief), " (want 32.1→32.2) floors 27/30/34/35/65=", [tr.plan(27, plats).size(), tr.plan(30, plats).size(), tr.plan(34, plats).size(), tr.plan(35, plats).size(), tr.plan(65, plats).size()], " (want 0 1 1 0 1)")
	var band_root := Node3D.new(); root.add_child(band_root)
	tr.build(band_root, free)
	var s: Dictionary = tr.ropes[0]
	var x0 := float(s["x0"]); var x1 := float(s["x1"]); var mid := (x0 + x1) / 2.0
	print("SURF end0=%.1f (want y0 19330) end1=%.1f (want y1 19360) mid=%.1f (want chord 19345 − sag 4 = 19341) quarter=%.2f (want 19337.5 − 3 = 19334.50) outside=%.1f/%.1f (want 19330/19360)" % [tr.surf(s, x0), tr.surf(s, x1), tr.surf(s, mid), tr.surf(s, x0 + (x1 - x0) * 0.25), tr.surf(s, x0 - 30.0), tr.surf(s, x1 + 30.0)])
	# 착지: 가운데 밧줄 위 5px 에서 5px 아래로 → 받는다(cross); 20px 위에서 내려오는 몸 → step; 20px 아래에서 내려오는 몸(턱에서 오르는 밧줄로 내디뎠다) → step; 30px 위 → 아니다; 폭 밖·앞뒤 밖 → 아니다
	var sy := tr.surf(s, mid)
	tr.sync(10.0)
	var l_cross := tr.land(mid, sy + 5.0, sy - 5.0, C.PLAYER_Z)
	var l_step := tr.land(mid, sy + 20.0, sy + 19.0, C.PLAYER_Z)
	var l_up := tr.land(x0 + 10.0, tr.surf(s, x0 + 10.0) - 20.0, tr.surf(s, x0 + 10.0) - 21.0, C.PLAYER_Z)
	var l_high := tr.land(mid, sy + 30.0, sy + 29.0, C.PLAYER_Z)
	var l_side := tr.land(x1 + 30.0, sy + 5.0, sy - 5.0, C.PLAYER_Z)
	var l_z := tr.land(mid, sy + 5.0, sy - 5.0, C.PLAYER_Z + 100.0)
	print("LAND cross=%s y=%.1f step=%s (want 32.R0, %.1f, false) | down=%s step=%s (want 32.R0 true) | up=%s step=%s (want 32.R0 true) | high=%s side=%s far_z=%s (want all -)" % [l_cross.get("id", "-"), float(l_cross.get("y", 0.0)), l_cross.get("step", "-"), sy, l_step.get("id", "-"), l_step.get("step", "-"), l_up.get("id", "-"), l_up.get("step", "-"), l_high.get("id", "-"), l_side.get("id", "-"), l_z.get("id", "-")])
	# 서기(파이썬 모형으로 먼저 낸 값): 가만히 — 진폭 1.2 로 차고(0.14 s) |off| 는 1.2 를 넘지 않는다, 24 틱(0.4 s)에 off 1.2(사인 꼭대기), 180 틱에 −0.8485, fall 없음, hum 스트림;
	# 걸음(틱마다 260/60) — 22 틱(0.3667 s, 95.3 px)에 off 3.116 > 3 → fall, 진폭 3.143, twang; 그 뒤 1.2 s 동안 land 가 받지 않다가 다시 받는다; 바람 120 에 가만히 — 진폭 2.4, |off| ≤ 2.4, fall 없음
	var fig := Stick3D.new(); root.add_child(fig)
	var still := _sim(tr, s, fig, false, 180, mid, 100.0)
	var hum_ok: bool = (s["hum"] as AudioStreamPlayer3D).stream != null and (s["twang"] as AudioStreamPlayer3D).stream != null
	var meta_still := float(fig.get_meta("tiptoe_k", 9.0))
	var walk := _sim(tr, s, fig, true, 120, x0 + 10.0, 200.0)
	var tf := float(walk["t_end"])
	var refused := tr.land(mid, sy + 5.0, sy - 5.0, C.PLAYER_Z).is_empty()
	tr.sync(tf + 1.3)
	var again := not tr.land(mid, sy + 5.0, sy - 5.0, C.PLAYER_Z).is_empty()
	var meta_gone := not fig.has_meta("tiptoe_k")
	s["wind"] = 120.0
	var windy := _sim(tr, s, fig, false, 180, mid, 400.0)
	s["wind"] = 0.0
	print("STAND still: fall=%s max|off|=%.4f amp=%.4f off24=%.4f off180=%.4f (want false 1.2000 1.2000 1.2000 −0.8485) hum/twang=%s meta=%.4f (want true, off180 / 3 = −0.2828) | walk: fall=%s tick=%d t=%.4f x=%.3f off=%.4f amp=%.4f (want true 22 0.3667 555.333 3.1160 3.1429) refused=%s again=%s meta_gone=%s (want true ×3) | wind 120: fall=%s max|off|=%.4f amp=%.4f (want false 2.4000 2.4000)" % [still["fall"], float(still["maxoff"]), float(still["amp"]), float(still["off24"]), float(still["off_end"]), hum_ok, meta_still, walk["fall"], int(walk["ticks"]), float(walk["t_end"]) - 200.0, float(walk["x"]), float(walk["off_end"]), float(walk["amp"]), refused, again, meta_gone, windy["fall"], float(windy["maxoff"]), float(windy["amp"])])
	# 그림: 토막 170 / 25 = 6, 고리 2, 꼬리 2, 별 3(실·별 둘씩 든 pin), 매듭 1, 소리 2 → 16 아이; 노드 자리 (450 − 480)/36 = −0.8333, 19330/36 = 536.9444, −29/36 = −0.8056; 토막 기울기 = atan(현 30/170 − 처짐 16(1 − 2u)/170) — 첫 토막 0.0977, 끝 토막 0.2496; 별 pin x 1/4·170/36 = 1.1806
	var node: Node3D = s["node"]; var segs: Array = s["segs"]; var stars: Array = s["stars"]
	var seg0: MeshInstance3D = segs[0]; var seg5: MeshInstance3D = segs[5]; var pin0: Node3D = stars[0]
	print("VISUAL children=%d (want 16) segs=%d stars=%d (want 6 3) node pos=%.4f %.4f %.4f (want −0.8333 536.9444 −0.8056) seg0 x=%.4f y=%.4f slope=%.4f (want 0.3935 0.0455 0.0977: the rope sits its radius 0.01 over the line) seg5 x=%.4f slope=%.4f (want 4.3287 0.2496: the sag flattens the start and steepens the end) pin0 x=%.4f y=%.4f (want 1.1806 0.1250: 7.5 − 3 = 4.5 px up)" % [node.get_child_count(), segs.size(), stars.size(), node.position.x, node.position.y, node.position.z, seg0.position.x, seg0.position.y, seg0.rotation.z, seg5.position.x, seg5.rotation.z, pin0.position.x, pin0.position.y])
	# 자세(tiptoe_k 1.0, 40 프레임 뒤): 오른팔 어깨 z −(0.1 + 1.45 − 0.4) = −1.15 ± 0.03, 왼팔 +(0.1 + 1.85) = 1.95 ± 0.03, 골반 z 돌림 0.22, 골반 높이 0.45 ± 0.006, 오른 엉덩이 −0.30(앞) 왼 +0.10(뒤), 무릎 0.08; 뒤집으면 돌림 −0.22, 오른팔 −1.95
	fig.pose_request = "tiptoe"; fig.set_meta("tiptoe_k", 1.0)
	await process_frame; await process_frame; await process_frame
	var early: float = (fig.shoulders[1.0] as Node3D).rotation.z
	for i in 40: await process_frame
	var sh_r: float = (fig.shoulders[1.0] as Node3D).rotation.z; var sh_l: float = (fig.shoulders[-1.0] as Node3D).rotation.z
	var hip_r: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_l: float = (fig.hips[-1.0] as Node3D).rotation.x; var kn_r: float = (fig.knees[1.0] as Node3D).rotation.x
	var roll := fig.pelvis.rotation.z; var hip_y := fig.pelvis.position.y
	fig.set_meta("tiptoe_k", -1.0)
	for i in 40: await process_frame
	var roll2 := fig.pelvis.rotation.z; var sh_r2: float = (fig.shoulders[1.0] as Node3D).rotation.z
	print("POSE early=%.2f (≈ 0, before the arms open) right arm=%.2f left arm=%.2f (want ≈ −1.15 and ≈ +1.95: the dipping left side rises) hips r=%.2f l=%.2f (want −0.30 and +0.10 — one foot before the other) knee=%.2f (want 0.08: straight) pelvis roll=%.3f (want ≈ 0.22) hip_y=%.3f (want ≈ 0.450: on the toes) | flipped: roll=%.3f (want ≈ −0.22) right arm=%.2f (want ≈ −1.95)" % [early, sh_r, sh_l, hip_r, hip_l, kn_r, roll, hip_y, roll2, sh_r2])
	# 진짜 탑: 1..70층에 plan 이 찾는 밧줄 — 별밤 층 30..34, 65..69 중 고드름·등롱·그네·망원경이 비켜 가고 높이가 거의 같은 짝이 남는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var icn: Array = ci.plan(n, pl); var lp: Array = cn.plan(n, pl, icn); var tp: Array = ct.plan(n, pl, icn + lp)
		var out2 := tr.plan(n, pl, icn + lp + tp + ts.plan(n, pl, icn + lp + tp))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s gap %.0f dy %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["w"]), float(v["y1"]) - float(v["y0"])])]); count += out2.size()
	print("TOWER floors=", bands, " ropes=", count, " (want a subset of 30..34 and 65..69 — one each, never another theme; a floor whose fitting gaps all belong to the lantern, the trapeze or the icicles has none)")
	quit()

## 서기 모형 — 틱마다 sync 를 1/60 올리고(걸으면 x 도 260/60) stand 를 부른다; fall 이 나거나 ticks 를 다 돌면 끝
func _sim(tr: ClimbTightrope, s: Dictionary, fig: Stick3D, walk: bool, ticks: int, x_start: float, t0: float) -> Dictionary:
	var tt := t0; var x := x_start; var maxoff := 0.0; var off24 := 0.0; var off := 0.0; var n := 0; var fell := false
	tr.sync(tt)
	while n < ticks:
		tt += 1.0 / 60.0; tr.sync(tt); n += 1
		if walk: x += C.WALK / 60.0
		var r := tr.stand(s, x, 1.0 / 60.0, fig)
		off = float(r["off"]); maxoff = maxf(maxoff, absf(off))
		if n == 24: off24 = off
		if bool(r["fall"]): fell = true; break
	return { "fall": fell, "ticks": n, "t_end": tt, "x": x, "maxoff": maxoff, "off24": off24, "off_end": off, "amp": float(s["amp"]) if not fell else float(s.get("fall_amp", 0.0)) }
