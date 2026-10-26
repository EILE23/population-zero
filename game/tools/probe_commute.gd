extends SceneTree
## 출근길 시간 쓰임 — 아침으로 돌려 120초, 0.5초마다 달리는 출퇴근 차의 상태(달림·빨간불·멈춤 표지·교차로 칸·앞차·건너는 차·사람·느림)를 센다, 도착까지 걸린 시간
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await physics_frame
	town.clock = (5.9 - 6.0 + 24.0) / 24.0 - 1.0 if false else 0.9958
	var vs: Array = []; var caps: Array = []
	var why := {}; var start := {}; var took: Array = []; var dist: Array = []
	for f in 60 * 150:
		await physics_frame
		if f % 30 != 0: continue
		var now := f / 60.0
		for e in town.commuters:
			var c: Car3D = e["car"]
			if e["phase"] == "driving" and String(e["dest"].get("name", "")) == "work":
				if not start.has(c):
					start[c] = [now, c.global_position]
					if c.rail and c.rail.lane.size() * 1.5 > 4.0 * c.global_position.distance_to(town.dest_park(e)):
						var smp := ""
						for i in range(0, c.rail.centers.size(), maxi(1, c.rail.centers.size() / 10)): smp += str(Vector2(c.rail.centers[i].x, c.rail.centers[i].z).snapped(Vector2.ONE)) + " "
						print("PC bad goal=%s path %s" % [str(town.dest_park(e).snapped(Vector3.ONE)), smp])
					if c.rail: print("PC trip lane=%dm straight=%.0fm goal=%.0fm from %s" % [int(c.rail.lane.size() * 1.5), c.global_position.distance_to(town.dest_park(e)), 0.0, str(c.global_position.snapped(Vector3.ONE))])
				vs.append(absf(c.v)); if c.rail and c.rail.li < c.rail.cap.size(): caps.append(c.rail.cap[c.rail.li])
				var k := "moving" if absf(c.v) > 2.0 else (("slow:" + (c.rail.why if c.rail else "")) if absf(c.v) > 0.3 else ("stop:" + (c.rail.why if c.rail else "norail")))
				if k.contains("car:"): k = k.split(":")[0] + ":car_ahead"
				why[k] = int(why.get(k, 0)) + 1
			elif start.has(c) and e["phase"] == "there":
				took.append(now - float(start[c][0])); dist.append(c.global_position.distance_to(start[c][1])); start.erase(c)
	var tot := 0
	for k in why: tot += why[k]
	var ks: Array = why.keys(); ks.sort_custom(func(a, b): return why[a] > why[b])
	for k in ks: print("PC %-10s %4.0f%%" % [k, 100.0 * why[k] / tot])
	var sv := 0.0; for x in vs: sv += x
	var sc := 0.0; for x in caps: sc += x
	vs.sort()
	print("PC speed avg=%.1f median=%.1f p90=%.1f cap_avg=%.1f" % [sv / maxf(1, vs.size()), vs[vs.size() / 2], vs[vs.size() * 9 / 10], sc / maxf(1, caps.size())])
	var s := 0.0; var d := 0.0
	for t in took: s += t
	for x in dist: d += x
	print("PC arrived=%d avg_trip=%.0fs avg_straight=%.0fm still_driving=%d h=%.1f" % [took.size(), s / maxf(1, took.size()), d / maxf(1, dist.size()), start.size(), fmod(town.clock * 24.0 + 6.0, 24.0)])
	quit()
