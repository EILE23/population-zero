extends SceneTree
## 별 등롱 팩 점검(헤드리스): 자료가 읽히나, 별밤 층의 잇단 still 발판 사이 틈 중 가장 넓은 하나에만 장대가 서나(움직이는 발판 옆·너무 넓은 틈·지름길 판이 쓸고 지나는 길을 가르는 틈은 지고, taken 의 고드름이 가르면 다음 틈으로, 다른 테마 층은 아니다),
## 기하가 맞나(r = sqrt(D² + H²), amax = atan2(D, H), 손 높이 h = r + 58, 오르는 시간 = (h − 70) / 90), 손이 갈고리 범위 안인 공중의 몸만 grab 이 받나(높이·좌우·앞뒤 밖·돌아오는 장대는 아니다),
## 안으면 손이 90 px/s 로 오르다 h 에서 장대가 1.8초에 걸쳐 넘어가 발이 건너편 발판 16 안·10 위에 오고 0.2초 뒤 발판 윗면에 내려지나(done), 놓을 때 오르는 중엔 위로·호의 가운데선 접선으로 속도가 나오나, 빈 장대가 2초에 걸쳐 돌아오며 그동안 못 잡나,
## 돌 발판·핀·장대·띠·갈고리·팔·끈·별·갓이 그려지고 장대가 각대로 돌며 등롱은 아래로 드리우나, 움직이는 동안 creak 이 돌고 끝에서 clack 이 울리나, cling 자세가 장대를 안고 오르다 넘어갈 땐 골반째 기우나, 진짜 탑의 1..70층에서 plan 이 별밤 층에만 장대를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cn := ClimbLantern.new(); root.add_child(cn)
	var ci := ClimbIcicle.new(); root.add_child(ci)
	await process_frame
	print("PACK id=", cn.pack.get("id"), " kind=", cn.kind.size() > 0, " pose=", cn.pack.get("pose"), " themes=", cn.pack.get("themes"), " hook=%.0f (want 70) shin_v=%.0f (want 90) swing=%.1f (want 1.8) back=%.1f (want 2.0)" % [cn.hook(), cn.shin_v(), cn.swing_s(), cn.back_s()])
	var plats: Array = [
		{ "id": "31.0", "x": 100.0, "y": 18700.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31.1", "x": 416.0, "y": 18810.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31.2", "x": 100.0, "y": 18930.0, "w": 140.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "31.3", "x": 370.0, "y": 19060.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31.4", "x": 650.0, "y": 19150.0, "w": 130.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31.5", "x": 460.0, "y": 19260.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31s", "x": 540.0, "y": 19230.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cn.plan(31, plats)
	var taken := cn.plan(31, plats, [{ "id": "31.i1.0", "kind": "icicle", "x": 300.0, "y": 18850.0, "floor": 18700.0 }])
	var rest := cn.plan(30, plats)
	var other := cn.plan(35, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	cn.build(band_root, free)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " on %s dir %.0f px %.0f tgt %.0f r %.2f amax %.3f h %.1f len %.1f shin %.3f x %.0f w %.0f z %.0f" % [String(v["a_id"]), float(v["dir"]), float(v["px"]), float(v["tgt"]), float(v["r"]), float(v["amax"]), float(v["h"]), float(v["len"]), float(v["shin_s"]), float(v["x"]), float(v["w"]), float(v["z"])]
	print("PLAN free=", free.map(show), " (want 1: gaps 136 (31.0↔31.1), 176 (31.1↔31.2, past max_gap → out), 130 (31.2↔31.3), 140 (31.3↔31.4: dy 90 makes the tilt 1.023 > max_tilt → out), 70 (31.4↔31.5: the short slab 31s in the pole's sweep → out); the widest left, 136, gets the pole — 31.L0 on 31.0 dir 1 px 272 tgt 432 r 200.00 amax 0.927 h 258.0 len 298.0 shin 2.089 x 272 w 160 z −56)")
	print("PLAN taken=", taken.map(show), " (want 1: the icicle at 300,18850 cuts the first gap's box → the 130 gap: 31.L0 on 31.2 dir 1 px 232 tgt 386 r 208.12 amax 0.833 h 266.1 len 306.1 shin 2.179 x 232 w 154) rest=", rest.size(), " (want 1: floor 30 is Starlit too) other=", other.size(), " (want 0: Old hall)")
	var s: Dictionary = cn.poles[0]
	# 잡기(t 0, 곧게 선 장대, 갈고리 272,18770): 손(발 + 58)이 22 안·x 26 안인 몸 → 받는다; 50 아래·40 옆·앞뒤 밖은 아니다
	cn.sync(0.0)
	var g_ok := cn.grab(270.0, 18720.0, C.PLAYER_Z)
	var g_low := cn.grab(270.0, 18680.0, C.PLAYER_Z)
	var g_side := cn.grab(310.0, 18720.0, C.PLAYER_Z)
	var g_z := cn.grab(270.0, 18720.0, C.PLAYER_Z + 100.0)
	print("GRAB ok=%s x=%.1f y=%.1f dir=%.0f (want 31.L0 272.0 18712.0 1: under the rung) | low=%s side=%s far_z=%s (want all empty) held=%s" % [g_ok.get("id", "-"), float(g_ok.get("x", 0.0)), float(g_ok.get("y", 0.0)), float(g_ok.get("dir", 0.0)), g_low.get("id", "-"), g_side.get("id", "-"), g_z.get("id", "-"), bool(s["held"])])
	# 오르기(1.0: 손 160, 발 102 → 272,18802, 곧게, cling_v 1) → 손이 h 에(2.0889: 발 200 → 272,18900) → 넘어가기 가운데(2.9889, u 0.5: 각 0.464 → 361.4,18878.9, cling_v 0) → 끝(3.8889: 각 0.927 → 432,18820 = 건너편 16 안·10 위) → 내려놓기(4.1: done, y 18810)
	var fig := Stick3D.new(); root.add_child(fig)
	cn.sync(1.0); var h1 := cn.hang_on(g_ok, fig); var v1 := float(fig.get_meta("cling_v", 9.0)); var a1 := float(fig.get_meta("cling_a", 9.0))
	cn.sync(2.0889); var h2 := cn.hang_on(g_ok, fig)
	cn.sync(2.9889); var h3 := cn.hang_on(g_ok, fig); var v3 := float(fig.get_meta("cling_v", 9.0)); var a3 := float(fig.get_meta("cling_a", 9.0))
	var lg_mid := cn.let_go(g_ok)
	s["held"] = true; s["rel"] = -9.0   # 놓은 손을 되돌려 호를 끝까지 본다
	cn.sync(3.8889); var h4 := cn.hang_on(g_ok, fig)
	cn.sync(4.1); var h5 := cn.hang_on(g_ok, fig)
	var h_lost := cn.hang_on({ "id": "nope", "x": 1.0, "y": 2.0 })
	print("HANG 1.0: x=%.1f y=%.1f v=%.0f a=%.3f (want 272.0 18802.0 1 0.000) | 2.0889: y=%.1f (want 18900.0: the hands at h) | 2.9889: x=%.1f y=%.1f v=%.0f a=%.3f (want 361.4 18878.9 0 0.464) | 3.8889: x=%.1f y=%.1f done=%s (want 432.0 18820.0 false) | 4.1: x=%.1f y=%.1f done=%s held=%s (want 432.0 18810.0 true false) | unknown id: lost=%s" % [float(h1["x"]), float(h1["y"]), v1, a1, float(h2["y"]), float(h3["x"]), float(h3["y"]), v3, a3, float(h4["x"]), float(h4["y"]), h4["done"], float(h5["x"]), float(h5["y"]), h5["done"], bool(s["held"]), h_lost["lost"]])
	# 놓기: 호의 가운데(2.9889, u 0.5)선 ω = 0.927 × 1.5 / 1.8 = 0.773, v = 200 × 0.773 = 154.6 → vx 138.2 vy −69.1; 오르는 중(1.0)엔 0 / 90
	s["held"] = true; s["rel"] = -9.0; cn.sync(1.0); var lg_shin := cn.let_go(g_ok)
	print("LETGO mid-arc: vx=%.1f vy=%.1f (want 138.2 −69.1: tangent, going over and down) | shinning: vx=%.1f vy=%.1f (want 0.0 90.0) | after: held=%s rel=%.1f rang=%.3f (want false 1.0 0.000)" % [float(lg_mid["vx"]), float(lg_mid["vy"]), float(lg_shin["vx"]), float(lg_shin["vy"]), bool(s["held"]), float(s["rel"]), float(s["rang"])])
	# 돌아오기: 4.1 에 각 0.927 에서 놓인 장대는 5.1 에 반(0.464), 6.1 에 집(0) — 5.1 엔 못 잡고 6.2 엔 잡는다
	s["rel"] = 4.1; s["rang"] = float(s["amax"])
	cn.sync(5.1); var a_half := cn.ang(s, 5.1); var g_back := cn.grab(270.0, 18720.0, C.PLAYER_Z)
	cn.sync(6.2); var a_home := cn.ang(s, 6.2); var g_again := cn.grab(270.0, 18720.0, C.PLAYER_Z)
	print("RETURN 5.1: ang=%.3f (want 0.464) grab=%s (want empty: returning) | 6.2: ang=%.3f (want 0.000) grab=%s (want 31.L0)" % [a_half, g_back.get("id", "-"), a_home, g_again.get("id", "-")])
	# 그림·소리: 노드 아이 5(돌 발판·핀·장대 노드·creak·clack), 장대 아이 7(장대·띠 셋·갈고리·팔·끈 노드), 끈 아이 2(끈·별 노드), 별 아이 3(두 판·갓); 넘어가는 가운데(각 0.464)에 장대 −0.464·끈 +0.464, creak 이 돌고; 집에 앉으면 clack
	s["held"] = true; s["t0"] = 0.0; s["rel"] = -9.0
	cn.sync(2.9889); cn._process(0.0)
	var pole: Node3D = s["pole"]; var cord: Node3D = s["cord"]; var creak: AudioStreamPlayer3D = s["creak"]; var clack: AudioStreamPlayer3D = s["clack"]
	var rot_mid := pole.rotation.z; var cord_mid := cord.rotation.z; var creak_mid := creak.playing
	cn.sync(3.9); cn._process(0.0); var rot_end := pole.rotation.z
	cn._release(s, float(s["amax"])); s["rel"] = 3.9
	cn.sync(6.0); cn._process(0.0); var clack_home := clack.playing; cn._process(0.0); var creak_home := creak.playing   # 두 번째 틀에서 멎는다(서가의 rumble 과 같은 식)
	var node: Node3D = s["node"]; var glow: StandardMaterial3D = s["glow"]
	print("VISUAL node children=", node.get_child_count(), " (want 5) pole=", pole.get_child_count(), " (want 7) cord=", cord.get_child_count(), " (want 2: cord, star) star=", (cord.get_child(1) as Node3D).get_child_count(), " (want 3: two plates, a crown) | mid-arc pole=%.3f cord=%.3f (want −0.464 0.464: the lantern hangs plumb) creak=%s (want true) | end pole=%.3f (want −0.927) | home: clack=%s creak=%s (want true false) glow=%s energy=%.2f (want true, 0.7..1.5) node pos=%.3f %.3f %.3f (want −5.778 519.444 −1.556)" % [rot_mid, cord_mid, creak_mid, rot_end, clack_home, creak_home, glow.emission_enabled, glow.emission_energy_multiplier, node.position.x, node.position.y, node.position.z])
	# 자세: 오르기(v 1): 두 어깨 ≤ −2.2(머리 위 앞), 팔꿈치 −0.95(접은 채), 무릎 ≥ 0.9(죈다), 엉덩이 ≤ −0.55(앞으로), 고개 위로; 넘어가기(v 0, a 0.9, +x 를 보며): 골반 0.81(장대와 같이 앞으로), 무릎 1.4, 엉덩이 −0.95
	fig.pose_request = "cling"; fig._yaw = PI / 2.0; fig._yaw_target = PI / 2.0
	fig.set_meta("cling_v", 1.0); fig.set_meta("cling_a", 0.0)
	await process_frame; await process_frame; await process_frame
	var early_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	for i in 60: await process_frame
	var sh_a: float = (fig.shoulders[1.0] as Node3D).rotation.x; var sh_b: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var el_a: float = (fig.elbows[1.0] as Node3D).rotation.x
	var hip_a: float = (fig.hips[1.0] as Node3D).rotation.x; var kn_a: float = (fig.knees[1.0] as Node3D).rotation.x; var neck_c := fig.neck.rotation.x; var pel_c := fig.pelvis.rotation.x
	fig.set_meta("cling_v", 0.0); fig.set_meta("cling_a", 0.9)
	for i in 40: await process_frame
	var pel_t := fig.pelvis.rotation.x; var kn_t: float = (fig.knees[1.0] as Node3D).rotation.x; var hip_t: float = (fig.hips[1.0] as Node3D).rotation.x; var sh_t: float = (fig.shoulders[1.0] as Node3D).rotation.x
	print("POSE early=%.2f (want > −2.2: the arms are only reaching) shinning: shoulders=%.2f %.2f (want both ≤ −2.2) elbow=%.2f (want −0.95) hip=%.2f (want ≤ −0.55) knee=%.2f (want ≥ 0.9) neck=%.2f (want < 0: looking up the pole) pelvis=%.3f (want 0..0.04) | tilted: pelvis=%.2f (want 0.81 = 0.9 × 0.9) knee=%.2f (want 1.40) hip=%.2f (want −0.95) shoulder=%.2f (want −2.55)" % [early_sh, sh_a, sh_b, el_a, hip_a, kn_a, neck_c, pel_c, pel_t, kn_t, hip_t, sh_t])
	# 진짜 탑: 1..70층에 plan 이 찾는 장대 — 별밤 층 30..34, 65..69 (틈이 60..170 이고 기하가 맞는 층만; 고드름의 자리는 비켜서)
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var out := cn.plan(n, pl, ci.plan(n, pl))
		if out.size() > 0: bands.append("%d:%s" % [n, out.map(func(v: Dictionary) -> String: return "%s gap %.0f amax %.2f r %.0f" % [String(v["a_id"]), float(v["gap"]), float(v["amax"]), float(v["r"])])]); count += out.size()
	print("TOWER floors=", bands, " lanterns=", count, " (want a subset of 30..34 and 65..69, one each)")
	quit()
