extends SceneTree
## 하루(출퇴근) 점검 — 아침 6시로 돌려 출근, 오후 14.5시로 돌려 퇴근, 밤으로 돌려 침대. 차 있는 주민의 단계·일터에 있는 수·집 침대에 누운 수
func _phase(town) -> String:
	var ph := {}; var at_work := 0; var in_car := 0
	for e in town.commuters:
		var r: Resident = e["r"]
		var k := "%s:%s" % [e["phase"], String(e["dest"].get("name", "-"))]
		ph[k] = int(ph.get(k, 0)) + 1
		if r.spot.get("kind", "") == "work" and r.state == "busy": at_work += 1
		if r.state == "drive": in_car += 1
	return "%s at_work=%d in_car=%d" % [str(ph), at_work, in_car]
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await physics_frame
	print("DAY commuters=%d workplaces=%d with_work=%d" % [town.commuters.size(), town.workplaces.size(), town.commuters.filter(func(e): return not e["work"].is_empty()).size()])
	town.clock = (6.2 - 6.0) / 24.0
	for t in 8:
		for i in 60 * 15: await physics_frame
		print("  morning +%ds h=%.1f %s" % [(t + 1) * 15, fmod(town.clock * 24.0 + 6.0, 24.0), _phase(town)])
	town.clock = (14.9 - 6.0) / 24.0
	for t in 10:
		for i in 60 * 15: await physics_frame
		if t == 5:
			for e in town.commuters:
				var c: Car3D = e["car"]
				if e["phase"] == "driving" and c.rail and absf(c.v) < 0.3: print("    stuck %s at %s why=%s li=%d/%d done=%s" % [c.kind, str(c.global_position.snapped(Vector3.ONE)), c.rail.why, c.rail.li, c.rail.lane.size(), str(c.rail.done)])
				elif e["phase"] == "driving" and c.rail == null: print("    no rail at %s" % str(c.global_position.snapped(Vector3.ONE)))
		print("  afternoon +%ds h=%.1f %s" % [(t + 1) * 15, fmod(town.clock * 24.0 + 6.0, 24.0), _phase(town)])
	town.clock = (22.0 - 6.0) / 24.0
	for i in 60 * 60: await physics_frame
	var beds := 0; var kinds := {}
	for e in town.commuters:
		var r: Resident = e["r"]
		if r.spot.get("kind", "") == "bed": beds += 1
		var k := "%s/%s" % [r.state, String(r.spot.get("kind", ""))]
		kinds[k] = int(kinds.get(k, 0)) + 1
		if e["phase"] == "to_car": print("    to_car r=%s d_car=%.1f route=%d hd=%s" % [k, r.global_position.distance_to((e["car"] as Car3D).exit_pos()), r.route.size(), str(not r.home_door.is_empty())])
	print("  night kinds ", kinds)
	print("  night h=%.1f in_bed=%d/%d %s" % [fmod(town.clock * 24.0 + 6.0, 24.0), beds, town.commuters.size(), _phase(town)])
	quit()
