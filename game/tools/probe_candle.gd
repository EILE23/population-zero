extends SceneTree
## 촛대 계단 팩 점검(헤드리스): 자료가 읽히나, 별밤 층의 잇단 still 발판 짝(100..200 px 틈, 위 발판이 150 px 안) 중 가장 넓은 틈에만 계단이 놓이나(좁은 틈은 지고, 상자에 드는 발판·진폭째 드는 움직이는 발판·taken 조각(등롱 장대·고드름)이 든 틈은 비켜 가며, 다른 테마 층은 아니다, 거울 층은 반대로),
## 세 오름이 dy − 20 을 base−4·base+4·base 로 나눈 정수(29·37·33 → 꼭대기 29·66·99)인가, 초에 내려서면 squish 하고 심지가 꺼지며(hiss) 1/16 틱으로 6 px/s 가라앉다 16 에서 멈추나(sink_k·sink_v), 떠난 뒤 20초를 지키다 3초에 걸쳐 돌아오고 다시 불이 붙나(pop),
## 더 높은 옆 초로 걸으면 밀랍 벽에서 x 가 서나(307.5), 낮은 옆 초·계단 밖으로 걸으면 off 인가, 모르는 계단은 off 인가,
## 꼭대기를 지나는 몸·catch 안에서 내려서는 몸·꼭대기 밑 catch 안의 몸만 land 가 받나(멀리 위·밑·오르는 몸·옆·앞은 아니다), 가라앉은 첫 초는 발판에서 걸어 올라서지나(ramp), 꼭대기 초는 18199 에서 받나,
## 받침·받침 팔 둘·초 셋·소리가 그려지고 초마다 기둥·테·심지·불꽃·흘러내린 밀랍 둘·hiss·pop 인가, 자국만큼 기둥이 줄고 테가 내려오며 꺼진 초의 불꽃이 안 보이나, sink 자세가 무릎을 자국만큼 접고 골반을 내리며 꺼지는 동안 팔을 올리고 뒷발이 뜨나, 진짜 탑의 1..70층에서 plan 이 별밤 층에만 계단을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cc := ClimbCandle.new(); root.add_child(cc)
	var cn := ClimbLantern.new(); root.add_child(cn)
	var ci := ClimbIcicle.new(); root.add_child(ci)
	await process_frame
	print("PACK id=", cc.pack.get("id"), " kind=", cc.kind.size() > 0, " pose=", cc.pack.get("pose"), " themes=", cc.pack.get("themes"), " steps=%d tread=%.0f min_h=%.0f max_h=%.0f top_short=%.0f sag_v=%.1f max_sag=%.1f hold=%.1f set=%.1f catch=%.0f deck_d=%.0f rises(120)=%s rises(60)=%s rises(170)=%s (want 3 28 24 40 20 6.0 16.0 20.0 3.0 16 28 [29, 37, 33] [24, 28, 24] [36, 40, 40])" % [cc.steps(), cc.tread(), cc.min_h(), cc.max_h(), cc.top_short(), cc.sag_v(), cc.max_sag(), cc.hold_s(), cc.set_s(), cc.catch_px(), cc.deck_d(), cc.rises(120.0), cc.rises(60.0), cc.rises(170.0)])
	var plats: Array = [
		{ "id": "30.0", "x": 100.0, "y": 18100.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "30.1", "x": 420.0, "y": 18220.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "30.2", "x": 150.0, "y": 18330.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "30.3", "x": 435.0, "y": 18450.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "30.4", "x": 620.0, "y": 18470.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "30s", "x": 560.0, "y": 18480.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cc.plan(30, plats)
	var lit := cc.plan(30, plats, [{ "id": "30.L0", "kind": "lantern", "x": 272.0, "w": 164.0, "y": 18100.0, "len": 120.0 }])   # 장대(262..446, 18090..18320)가 30.0↔30.1 의 상자(276..368, 18101..18265)만 가른다 — 30.2↔30.3 (125) 이 남는다
	var iced := cc.plan(30, plats, [{ "id": "30.i1.0", "kind": "icicle", "x": 300.0, "y": 18210.0, "floor": 18100.0 }])   # 고드름(290..310, 18090..18430)이 30.0↔30.1 과 30.2↔30.3 (306..398, 18331..) 을 가른다 — 30.1↔30.2 (110, 332..424) 가 남는다
	var moved := plats.duplicate(true); moved.append({ "id": "30m", "x": 330.0, "y": 18150.0, "w": 60.0, "kind": "move", "z": -29.0, "d": 82.0, "amp": 80.0 })   # 진폭째(240..480, 18150) 30.0↔30.1 의 상자에 든다
	var movep := cc.plan(30, moved)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := cc.plan(30, mirror)
	var lib := cc.plan(10, plats); var f29 := cc.plan(29, plats); var f31 := cc.plan(31, plats); var f34 := cc.plan(34, plats); var f35 := cc.plan(35, plats); var f65 := cc.plan(65, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cc.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f %s→%s a_edge %.0f b_edge %.0f hs %s y_top %.0f x %.0f w %.0f y %.0f z %.0f d %.0f" % [float(v["dir"]), float(v["gap"]), String(v["a_id"]), String(v["b_id"]), float(v["a_edge"]), float(v["b_edge"]), str(v["hs"]), float(v["y_top"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["z"]), float(v["d"])]
	print("PLAN free=", free.map(show), " (want 1: 30.C0 dir 1 gap 140 30.0→30.1 wins over 30.2↔30.3 gap 125 and 30.1↔30.2 gap 110, 30.3↔30.4 gap 65 out: a_edge 280 b_edge 420 hs [29, 66, 99] y_top 18199 x 280 w 84 y 18100 z −48 d 28)")
	print("PLAN lit=", lit.map(show), " (want 30.C0 dir 1 gap 125 30.2→30.3 a_edge 310 b_edge 435 hs [29, 66, 99] y_top 18429 x 310) iced=", iced.map(show), " (want 30.C0 dir −1 gap 110 30.1→30.2 a_edge 420 b_edge 310 hs [26, 60, 90] y_top 18310 x 336) moved=", movep.map(func(v: Dictionary) -> String: return String(v["id"]) + " gap %.0f a_edge %.0f" % [float(v["gap"]), float(v["a_edge"])]), " (want 30.C0 gap 125 a_edge 310) right=", right.map(func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f a_edge %.0f b_edge %.0f x %.0f" % [float(v["dir"]), float(v["gap"]), float(v["a_edge"]), float(v["b_edge"]), float(v["x"])]), " (want 30.C0 dir −1 gap 140 a_edge 680 b_edge 540 x 596) lib=", lib.size(), " f29=", f29.size(), " f31=", f31.size(), " f34=", f34.size(), " f35=", f35.size(), " f65=", f65.size(), " (want 0 0 1 1 0 1)")
	var s: Dictionary = cc.stairs[0]
	var on: Dictionary = free[0]
	var z := C.PLAYER_Z
	var fig := Stick3D.new(); root.add_child(fig)
	var dt := 0.0625
	var squish: AudioStreamPlayer3D = s["squish"]; var hiss0: AudioStreamPlayer3D = (s["hiss"] as Array)[0]; var pop0: AudioStreamPlayer3D = (s["pop"] as Array)[0]
	# 가라앉기(1/16 틱): x 294(초 0)에 내려선다 — squish, y 18129, i 0; 1틱 자국 0.375 y 18128.625 hiss k 0.0234 v 1; 16틱 자국 6 y 18123; 42틱 15.75 y 18113.25 v 1; 43틱 16 y 18113 v 0;
	# 떠남(마지막 stand 2.6875): 22.0 자국 16 꺼진 채; 23.6875(지킴 끝 + 1초) 10.6667 y 18118.3333; 25.0 3.6667; 25.6875 0 불 pop
	cc.sync(0.0)
	var first := cc.land(294.0, 18135.0, 18125.0, z); var squish_w := squish.playing
	var got: Dictionary = {}
	for i in 43:
		var now := float(i + 1) * dt
		squish.stop(); hiss0.stop(); pop0.stop()
		cc.sync(now)
		var r := cc.stand(on, 294.0, dt, fig)
		if (i + 1) in [1, 16, 42, 43]: got[i + 1] = { "r": r, "sk": float(fig.get_meta("sink_k", 9.0)), "sv": float(fig.get_meta("sink_v", 9.0)), "hiss": hiss0.playing }
	var showt := func(k: int) -> String: var e: Dictionary = got[k]; var r: Dictionary = e["r"]; return "%d: x=%.1f y=%.4f dent=%.4f i=%d off=%s sk=%.4f sv=%.1f hiss=%s" % [k, float(r["x"]), float(r["y"]), float(r["dent"]), int(r["i"]), r["off"], float(e["sk"]), float(e["sv"]), e["hiss"]]
	print("SINK first: kind=%s y=%.0f i=%d step=%s ramp=%s squish=%s (want candle 18129 0 false false true) | " % [String(first.get("kind", "-")), float(first.get("y", 0.0)), int(first.get("i", -1)), first.get("step", "-"), first.get("ramp", "-"), squish_w], showt.call(1), " (want 294.0 18128.6250 0.3750 0 false 0.0234 1.0 true) | ", showt.call(16), " (want 18123.0000 6.0000 … hiss=false) | ", showt.call(42), " (want 18113.2500 15.7500 … sv=1.0) | ", showt.call(43), " (want 18113.0000 16.0000 … sk=1.0000 sv=0.0)")
	pop0.stop()
	cc.sync(22.0); var d22 := float((s["dents"] as Array)[0]); var lit22: bool = (s["lit"] as Array)[0]
	cc.sync(23.6875); var d23 := float((s["dents"] as Array)[0]); var y23 := cc.top_of(s, 0)
	cc.sync(25.0); var d25 := float((s["dents"] as Array)[0]); var lit25: bool = (s["lit"] as Array)[0]; var pop25 := pop0.playing
	cc.sync(25.6875); var d256 := float((s["dents"] as Array)[0]); var lit256: bool = (s["lit"] as Array)[0]; var pop256 := pop0.playing
	# 벽·내려섬(dt 0, 26.0): 초 0 에서 x 312(초 1, 더 높다)은 307.5 에 선다; cur 2 에서 x 320(초 1, 낮다)은 off y 18199; cur 0 에서 x 270 은 off y 18129; 모르는 계단은 off
	cc.sync(26.0)
	var wall := cc.stand(on, 312.0, 0.0, fig)
	s["cur"] = 2; var down := cc.stand(on, 320.0, 0.0, fig)
	s["cur"] = 0; var past := cc.stand(on, 270.0, 0.0, fig)
	var lost := cc.stand({ "id": "nope", "x": 5.0, "y": 7.0 }, 50.0, dt)
	print("HOLD 22.0: dent=%.4f lit=%s (want 16.0000 false) 23.6875: dent=%.4f y=%.4f (want 10.6667 18118.3333) 25.0: dent=%.4f lit=%s pop=%s (want 3.6667 false false) 25.6875: dent=%.4f lit=%s pop=%s (want 0.0000 true true) | WALL x=%.1f y=%.0f off=%s i=%d (want 307.5 18129 false 0) | DOWN off=%s y=%.0f i=%d (want true 18199 2) | PAST off=%s y=%.0f (want true 18129) | unknown: off=%s x=%.0f y=%.0f i=%d (want true 50 7 −1)" % [d22, lit22, d23, y23, d25, lit25, pop25, d256, lit256, pop256, float(wall["x"]), float(wall["y"]), wall["off"], int(wall["i"]), down["off"], float(down["y"]), int(down["i"]), past["off"], float(past["y"]), lost["off"], float(lost["x"]), float(lost["y"]), int(lost["i"])])
	# 착지(초 1 꼭대기 18166, x 322): 지나는 몸(18170→18160) 받는다; 10 위에서 내려서는 몸 step; 밑 11 의 몸 ramp; 24 위·26 밑·오르는 몸·옆(x 250)·앞(z −20)은 아니다; 꼭대기 초(x 350)는 18199; 자국 16 의 초 0 은 발판 높이 18100 에서 ramp(13 ≤ 16)
	var cross := cc.land(322.0, 18170.0, 18160.0, z); var step := cc.land(322.0, 18176.0, 18175.0, z); var ramp := cc.land(322.0, 18155.0, 18154.9, z)
	var high := cc.land(322.0, 18190.0, 18189.0, z); var low := cc.land(322.0, 18140.0, 18139.0, z); var rising := cc.land(322.0, 18160.0, 18161.0, z); var side := cc.land(250.0, 18120.0, 18119.0, z); var front := cc.land(322.0, 18170.0, 18160.0, -20.0)
	var top := cc.land(350.0, 18200.0, 18195.0, z)
	(s["dents"] as Array)[0] = 16.0; (s["rests"] as Array)[0] = 16.0
	var sunk := cc.land(294.0, 18100.0, 18099.9, z)
	print("LAND cross=%s y=%.0f i=%d x=%.0f w=%.0f z=%.0f d=%.0f step=%s ramp=%s (want candle 18166 1 280 84 −48 28 false false) | step: y=%.0f step=%s (want 18166 true) ramp: y=%.0f ramp=%s (want 18166 true) | high=%s low=%s rising=%s side=%s front=%s (want empty ×5) | top: y=%.0f i=%d (want 18199 2) | sunk: y=%.0f ramp=%s (want 18113 true)" % [String(cross.get("kind", "-")), float(cross.get("y", 0.0)), int(cross.get("i", -1)), float(cross.get("x", 0.0)), float(cross.get("w", 0.0)), float(cross.get("z", 0.0)), float(cross.get("d", 0.0)), cross.get("step", "-"), cross.get("ramp", "-"), float(step.get("y", 0.0)), step.get("step", "-"), float(ramp.get("y", 0.0)), ramp.get("ramp", "-"), high.is_empty(), low.is_empty(), rising.is_empty(), side.is_empty(), front.is_empty(), float(top.get("y", 0.0)), int(top.get("i", -1)), float(sunk.get("y", 0.0)), sunk.get("ramp", "-")])
	# 그림: 노드 아이 7(받침·팔 둘·초 셋·squish), 초 아이 6(기둥·꼭대기·밀랍 둘·hiss·pop), 꼭대기 아이 3(테·심지·불꽃); 노드 자리 −5.5556 502.7778 −1.3333, 초 0 x 0.3889;
	# 자국 16·꺼진 초 0: 기둥 scale 0.4483 y 0.1806(반 높이), 꼭대기 y 0.3611, 불꽃 안 보임; 되돌리면 1.0 0.8056 보임
	var node: Node3D = s["node"]; var cand0: Node3D = (s["cands"] as Array)[0]; var body0: Node3D = (s["waxes"] as Array)[0]; var top0: Node3D = (s["rims"] as Array)[0]; var flame0: Node3D = (s["flames"] as Array)[0]
	(s["lit"] as Array)[0] = false; cc._place(s); var sc_d := body0.scale.y; var by_d := body0.position.y; var ty_d := top0.position.y; var vis_d := flame0.visible
	(s["dents"] as Array)[0] = 0.0; (s["rests"] as Array)[0] = 0.0; (s["lit"] as Array)[0] = true; cc._place(s); var sc_f := body0.scale.y; var ty_f := top0.position.y; var vis_f := flame0.visible
	print("VISUAL node children=%d (want 7) cand children=%d (want 6) top children=%d (want 3) node pos=%.4f %.4f %.4f (want −5.5556 502.7778 −1.3333) cand0 x=%.4f (want 0.3889) | sunk: scale=%.4f body y=%.4f top y=%.4f flame=%s (want 0.4483 0.1806 0.3611 false) | set: scale=%.4f top y=%.4f flame=%s (want 1.0000 0.8056 true)" % [node.get_child_count(), cand0.get_child_count(), top0.get_child_count(), node.position.x, node.position.y, node.position.z, cand0.position.x, sc_d, by_d, ty_d, vis_d, sc_f, ty_f, vis_f])
	# 자세: 자국 반(sink_k 0.5, v 0): 골반 0.350 몸통 0.0360 (lean 0.08 × 0.45) 엉덩이 −0.275/−0.275 무릎 0.550 어깨 −0.100 어깨 z ∓0.700 팔꿈치 −0.300; 꺼지는 중(v 1): 골반 0.320 어깨 z ∓1.600 몸통 0.036..0.09, 뒷발 엉덩이 −0.275..−0.775 뒷무릎 0.55..1.15 의 회복 뜀
	fig.pose_request = "sink"
	fig.set_meta("sink_k", 0.5); fig.set_meta("sink_v", 0.0)
	await process_frame; await process_frame; await process_frame
	var early_z: float = (fig.shoulders[1.0] as Node3D).rotation.z
	for i in 60: await process_frame
	var pel_h := fig.pelvis.position.y; var torso_h := fig.torso.rotation.x; var hip_h: float = (fig.hips[1.0] as Node3D).rotation.x; var hip_hb: float = (fig.hips[-1.0] as Node3D).rotation.x; var knee_h: float = (fig.knees[1.0] as Node3D).rotation.x
	var sh_h: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz_h: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shz_hb: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var el_h: float = (fig.elbows[1.0] as Node3D).rotation.x
	fig.set_meta("sink_v", 1.0)
	var hip_lo := 0.0; var hip_hi := -9.0; var knee_hi := 0.0
	for i in 40:
		await process_frame
		hip_lo = minf(hip_lo, (fig.hips[-1.0] as Node3D).rotation.x); hip_hi = maxf(hip_hi, (fig.hips[-1.0] as Node3D).rotation.x); knee_hi = maxf(knee_hi, (fig.knees[-1.0] as Node3D).rotation.x)
	var pel_v := fig.pelvis.position.y; var torso_v := fig.torso.rotation.x; var shz_v: float = (fig.shoulders[1.0] as Node3D).rotation.z
	print("POSE early z=%.2f (want > −0.7: the arms have only begun to open) half: pelvis=%.3f (want 0.350) torso=%.4f (want 0.0360) hips=%.3f %.3f (want −0.275 −0.275) knee=%.3f (want 0.550) shoulder=%.3f (want −0.100) z=%.3f %.3f (want −0.700 0.700) elbow=%.3f (want −0.300) | sinking: pelvis=%.3f (want 0.320) torso=%.4f (want 0.036..0.09) z=%.3f (want −1.600) back hip %.3f..%.3f (want −0.775..−0.275 — the hop) back knee max=%.3f (want ≤ 1.150, > 0.55) pose_t=%.2f" % [early_z, pel_h, torso_h, hip_h, hip_hb, knee_h, sh_h, shz_h, shz_hb, el_h, pel_v, torso_v, shz_v, hip_lo, hip_hi, knee_hi, fig.pose_t])
	# 진짜 탑: 1..70층에 plan 이 찾는 계단 — 별밤 층 30..34, 65..69 중 등롱·고드름(taken)이 안 든 100..200 틈이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var ip: Array = ci.plan(n, pl); var lp: Array = cn.plan(n, pl, ip)
		var out2 := cc.plan(n, pl, lp + ip)
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f dy %.0f hs %s" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["b_y"]) - float(v["a_y"]), str(v["hs"])])]); count += out2.size()
	print("TOWER floors=", bands, " stairs=", count, " (want a subset of 30..34 and 65..69 — one each, never another theme; the last top ≈ dy − 20)")
	quit()
