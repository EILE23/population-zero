extends SceneTree
## 데스크톱 성능 점검(헤드리스 — 그리기 비용은 못 재고 스크립트·물리만): 허브 → 열린 세계 장소 셋 → 허브로 걸어가듯 순간이동하며
## 칸 짓기 시간(최대·평균)과 장소마다 처리·물리 시간(틱 평균·최악)을 찍는다. 끝에 차가 다 땅 위에 있는지도 — godot --headless --path game -s res://tools/probe_perf.gd
const STOPS := [["hub", Vector3(0, 0, 4)], ["cabin", Vector3(-150, 0, -30)], ["lakeside", Vector3(135, 0, -40)], ["tower", Vector3(16, 0, -70)], ["hub", Vector3(0, 0, 4)]]
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var g: WorldGen = town.gen
	g.build_us_max = 0; g.build_us_sum = 0; g.built = 0
	for st in STOPS:
		var to: Vector3 = st[1]
		var from: Vector3 = town.body.global_position
		# 6m 씩 끊어 옮겨 칸 흐름이 실제로 걸을 때처럼 한 칸씩 들어오게
		var n := int(from.distance_to(to) / 6.0) + 1
		for k in n:
			var p := from.lerp(to, float(k + 1) / n); p.y = g.height(p.x, p.z) + 0.5
			town.body.global_position = p; town.body.velocity = Vector3.ZERO
			await process_frame
		for i in 60: await process_frame   # 남은 칸이 다 들어오게
		var proc := 0.0; var phys := 0.0; var worst := 0.0
		for i in 120:   # 물리 틱마다 잰다 — 헤드리스는 그리기가 없어 프레임이 물리보다 잦다
			await physics_frame
			var a := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			var b := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			proc += a; phys += b; worst = maxf(worst, a + b)
		var far := 0
		for r in town.residents: if (r as Node3D).global_position.distance_to(town.body.global_position) > 60.0: far += 1
		print("PERF %-8s process %.2fms physics %.2fms worst %.2fms chunks %d far residents %d/%d" % [st[0], proc / 120.0, phys / 120.0, worst, g.chunks.size(), far, town.residents.size()])
	for c in town.cars: if (c as Node3D).global_position.y < -1.0: print("PERF FELL ", c.kind, " at ", (c as Node3D).global_position.snapped(Vector3.ONE))
	print("PERF chunk stream: %d chunks built, %.2fms per chunk (ground + nature, two frames), worst frame %.2fms" % [g.built, g.build_us_sum / 1000.0 / maxi(g.built, 1), g.build_us_max / 1000.0])
	quit()
