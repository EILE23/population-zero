extends SceneTree
## 산 점검(헤드리스): 사람이 나선 돌계단을 걸어 꼭대기까지 가나, 차는 계단을 못 오르나, 산스장 기구 자세, 숲 밀도
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	var pk: Dictionary = WorldGen.PEAKS[0]
	var pts := WorldGen.trail_xz(pk)
	var top_y: float = town.gen.summit_y(pk)
	print("PEAK %s summit=%.1f trail_pts=%d" % [pk["name"], top_y, pts.size()])
	# 사람: 들머리에서 출발해 다음 점으로 방향키(아날로그 세기)를 넣는다
	var b: CharacterBody3D = town.body
	b.global_position = Vector3(pts[0].x, town.gen.height(pts[0].x, pts[0].y) + 0.6, pts[0].y); b.velocity = Vector3.ZERO
	var idx := 1; var stuck := 0; var best := 0; var frames := 0
	while idx < pts.size() - 1 and frames < 60 * 260:
		town.gen.stream(b.global_position, false)
		var p := Vector2(b.global_position.x, b.global_position.z)
		while idx < pts.size() - 1 and p.distance_to(pts[idx]) < 1.2: idx += 1
		var d := (pts[idx] - p).normalized()
		Input.action_release("move_left"); Input.action_release("move_right"); Input.action_release("move_up"); Input.action_release("move_down")
		if d.x > 0.0: Input.action_press("move_right", d.x)
		else: Input.action_press("move_left", -d.x)
		if d.y > 0.0: Input.action_press("move_down", d.y)
		else: Input.action_press("move_up", -d.y)
		await physics_frame
		frames += 1
		if idx > best: best = idx; stuck = 0
		else: stuck += 1
		if stuck > 60 * 6:
			print("  STUCK at idx=%d pos=%s" % [idx, str(b.global_position)]); break
		if frames % 1200 == 0: print("  t=%ds idx=%d/%d y=%.1f" % [frames / 60, idx, pts.size(), b.global_position.y])
	for a in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(a)
	print("WALK reached idx=%d/%d y=%.1f (summit %.1f) in %ds" % [idx, pts.size(), b.global_position.y, top_y, frames / 60])
	# 차: 들머리 지나 첫 계단 앞에 두고 앞으로 밟는다
	var car: Car3D = null
	for n in town.find_children("*", "Car3D", true, false): car = n; break
	var s0 := pts[40]; var s1 := pts[60]
	var yaw := atan2(s1.x - s0.x, s1.y - s0.y)
	town.gen.stream(Vector3(s0.x, 0, s0.y), false)
	car.global_position = Vector3(s0.x, town.gen.height(s0.x, s0.y) + 1.2, s0.y); car.rotation = Vector3(0, yaw + PI, 0); car.velocity = Vector3.ZERO
	car.ai = false; car.driver = car   # 운전사가 없으면 차가 입력을 0 으로 만든다 — 사람이 모는 셈
	var y0 := car.global_position.y
	for i in 60 * 8:
		car.input = { "throttle": 1.0, "steer": 0.0, "brake": false }
		await physics_frame
	print("CAR on stairs: climbed %.2f m, moved %.1f m" % [car.global_position.y - y0, Vector2(car.global_position.x - s0.x, car.global_position.z - s0.y).length()])
	car.global_position = Vector3(-40, 0.3, 2.9); car.rotation = Vector3(0, PI / 2.0, 0); car.velocity = Vector3.ZERO
	for i in 60 * 3:
		car.input = { "throttle": 1.0, "steer": 0.0, "brake": false }
		await physics_frame
	print("CAR on road (control): moved %.1f m" % Vector2(car.global_position.x + 40.0, car.global_position.z - 2.9).length())
	# 산스장
	var gyms: Array = town.spots.filter(func(sp): return sp["kind"] == "gym")
	for sp in gyms:
		town.gym_use(sp, Time.get_ticks_msec() / 1000.0)
		for i in 30: await physics_frame
		print("GYM %s emote=%s action=%s move=%s t=%.2f" % [sp["ex"], town.emote, town.player.action, town.player.move, town.player.action_t])
	# 숲 밀도: 산 자락 칸 하나의 나무 수
	var mm := 0
	for k in town.gen.chunks:
		var ch: Node3D = town.gen.chunks[k]
		for m in ch.get_children(): if m is MultiMeshInstance3D: mm += (m as MultiMeshInstance3D).multimesh.instance_count
	print("NATURE instances in %d chunks: %d" % [town.gen.chunks.size(), mm])
	quit()
