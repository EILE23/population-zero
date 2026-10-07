extends SceneTree
## 상승기류 팩 점검(헤드리스): 자료가 읽히나, 짝이 박자에 번갈아 켜지나, 기둥에 든 몸이 lift 로 떠올라 height 근처에서 떠도나(순수 step_vy 시뮬레이션),
## 기둥 밖·꺼진 기둥에선 그냥 떨어지나, glide 자세가 팔을 벌리고 착지 뒤 DROP_T 에 내려오나, 진짜 탑의 1..40층에서 plan 이 통풍구를 몇 개 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var up := ClimbUpdraft.new(); root.add_child(up)
	await process_frame
	print("PACK id=", up.pack.get("id"), " kind=", up.kind.size() > 0, " pose=", up.pack.get("pose"))
	var plats: Array = [
		{ "id": "7.0", "x": 100.0, "y": 4300.0, "w": 190.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "7.1", "x": 400.0, "y": 4400.0, "w": 120.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "7.2", "x": 600.0, "y": 4500.0, "w": 170.0, "kind": "std", "z": -35.0, "d": 70.0 },
		{ "id": "7s", "x": 300.0, "y": 4448.0, "w": 60.0, "kind": "short", "z": -35.0, "d": 60.0 },
	]
	var planned := up.plan(7, plats)
	var none := up.plan(8, plats)
	var band_root := Node3D.new(); root.add_child(band_root)
	up.build(band_root, planned)
	print("PLAN n7=", planned.size(), " (want 2: 7.0 and 7.2) ids=", planned.map(func(v: Dictionary) -> String: return String(v["id"]) + "@%.0f" % float(v["x"])), " n8=", none.size(), " nodes=", band_root.get_child_count(), " streaks=", (up.vents[0]["streaks"] as Array).size())
	up.t = 0.5; var a0 := up.active(up.vents[0]); var b0 := up.active(up.vents[1])
	up.t = 2.5; var a1 := up.active(up.vents[0]); var b1 := up.active(up.vents[1])
	print("BEAT t0.5 a=", a0, " b=", b0, " | t2.5 a=", a1, " b=", b1, " (want a on then b on)")
	up.t = 0.5; await process_frame   # _process 가 줄기·틈·소리를 켠다(a 가 켜진 때)
	var v: Dictionary = up.vents[0]
	print("VISUAL a_on=", up.active(v), " emitting=", (v["streaks"][0] as CPUParticles3D).emitting, " glow=", (v["glow"] as Node3D).visible, " hum=", (v["hum"] as AudioStreamPlayer3D).playing)
	# 몸: 판 위 60px 에서 vy 0 으로 — 5초 뒤 apex 와 끝 높이(판 기준 px). 켜진 기둥 안 / 기둥 밖 / 꺼진 기둥
	var sim := func(x: float, tt: float) -> Array:
		up.t = tt
		var y: float = float(v["y"]) + 60.0; var vy := 0.0; var apex := -1e9; var lifted := false
		for i in 300:
			var dt := 1.0 / 60.0
			vy -= C.G * dt
			vy = up.step_vy(x, y, float(v["z"]), vy, dt, C.G)
			lifted = lifted or up.lifting
			y += vy * dt; apex = maxf(apex, y - float(v["y"]))
			if y < float(v["y"]): y = float(v["y"]); vy = maxf(vy, 0.0)   # 쇠살판
		return [apex, y - float(v["y"]), lifted]
	var h := float(up.kind["height"])
	var r_in: Array = sim.call(float(v["x"]), 0.0); var r_out: Array = sim.call(float(v["x"]) + 200.0, 0.0); var r_off: Array = sim.call(float(v["x"]), 2.5)
	print("LIFT in apex=%.0f end=%.0f lifted=%s (want apex %.0f..%.0f, end > %.0f) | out apex=%.0f lifted=%s (want 60) | off apex=%.0f lifted=%s (want 60)" % [r_in[0], r_in[1], r_in[2], h, h + 20.0, h - 10.0, r_out[0], r_out[2], r_off[0], r_off[2]])
	# 기둥 안에서 뛴 몸은 더 높이 간다(중력 ×0.35) — JUMP_V 로 판에서 뛰어 apex 비교
	up.t = 0.0
	var jump := func(x: float) -> float:
		var y: float = float(v["y"]); var vy: float = C.JUMP_V; var apex := 0.0
		for i in 120:
			vy -= C.G / 60.0; vy = up.step_vy(x, y, float(v["z"]), vy, 1.0 / 60.0, C.G); y += vy / 60.0; apex = maxf(apex, y - float(v["y"]))
		return apex
	print("JUMP in=%.0f out=%.0f px (in > out, out ≈ 154)" % [jump.call(float(v["x"])), jump.call(float(v["x"]) + 200.0)])
	# 자세: 공중에서 glide — 팔이 옆으로 벌어지고(어깨 z ≈ -1.45), 착지 뒤 DROP_T 에 내려온다(≈ -0.04), done 이 참이 된다
	var f := Stick3D.new(); root.add_child(f)
	f.pose_request = "glide"; f.airborne = true; f.vertical = 1.0
	await process_frame; await process_frame; await process_frame
	var early: float = (f.shoulders[1.0] as Node3D).rotation.z
	for i in 40: await process_frame
	var spread: float = (f.shoulders[1.0] as Node3D).rotation.z; var done_air := GlidePoses.done(f)
	f.airborne = false
	for i in 120: await process_frame   # 헤드리스 프레임은 ~5ms — DROP_T 0.3초를 넉넉히
	var dropped: float = (f.shoulders[1.0] as Node3D).rotation.z
	print("GLIDE early=%.2f spread=%.2f (want ≈ -1.45) done_air=%s done_land=%s dropped=%.2f (want ≈ -0.04) pose=%s" % [early, spread, done_air, GlidePoses.done(f), dropped, f.pose_request])
	# 진짜 탑: 1..40층에 plan 이 찾는 통풍구 수
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var g: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 41):
		var pl := up.plan(n, g.band(n))
		if pl.size() > 0: bands.append(n); count += pl.size()
	print("TOWER floors=", bands, " vents=", count, " (want every 4th floor from 3 — camp floors keep their hops, so 15 and 35 count too)")
	quit()
