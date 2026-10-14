extends SceneTree
## 신호(signals.gd) 점검 — 신호·멈춤 마디 수, 신호 마디에서 큰길 쪽·골목 쪽 규칙, 큰길 건너기 경유지
func _init() -> void:
	Valley.roads(); Signals.build()
	print("SIG n=%d yield=%d t=%.1f" % [Signals.list.size(), Signals._yield.size(), Signals.phase_t()])
	for s in Signals.list:
		var d: Vector2 = s["dir"]
		print("  at %s main=%d side=%d" % [str((s["p"] as Vector2).snapped(Vector2.ONE)), Signals.rule(s["node"], -d * 10.0), Signals.rule(s["node"], Vector2(-d.y, d.x) * 10.0)])
	print("WALK ", Signals.walk_steps(Vector3(-100, 0, -30), Vector3(-80, 0, 8)))
	print("WALK same side ", Signals.walk_steps(Vector3(-100, 0, -30), Vector3(-80, 0, -20)))
	quit()
