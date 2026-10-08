extends SceneTree
## 밤에 집에 간 주민이 방에 보이나(헤드리스) — 시계를 밤으로 돌리고 60초, 침대·의자에 간 주민의 집으로 들어가 본다
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.clock = 0.92
	for f in 60 * 60: await physics_frame
	var homey: Array = []
	for r in town.residents:
		if r.home_door.is_empty(): continue
		var h: Dictionary = {}
		for hh in town.houses: if hh["door"] == r.home_door: h = hh
		var p: Vector3 = r.global_position
		var walls: bool = not h.is_empty() and p.x > h["min"].x and p.x < h["max"].x and p.z > h["min"].z and p.z < h["max"].z
		var on_spot: bool = r.state == "busy" and r.spot.get("door") is Dictionary and r.spot["door"] == r.home_door
		if walls or on_spot: homey.append([r, walls, on_spot])
	print("NIGHT night=%s residents=%d at_home=%d" % [town.is_night(), town.residents.size(), homey.size()])
	var shown := 0; var tried := 0
	for e in homey.slice(0, 4):
		var r: Resident = e[0]
		town._enter_room(town.doors.find(r.home_door))
		for i in 50: await physics_frame
		var px: Dictionary = town.inside.get("proxies", {})
		tried += 1; if px.has(r.uid): shown += 1
		print("  %s walls=%s spot=%s state=%s kind=%s -> proxies=%d has_me=%s" % [r.handle, e[1], e[2], r.state, r.spot.get("kind", ""), px.size(), px.has(r.uid)])
		town._leave_room(); for i in 30: await physics_frame
	print("NIGHT shown %d/%d" % [shown, tried])
	quit()
