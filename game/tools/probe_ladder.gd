extends SceneTree
## 서가 사다리 팩 점검(헤드리스): 자료가 읽히나, 서재 층의 선 발판(std·ice·spring·crumble) 사이 틈 하나에만 사다리가 서나(가장 긴 틈 한둘은 그 층의 다른 팩 몫 — 다리·유령 층은 하나, 버섯 층은 둘; 지름길 판이 서가를 가르는 틈은 지고, 통풍구 층·다른 테마 층은 아니다),
## 두 끝 자리·난간 높이·내리는 자리가 기하대로 나오나, 건너편의 사다리는 C 로 부르면 빈 채 굴러와 서고(clunk) 구르는 중엔 C 가 먹히지 않나, 닿는 거리 안의 C 만 올라타나,
## 오르는 길이 올라타기 → 가로대 오르기 → 구르기(가운데서 roll_v, 양 끝에서 0) → 위 발판 자리로 끝나고 메타가 적히나, 타다 놓으면 사다리의 속도를 주고 빈 채 마저 가나, 내려가는 길이 구르기 → 내려가기 → 아래 발판 자리로 끝나나, 모르는 사다리는 lost 인가,
## 서가·난간·레일·차가 그려지고 차가 사다리 자리를 따라가나, rail 자세가 오를 땐 손발을 엇갈려 올리고 구를 땐 뒷손이 난간·앞손이 앞·뒷발이 처지며 몸통이 가는 쪽으로 기우나, 진짜 탑의 1..65층에서 plan 이 서재 층에만 사다리를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cl := ClimbLadder.new(); root.add_child(cl)
	await process_frame
	print("PACK id=", cl.pack.get("id"), " kind=", cl.kind.size() > 0, " pose=", cl.pack.get("pose"), " themes=", cl.pack.get("themes"), " roll_v=%.0f (want 150) climb_v=%.0f (want 110) mount=%.2f (want 0.25)" % [cl.roll_v(), cl.climb_v(), cl.mount_s()])
	var plats: Array = [
		{ "id": "12.0", "x": 100.0, "y": 7300.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "12.1", "x": 380.0, "y": 7410.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "12.2", "x": 650.0, "y": 7520.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "12.3", "x": 400.0, "y": 7630.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "12.4", "x": 200.0, "y": 7740.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "12.5", "x": 25.0, "y": 7850.0, "w": 90.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "12s", "x": 550.0, "y": 7650.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var planned := cl.plan(12, plats)
	var two := cl.plan(13, plats)
	var vent := cl.plan(11, plats)
	var other := cl.plan(15, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cl.build(band_root, planned)
	print("PLAN n12=", planned.size(), " (want 1: gaps 100 (12.0↔12.1), 120 (12.1↔12.2), 130 (12.2↔12.3, the short slab 12s cuts its shelf box → out), 90 (12.3↔12.4), 85 (12.4↔12.5, under min_gap → out) — a bridge floor leaves the longest, 120, so the 100 gap gets the ladder: cx0 300 = 280 + 8 + 12, cx1 360, rail 7466 = 7410 + 56, xa 264, xb 396, dirx 1) ids=", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + " cx0 %.0f cx1 %.0f rail %.0f xa %.0f xb %.0f dirx %.0f a %s b %s x %.0f w %.0f" % [float(v["cx0"]), float(v["cx1"]), float(v["rail_y"]), float(v["xa"]), float(v["xb"]), float(v["dirx"]), v["a_id"], v["b_id"], float(v["x"]), float(v["w"])]), " n13=", two.map(func(v: Dictionary) -> String: return String(v["id"]) + " cx0 %.0f cx1 %.0f dirx %.0f" % [float(v["cx0"]), float(v["cx1"]), float(v["dirx"])]), " (want 13.L0 cx0 380 cx1 330 dirx −1: a mushroom floor leaves two, 120 and 100, so the 90 gap whose upper hop is to the left) n11=", vent.size(), " n15=", other.size(), " (want 0 0: vent floor, Clockwork) nodes=", band_root.get_child_count())
	var s: Dictionary = cl.ladders[0]
	var a: Dictionary = plats[0]; var b: Dictionary = plats[1]; var z := float(a["z"])
	print("TIMES roll_s=%.2f (want 0.60 = 60 × 1.5 / 150) climb_s=%.2f (want 1.00 = 110 / 110) parked lx=%.0f (want 300) lvx=%.0f (want 0)" % [cl.roll_s(s), cl.climb_s(s), cl.lx(s, 0.0), cl.lvx(s, 0.0)])
	# 부르기: 위 발판(12.1)에서 C — 사다리는 아래 끝에 서 있으니 빈 채 굴러온다(go 0, from 0, to 1); 0.3 초엔 가운데 330 에 150 px/s, 0.7 초엔 위 끝 360 에 서고 clunk; 구르는 중의 C 는 아무것도
	cl.sync(0.0)
	var called := cl.grab(b, 390.0, z)
	var mid_grab := {}
	cl.sync(0.3); cl._process(0.0)
	var mid_x := cl.lx(s, 0.3); var mid_v := cl.lvx(s, 0.3)
	mid_grab = cl.grab(a, 270.0, z)
	cl.sync(0.7); cl._process(0.0)
	var ck: AudioStreamPlayer3D = s["clunk"]
	print("CALL returned=%s (want empty: a call, not a mount) go=%.1f→ mid lx=%.0f (want 330) lvx=%.0f (want 150: mid-roll) grab while rolling=%s (want empty) | parked end=%d (want 1) lx=%.0f (want 360) clunk=%s (want true) stop=%.1f (want 0.7) car x=%.3f (want %.3f: 360 − 280 in metres)" % [called.is_empty(), 0.0, mid_x, mid_v, mid_grab.is_empty(), int(s["end"]), cl.lx(s, 0.7), ck.playing, float(s.get("stop", -1.0)), (s["car"] as Node3D).position.x, 80.0 * C.K])
	# 닿는 거리: 아래 발판에서 x 250 (50 px 떨어짐) 은 아무것도; 270 은 부른다(사다리가 위 끝에); 굴러오면 270 에서 올라탄다(dir +1)
	cl.sync(5.0)
	var far := cl.grab(a, 250.0, z); var far_end := int(s["end"]); var far_go := float(s.get("go", -9.0))
	var call2 := cl.grab(a, 270.0, z)
	cl.sync(5.8); cl._process(0.0)
	var g := cl.grab(a, 270.0, z)
	print("REACH x 250: returned=%s end=%d go=%.0f (want empty 1 −9: nothing happened) | x 270: call=%s (want empty: called) → at 5.8 end=%d (want 0) mount=%s dir=%.0f t0=%.1f x0=%.0f y0=%.0f (want 12.L0 1 5.8 270 7300) rider=%s (want true)" % [far.is_empty(), far_end, far_go, call2.is_empty(), int(s["end"]), g.get("id", "-"), float(g.get("dir", 0.0)), float(g.get("t0", 0.0)), float(g.get("x0", 0.0)), float(g.get("y0", 0.0)), bool(s["rider"])])
	# 오르는 길(t0 5.8): 5.9 올라타기(x 270→300 의 smoothstep 0.4 = 280.6, y 7300), 6.55 오르기 반(y 7355, c +1), 7.06 다 올라 구르기 시작(x 300, y 7410, go 7.06), 7.36 가운데(x 330, v 1.0), 7.7 다 굴러 위 발판 자리(x 396, y 7410, done)
	var fig := Stick3D.new(); root.add_child(fig)
	cl.sync(5.9); var r1 := cl.ride_on(g, fig)
	cl.sync(6.55); var r2 := cl.ride_on(g, fig); var m_c := float(fig.get_meta("rail_c", 9.0))
	cl.sync(7.06); var r3 := cl.ride_on(g, fig); var go_up := float(s.get("go", -9.0))
	cl.sync(7.36); cl._process(0.0); var r4 := cl.ride_on(g, fig); var m_v := float(fig.get_meta("rail_v", 9.0))
	cl.sync(7.7); cl._process(0.0); var r5 := cl.ride_on(g, fig); var rider_after := bool(s["rider"])
	var grab_busy := cl.grab(b, 390.0, z)
	print("UP mount x=%.1f y=%.0f (want 280.6 7300) | climb x=%.0f y=%.0f c=%.0f face=%.0f (want 300 7355 1 1) | roll start x=%.0f y=%.0f go=%.2f (want 300 7410 7.06) | mid x=%.0f v=%.2f (want 330 1.00) | done=%s x=%.0f y=%.0f (want true 396 7410) rider=%s (want false) end=%d (want 1) | grab from b at done tick=%s (want 12.L0: parked here, nobody on it)" % [float(r1["x"]), float(r1["y"]), float(r2["x"]), float(r2["y"]), m_c, float(r2["face"]), float(r3["x"]), float(r3["y"]), go_up, float(r4["x"]), m_v, r5["done"], float(r5["x"]), float(r5["y"]), rider_after, int(s["end"]), grab_busy.get("id", "-")])
	# 놓기: 방금 b 에서 올라탄 길(dir −1, t0 7.7) — 8.0 에 구르기 시작(go 8.0), 8.3 가운데(x 330, v −1.0)에서 ↓: let_go 가 −150 을 주고 사다리는 빈 채 8.6 에 아래 끝에 선다
	cl.sync(8.0); var d1 := cl.ride_on(grab_busy, fig); var go_dn := float(s.get("go", -9.0))
	cl.sync(8.3); cl._process(0.0); var d2 := cl.ride_on(grab_busy, fig); var m_v2 := float(fig.get_meta("rail_v", 9.0))
	var v := cl.let_go(grab_busy)
	cl.sync(8.7); cl._process(0.0)
	print("DROP roll start x=%.0f y=%.0f face=%.0f go=%.2f (want 360 7410 −1 8.00) | mid x=%.0f v=%.2f (want 330 −1.00) let_go vx=%.0f (want −150) rider=%s (want false) | empty ladder parked end=%d lx=%.0f (want 0 300)" % [float(d1["x"]), float(d1["y"]), float(d1["face"]), go_dn, float(d2["x"]), m_v2, float(v["vx"]), bool(s["rider"]), int(s["end"]), cl.lx(s, 8.7)])
	# 내려가는 길: 사다리를 위로 부르고(9.0 → 9.6) b 에서 올라타(t0 10.0) 10.3 구르기 시작, 10.9 다 굴러 내려가기 시작(y 7410, c −1), 11.4 반(y 7355), 11.9 아래 발판 자리(x 264, y 7300, done)
	cl.sync(9.0); cl.grab(b, 390.0, z); cl.sync(9.7); cl._process(0.0)
	cl.sync(10.0); var g2 := cl.grab(b, 390.0, z)
	cl.sync(10.3); var e1 := cl.ride_on(g2, fig)
	cl.sync(10.95); cl._process(0.0); var e2 := cl.ride_on(g2, fig); var m_c2 := float(fig.get_meta("rail_c", 9.0))
	cl.sync(11.45); var e3 := cl.ride_on(g2, fig)
	cl.sync(11.95); var e4 := cl.ride_on(g2, fig)
	var lost := cl.ride_on({ "id": "nope", "x0": 5.0, "y0": 7.0 })
	print("DOWN mount=%s dir=%.0f (want 12.L0 −1) | roll start x=%.0f y=%.0f (want 360 7410) | climb down start x=%.0f y=%.0f c=%.0f (want 300 7410 −1) | half y=%.0f (want 7355) | done=%s x=%.0f y=%.0f (want true 264 7300) | unknown: lost=%s x=%.0f y=%.0f (want true 5 7)" % [g2.get("id", "-"), float(g2.get("dir", 0.0)), float(e1["x"]), float(e1["y"]), float(e2["x"]), float(e2["y"]), m_c2, float(e3["y"]), e4["done"], float(e4["x"]), float(e4["y"]), lost["lost"], float(lost["x"]), float(lost["y"])])
	# 그림: 차 노드 아이 14(세로대 둘·갈고리 둘·바퀴 둘·가로대 일곱(22 px 마다, 0 은 빼고 154 까지)·clunk); 서가 노드에 선반 줄과 책 덩이들; 차가 사다리 자리에
	var node: Node3D = s["node"]; var car: Node3D = s["car"]
	print("VISUAL car children=", car.get_child_count(), " (want 14) node children=", node.get_child_count(), " (want > 40: wall, rail, brackets, track, car, shelves and book blocks) car x=%.3f (want %.3f: 300 − 280 in metres)" % [car.position.x, 20.0 * C.K])
	# 자세: 오르기(c +1) — 엉덩이가 −1.0 까지 들리고 어깨가 −2.9 까지 뻗으며 고개는 위를(≈ −0.3); 구르기(v 1, yaw 0 → 앞 = +x) — 앞다리(s +) 곧게 ≈ −0.08, 뒷다리(s −) 뒤로 ≈ 0.45 ± 0.08, 뒷손 −2.8, 앞손 −1.5, 몸통 ≈ 0.28
	fig.pose_request = "rail"
	fig.set_meta("rail_c", 1.0); fig.set_meta("rail_v", 0.0)
	await process_frame; await process_frame; await process_frame
	var early: float = (fig.shoulders[1.0] as Node3D).rotation.x
	for i in 20: await process_frame   # 잡기(0.2초)가 끝난 뒤부터 잰다
	var lo := 10.0; var hi := -10.0; var slo := 10.0; var nk := 0.0
	for i in 200:
		await process_frame
		var hv: float = (fig.hips[1.0] as Node3D).rotation.x; var sv: float = (fig.shoulders[1.0] as Node3D).rotation.x
		lo = minf(lo, hv); hi = maxf(hi, hv); slo = minf(slo, sv); nk = fig.neck.rotation.x
	fig.set_meta("rail_c", 0.0); fig.set_meta("rail_v", 1.0)
	for i in 60: await process_frame
	var fh: float = (fig.hips[1.0] as Node3D).rotation.x; var bh: float = (fig.hips[-1.0] as Node3D).rotation.x
	var fs: float = (fig.shoulders[1.0] as Node3D).rotation.x; var bs: float = (fig.shoulders[-1.0] as Node3D).rotation.x
	print("POSE early=%.2f (want > −1.5: the grab has only begun) climbing: hip lo=%.2f hi=%.2f (want lo ≤ −0.9, hi ≥ −0.4: a leg lifts to the next rung and sets) shoulder lo=%.2f (want ≤ −2.8: a hand reaches the rung above) neck=%.2f (want ≈ −0.3: looking up) | rolling: front hip=%.2f (want ≈ −0.08) back hip=%.2f (want 0.45 ± 0.1: trailing) front arm=%.2f (want −1.50) back arm=%.2f (want −2.80: on the rail) torso=%.3f (want ≈ 0.13: the 0.28 lean after the figure's blend, like wade's 0.25 → 0.11)" % [early, lo, hi, slo, nk, fh, bh, fs, bs, fig.torso.rotation.x])
	# 진짜 탑: 1..65층에 plan 이 찾는 사다리 — 서재 층 10, 12, 13, 14, 45, 46, 48, 49 중 틈이 맞는 층(11, 47 은 통풍구 층)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 66):
		var pl := cl.plan(n, gm.band(n))
		if pl.size() > 0: bands.append("%d:%d" % [n, pl.size()]); count += pl.size()
	print("TOWER floors=", bands, " ladders=", count, " (want a subset of 10, 12, 13, 14, 45, 46, 48, 49, one each)")
	quit()
