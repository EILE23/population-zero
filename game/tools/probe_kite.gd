extends SceneTree
## 연줄 팩 점검(헤드리스): 자료가 읽히나, 바람 절벽 층의 잇단 still 발판 짝(60..200 px 틈, 위 발판이 150 px 안으로 높다) 중 바람 아래쪽의 가장 넓은 틈 하나에만 연이 서나(바람이 없으면 어느 쪽이든, 바람이 있으면 그쪽만; 지름길 판·겹친 턱이 상자를 가르는 짝은 지고, 다른 테마 층은 아니다),
## 닿는 거리 안의 ↑ 만 잡나(snap), 끌려가는 길이 속도가 붙고(0.25초) 내려앉고(12 px, 0.4초) 건너편 발판 위로 20 px 들어서면 내려놓기(0.3초, 드리프트 반)로 발판 윗면에서 끝나고 메타가 적히나,
## 놓으면 연의 속도를 주고(flap) 빈 연이 2초에 걸쳐 돌아오며 그동안 잡히지 않나, 집에 오면 흔들림이 돌아오나, 모르는 연은 lost 인가,
## 말뚝·실패·연줄·연(돛·살·줄·토글·꼬리)이 그려지고 연줄이 실패에서 돛까지 이어지나, kite 자세가 두 손을 머리 위 한 줄로 모으고 다리가 뒤로 흐르다 내려놓으면 앞으로 오나, 진짜 탑의 1..65층에서 plan 이 바람 절벽 층에만 연을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var ck := ClimbKite.new(); root.add_child(ck)
	await process_frame
	print("PACK id=", ck.pack.get("id"), " kind=", ck.kind.size() > 0, " pose=", ck.pack.get("pose"), " themes=", ck.pack.get("themes"), " hang=%.0f (want 58) ease=%.2f (want 0.25) land=%.2f (want 0.30) return=%.1f (want 2.0) v(0)=%.0f v(80)=%.0f v(400)=%.0f (want 150 190 260)" % [ck.hang(), ck.ease_s(), ck.land_s(), ck.return_s(), ck.speed_for(0.0), ck.speed_for(80.0), ck.speed_for(400.0)])
	var plats: Array = [
		{ "id": "20.0", "x": 100.0, "y": 12100.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "20.1", "x": 370.0, "y": 12210.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "20.2", "x": 110.0, "y": 12320.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "20.3", "x": 380.0, "y": 12480.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "20.4", "x": 560.0, "y": 12590.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "20.5", "x": 400.0, "y": 12700.0, "w": 90.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "20s", "x": 600.0, "y": 12248.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var gust := ck.plan(20, plats, 0.0)
	var east := ck.plan(20, plats, 80.0)
	var west := ck.plan(20, plats, -80.0)
	var other := ck.plan(25, plats, 0.0)
	var band_root := Node3D.new(); root.add_child(band_root)
	ck.build(band_root, east)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " hx %.0f dir %.0f gap %.0f feet %.0f hand %.0f kite %.0f peg %.0f drift %.0f v %.0f x %.0f w %.0f" % [float(v["hx"]), float(v["dir"]), float(v["gap"]), float(v["feet_y"]), float(v["hand_y"]), float(v["kite_y"]), float(v["peg_x"]), float(v["drift"]), float(v["v"]), float(v["x"]), float(v["w"])]
	print("PLAN gust=", gust.map(show), " (want 1: 20.1↔20.2 gap 100 left wins over 20.0↔20.1 gap 90; 20.2↔20.3 gap 110 but dy 160 > 150 → out; 20.3↔20.4 gap 60 but 20.5 cuts the box → out; so hx 330 dir −1 feet 12340 hand 12398 kite 12518 peg 384 drift 250 v 150 x 270 w 100)")
	print("PLAN east=", east.map(show), " (want 1: only 20.0↔20.1 lies downwind — hx 316 dir 1 gap 90 feet 12230 hand 12288 kite 12408 peg 266 drift 234 v 190 x 280 w 90) west=", west.map(func(v: Dictionary) -> String: return String(v["id"]) + " hx %.0f dir %.0f v %.0f" % [float(v["hx"]), float(v["dir"]), float(v["v"])]), " (want 20.K0 hx 330 dir −1 v 190) other=", other.size(), " (want 0: Cloud sea) nodes=", band_root.get_child_count())
	var s: Dictionary = ck.kites[0]
	var z := float(plats[0]["z"])
	# 닿는 거리(t 0: 흔들림 0): 발 12230 손 12288 — x 316 은 잡힌다; x 350 (34 떨어짐) 과 발 12190 (손 12248, 40 아래) 은 아니다
	ck.sync(0.0)
	var far := ck.grab(350.0, 12230.0, z); var low := ck.grab(316.0, 12190.0, z)
	var g := ck.grab(316.0, 12230.0, z)
	var sn: AudioStreamPlayer3D = s["snap"]
	print("REACH far=%s low=%s (want empty empty) | caught=%s x=%.0f y=%.0f dir=%.0f t0=%.1f (want 20.K0 316 12230 1 0.0) held=%s snap=%s (want true true)" % [far.is_empty(), low.is_empty(), g.get("id", "-"), float(g.get("x", 0.0)), float(g.get("y", 0.0)), float(g.get("dir", 0.0)), float(g.get("t0", 9.0)), bool(s["held"]), sn.playing])
	# 끌려가는 길(v 190, ease 0.25): 0.1 → 거리 2·190·0.01 = 3.8 (x 319.8), 내려앉음 3 (발 12227), kite_v 0.4; 0.5 → 71.25 (x 387.25, 발 12218, 아직 390 전); 0.6 → 90.25 (x 406.25 ≥ 390: 내려놓기 시작, 발 12218); 0.75 → ks 0.5: x 427.6 발 12214 kite_v 0.75; 0.9 → ks 1: x 434.75 발 12210 done, snap, 연은 118.75 밀린 채 놓인다
	var fig := Stick3D.new(); root.add_child(fig)
	ck.sync(0.1); var r1 := ck.hang_on(g, fig); var v1 := float(fig.get_meta("kite_v", 9.0))
	ck.sync(0.5); var r2 := ck.hang_on(g, fig); var set_a := float(s["set0"])
	ck.sync(0.6); var r3 := ck.hang_on(g, fig); var set_b := float(s["set0"])
	ck.sync(0.75); var r4 := ck.hang_on(g, fig); var v4 := float(fig.get_meta("kite_v", 9.0)); var k4 := float(fig.get_meta("kite_set", 9.0))
	ck.sync(0.9); var r5 := ck.hang_on(g, fig); var k5 := float(fig.get_meta("kite_set", 9.0))
	print("DRAG 0.1: x=%.1f y=%.0f v=%.2f (want 319.8 12227 0.40) | 0.5: x=%.2f y=%.0f set0=%.0f (want 387.25 12218 −9) | 0.6: x=%.2f y=%.0f set0=%.1f (want 406.25 12218 0.6) | 0.75: x=%.1f y=%.0f v=%.2f set=%.2f (want 427.6 12214 0.75 0.50) | 0.9: done=%s x=%.2f y=%.0f set=%.2f (want true 434.75 12210 1.00) held=%s rel=%.1f roff=%.2f rdip=%.0f (want false 0.9 118.75 12) snap=%s (want true)" % [float(r1["x"]), float(r1["y"]), v1, float(r2["x"]), float(r2["y"]), set_a, float(r3["x"]), float(r3["y"]), set_b, float(r4["x"]), float(r4["y"]), v4, k4, r5["done"], float(r5["x"]), float(r5["y"]), k5, bool(s["held"]), float(s["rel"]), float(s["roff"]), float(s["rdip"]), sn.playing])
	# 돌아오기(0.9 → 2.9): 1.5 엔 잡히지 않는다; 1.9 엔 반(59.375 밀림, 6 내려앉음 → 토글 375.4, 12282; 연 노드 x 1.649 m); 2.9 엔 제자리; 4.0 엔 집에서 흔들림 0 (sway 0.25Hz·bob 0.5Hz 모두 영점) 이라 316, 12288 에서 다시 잡힌다
	ck.sync(1.5); var busy := ck.grab(316.0, 12230.0, z)
	ck.sync(1.9); ck._process(0.0); var tg := ck.toggle(s, 1.9); var kx: float = (s["kite"] as Node3D).position.x
	ck.sync(2.9); var home := ck.toggle(s, 2.9)
	ck.sync(4.0); var g2 := ck.grab(316.0, 12230.0, z)
	print("RETURN grab while returning=%s (want empty) | 1.9: toggle=%.1f %.0f (want 375.4 12282) kite x=%.3f (want 1.649) | 2.9: toggle=%.1f %.0f (want 316 12288) | 4.0: caught=%s t0=%.1f (want 20.K0 4.0)" % [busy.is_empty(), tg.x, tg.y, kx, home.x, home.y, g2.get("id", "-"), float(g2.get("t0", 9.0))])
	# 놓기(t0 4.0): 4.5 에 SPACE — vx 190 (속도가 다 붙었다), 연은 71.25 밀린 채 놓여 5.5 엔 반(35.625 → 0.990 m); 5.0 의 잡기는 안 된다; 모르는 연은 lost
	ck.sync(4.5); var v := ck.let_go(g2); var roff2 := float(s["roff"])
	var fl: AudioStreamPlayer3D = s["flap"]; var flap_on := fl.playing
	ck.sync(5.0); var busy2 := ck.grab(316.0, 12230.0, z)
	ck.sync(5.5); ck._process(0.0); var kx2: float = (s["kite"] as Node3D).position.x
	var lost := ck.hang_on({ "id": "nope", "x": 5.0, "y": 7.0 })
	print("LETGO vx=%.0f vy=%.0f (want 190 0) held=%s roff=%.2f (want false 71.25) flap=%s (want true) | 5.0 grab=%s (want empty) | 5.5 kite x=%.3f (want 0.990) | unknown: lost=%s x=%.0f y=%.0f (want true 5 7)" % [float(v["vx"]), float(v["vy"]), bool(s["held"]), roff2, flap_on, busy2.is_empty(), kx2, lost["lost"], float(lost["x"]), float(lost["y"])])
	# 그림: 노드 아이 4(말뚝·실패·연줄·연), 연 아이 9(돛 노드·줄·토글·꼬리 줄·고리 셋·snap·flap); 집의 연줄은 실패(−1.389, −4.962)에서 돛(0, 3.333)까지 ≈ 8.41 m
	ck.sync(8.0); ck._process(0.0)
	var node: Node3D = s["node"]; var kite: Node3D = s["kite"]; var tether: Node3D = s["tether"]
	print("VISUAL node children=", node.get_child_count(), " (want 4) kite children=", kite.get_child_count(), " (want 9) kite pos=%.3f %.3f (want 0 0: home at 8.0) tether len=%.2f (want ≈ 8.41) tether mid y=%.2f (want ≈ −0.81 = (−4.96 + 3.33) / 2)" % [kite.position.x, kite.position.y, tether.scale.y, tether.position.y])
	# 자세: 매달림(v 1, set 0): 두 어깨 −2.95 (한 줄로), 엉덩이 ≈ +0.6 ± 0.17 (뒤로 흐른다), 무릎 ≈ 0.7 ± 0.17, 고개 −0.45 ; 내려놓기(set 1): 엉덩이 −0.2, 무릎 0.25, 고개 0
	fig.pose_request = "kite"
	fig.set_meta("kite_v", 1.0); fig.set_meta("kite_set", 0.0)
	await process_frame; await process_frame; await process_frame
	var early_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	for i in 60: await process_frame   # 잡기(0.2초)가 끝난 뒤부터 잰다(헤드리스 프레임은 짧을 수 있다)
	var sh_a: float = (fig.shoulders[1.0] as Node3D).rotation.x; var sh_b: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var shz: float = (fig.shoulders[1.0] as Node3D).rotation.z
	var hip_h: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_h: float = (fig.knees[1.0] as Node3D).rotation.x; var neck_h := fig.neck.rotation.x; var torso_h := fig.torso.rotation.x
	fig.set_meta("kite_set", 1.0)
	for i in 30: await process_frame   # 그림의 관절 블렌딩이 따라올 때까지
	var hip_s: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_s: float = (fig.knees[1.0] as Node3D).rotation.x; var neck_s := fig.neck.rotation.x; var torso_s := fig.torso.rotation.x
	print("POSE early=%.2f (want > −2.0: the grab has only begun) hanging: shoulders=%.2f %.2f (want −2.95 both) z=%.3f (want −0.020: arms together) hip=%.2f (want ≈ 0.6 ± 0.17: trailing) knee=%.2f (want ≈ 0.7 ± 0.17) neck=%.2f (want ≈ −0.73 = −0.45 looking up on top of the −0.7 × 0.4 lean the rig gives the head) torso=%.3f (want > 0: leaning the way it goes) | set down: hip=%.2f (want −0.20) knee=%.2f (want 0.25) neck=%.2f (want ≈ 0) torso=%.3f (want ≈ 0)" % [early_sh, sh_a, sh_b, shz, hip_h, knee_h, neck_h, torso_h, hip_s, knee_s, neck_s, torso_s])
	# 진짜 탑: 1..65층에 plan 이 찾는 연 — 바람 절벽 층 20..24 (돌풍) 와 55..59 (그 층의 바람과 같은 쪽 짝이 있을 때만)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 66):
		var pl := ck.plan(n, gm.band(n), gm.wind_of(n))
		if pl.size() > 0: bands.append("%d:%s" % [n, pl.map(func(v: Dictionary) -> String: return "gap %.0f dir %.0f wind %.0f v %.0f" % [float(v["gap"]), float(v["dir"]), float(v["wind"]), float(v["v"])])]); count += pl.size()
	print("TOWER floors=", bands, " kites=", count, " (want a subset of 20..24 and 55..59, one each, dir matching the wind's sign where wind ≠ 0)")
	quit()
