extends SceneTree
## 열기구 팩 점검(헤드리스): 자료가 읽히나, 구름바다 층의 잇단 두 발판 사이 틈(64..200, 건너편이 60..160 높다) 중 당김 수의 바람으로 건널 수 있고 비스듬한 길의 다섯 상자를 다른 판이 가르지 않고 taken 조각이 닿지 않는 것 중 가장 높이 오르는 하나에만 기구가 매이나(통풍구 층·다른 테마 층은 아니다, 바람이 못 실어 가는 넓은 틈은 아니다, 지름길 판이 길에 있으면 진다, 움직이는 발판 옆은 아니다, 널의 틈은 비켜 간다),
## 아래 발판 바구니 옆의 C 만 grab 이 받나(건너편 발판·먼 x·앞뒤 밖·이미 타는 중·되내려오는 중은 아니다), 올라타기가 0.25 에 바구니 가운데로 가나, 올라타는 중의 당김은 안 받나, 당김마다 50 오르며 바람에 32 실려 가고(0.8 에 걸쳐: 0.4 에 25) 0.6 버틴 뒤 10/s 로 가라앉나,
## 건너편 윗면에 닿으면 건너편 발판 위(416, 15200)로 내려서나, 빈 기구가 4초에 되내려와 앉나(thud), 놓으면 오르는 속도(93.7)를 주고 오른 만큼의 시간에 되내려오나,
## 말뚝·줄·바구니·creak·whoosh·thud 와 바구니 안의 바닥·네 벽·테·네 줄·버너·불꽃·풍선·버너 줄·토글, 풍선 안의 치마·풍선·띠가 그려지나, 바구니가 높이와 바람에 실린 x 로 가고 줄이 늘어나나, tug 자세가 토글 손을 얼굴에서 어깨로 홱 내리고 되올리며 테 손은 테에 두나, 진짜 탑의 1..60층에서 plan 이 구름바다 층(25, 26, 28, 29, 60, 61, 62, 64)에만 기구를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var ba := ClimbBalloon.new(); root.add_child(ba)
	var cr := ClimbRaft.new(); root.add_child(cr)
	var mu := ClimbMushroom.new(); root.add_child(mu)
	var cp := ClimbPlank.new(); root.add_child(cp)
	await process_frame
	print("PACK id=", ba.pack.get("id"), " kind=", ba.kind.size() > 0, " pose=", ba.pack.get("pose"), " themes=", ba.pack.get("themes"), " basket=%.0f lift=%.0f drift=%.0f tug=%.2f hold=%.2f cool=%.0f sink=%.2f mount=%.2f yank=%.2f (want 44 50 40 0.80 0.60 10 4.00 0.25 0.45)" % [ba.basket_w(), ba.lift(), ba.drift(), ba.tug_s(), ba.hold_s(), ba.cool_v(), ba.sink_s(), ba.mount_s(), ba.yank_s()])
	var plats: Array = [
		{ "id": "25r", "x": 250.0, "y": 14900.0, "w": 400.0, "kind": "rest", "z": 0.0, "d": 180.0 },
		{ "id": "25.0", "x": 100.0, "y": 15100.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "25.1", "x": 400.0, "y": 15200.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "25.2", "x": 700.0, "y": 15300.0, "w": 200.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "25.3", "x": 420.0, "y": 15420.0, "w": 160.0, "kind": "ice", "z": -35.0, "d": 70.0 },
		{ "id": "25.4", "x": 200.0, "y": 15540.0, "w": 170.0, "kind": "move", "z": -35.0, "d": 70.0 },
		{ "id": "25.5", "x": 25.0, "y": 15650.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "25s", "x": 680.0, "y": 15468.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var free := ba.plan(25, plats)
	var planked := ba.plan(25, plats, cp.plan(25, plats))   # 널은 25.1-25.2 의 틈(550..620)에 — 기구의 틈이 아니다
	var rafted := ba.plan(25, plats, [{ "id": "25.c0", "kind": "raft", "x": 310.0, "w": 60.0, "y": 15150.0 }])   # 뗏목이 기구의 틈에
	var cut := plats.duplicate(true); cut.append({ "id": "25c", "x": 300.0, "y": 15230.0, "w": 50.0, "kind": "short", "z": -35.0, "d": 60.0 })   # 기구의 길에 지름길 판
	var cutp := ba.plan(25, cut)
	var ghost := ba.plan(26, plats); var vent := ba.plan(27, plats); var bridge := ba.plan(28, plats); var wind := ba.plan(24, plats); var high := ba.plan(60, plats); var star := ba.plan(30, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	ba.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " %s-%s gap %.0f dy %.0f dir %.0f hx %.0f ex %.0f out %.0f tugs %d x %.0f w %.0f z %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"]), float(v["dy"]), float(v["dir"]), float(v["hx"]), float(v["ex"]), float(v["out_x"]), int(v["tugs"]), float(v["x"]), float(v["w"]), float(v["z"])]
	print("PLAN free=", free.map(show), " (want 1: 25.B0 25.0-25.1 gap 120 dy 100 dir 1 hx 308 ex 372 out 416 tugs 2 x 286 w 44 z −35 — 25.1-25.2 needs 94 px of drift for 2 tugs (80), 25.2-25.3 has the shortcut slab 25s in its path, 25.4 moves)")
	print("PLAN planked=", planked.size(), " rafted=", rafted.size(), " cut=", cutp.size(), " (want 1 0 0) ghost=", ghost.size(), " vent=", vent.size(), " bridge=", bridge.size(), " wind=", wind.size(), " high=", high.size(), " star=", star.size(), " (want 1 0 1 0 1 0)")
	var s: Dictionary = ba.balloons[0]
	var z := C.PLAYER_Z
	var a_hop: Dictionary = plats[1]; var b_hop: Dictionary = plats[2]
	# 올라타기(t 1): 건너편 발판·먼 x(250)·앞 z 20 은 아니다; 아래 발판 바구니 옆(300)은 받는다(creak); 탄 채 다시는 아니다
	ba.sync(1.0)
	var g_b := ba.grab(b_hop, 420.0, z); var g_far := ba.grab(a_hop, 250.0, z); var g_front := ba.grab(a_hop, 300.0, 20.0)
	var g := ba.grab(a_hop, 300.0, z); var creak: AudioStreamPlayer3D = s["creak"]; var creak_on := creak.playing
	var g_again := ba.grab(a_hop, 300.0, z)
	print("GRAB ok id=%s kind=%s x0=%.0f y0=%.0f creak=%s (want 25.B0 balloon 300 15100 true) | b=%s far=%s front=%s again=%s (want true ×4: empty)" % [g.get("id", "-"), g.get("kind", "-"), float(g.get("x0", 0.0)), float(g.get("y0", 0.0)), creak_on, g_b.is_empty(), g_far.is_empty(), g_front.is_empty(), g_again.is_empty()])
	# 타기: 1.0 → 300(선 자리), 1.125 → 304(한 걸음의 반), 1.1 의 당김은 안 받는다; 1.3 당김(whoosh, 손 −1) → 1.7 에 25 올라 15125·324, 2.1 에 50 → 15150·340, 3.2 (0.6 버틴 뒤 0.5초 식어) 45 → 15145·336.80
	var fig := Stick3D.new(); root.add_child(fig)
	var r0 := ba.ride_on(g, fig); ba.sync(1.125); var r1 := ba.ride_on(g, fig)
	ba.sync(1.1); var t_early := ba.tug(g)
	ba.sync(1.3); var t_ok := ba.tug(g); var whoosh: AudioStreamPlayer3D = s["whoosh"]; var whoosh_on := whoosh.playing
	ba.sync(1.7); var r2 := ba.ride_on(g, fig); var k2 := float(fig.get_meta("tug_k", 9.0)); var v2 := float(fig.get_meta("tug_v", 9.0)); var h2 := float(fig.get_meta("tug_h", 9.0))
	ba.sync(2.1); var r3 := ba.ride_on(g, fig)
	ba.sync(3.2); var r4 := ba.ride_on(g, fig)
	print("RIDE 1.0 x=%.2f y=%.2f (want 300.00 15100.00) | 1.125 x=%.2f (want 304.00) | early tug=%s (want false) | tug=%s whoosh=%s (want true true) | 1.7 x=%.2f y=%.2f k=%.2f v=%.2f hand=%.0f (want 324.00 15125.00 0.11 1.00 −1) | 2.1 x=%.2f y=%.2f (want 340.00 15150.00) | 3.2 x=%.2f y=%.2f done=%s (want 336.80 15145.00 false)" % [float(r0["x"]), float(r0["y"]), float(r1["x"]), t_early, t_ok, whoosh_on, float(r2["x"]), float(r2["y"]), k2, v2, h2, float(r3["x"]), float(r3["y"]), float(r4["x"]), float(r4["y"]), r4["done"]])
	# 내려서기: 3.2 당김 → 4.0 에 95(15195·368.80), 4.7 에 94 → 당김(100 까지) → 5.5 에 닿아 내려선다(416, 15200, creak); 빈 기구는 6.0 엔 안 받고(되내려오는 중) 7.5 에 50, 9.5 에 앉는다(thud, go 비움)
	ba.tug(g); ba.sync(4.0); var r5 := ba.ride_on(g, fig)
	ba.sync(4.7); var r6 := ba.ride_on(g, fig); ba.tug(g)
	ba.sync(5.5); creak.stop(); var r7 := ba.ride_on(g, fig); var creak_out := creak.playing
	ba.sync(6.0); var g_sink := ba.grab(a_hop, 300.0, z)
	var h_mid := ba.hgt(s, 7.5)
	ba.sync(9.5); ba._process(0.0); var thud: AudioStreamPlayer3D = s["thud"]; var thud_on := thud.playing; var go_clear := float(s["go"]) < -1.0
	print("OUT 4.0 x=%.2f y=%.2f (want 368.80 15195.00) | 4.7 y=%.2f (want 15194.00) | 5.5 x=%.2f y=%.2f done=%s creak=%s (want 416.00 15200.00 true true) | sinking grab empty=%s (want true) | 7.5 h=%.2f (want 50.00) | 9.5 thud=%s go clear=%s (want true true)" % [float(r5["x"]), float(r5["y"]), float(r6["y"]), float(r7["x"]), float(r7["y"]), r7["done"], creak_out, g_sink.is_empty(), h_mid, thud_on, go_clear])
	# 놓기: 10.0 다시 타고 10.3 당겨 10.7 에 놓으면 오르는 속도 93.7 을 주고 25 에서 되내려와 1초(4 × 25/100) 뒤 11.7 에 앉는다
	ba.sync(10.0); var g2 := ba.grab(a_hop, 300.0, z)
	ba.sync(10.3); ba.tug(g2)
	ba.sync(10.7); var lg := ba.let_go(g2); var gh := float(s["gh"]); var secs := ba.sink_secs(s)
	ba.sync(11.7); var h_home := ba.hgt(s, 11.7); thud.stop(); ba._process(0.0); var thud2 := thud.playing
	print("LETGO again=%s vy=%.1f gh=%.2f secs=%.2f (want false 93.7 25.00 1.00) | 11.7 h=%.2f thud=%s (want 0.00 true)" % [g2.is_empty(), float(lg["vy"]), gh, secs, h_home, thud2])
	# 그림: 노드 아이 6(말뚝·줄·바구니·creak·whoosh·thud), 바구니 아이 15(바닥·네 벽·테·네 줄·버너·불꽃·풍선·버너 줄·토글), 풍선 아이 3; 노드 자리 −4.778 419.444 −0.972; 매인 자리에선 바구니 0·0, 줄 0.574, 불씨 0.32; 건너편 높이에선 1.778·2.778, 줄 3.865
	var node: Node3D = s["node"]; var car: Node3D = s["car"]; var env: Node3D = s["env"]; var rope: Node3D = s["rope"]; var flame: Node3D = s["flame"]
	s["rider"] = false; s["go"] = -9.0; s["gh"] = 0.0
	ba.sync(20.0); ba._place(s); var home_x := car.position.x; var home_y := car.position.y; var rope_home := rope.scale.y; var flame_home := flame.scale.y
	s["go"] = 20.0; s["gh"] = 100.0; ba._place(s); var top_x := car.position.x; var top_y := car.position.y; var rope_top := rope.scale.y
	print("VISUAL node children=", node.get_child_count(), " (want 6) car children=", car.get_child_count(), " (want 15) env children=", env.get_child_count(), " (want 3) node pos=%.3f %.3f %.3f (want −4.778 419.444 −0.972) | home car=%.3f %.3f rope=%.3f flame=%.2f (want 0.000 0.000 0.574 0.32) | top car=%.3f %.3f rope=%.3f (want 1.778 2.778 3.865)" % [node.position.x, node.position.y, node.position.z, home_x, home_y, rope_home, flame_home, top_x, top_y, rope_top])
	# 자세: 당김(k 0.7 — 홱 내린 순간, 오른손): 오른 엉덩이 −0.22, 무릎 0.35, 어깨 −1.50, 팔꿈치 −1.40; 왼(테 손) 어깨 −0.55, 팔꿈치 −0.50; 골반 0.370 → 예비(k 1.0): 어깨 −2.20, 팔꿈치 −0.50, 엉덩이 −0.10, 무릎 0.15 → 오름(k 0, v 1): 엉덩이 −0.05, 골반 0.400
	fig.pose_request = "tug"
	fig.set_meta("tug_k", 0.7); fig.set_meta("tug_h", 1.0); fig.set_meta("tug_v", 0.0)
	for i in 90: await process_frame   # 헤드리스 프레임은 짧다 — 널의 점검처럼 90 프레임
	var hip_d: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_d: float = (fig.knees[1.0] as Node3D).rotation.x; var sh_d: float = (fig.shoulders[1.0] as Node3D).rotation.x; var el_d: float = (fig.elbows[1.0] as Node3D).rotation.x
	var sh_r: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var el_r: float = (fig.elbows[-1.0] as Node3D).rotation.x; var pel_d := fig.pelvis.position.y
	fig.set_meta("tug_k", 1.0)
	for i in 90: await process_frame
	var hip_u: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_u: float = (fig.knees[1.0] as Node3D).rotation.x; var sh_u: float = (fig.shoulders[1.0] as Node3D).rotation.x; var el_u: float = (fig.elbows[1.0] as Node3D).rotation.x
	fig.set_meta("tug_k", 0.0); fig.set_meta("tug_v", 1.0)
	for i in 90: await process_frame
	var hip_v: float = (fig.hips[1.0] as Node3D).rotation.x; var pel_v := fig.pelvis.position.y
	print("POSE yank: hip=%.2f knee=%.2f shoulder=%.2f elbow=%.2f rim shoulder=%.2f elbow=%.2f pelvis=%.3f (want −0.22 0.35 −1.50 −1.40 −0.55 −0.50 0.370) | ready: hip=%.2f knee=%.2f shoulder=%.2f elbow=%.2f (want −0.10 0.15 −2.20 −0.50) | rising: hip=%.2f pelvis=%.3f (want −0.05 0.400)" % [hip_d, knee_d, sh_d, el_d, sh_r, el_r, pel_d, hip_u, knee_u, sh_u, el_u, hip_v, pel_v])
	# 진짜 탑: 1..60층에 plan 이 찾는 기구 — 구름바다 층 25, 26, 28, 29, 60, 61, 62, 64 중 뗏목·버섯·널이 안 가져간 틈이 있고 위가 트인 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 61):
		var pl: Array = gm.band(n)
		var tk: Array = cr.plan(n, pl) + mu.plan(n, pl)
		var out := ba.plan(n, pl, tk + cp.plan(n, pl, tk))
		if out.size() > 0: bands.append("%d:%s" % [n, out.map(func(v: Dictionary) -> String: return "%s-%s gap %.0f dy %.0f tugs %d" % [String(v["a_id"]), String(v["b_id"]), float(v["gap"]), float(v["dy"]), int(v["tugs"])])]); count += out.size()
	print("TOWER floors=", bands, " balloons=", count, " (want a subset of 25, 26, 28, 29, 60, 61, 62, 64 — at most one each)")
	quit()
