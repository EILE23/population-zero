extends SceneTree
## 밧줄 다리 팩 점검(헤드리스): 자료가 읽히나, min_gap..max_gap 안의 가장 긴 틈 하나에 다리가 걸리나(아래 턱 끝 → 위 턱 끝, 너무 짧은·긴 틈은 진다), 바닥이 현수선으로 처지나(끝은 턱 높이, 가운데 sag),
## 바닥을 지나는 몸과 catch 안에서 내려서는 몸만 land 가 받나(멀리 위·옆·앞뒤 밖은 아니다), 서 있으면 load_t 에 걸쳐 dip 만큼 더 처지고 흔들리며 삐걱이나, 떠나면 돌아오나, 판자·밧줄이 그려지나,
## sway 자세가 팔을 벌리고 무릎을 느슨히 하고 골반이 흔들림을 따라 기우나, 진짜 탑의 1..40층에서 plan 이 다리를 몇 개 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var br := ClimbBridge.new(); root.add_child(br)
	await process_frame
	print("PACK id=", br.pack.get("id"), " kind=", br.kind.size() > 0, " pose=", br.pack.get("pose"))
	var plats: Array = [
		{ "id": "4.0", "x": 100.0, "y": 2500.0, "w": 180.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "4.1", "x": 330.0, "y": 2610.0, "w": 150.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "4.2", "x": 720.0, "y": 2720.0, "w": 160.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "4.3", "x": 420.0, "y": 2830.0, "w": 120.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "4.4", "x": 140.0, "y": 2940.0, "w": 120.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "4s", "x": 600.0, "y": 2758.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var planned := br.plan(4, plats)
	var none := br.plan(5, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	br.build(band_root, planned)
	print("PLAN n4=", planned.size(), " (want 1: the 160 gap 4.4↔4.3 — x0 260 y0 2940 (4.4, the upper hop, on the left) → x1 420 y1 2830; the 50 gap 4.0→4.1 is too short and the 240 and 180 gaps both hold the short slab 4s) ids=", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + " %.0f,%.0f→%.0f,%.0f" % [float(v["x0"]), float(v["y0"]), float(v["x1"]), float(v["y1"])]), " n5=", none.size(), " nodes=", band_root.get_child_count())
	var s: Dictionary = br.bridges[0]
	var x0 := float(s["x0"]); var x1 := float(s["x1"]); var mid := (x0 + x1) / 2.0
	var chord := (float(s["y0"]) + float(s["y1"])) / 2.0
	print("SURF end0=%.1f (want y0 %.0f) end1=%.1f (want y1 %.0f) mid=%.1f (want chord %.0f − sag 28 = %.0f) quarter=%.1f" % [br.surf(s, x0), float(s["y0"]), br.surf(s, x1), float(s["y1"]), br.surf(s, mid), chord, chord - 28.0, br.surf(s, x0 + (x1 - x0) * 0.25)])
	# 착지: 가운데 바닥 위 5px 에서 5px 아래로 → 받는다; 10px 위에서 내려서는 몸 → step; 20px 위 → 아니다; 폭 밖·앞뒤 밖 → 아니다
	var sy := br.surf(s, mid)
	var l_cross := br.land(mid, sy + 5.0, sy - 5.0, float(s["z"]))
	var l_step := br.land(mid, sy + 10.0, sy + 9.0, float(s["z"]))
	var l_high := br.land(mid, sy + 20.0, sy + 19.0, float(s["z"]))
	var l_side := br.land(x1 + 30.0, sy + 5.0, sy - 5.0, float(s["z"]))
	var l_z := br.land(mid, sy + 5.0, sy - 5.0, float(s["z"]) + 100.0)
	print("LAND cross=%s y=%.1f step=%s (want 4.b0, %.1f, false) | catch=%s step=%s (want 4.b0 true) | high=%s side=%s far_z=%s (want all empty)" % [l_cross.get("id", "-"), float(l_cross.get("y", 0.0)), l_cross.get("step", "-"), sy, l_step.get("id", "-"), l_step.get("step", "-"), l_high.get("id", "-"), l_side.get("id", "-"), l_z.get("id", "-")])
	# 서기: 매 프레임 stand → 0.4초 뒤 load 1, 바닥이 dip 11 더 낮고, 흔들림이 −1..1 을 오가며, 노드가 앞뒤로 밀린다; 삐걱 스트림; 떠나면 0.4초 안에 돌아온다
	var fig := Stick3D.new(); root.add_child(fig)
	var swing_lo := 9.0; var swing_hi := -9.0; var z_lo := 9.0; var z_hi := -9.0
	var node: Node3D = s["node"]; var z_rest := node.position.z
	var frames_on := 0   # 헤드리스 _process 의 delta 는 수 ms — 프레임 수가 아니라 load 가 차는 걸 본다
	for i in 400:
		br.stand(s, mid, 0.016, fig)
		await process_frame
		frames_on = i + 1
		if float(s["load"]) >= 1.0: break
	var load_on := float(s["load"]); var dip_on := sy - br.surf(s, mid)
	for i in 80:
		br.stand(s, mid, 0.016, fig)
		await process_frame
		var sw := br.swing_of(s); swing_lo = minf(swing_lo, sw); swing_hi = maxf(swing_hi, sw)
		z_lo = minf(z_lo, node.position.z - z_rest); z_hi = maxf(z_hi, node.position.z - z_rest)
	var meta_k := float(fig.get_meta("sway_k", 9.0))
	var creak: bool = (s["creak"] as AudioStreamPlayer3D).stream != null
	var frames_off := 0
	for i in 400:
		await process_frame
		frames_off = i + 1
		if float(s["load"]) <= 0.0: break
	var load_off := float(s["load"]); var dip_off := sy - br.surf(s, mid)
	print("STAND load=%.2f dip=%.1f (want 1.00, 11.0; took %d frames, ≈ 0.25 s of process delta) swing lo=%.2f hi=%.2f (want ≈ −1..1) node z lo=%.3f hi=%.3f (want ≈ ∓0.17 m) meta=%.2f (inside −1..1) creak=%s | left: load=%.2f dip=%.1f (want 0.00, 0.0; %d frames) rest z=%.3f (want %.3f)" % [load_on, dip_on, frames_on, swing_lo, swing_hi, z_lo, z_hi, meta_k, creak, load_off, dip_off, frames_off, node.position.z, z_rest])
	# 그림: 판자 수(폭 160 / 18 = 8), 손잡이 2 × 판자, 실, 말뚝 4
	var planks: Array = s["planks"]; var rails: Array = s["rails"]; var threads: Array = s["threads"]
	var p0: MeshInstance3D = planks[0]; var pm: MeshInstance3D = planks[planks.size() / 2]
	print("VISUAL planks=", planks.size(), " (want 8) rails=", rails.size(), " (want 16) threads=", threads.size(), " (want 6) children=", node.get_child_count(), " (want 8+16+6+4 posts+1 creak = 35) plank0 y=%.2f mid y=%.2f (mid lower than the ends by ≈ sag·K = 0.78 m less the chord's rise; both relative to y0)" % [p0.position.y, pm.position.y])
	# 자세: 팔 벌림(어깨 z 오른 −1.0 쯤·왼 +1.3 쯤 — 낮아지는 왼쪽이 더 오른다 when sway_k = 1), 무릎 느슨(오른 0.3·왼 0.6), 골반 z 돌림 0.1, 골반 0.37
	fig.pose_request = "sway"; fig.set_meta("sway_k", 1.0)
	await process_frame; await process_frame; await process_frame
	var early: float = (fig.shoulders[1.0] as Node3D).rotation.z
	for i in 40: await process_frame
	var sh_r: float = (fig.shoulders[1.0] as Node3D).rotation.z; var sh_l: float = (fig.shoulders[-1.0] as Node3D).rotation.z
	var kn_r: float = (fig.knees[1.0] as Node3D).rotation.x; var kn_l: float = (fig.knees[-1.0] as Node3D).rotation.x
	var roll := fig.pelvis.rotation.z; var hip_y := fig.pelvis.position.y
	fig.set_meta("sway_k", -1.0)
	for i in 40: await process_frame
	var roll2 := fig.pelvis.rotation.z; var sh_r2: float = (fig.shoulders[1.0] as Node3D).rotation.z
	print("POSE early=%.2f (≈ 0, before the arms open) right arm=%.2f left arm=%.2f (want ≈ −1.05 and ≈ +1.75: the dipping left side rises) knees r=%.2f l=%.2f (want ≈ 0.30 and 0.60 — the low side bends more) pelvis roll=%.3f (want ≈ 0.10) hip_y=%.2f (want ≈ 0.37) | swing flipped: roll=%.3f (want ≈ −0.10) right arm=%.2f (want ≈ −1.75)" % [early, sh_r, sh_l, kn_r, kn_l, roll, hip_y, roll2, sh_r2])
	# 진짜 탑: 1..40층에 plan 이 찾는 다리 수
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var g: Node3D = town.game_node
	var count := 0; var bands: Array = []; var spans: Array = []
	for n in range(1, 41):
		var pl := br.plan(n, g.band(n))
		if pl.size() > 0: bands.append(n); count += pl.size()
		for v in pl: spans.append(int(float(v["w"])))
	print("TOWER floors=", bands, " bridges=", count, " spans=", spans, " (want every 4th floor from 4 — 4, 8, 12 … 40 — one each where two std hops meet 90..320 px apart, some skipped by a slab in the span)")
	quit()
