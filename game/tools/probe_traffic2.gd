extends SceneTree
## 볼일 보는 차(헤드리스): 주민이 차로 걸어가 타고, 목적지까지 몰고 가 내려 문으로 — 단계별 수와 차가 간 거리
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.clock = 0.45
	var start := {}
	for e in town.commuters:
		e["until"] = 0.0; start[e["car"]] = (e["car"] as Node3D).global_position
	print("TRAFFIC commuters=%d" % town.commuters.size())
	var arrived := 0; var seen_driving := 0
	for f in 60 * 180:
		await physics_frame
		if f % 600 == 0:
			var ph := {}
			for e in town.commuters: ph[e["phase"]] = int(ph.get(e["phase"], 0)) + 1
			var moved := 0.0
			for e in town.commuters: moved = maxf(moved, (e["car"] as Node3D).global_position.distance_to(start[e["car"]]))
			var cm := 0.0
			for e in town.cruisers: cm += (e["car"] as Car3D).v
			print("  t=%ds phases=%s max_car_moved=%.0fm cruisers=%d avg_speed=%.1f" % [f / 60, str(ph), moved, town.cruisers.size(), cm / maxf(1.0, town.cruisers.size())])
			seen_driving = maxi(seen_driving, int(ph.get("driving", 0)))
			if f == 60 * 40:
				for e in town.cruisers:
					var cc: Car3D = e["car"]
					var bk: Variant = cc._wk[0][1] if not cc._wk.is_empty() else null
					print("    cruiser pos=%s rot=%.1f v=%.1f ri=%d/%d tgt=%s block=%s" % [str(cc.global_position.snapped(Vector3.ONE * 0.1)), cc.rotation.y, cc.v, cc._ri, cc.route.size(), str(cc.route[cc._ri] if cc._ri < cc.route.size() else "-"), (bk.get_class() + ":" + str(bk.name)) if bk is Node else "none"])
			if f == 60 * 50:
				for e in town.commuters:
					if e["phase"] != "driving": continue
					var c: Car3D = e["car"]
					var blk: Variant = c._wk[0][1] if not c._wk.is_empty() else null
					print("    car %s pos=%s v=%.1f ri=%d/%d tgt=%s block=%s" % [c.kind, str(c.global_position.snapped(Vector3.ONE * 0.1)), c.v, c._ri, c.route.size(), str(c.route[c._ri] if c._ri < c.route.size() else "-"), (blk.name + ":" + blk.get_parent().name) if blk is Node else str(blk)])
			arrived = maxi(arrived, int(ph.get("there", 0)))
	print("TRAFFIC max_driving=%d max_arrived=%d" % [seen_driving, arrived])
	quit()
