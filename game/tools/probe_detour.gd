extends SceneTree
## 길 돌아감 — 서로 40~80m 떨어진(강 같은 편) 필지 둘 사이 차 길 길이 / 직선. 나쁜 몇 쌍의 길 모양(마디 수·지나는 곳)
func _init() -> void:
	Valley.roads()
	var lots := Valley.lots()
	var car := Node3D.new(); root.add_child(car)
	await process_frame
	print("PDT inside=%s" % str(car.is_inside_tree()))
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	var ratios: Array = []; var bad := 0
	for t in 400:
		var a: Dictionary = lots[rng.randi() % lots.size()]; var b: Dictionary = lots[rng.randi() % lots.size()]
		var d: float = (a["c"] as Vector2).distance_to(b["c"])
		if d < 40.0 or d > 80.0 or ((a["c"] as Vector2).y < Valley.RIVER_Z) != ((b["c"] as Vector2).y < Valley.RIVER_Z): continue
		var pa: Array = Valley.near(a["c"], 3)
		car.position = Vector3((pa[1] as Vector2).x, 0, (pa[1] as Vector2).y); car.force_update_transform()
		var dd: Vector2 = pa[2]; car.rotation.y = atan2(-dd.x, -dd.y)
		var pb: Array = Valley.near(b["c"], 3)
		var r := CarRail.plan(null, car, Vector3((pb[1] as Vector2).x, 0, (pb[1] as Vector2).y))
		if r == null: continue
		var L := 0.0
		for i in r.centers.size() - 1: L += r.centers[i].distance_to(r.centers[i + 1])
		var sd := (pa[1] as Vector2).distance_to(pb[1])
		ratios.append(L / maxf(sd, 1.0))
		if L / maxf(sd, 1.0) > 4.0 and bad < 6:
			bad += 1
			var smp := ""
			for i in range(0, r.centers.size(), maxi(1, r.centers.size() / 8)): smp += str(Vector2(r.centers[i].x, r.centers[i].z).snapped(Vector2.ONE)) + " "
			print("PDT bad L=%.0f sd=%.0f from %s to %s path %s" % [L, sd, str((pa[1] as Vector2).snapped(Vector2.ONE)), str((pb[1] as Vector2).snapped(Vector2.ONE)), smp])
	ratios.sort()
	print("PDT n=%d median=%.1f p75=%.1f p90=%.1f" % [ratios.size(), ratios[ratios.size() / 2], ratios[ratios.size() * 3 / 4], ratios[ratios.size() * 9 / 10]])
	quit()
