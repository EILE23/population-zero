extends SceneTree
## 덤웨이터 팩 점검(헤드리스): 자료가 읽히나, 서재 층의 둘 건너 선 발판(std·ice) 중 160..330 px 높이차로 104 px 이상 겹친 짝의 가장 넓은 겹침 하나에만 덤웨이터가 서나(지름길 판이 기둥을 가르는 짝은 지고, 통풍구 층·다른 테마 층은 아니다),
## 건너편의 상자는 C 로 부르면 빈 채 와 서고(clack) 가는 중엔 C 가 먹히지 않나, 닿는 거리 안의 C 만 올라타나, 오르는 길이 올라타기 → 당김(36 px, 0.3초) → 멈춤(0.4초) → 되미끄러짐(30 px/s) → 당김마다 36 px 씩 → 위 발판 높이에서 끝나고 메타가 적히나,
## 내려가는 길이 제동 하강(2.75초, 가운데 120 px/s)으로 바닥에서 끝나나, 타다 놓으면 상자의 세로 속도를 주고 빈 상자가 가까운 끝으로 가나, 모르는 덤웨이터는 lost 인가,
## 레일·들보·도르래·줄·평형추·상자가 그려지고 줄 길이와 평형추가 상자를 따라가나, heave 자세가 당길 땐 손을 바꿔 위·가슴을 오가고 제동하면 두 손이 위 줄·무릎이 굽나, 진짜 탑의 1..65층에서 plan 이 서재 층에만 덤웨이터를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cd := ClimbDumbwaiter.new(); root.add_child(cd)
	await process_frame
	print("PACK id=", cd.pack.get("id"), " kind=", cd.kind.size() > 0, " pose=", cd.pack.get("pose"), " themes=", cd.pack.get("themes"), " pull=%.0f (want 36) heave_s=%.2f (want 0.30) hold_s=%.2f (want 0.40) slip=%.0f (want 30) down_v=%.0f (want 120) call_v=%.0f (want 160) mount=%.2f (want 0.25)" % [cd.pull(), cd.heave_s(), cd.hold_s(), cd.slip_v(), cd.down_v(), cd.call_v(), cd.mount_s()])
	var plats: Array = [
		{ "id": "12.0", "x": 100.0, "y": 7300.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "12.1", "x": 380.0, "y": 7410.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "12.2", "x": 120.0, "y": 7520.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "12.3", "x": 400.0, "y": 7630.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "12.4", "x": 150.0, "y": 7740.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "12.5", "x": 420.0, "y": 7850.0, "w": 90.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "12s", "x": 430.0, "y": 7500.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var planned := cd.plan(12, plats)
	var two := cd.plan(13, plats)
	var vent := cd.plan(11, plats)
	var other := cd.plan(15, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cd.build(band_root, planned)
	print("PLAN n12=", planned.size(), " (want 1: pairs 12.0↔12.2 overlap 120..280 = 160 dy 220 ✓, 12.1↔12.3 overlap 400..520 = 120 but the short slab 12s cuts the shaft → out, 12.2↔12.4 overlap 150..260 = 110 dy 220 ✓ but narrower, 12.3↔12.5 overlap 420..510 = 90 < 104 → out; so hx 200, a 7300, b 7520, beam 7616) ids=", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + " hx %.0f a %.0f b %.0f beam %.0f a_id %s b_id %s x %.0f w %.0f" % [float(v["hx"]), float(v["a_y"]), float(v["b_y"]), float(v["beam_y"]), v["a_id"], v["b_id"], float(v["x"]), float(v["w"])]), " n13=", two.map(func(v: Dictionary) -> String: return String(v["id"]) + " hx %.0f" % float(v["hx"])), " (want 13.D0 hx 200: same shape, the residue-1 piece) n11=", vent.size(), " n15=", other.size(), " (want 0 0: vent floor, Clockwork) nodes=", band_root.get_child_count())
	var s: Dictionary = cd.lifts[0]
	var a: Dictionary = plats[0]; var b: Dictionary = plats[2]; var z := float(a["z"])
	print("TIMES desc_s=%.2f (want 2.75 = 220 × 1.5 / 120) parked cy=%.0f (want 7300) cvy=%.0f (want 0)" % [cd.desc_s(s), cd.cy(s, 0.0), cd.cvy(s, 0.0)])
	# 부르기: 위 발판(12.2)에서 C — 상자는 바닥에 서 있으니 빈 채 올라온다(go 0, gy 7300, to 1; 220 × 1.5 / 160 = 2.0625 초); 1.03 초엔 가운데 7410 에 160 px/s, 2.1 초엔 꼭대기에 서고 clack; 가는 중의 C 는 아무것도
	cd.sync(0.0)
	var called := cd.grab(b, 210.0, z)
	cd.sync(1.03125); cd._process(0.0)
	var mid_y := cd.cy(s, 1.03125); var mid_v := cd.cvy(s, 1.03125)
	var mid_grab := cd.grab(a, 200.0, z)
	cd.sync(2.1); cd._process(0.0)
	var ck: AudioStreamPlayer3D = s["clack"]
	print("CALL returned=%s (want empty: a call, not a mount) go=%.1f gy=%.0f to=%d (want 0.0 7300 1) → mid cy=%.0f (want 7410) cvy=%.0f (want 160: mid-glide) grab while gliding=%s (want empty) | parked end=%d (want 1) cy=%.0f (want 7520) clack=%s (want true) car y=%.3f (want %.3f: 220 px in metres)" % [called.is_empty(), 0.0, float(s["gy"]), int(s["to"]), mid_y, mid_v, mid_grab.is_empty(), int(s["end"]), cd.cy(s, 2.1), ck.playing, (s["car"] as Node3D).position.y, 220.0 * C.K])
	# 닿는 거리: 아래 발판에서 x 150 (50 px 떨어짐) 은 아무것도; 230 은 부른다(상자가 꼭대기에); 내려오면(5.0 → 7.0625) 230 에서 올라탄다(dir +1)
	cd.sync(5.0)
	var far := cd.grab(a, 150.0, z); var far_end := int(s["end"]); var far_go := float(s.get("go", -9.0))
	var call2 := cd.grab(a, 230.0, z)
	cd.sync(7.1); cd._process(0.0)
	var g := cd.grab(a, 230.0, z)
	print("REACH x 150: returned=%s end=%d go=%.0f (want empty 1 −9: nothing happened) | x 230: call=%s (want empty: called) → at 7.1 end=%d (want 0) mount=%s dir=%.0f t0=%.1f x0=%.0f y0=%.0f (want 12.D0 1 7.1 230 7300) rider=%s mode=%d (want true 1)" % [far.is_empty(), far_end, far_go, call2.is_empty(), int(s["end"]), g.get("id", "-"), float(g.get("dir", 0.0)), float(g.get("t0", 0.0)), float(g.get("x0", 0.0)), float(g.get("y0", 0.0)), bool(s["rider"]), int(s["mode"])])
	# 오르는 길(t0 7.1): 7.2 올라타기(x 230→200 의 smoothstep 0.4 = 219.4, y 7300); 올라타는 중의 C 는 당김이 아니다; 7.4 당김(pf 7300 pto 7336) → 7.55 가운데 7318 (heave_k 0.5, 속도 180 → hv 1.0), 7.75 멈춤 7336, 8.4 되미끄러짐 7327 (0.3 s × 30)
	var fig := Stick3D.new(); root.add_child(fig)
	cd.sync(7.2); var early := cd.heave(g); var r1 := cd.ride_on(g, fig)
	cd.sync(7.4); var h1 := cd.heave(g); var pf := float(s["pf"]); var pto := float(s["pto"])
	cd.sync(7.55); var r2 := cd.ride_on(g, fig); var m_k := float(fig.get_meta("heave_k", 9.0)); var m_v := float(fig.get_meta("heave_v", 9.0)); var m_h := float(fig.get_meta("heave_h", 9.0))
	cd.sync(7.75); var r3 := cd.ride_on(g, fig); var m_k2 := float(fig.get_meta("heave_k", 9.0))
	cd.sync(8.4); var r4 := cd.ride_on(g, fig); var m_v2 := float(fig.get_meta("heave_v", 9.0))
	var click: AudioStreamPlayer3D = s["click"]
	print("UP mount x=%.1f y=%.0f (want 219.4 7300) early heave=%s (want false) | heave=%s pf=%.0f pto=%.0f (want true 7300 7336) click=%s (want true) hand=%.0f (want −1) | mid x=%.0f y=%.0f k=%.2f v=%.2f h=%.0f (want 200 7318 0.50 1.00 −1) | held y=%.0f k=%.2f (want 7336 0.00) | slipping y=%.0f v=%.2f (want 7327 −0.25 = −30 / 120)" % [float(r1["x"]), float(r1["y"]), early, h1, pf, pto, click.playing, float(s["hand"]), float(r2["x"]), float(r2["y"]), m_k, m_v, m_h, float(r3["y"]), m_k2, float(r4["y"]), m_v2])
	# 당김 여섯 번(8.4 부터 0.35 초마다 — 멈춤 안에서 다음 당김): 7327 → 7363 → 7399 → 7435 → 7471 → 7507 → 7520(꼭대기에서 멈춘다); 마지막 당김 0.3 초 뒤 done, x 200 y 7520, 상자는 꼭대기에 서고(end 1) clack
	var tt := 8.4; var ys: Array = []
	for i in 6:
		cd.sync(tt); cd.heave(g); tt += 0.35
		cd.sync(tt - 0.05); ys.append("%.0f" % float(cd.ride_on(g, fig)["y"]))
	var t_done := tt - 0.35 + 0.3
	cd.sync(t_done); var r5 := cd.ride_on(g, fig); var rider_after := bool(s["rider"])
	var grab_busy := cd.grab(b, 220.0, z)
	print("HEAVES ys=", ys, " (want 7363 7399 7435 7471 7507 7520) | done=%s x=%.0f y=%.0f (want true 200 7520) rider=%s (want false) end=%d (want 1) clack=%s (want true) | grab from b at done tick=%s dir=%.0f (want 12.D0 −1: parked here, nobody in it)" % [r5["done"], float(r5["x"]), float(r5["y"]), rider_after, int(s["end"]), ck.playing, grab_busy.get("id", "-"), float(grab_busy.get("dir", 0.0))])
	# 내려가는 길(t0 = t_done): 올라타기 0.25 → 제동 하강 2.75 (가운데 1.375 초에 7410, 120 px/s → hv −1.0; 당김은 안 먹힌다) → 3.0 초에 바닥, done, x 200 y 7300, end 0
	cd.sync(t_done + 0.1); var d1 := cd.ride_on(grab_busy, fig)
	cd.sync(t_done + 0.25 + 1.375); var d_heave := cd.heave(grab_busy); var d2 := cd.ride_on(grab_busy, fig); var m_v3 := float(fig.get_meta("heave_v", 9.0))
	cd.sync(t_done + 3.0); var d3 := cd.ride_on(grab_busy, fig)
	print("DOWN mount y=%.0f (want 7520) | mid y=%.0f v=%.2f heave=%s (want 7410 −1.00 false) | done=%s x=%.0f y=%.0f (want true 200 7300) end=%d (want 0)" % [float(d1["y"]), float(d2["y"]), m_v3, d_heave, d3["done"], float(d3["x"]), float(d3["y"]), int(s["end"])])
	# 놓기: 바닥에서 올라타(t0 20.0) 20.3 당김, 20.45 가운데(7318, 오르는 중)에서 SPACE: let_go 가 +180 을 주고 빈 상자는 가까운 끝(바닥)으로 가서 선다(gy 7318 → 7300, 18 × 1.5 / 160 = 0.17 초)
	cd.sync(20.0); var g3 := cd.grab(a, 200.0, z)
	cd.sync(20.3); cd.heave(g3)
	cd.sync(20.45); var v := cd.let_go(g3); var to_end := int(s["to"]); var gy := float(s["gy"])
	cd.sync(20.7); cd._process(0.0)
	var lost := cd.ride_on({ "id": "nope", "x0": 5.0, "y0": 7.0 })
	print("DROP let_go vy=%.0f (want 180: mid-heave, 36 × 1.5 / 0.3) rider=%s (want false) to=%d gy=%.0f (want 0 7318: the nearer end) | at 20.7 end=%d cy=%.0f (want 0 7300) | unknown: lost=%s x=%.0f y=%.0f (want true 5 7)" % [float(v["vy"]), bool(s["rider"]), to_end, gy, int(s["end"]), cd.cy(s, 20.7), lost["lost"], float(lost["x"]), float(lost["y"])])
	# 그림: 노드 아이 9(레일 둘·들보·도르래 둘·줄 둘·평형추·상자), 상자 아이 11(바닥·벽 넷·책 둘·고리 둘·click·clack); 바닥에 선 상자의 줄은 8.68 − 1.5 = 7.18 m, 평형추는 도르래 밑 0.5 m
	var node: Node3D = s["node"]; var car: Node3D = s["car"]; var rope: Node3D = s["rope"]; var weight: Node3D = s["weight"]
	print("VISUAL node children=", node.get_child_count(), " (want 9) car children=", car.get_child_count(), " (want 11) car y=%.3f (want 0.000) rope len=%.2f (want 7.18) weight y=%.2f (want 8.18 = beam 8.68 − 0.5)" % [car.position.y, rope.scale.y, weight.position.y])
	# 자세: 쉬는 손(k 0, hand +1): 당긴 손(s +) 가슴 −1.3, 다른 손(s −) 위 −2.7; 당김 시작(k 1): 당기는 손 위 −2.7, 다른 손 가슴 −1.3; 제동(v −1): 두 손 위 ≈ −2.6, 무릎 ≈ 0.55, 고개 발밑 ≈ +0.35
	fig.pose_request = "heave"
	fig.set_meta("heave_k", 0.0); fig.set_meta("heave_h", 1.0); fig.set_meta("heave_v", 0.0)
	await process_frame; await process_frame; await process_frame
	var early_sh: float = (fig.shoulders[-1.0] as Node3D).rotation.x
	for i in 60: await process_frame   # 잡기(0.2초)가 끝난 뒤부터 잰다(헤드리스 프레임은 짧을 수 있다)
	var rest_pull: float = (fig.shoulders[1.0] as Node3D).rotation.x; var rest_other: float = (fig.shoulders[-1.0] as Node3D).rotation.x
	fig.set_meta("heave_k", 1.0)
	for i in 30: await process_frame   # 그림의 관절 블렌딩이 따라올 때까지(놀이에선 heave_k 가 0.3초에 걸쳐 흐른다)
	var start_pull: float = (fig.shoulders[1.0] as Node3D).rotation.x; var start_other: float = (fig.shoulders[-1.0] as Node3D).rotation.x
	fig.set_meta("heave_k", 0.0); fig.set_meta("heave_v", -1.0)
	for i in 30: await process_frame
	var br_a: float = (fig.shoulders[1.0] as Node3D).rotation.x; var br_b: float = (fig.shoulders[-1.0] as Node3D).rotation.x
	var br_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var br_neck := fig.neck.rotation.x
	print("POSE early=%.2f (want > −2.0: the grab has only begun) resting: pulled hand=%.2f (want −1.30) other=%.2f (want −2.70) | pull start: pulling hand=%.2f (want −2.70) other=%.2f (want −1.30) | braking: hands=%.2f %.2f (want ≈ −2.6 both) knee=%.2f (want ≈ 0.55) neck=%.2f (want ≈ 0.35: looking down) torso=%.3f (want > 0: a little forward)" % [early_sh, rest_pull, rest_other, start_pull, start_other, br_a, br_b, br_knee, br_neck, fig.torso.rotation.x])
	# 진짜 탑: 1..65층에 plan 이 찾는 덤웨이터 — 서재 층 10, 12, 13, 14, 45, 46, 48, 49 중 겹친 짝이 있는 층(11, 47 은 통풍구 층)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 66):
		var pl := cd.plan(n, gm.band(n))
		if pl.size() > 0: bands.append("%d:%s" % [n, pl.map(func(v: Dictionary) -> String: return "%s↔%s hx %.0f dy %.0f" % [v["a_id"], v["b_id"], float(v["hx"]), float(v["b_y"]) - float(v["a_y"])])]); count += pl.size()
	print("TOWER floors=", bands, " dumbwaiters=", count, " (want a subset of 10, 12, 13, 14, 45, 46, 48, 49, one each)")
	quit()
