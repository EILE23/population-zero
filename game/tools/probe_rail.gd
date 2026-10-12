extends SceneTree
## 차선 주행(car_rail, 헤드리스): 차선 위에 있나(차선 토막까지 평균·최대 거리), 섰던 시간, 도착 수, 길을 잃은 수, 길 못 찾은 차
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.clock = 0.45
	for e in town.commuters: e["until"] = 0.0
	var dev_sum := 0.0; var dev_n := 0; var dev_max := 0.0
	var still := {}; var arrivals := 0; var lost := 0; var noplan := 0
	var last_done := {}
	for f in 60 * 150:
		await physics_frame
		if f % 30 != 0: continue
		for c in town.cars:
			var cc: Car3D = c
			if cc.rail == null or not cc.ai: continue
			var rl: CarRail = cc.rail
			if rl.done:
				if not last_done.get(cc, false):
					last_done[cc] = true
					if cc.has_meta("rail_lost"):
						lost += 1
						if lost < 25: print("    lost %s %s" % [cc.kind, str(cc.get_meta("rail_lost"))])
						cc.remove_meta("rail_lost")
					else: arrivals += 1
				continue
			last_done[cc] = false
			if rl.li == 0 or rl.li >= rl.lane.size(): continue
			var p := cc.global_position; p.y = 0.0
			var d := CarRail._seg_d(p, rl.lane[rl.li - 1], rl.lane[rl.li])
			dev_sum += d; dev_n += 1; dev_max = maxf(dev_max, d)
			if absf(cc.v) < 0.3: still[cc] = float(still.get(cc, 0.0)) + 0.5
		if f % 1200 == 0:
			var on := 0; var nul := 0
			for e in town.cruisers + town.commuters:
				var cc: Car3D = e["car"]
				if cc.ai and cc.rail != null: on += 1
				elif cc.ai: nul += 1
			noplan = maxi(noplan, nul)
			var ph := {}
			for e in town.commuters: ph[e["phase"]] = int(ph.get(e["phase"], 0)) + 1
			print("  t=%ds on_rail=%d no_plan=%d phases=%s dev_avg=%.2f dev_max=%.2f arrivals=%d lost=%d" % [f / 60, on, nul, str(ph), dev_sum / maxf(1.0, dev_n), dev_max, arrivals, lost])
	var worst: Array = still.keys()
	worst.sort_custom(func(a, b): return float(still[a]) > float(still[b]))
	for k in mini(5, worst.size()):
		var cc: Car3D = worst[k]
		print("    still %.0fs %s at %s held=%s why=%s li=%d/%d" % [float(still[cc]), cc.kind, str(cc.global_position.snapped(Vector3.ONE * 0.1)), str(cc.rail._held if cc.rail else "-"), cc.rail.why if cc.rail else "-", cc.rail.li if cc.rail else -1, cc.rail.lane.size() if cc.rail else 0])
	print("RAIL dev_avg=%.2f dev_max=%.2f arrivals=%d lost=%d max_no_plan=%d" % [dev_sum / maxf(1.0, dev_n), dev_max, arrivals, lost, noplan])
	quit()
