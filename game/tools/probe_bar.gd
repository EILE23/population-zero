extends SceneTree
## 높이뛰기 바 팩 점검(헤드리스): 자료가 읽히나(눈금 56/72/88 이 층으로 돌아가나), 바람 절벽 층의 앞 발판이 있는 가장 넓은 still 발판에만 바가 서나(허들 줄이 선 발판·통풍구 발판·상자에 지름길 판이 든 발판은 비켜 가고, 좁은 발판은 짧은 run, 다 빼면 없고, 다른 테마 층은 아니다; 들어오는 쪽이 앞 발판 쪽인가),
## 공중의 몸이 approach 안에서 in_flight 와 자리 k 를 받고 메타에 적히나, 가로대의 면을 발이 위로 지나면 넘어 세고(같은 날 두 번은 한 번, 다음 날은 0), 머리가 밑에 닿게 지나면 떨어뜨리나(clatter, arch_hit — 누운 가로대는 세지도 떨어지지도 않고 다른 몸엔 없다), 낮게 밑을 지나면 아무 일 없나, 멀리·앞뒤 밖·발판 밑은 아니다,
## 떨어진 가로대가 0.5 s 에 매트로 굴러 20 s 눕고 thump 와 함께 0.6 s 에 눈금으로 돌아가나, 바람 120 에 1.5 px 안에서 떨고 바람 없는 층도 그 1/3 로 떠나, 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 세고 높이를 m 로 읽나,
## 기둥 둘·눈금 여섯·가로대·매트·띠·소리 둘이 그려지나, arch 자세가 활에 등을 젖히고 팔을 머리 너머로 들고 다리를 매달았다가 넘김에 차올리고 매트를 보나(사림은 끌어안나), 진짜 탑의 1..60층에서 plan 이 바람 절벽 층에만 바를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cb := ClimbBar.new(); root.add_child(cb)
	var ch := ClimbHurdle.new(); root.add_child(ch)
	var cu := ClimbUpdraft.new(); root.add_child(cu)
	var ci := ClimbIcicle.new(); root.add_child(ci)
	var ck := ClimbKite.new(); root.add_child(ck)
	var cd := ClimbDandelion.new(); root.add_child(cd)
	var cv := ClimbVane.new(); root.add_child(cv)
	await process_frame
	print("PACK id=", cb.pack.get("id"), " kind=", cb.kind.size() > 0, " pose=", cb.pack.get("pose"), " themes=", cb.pack.get("themes"), " notches=", cb.notches(), " notch 20/21/22/55=%.0f %.0f %.0f %.0f bar_r=%.0f bar_d=%.0f run=%.0f/%.0f mat=%.0f/%.0f mat_h=%.0f edge=%.0f approach=%.0f drop=%.2f reset=%.0f lift=%.2f day=%.0f need=%.0f/%.0f top=%.0f (want [56, 72, 88] 88 56 72 72 2 34 70/50 50/40 14 16 60 0.50 20 0.60 600 140/110 88)" % [cb.notch(20), cb.notch(21), cb.notch(22), cb.notch(55), cb.bar_r(), cb.bar_d(), cb.run_w(true), cb.run_w(false), cb.mat_w(true), cb.mat_w(false), cb.mat_h(), cb.edge(), cb.approach(), cb.drop_s(), cb.reset_s(), cb.lift_s(), cb.day_s(), cb.need_w(true), cb.need_w(false), cb.top_h()])
	var plats: Array = [
		{ "id": "21.0", "x": 60.0, "y": 12700.0, "w": 170.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21.1", "x": 420.0, "y": 12800.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21.2", "x": 180.0, "y": 12900.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "21.3", "x": 540.0, "y": 13000.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21.4", "x": 300.0, "y": 13100.0, "w": 176.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21s", "x": 700.0, "y": 13050.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cb.plan(21, plats)
	var rows := ch.plan(21, plats)   # 허들 줄은 가장 넓은 21.4 — 바는 다음 21.2 로
	var hurdled := cb.plan(21, plats, 0.0, rows)
	var vent2 := { "id": "21.v2", "kind": "vent", "x": 260.0, "y": 12900.0 }; var vent1 := { "id": "21.v1", "kind": "vent", "x": 495.0, "y": 12800.0 }; var vent3 := { "id": "21.v3", "kind": "vent", "x": 600.0, "y": 13000.0 }
	var vented := cb.plan(21, plats, 0.0, rows + [vent2])   # 21.2 가운데 통풍구 — 21.1 로(들어오는 쪽이 왼쪽)
	var narrow := cb.plan(21, plats, 0.0, rows + [vent2, vent1])   # 21.3 (120 — 짧은 run 50·매트 40)
	var none := cb.plan(21, plats, 0.0, rows + [vent2, vent1, vent3])   # 다 뺐다 — 21.0 은 앞 발판이 없다
	var cut := plats.duplicate(true); cut.append({ "id": "21c", "x": 380.0, "y": 13130.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 })   # 21.4 의 상자에 지름길 판 — 21.2 로
	var cutp := cb.plan(21, cut)
	var f19 := cb.plan(19, plats); var f20 := cb.plan(20, plats); var f24 := cb.plan(24, plats); var f25 := cb.plan(25, plats); var f55 := cb.plan(55, plats); var f59 := cb.plan(59, plats)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " on %s w %.0f dir %.0f bx %.0f h %.0f run %.0f mat %.0f x %.0f w %.0f y %.0f y_top %.0f z %.0f d %.0f" % [String(v["hop_id"]), float(v["hop_w"]), float(v["dir"]), float(v["bx"]), float(v["h"]), float(v["run"]), float(v["mat"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	var brief := func(v: Dictionary) -> String: return String(v["hop_id"]) + " bx %.0f run %.0f" % [float(v["bx"]), float(v["run"])]
	print("PLAN free=", free.map(show), " (want 1: 21.B0 on 21.4 w 176 dir −1 bx 406 h 56 run 70 mat 50 x 352 w 124 y 13100 y_top 13200 z −53 d 34)")
	print("PLAN hurdled=", hurdled.map(brief), " (want [21.2 bx 270 run 70]) vented=", vented.map(brief), " (want [21.1 bx 490 run 70]) narrow=", narrow.map(brief), " (want [21.3 bx 590 run 50]) none=", none.size(), " (want 0) cut=", cutp.map(brief), " (want [21.2 bx 270 run 70]) floors 19/20/24/25/55/59=", [f19.size(), f20.size(), f24.size(), f25.size(), f55.size(), f59.size()], " (want 0 1 1 0 1 1) h 20/24/55=", [f20.map(func(v: Dictionary) -> float: return float(v["h"])), f24.map(func(v: Dictionary) -> float: return float(v["h"])), f55.map(func(v: Dictionary) -> float: return float(v["h"]))], " (want [88] [56] [72])")
	var band_root := Node3D.new(); root.add_child(band_root)
	cb.build(band_root, free)
	var s: Dictionary = cb.bars[0]
	var fig := Stick3D.new(); root.add_child(fig)
	var z := C.PLAYER_Z
	# 비행(t 10, 가로대 406, 윗면 13156 + 2, 가는 쪽 −x): 470 → 462 는 approach 안 k 0.033; 410 → 402 를 13170 으로 지나면 넘는다(k 0.533, 오늘 1/1, 1.6 m); 13105 로 지나면 머리 13149 가 밑면 13154 에 안 닿아 아무 일 없다; 350 → 342 는 밖(메타 지움); 앞뒤 밖·발판 밑(13050)은 아니다
	cb.sync(10.0)
	var fa := cb.flight(470.0, 462.0, 13120.0, z, fig); var ma := float(fig.get_meta("arch_k", 9.0))
	var fb := cb.flight(410.0, 402.0, 13170.0, z, fig); var v1 := cb.cleared_today(21, 21)
	var fu := cb.flight(410.0, 402.0, 13105.0, z, fig)
	var fc := cb.flight(350.0, 342.0, 13130.0, z, fig); var mc := fig.has_meta("arch_k")
	var fz := cb.flight(410.0, 402.0, 13170.0, z + 100.0); var fl := cb.flight(410.0, 402.0, 13050.0, z)
	var again := cb.flight(410.0, 402.0, 13170.0, z, fig); var v1b := cb.cleared_today(21, 21)
	print("FLIGHT approach: in=%s k=%.3f meta=%.3f (want true 0.033 0.033) | clear: in=%s cleared=%s k=%.3f (want true true 0.533) today=%d/%d best=%.0f (want 1/1 56) | under: in=%s cleared=%s knocked=%s up=%s (want true false false true) | away: in=%s meta=%s (want false false) | far z: in=%s low: in=%s (want false false) | again: cleared=%s today=%d/%d (want true 1/1: once a day)" % [fa["in_flight"], float(fa["k"]), ma, fb["in_flight"], fb["cleared"], float(fb["k"]), int(v1["done"]), int(v1["total"]), float(v1["best"]), fu["in_flight"], fu["cleared"], fu["knocked"], cb.up(s), fc["in_flight"], mc, fz["in_flight"], fl["in_flight"], again["cleared"], int(v1b["done"]), int(v1b["total"])])
	print("NOTE 20=\"%s\" (want High jump, floors 20–24: 1 of 1 bar cleared today, the highest 1.6 m.) 25=\"%s\" (want the same: nothing on 25..29, so the floors below) 30=\"%s\" (want empty)" % [cb.note(20), cb.note(25), cb.note(30)])
	# 떨어뜨리기(t 11): 13140 으로 지나면 머리 13184 가 밑면에 닿는다 → knocked, clatter, arch_hit, 가로대가 눕는다(up 거짓), 오늘 그대로 1/1; 그 몸은 누운 가로대 옆에서도 in_flight(k 0.583); 메타를 지운 다른 몸(t 12)엔 없다 — 세지도 않는다; 다음 날(610) 0/1
	cb.sync(11.0)
	var fk := cb.flight(410.0, 402.0, 13140.0, z, fig); var clat: AudioStreamPlayer3D = s["clatter"]; var clat_on := clat.playing; var hitm := float(fig.get_meta("arch_hit", 0.0))
	var fk2 := cb.flight(404.0, 396.0, 13139.0, z, fig); var vk := cb.cleared_today(21, 21)
	cb.leave(fig); cb.sync(12.0)
	var fd := cb.flight(410.0, 402.0, 13170.0, z, fig); var vd := cb.cleared_today(21, 21)
	cb.sync(610.0); var v0 := cb.cleared_today(21, 21); var n0 := cb.note(20)
	print("KNOCK: in=%s knocked=%s cleared=%s clatter=%s hit_meta=%.0f up=%s (want true true false true 1 false) | same body on: in=%s k=%.3f (want true 0.583) today=%d/%d (want 1/1) | other body over the fallen bar: in=%s cleared=%s today=%d/%d (want false false 1/1) | next day: %d/%d note=\"%s\" (want 0/1 High jump, floors 20–24: 0 of 1 bar cleared today.)" % [fk["in_flight"], fk["knocked"], fk["cleared"], clat_on, hitm, cb.up(s), fk2["in_flight"], float(fk2["k"]), int(vk["done"]), int(vk["total"]), fd["in_flight"], fd["cleared"], int(vd["done"]), int(vd["total"]), int(v0["done"]), int(v0["total"]), n0])
	# 가로대의 길(fell_t 11, dir −1, 매트 가운데 −29 px = −0.8056, 매트 위 16 px = 0.4444, 눈금 56 px = 1.5556): 11.25 구르는 중(y 사이, x 기울어); 20 누움; 30.99 → 31 을 지나는 프레임에 thump; 31.3 올라오는 중; 31.7 눈금(up, y ±0.014 — 바람 없는 떨림 0.5 px)
	var bar: Node3D = s["bar"]; var thump: AudioStreamPlayer3D = s["thump"]
	cb.sync(11.25); cb._place(s); var p_fall := bar.position; var r_fall := bar.rotation.x
	cb.sync(20.0); cb._place(s); var p_lie := bar.position; var up_lie := cb.up(s)
	cb.sync(30.99); var thumped := false
	for i in 10:
		await process_frame
		if thump.playing: thumped = true
	cb.sync(31.3); cb._place(s); var p_lift := bar.position
	cb.sync(31.7); cb._place(s); var p_up := bar.position; var up_up := cb.up(s)
	s["wind"] = 120.0; var q_max := 0.0
	for i in 40:
		cb.sync(40.0 + float(i) * 0.01); cb._place(s); q_max = maxf(q_max, absf(bar.position.y - 56.0 * C.K))
	s["wind"] = 0.0
	print("PLACE fall@11.25: y=%.3f (want between 0.444 and 1.556) x=%.3f (want between −0.806 and 0) rot=%.2f (want > 0) | lie@20: pos=%.4f %.4f %.4f (want −0.8056 0.4444 0.0000) up=%s (want false) | thump across 31=%s (want true) | lift@31.3: y=%.3f (want between 0.444 and 1.556) | up@31.7: y=%.4f (want 1.5556 ± 0.014) x=%.3f (want 0.000) up=%s (want true) | wind 120: max quiver=%.4f (want ≤ 0.0417, > 0.03)" % [p_fall.y, p_fall.x, r_fall, p_lie.x, p_lie.y, p_lie.z, up_lie, thumped, p_lift.y, p_up.y, p_up.x, up_up, q_max])
	# 그림: 노드 아이 13(기둥 둘·눈금 여섯·가로대·매트·띠·소리 둘), 가로대 아이 1; 노드 자리 (406 − 480)/36 = −2.0556, 13100/36 = 363.8889, −70/36 = −1.9444
	var node: Node3D = s["node"]
	print("VISUAL children=%d (want 13) bar=%d (want 1) node pos=%.4f %.4f %.4f (want −2.0556 363.8889 −1.9444)" % [node.get_child_count(), bar.get_child_count(), node.position.x, node.position.y, node.position.z])
	# 자세(활, arch_k 0.5): 오른 엉덩이 0.55, 무릎 0.90, 어깨 x −2.60 (±0.05 떨림), 어깨 z −0.47, 팔꿈치 −0.25, 골반 0.42 + 0.28 = 0.70, 상체 0.45 × −0.6 = −0.27, 고개 ≈ 뒤로(−0.45 와 상체 되돌림); 넘김(0.9): 엉덩이 −1.30, 무릎 0.15, 어깨 x −0.80, 팔꿈치 −0.50, 골반 0.42, 상체 0.135, 고개 앞으로(+0.25 쪽); 사림(0.9, hit 1): 엉덩이 −1.00, 무릎 1.55, 어깨 x −0.30, 팔꿈치 −1.10, 골반 0.38, 상체 0.2925
	fig.pose_request = "arch"; fig.set_meta("arch_k", 0.5)
	while fig.pose_t < 0.3: await process_frame
	var a_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var a_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var a_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x; var a_shz: float = (fig.shoulders[1.0] as Node3D).rotation.z; var a_el: float = (fig.elbows[1.0] as Node3D).rotation.x
	var a_pel := fig.pelvis.position.y; var a_torso := fig.torso.rotation.x; var a_neck := fig.neck.rotation.x
	fig.set_meta("arch_k", 0.9)
	for i in 3: await process_frame
	var k_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var k_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var k_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x; var k_el: float = (fig.elbows[1.0] as Node3D).rotation.x
	var k_pel := fig.pelvis.position.y; var k_torso := fig.torso.rotation.x; var k_neck := fig.neck.rotation.x
	fig.set_meta("arch_hit", 1.0)
	for i in 3: await process_frame
	var h_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var h_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var h_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x; var h_el: float = (fig.elbows[1.0] as Node3D).rotation.x
	var h_pel := fig.pelvis.position.y; var h_torso := fig.torso.rotation.x
	var d_time := ArchPoses.done(fig)
	print("POSE arch: hip=%.2f knee=%.2f arm x=%.2f arm z=%.2f elbow=%.2f (want 0.55 0.90 −2.60±0.05 −0.47 −0.25) pelvis=%.2f torso=%.3f neck=%.2f (want 0.70 −0.270 < 0: head back) | kick: hip=%.2f knee=%.2f arm x=%.2f elbow=%.2f (want −1.30 0.15 −0.80±0.05 −0.50) pelvis=%.2f torso=%.3f neck=%.2f (want 0.42 0.135 > arch's: the mat) | tuck: hip=%.2f knee=%.2f arm x=%.2f elbow=%.2f pelvis=%.2f torso=%.3f (want −1.00 1.55 −0.30±0.05 −1.10 0.38 0.293) done(meta)=%s (want false)" % [a_hip, a_knee, a_sh, a_shz, a_el, a_pel, a_torso, a_neck, k_hip, k_knee, k_sh, k_el, k_pel, k_torso, k_neck, h_hip, h_knee, h_sh, h_el, h_pel, h_torso, d_time])
	fig.pose_request = ""; cb.leave(fig)
	# 진짜 탑: 1..60층에 plan 이 찾는 바 — 바람 절벽 층 20..24, 55..59 중 허들 줄·통풍구·고드름·연·민들레가 비켜 간 발판이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n); var wind: float = gm.wind_of(n)
		var kp: Array = ck.plan(n, pl, wind); var hop_top: Array = cu.plan(n, pl) + ci.plan(n, pl) + kp
		var out2 := cb.plan(n, pl, wind, hop_top + ch.plan(n, pl, hop_top) + cd.plan(n, pl, wind, kp + cv.plan(n, pl, wind, kp)))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s w %.0f h %.0f run %.0f" % [String(v["hop_id"]), float(v["hop_w"]), float(v["h"]), float(v["run"])])])
	print("TOWER floors=", bands, " (want a subset of 20..24, 55..59 — one bar each on a hop the hurdle row did not take, h by floor mod 3, run 70 below 55 and 50 or 70 above, never another theme)")
	quit()
