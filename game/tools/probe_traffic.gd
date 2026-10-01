extends SceneTree
## 평소 교통 90초: 주민 차의 사고·소품 파손·벽 금·멈춰 선 시간·도는 바퀴 수
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 10: await physics_frame
	var ai: Array = town.cars.filter(func(c): return c.ai)
	var crash := {}; var still := {}; var last := {}; var laps := {}
	var cracks0: int = town.cracks.size()
	for c in ai: crash[c] = 0; still[c] = 0.0; last[c] = -9.0; laps[c] = 0
	var prev_ri := {}
	for c in ai: prev_ri[c] = c._ri
	for i in 60 * 90:
		await physics_frame
		for c in ai:
			if c._crash_at != last[c]: last[c] = c._crash_at; crash[c] += 1
			if absf(c.v) < 0.3:
				still[c] += 1.0 / 60.0
				if i % 120 == 0: print("STILL ", c.kind, " at ", c.global_position.snapped(Vector3.ONE * 0.5), " block=", (c._block.name if c._block else "-"), " ", (c._block.get_class() if c._block else ""), " rev=", c._reverse_until > Time.get_ticks_msec() / 1000.0)
			if c._ri != prev_ri[c]: laps[c] += 1; prev_ri[c] = c._ri
	for c in ai: print("TRAFFIC ", c.kind, " crashes=", crash[c], " still=%.1fs" % still[c], " waypoints=", laps[c])
	print("TRAFFIC new cracks/wrecks=", town.cracks.size() - cracks0)
	for c in town.cracks.slice(cracks0): print("CRACK ", c.get("kind", "wall"), " at ", (c["at"] as Vector3).snapped(Vector3.ONE * 0.1))
	for c in ai: print("END ", c.kind, " at ", c.global_position.snapped(Vector3.ONE * 0.1), " ri=", c._ri)
	quit()
