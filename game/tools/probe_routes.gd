extends SceneTree
## 길 그래프·길 짜기 점검(마을 없이) — 마디·가지·이어진 덩이 수, 막다른 마디, 아무 두 필지 사이 길(성공률·점 사이 최대 간격·길이 대비 직선)
func _init() -> void:
	Valley.roads()
	var nodes := RoadNet.nodes(); var edges := RoadNet.edges(); var adj := RoadNet.adj()
	# 덩이
	var comp := {}; var nc := 0; var sizes: Array = []
	for i in nodes.size():
		if comp.has(i): continue
		var st: Array = [i]; comp[i] = nc; var sz := 0
		while not st.is_empty():
			var u: int = st.pop_back(); sz += 1
			for ei in adj[u]:
				var e: Dictionary = edges[ei]
				var v: int = e["b"] if int(e["a"]) == u else e["a"]
				if not comp.has(v): comp[v] = nc; st.append(v)
		sizes.append(sz); nc += 1
	sizes.sort(); sizes.reverse()
	var dead := 0
	for i in nodes.size(): if (adj[i] as Array).size() == 1: dead += 1
	print("RT roads=%d nodes=%d edges=%d components=%d sizes=%s dead_ends=%d" % [RoadNet.roads.size(), nodes.size(), edges.size(), nc, str(sizes.slice(0, 6)), dead])
	var lots := Valley.lots()
	var car := Node3D.new(); root.add_child(car)
	var ok := 0; var fail := 0; var gap_max := 0.0; var bad := 0
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for t in 200:
		var a: Dictionary = lots[rng.randi() % lots.size()]; var b: Dictionary = lots[rng.randi() % lots.size()]
		var pa: Array = Valley.near(a["c"], 3)
		car.global_position = Vector3((pa[1] as Vector2).x, 0, (pa[1] as Vector2).y)
		var d: Vector2 = pa[2]; car.rotation.y = atan2(-d.x, -d.y)
		var r := CarRail.plan(null, car, Vector3(b["c"].x, 0, b["c"].y))
		if r == null: fail += 1; continue
		ok += 1
		var g := 0.0
		for i in r.centers.size() - 1: g = maxf(g, r.centers[i].distance_to(r.centers[i + 1]))
		gap_max = maxf(gap_max, g)
		if g > 8.0:
			bad += 1
			if bad < 5:
				for i in r.centers.size() - 1:
					if r.centers[i].distance_to(r.centers[i + 1]) > 8.0: print("   GAP %.1f at %s -> %s (i %d/%d)" % [r.centers[i].distance_to(r.centers[i + 1]), str(r.centers[i].snapped(Vector3.ONE)), str(r.centers[i + 1].snapped(Vector3.ONE)), i, r.centers.size()])
	# 새 길(사람·주민이 놓는 길) — 북쪽 두 마디 사이를 곧게 잇고 다시 짠다: 그래프가 그 길을 쓰나
	var e0: int = RoadNet.edges().size()
	var a2 := Vector2(-200, -60); var b2 := Vector2(-120, -40)
	RoadNet.add(PackedVector2Array([a2, b2]), 5.0, "built")
	print("RT built road: edges %d -> %d components ok" % [e0, RoadNet.edges().size()])
	car.global_position = Vector3(a2.x, 0, a2.y) + Vector3(0.5, 0, 0)
	var rr := CarRail.plan(null, car, Vector3(b2.x, 0, b2.y))
	var plen := 0.0
	if rr:
		for i in rr.centers.size() - 1: plen += rr.centers[i].distance_to(rr.centers[i + 1])
	var nb: Dictionary = RoadNet.roads[RoadNet.roads.size() - 1]
	print("RT built pts ", (nb["pts"] as PackedVector2Array)[0], " .. ", (nb["pts"] as PackedVector2Array)[(nb["pts"] as PackedVector2Array).size() - 1], " near a2 ", RoadNet.near(a2, 1).slice(0, 2), " near b2 ", RoadNet.near(b2, 1).slice(0, 2))
	if rr:
		var samp := ""
		for i in range(0, rr.centers.size(), 40): samp += str(rr.centers[i].snapped(Vector3.ONE)) + " "
		print("RT path ", samp)
	print("RT plan on built road: %s %.0fm (straight %.0fm)" % [str(rr != null), plen, a2.distance_to(b2)])
	print("RT plans ok=%d fail=%d gap_max=%.1f plans_with_gap>8=%d" % [ok, fail, gap_max, bad])
	quit()
