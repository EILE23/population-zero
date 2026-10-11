extends SceneTree
## 뻐꾸기 발판 팩 점검(헤드리스): 자료가 읽히나, 태엽 층의 잇단 still 발판 짝 중 높이차 110 이상·틈 84..260 인 것들 중 높이차가 가장 큰 틈 하나 옆에만 집이 서나(지름길 판이 집 상자에 걸리는 틈·taken 조각(추)이 든 틈은 지고 다음으로 높은 틈으로, 통풍구 층·다른 테마 층은 아니다, 거울 층은 반대로),
## 박자가 맞나(5.6초마다 0.4 나와 2.0 머물고 0.4 들어간다, 선형), 널빤지가 14px 넘게 나온 때만 착지를 받나(로더의 z 검사 그대로 — 멀거나 앞이거나 들어가 있으면 아니다), 서면 on 의 z·d 가 다시 적히고 들어갈 땐 inside 가 되어 x 가 집 벽 사이에 갇히나, 메타(perch_in·perch_call)가 적히나,
## 문이 열리는 틱에 뻐꾸기가 울고 opened 가 적히나, 안에서 두드리면 바로 열려 0.8초 머물고 닫히나(밖에선 아무 일 없음), 집·문간·경첩 둘·지붕 둘·널빤지(뻐꾸기·부리)·톱니·소리가 그려지고 문짝이 1.3 rad 바깥으로 열리며 널빤지가 z 로 미끄러지나,
## perch 자세가 웅크려 문틀을 짚고 안에선 더 웅크려 손이 무릎으로 오며 부르면 고개를 내미나, 진짜 탑의 1..70층에서 plan 이 태엽 층(통풍구 층 빼고)에만 집을 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var pk := ClimbPerch.new(); root.add_child(pk)
	var cp := ClimbPendulum.new(); root.add_child(cp)
	var gh := ClimbGhost.new(); root.add_child(gh)
	var cb := ClimbBridge.new(); root.add_child(cb)
	var cm := ClimbMushroom.new(); root.add_child(cm)
	await process_frame
	print("PACK id=", pk.pack.get("id"), " kind=", pk.kind.size() > 0, " pose=", pk.pack.get("pose"), " themes=", pk.pack.get("themes"), " beat=%.1f reach=%.0f out=%.1f hold=%.1f in=%.1f plank=%.0f house=%.0f top=%.0f (want 5.6 60 0.4 2.0 0.4 48 72 86)" % [pk.beat(), pk.reach(), pk.out_s(), pk.hold_s(), pk.in_s(), pk.plank_w(), pk.house_w(), pk.house_top()])
	var plats: Array = [
		{ "id": "16.0", "x": 100.0, "y": 9700.0, "w": 160.0, "kind": "std", "z": -31.0, "d": 78.0 },
		{ "id": "16.1", "x": 420.0, "y": 9820.0, "w": 150.0, "kind": "std", "z": -31.0, "d": 78.0 },
		{ "id": "16.2", "x": 700.0, "y": 9915.0, "w": 130.0, "kind": "std", "z": -31.0, "d": 78.0 },
		{ "id": "16.3", "x": 480.0, "y": 10033.0, "w": 120.0, "kind": "std", "z": -31.0, "d": 78.0 },
		{ "id": "16.4", "x": 200.0, "y": 10140.0, "w": 140.0, "kind": "std", "z": -31.0, "d": 78.0 },
		{ "id": "16.5", "x": 40.0, "y": 10250.0, "w": 90.0, "kind": "move", "z": -31.0, "d": 78.0, "amp": 40.0, "freq": 0.3, "phase": 0.0 },
		{ "id": "16s", "x": 800.0, "y": 10060.0, "w": 60.0, "kind": "short", "z": -31.0, "d": 60.0 },
	]
	var free := pk.plan(16, plats)
	var hand_pend: Array = [{ "id": "16.p0", "kind": "pendulum", "x": 300.0, "w": 80.0, "y": 9760.0, "hp": 9970.0 }]   # 추가 160 틈(16.0↔16.1)에 매달린 경우
	var pend := pk.plan(16, plats, hand_pend)
	var blocked: Array = plats.duplicate(); blocked.append({ "id": "16t", "x": 330.0, "y": 9800.0, "w": 60.0, "kind": "short", "z": -31.0, "d": 60.0 })   # 지름길 판이 집 상자 안에
	var slab := pk.plan(16, blocked)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := pk.plan(16, mirror)
	var vent := pk.plan(15, plats); var other := pk.plan(20, plats); var next := pk.plan(17, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	pk.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " %s→%s dy %.0f gap %.0f hx %.0f x %.0f w %.0f y %.1f z %.0f len %.0f pw %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dy"]), float(v["gap"]), float(v["hx"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["z"]), float(v["len"]), float(v["pw"])]
	var brief := func(v: Dictionary) -> String: return String(v["id"]) + " %s→%s dy %.0f hx %.0f y %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dy"]), float(v["hx"]), float(v["y"])]
	print("PLAN free=", free.map(show), " (want 1: 16.H0 16.0→16.1 dy 120 gap 160 hx 340 x 304 w 72 y 9760.0 z −70 len 86 pw 48 — dy 120 beats 118; 16.1→16.2 is 95, 16.3→16.4 is 107, 16.5 moves) | pendulum in 160: ", pend.map(brief), " (want 16.H0 16.2→16.3 dy 118 hx 650 y 9974) | short slab in the box: ", slab.map(brief), " (want the same 16.2→16.3) | mirror: ", right.map(brief), " (want 16.0→16.1 hx 620) | vent15=", vent.size(), " other20=", other.size(), " floor17=", next.size(), " (want 0 0 1: 15 is a vent floor, 20 is Wind cliffs, 17 is Clockwork)")
	var s: Dictionary = pk.hatches[0]
	var z := C.PLAYER_Z
	# 박자(phase 0): 0 → 0, 0.2 → 0.5, 0.4..2.4 → 1, 2.6 → 0.5, 2.8..5.6 → 0; 깊이 60·e, z −70 + 30·e; 발판인 건 깊이 > 14 (e > 0.2333)
	var ext := func(at: float) -> String: return "%.3f" % pk.ext(s, at)
	print("BEAT ext 0=%s 0.2=%s 0.4=%s 1.0=%s 2.4=%s 2.6=%s 2.8=%s 4.0=%s 5.6=%s (want 0 0.5 1 1 1 0.5 0 0 0) | depth 0.2=%.1f z=%.1f (want 30 −55) | out 0.05=%s 0.093=%s 0.1=%s 0.2=%s 2.7=%s 2.71=%s 3.0=%s (want false false true true true false false: 14 px is the loader's line) | inside 0.05=%s 0.1=%s 0.5=%s 2.75=%s 3.0=%s (want true true false true true)" % [ext.call(0.0), ext.call(0.2), ext.call(0.4), ext.call(1.0), ext.call(2.4), ext.call(2.6), ext.call(2.8), ext.call(4.0), ext.call(5.6), pk.depth(s, 0.2), pk.z_of(s, 0.2), pk.is_out(s, 0.05), pk.is_out(s, 0.093), pk.is_out(s, 0.1), pk.is_out(s, 0.2), pk.is_out(s, 2.7), pk.is_out(s, 2.71), pk.is_out(s, 3.0), pk.inside(s, 0.05), pk.inside(s, 0.1), pk.inside(s, 0.5), pk.inside(s, 2.75), pk.inside(s, 3.0)])
	# 착지(t 0.2, 깊이 30): x 340 발 9765 → 9755 는 받는다; x 400 (끝 364 밖)·z 20 (앞)·t 3.0 (들어가 있다) 는 아니다
	pk.sync(0.2)
	var on := pk.land(340.0, 9765.0, 9755.0, z)
	var far := pk.land(400.0, 9765.0, 9755.0, z); var front := pk.land(340.0, 9765.0, 9755.0, 20.0)
	pk.sync(3.0); var shut := pk.land(340.0, 9765.0, 9755.0, z)
	print("LAND on=%s kind=%s x=%.0f w=%.0f y=%.0f z=%.0f d=%.0f hatch=%s (want 16.H0p perch 316 48 9760 −55 30 16.H0) | far=%s front=%s shut=%s (want empty ×3)" % [on.get("id", "-"), on.get("kind", "-"), float(on.get("x", 0.0)), float(on.get("w", 0.0)), float(on.get("y", 0.0)), float(on.get("z", 0.0)), float(on.get("d", 0.0)), on.get("hatch", "-"), far.is_empty(), front.is_empty(), shut.is_empty()])
	# 서기: t 0.5 (나와 있다) → on z −40 d 60, x 그대로, inside false; t 2.75 (들어간다, e 0.125) → inside, z −48 d 60, x 360 → 354 (벽), perch_in 0.875; 문이 열리는 틱(5.6 → 5.61)에 opened 가 적히고 뻐꾸기가 운다; t 5.75 (e 0.375) → 밖, perch_call 0.72, perch_in 0.625
	var fig := Stick3D.new(); root.add_child(fig)
	var dt := 1.0 / 60.0
	pk.sync(0.5); var r1 := pk.stand(on, 340.0, dt, fig)
	var z1 := float(on["z"]); var d1 := float(on["d"])
	pk.sync(2.75); var r2 := pk.stand(on, 360.0, dt, fig)
	var z2 := float(on["z"]); var d2 := float(on["d"]); var in2 := float(fig.get_meta("perch_in", 9.0))
	var call: AudioStreamPlayer3D = s["call"]
	pk.sync(5.5); pk._process(0.0); call.stop()
	pk.sync(5.59); pk._process(0.02)
	var rang := call.playing; var opened := float(s["opened"])
	pk.sync(5.75); var r3 := pk.stand(on, 340.0, dt, fig)
	var in3 := float(fig.get_meta("perch_in", 9.0)); var call3 := float(fig.get_meta("perch_call", 9.0))
	print("STAND 0.5: x=%.0f inside=%s ext=%.2f on z=%.0f d=%.0f (want 340 false 1.00 −40 60) | 2.75: x=%.0f inside=%s ext=%.3f on z=%.0f d=%.0f perch_in=%.3f (want 354 true 0.125 −48 60 0.875: the walls hold) | open tick: call=%s opened=%.2f (want true 5.61) | 5.75: inside=%s perch_in=%.3f perch_call=%.2f (want false 0.625 0.72: pushed out again, the cuckoo bob)" % [float(r1["x"]), r1["inside"], float(r1["ext"]), z1, d1, float(r2["x"]), r2["inside"], float(r2["ext"]), z2, d2, in2, rang, opened, r3["inside"], in3, call3])
	# 두드림: t 1.0 (밖) 은 거절; t 3.0 (안) 은 열린다 — 3.2 → 0.5, 3.4..4.2 → 1, 4.4 → 0.5, 4.6 → 0 (박자의 다음 열림 5.6 전까지 0); 모르는 집은 거절
	pk.sync(1.0); var k_out := pk.knock(on)
	pk.sync(3.0); var k_in := pk.knock(on)
	var k_none := pk.knock({ "hatch": "nope" })
	print("KNOCK outside=%s inside=%s unknown=%s (want false true false) | ext 3.2=%s 3.4=%s 4.2=%s 4.4=%s 4.6=%s 5.0=%s (want 0.5 1 1 0.5 0 0)" % [k_out, k_in, k_none, ext.call(3.2), ext.call(3.4), ext.call(4.2), ext.call(4.4), ext.call(4.6), ext.call(5.0)])
	s["knock"] = -9.0
	# 그림: 노드 아이 9(집·문간·경첩 2·지붕 2·널빤지·톱니·소리), 널빤지 아이 2(뻐꾸기·부리), 경첩 아이 1; 노드 자리 −3.889 271.111 −1.944; e 1 → 문짝 ∓1.3, 널빤지 z 0.833; e 0 → 0, −0.833
	var node: Node3D = s["node"]; var plank: Node3D = s["plank"]; var leaves: Array = s["leaves"]
	pk.sync(1.0); pk._process(0.0)
	var l_open: float = (leaves[0] as Node3D).rotation.y; var r_open: float = (leaves[1] as Node3D).rotation.y; var pz_open := plank.position.z
	pk.sync(4.0); pk._process(0.0)
	var l_shut: float = (leaves[0] as Node3D).rotation.y; var pz_shut := plank.position.z
	print("VISUAL node children=%d (want 9) plank children=%d (want 2) hinge children=%d (want 1) node pos=%.3f %.3f %.3f (want −3.889 271.111 −1.944) | open: leaves=%.2f %.2f plank z=%.3f (want −1.30 1.30 0.833) | shut: leaf=%.2f plank z=%.3f (want 0.00 −0.833: behind the cliff face)" % [node.get_child_count(), plank.get_child_count(), (leaves[0] as Node3D).get_child_count(), node.position.x, node.position.y, node.position.z, l_open, r_open, pz_open, l_shut, pz_shut])
	# 자세(+x 를 본다): 문간(in 0, call 0) — 골반 0.30, 엉덩이 −0.5, 무릎 0.9, 어깨 x −0.3, 어깨 z −1.3 (문틀을 짚은 팔), 팔꿈치 −0.9, 몸통 0.135 (= 0.45 × lean 0.3); 안(in 1) — 골반 0.22, 엉덩이 −0.9, 무릎 1.4, 어깨 x −0.9, 어깨 z −0.2 (무릎으로 내려온 손), 팔꿈치 −1.4, 몸통 0.225; 부르기(call 1, in 0) — 고개가 0.61 앞으로(0.5 + 0.7 × 0.15 의 몸통 몫), 몸통 0.203
	fig.pose_request = ""; await process_frame
	fig.pose_request = "perch"; fig._yaw = PI / 2.0; fig._yaw_target = PI / 2.0
	fig.set_meta("perch_in", 0.0); fig.set_meta("perch_call", 0.0)
	await process_frame; await process_frame; await process_frame
	var early: float = (fig.shoulders[1.0] as Node3D).rotation.z
	for i in 60: await process_frame
	var hip_o: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_o: float = (fig.knees[1.0] as Node3D).rotation.x
	var sh_o: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz_o: float = (fig.shoulders[1.0] as Node3D).rotation.z; var el_o: float = (fig.elbows[1.0] as Node3D).rotation.x
	var pel_o := fig.pelvis.position.y; var torso_o := fig.torso.rotation.x; var neck_o := fig.neck.rotation.x; var t60 := fig.pose_t
	fig.set_meta("perch_in", 1.0)
	for i in 60: await process_frame
	var hip_i: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_i: float = (fig.knees[1.0] as Node3D).rotation.x
	var sh_i: float = (fig.shoulders[1.0] as Node3D).rotation.x; var shz_i: float = (fig.shoulders[1.0] as Node3D).rotation.z; var el_i: float = (fig.elbows[1.0] as Node3D).rotation.x
	var pel_i := fig.pelvis.position.y; var torso_i := fig.torso.rotation.x
	fig.set_meta("perch_in", 0.0); fig.set_meta("perch_call", 1.0)
	for i in 60: await process_frame
	var neck_c := fig.neck.rotation.x; var torso_c := fig.torso.rotation.x
	print("POSE early=%.2f (want > −1.2: the crouch has only begun) pose_t after 60 frames=%.2f (want ≥ 0.2) doorway: hip=%.2f (want −0.50) knee=%.2f (want 0.90) shoulder=%.2f (want −0.30) z=%.2f (want −1.30: hands on the frame) elbow=%.2f (want −0.90) pelvis=%.3f (want 0.300) torso=%.3f (want 0.135 ± 0.01: stick3d gives the torso 0.45 of the lean 0.3) | inside: hip=%.2f (want −0.90) knee=%.2f (want 1.40) shoulder=%.2f (want −0.90) z=%.2f (want −0.20: hands to the knees) elbow=%.2f (want −1.40) pelvis=%.3f (want 0.220) torso=%.3f (want 0.225 ± 0.01: 0.45 × 0.5) | call: neck %.3f → %.3f (want ≈ 0.61 lower: 0.5 from the call and 0.7 × the torso's extra 0.15 of lean — the head pokes out) torso=%.3f (want 0.203 ± 0.01: 0.45 × 0.45)" % [early, t60, hip_o, knee_o, sh_o, shz_o, el_o, pel_o, torso_o, hip_i, knee_i, sh_i, shz_i, el_i, pel_i, torso_i, neck_o, neck_c, torso_c])
	# 진짜 탑: 1..70층에 plan 이 찾는 집 — 태엽 층 16, 17, 18, 50, 52, 53, 54 중 높은 틈이 있고 추·유령 판·다리·버섯이 비켜 준 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var out := pk.plan(n, pl, cp.plan(n, pl) + gh.plan(n, pl) + cb.plan(n, pl) + cm.plan(n, pl))
		if out.size() > 0: bands.append("%d:%s" % [n, out.map(func(v: Dictionary) -> String: return "%s→%s dy %.0f gap %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dy"]), float(v["gap"])])]); count += out.size()
	print("TOWER floors=", bands, " hatches=", count, " (want a subset of 16, 17, 18, 50, 52, 53, 54 — one each, never 15, 19, 51)")
	quit()
