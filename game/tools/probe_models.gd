extends SceneTree
## 문 닫기 확인: 주민 하나를 집 안 의자로 보내고 문 상태를 시간 순으로 찍는다
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	await process_frame
	var r = town.residents[2]
	var chair: Dictionary = {}
	for sp in town.spots: if sp["kind"] == "chair" and sp.has("door"): chair = sp; break
	var dr: Dictionary = chair["door"]
	r.global_position = dr["pos"] + Vector3(0, 0.02, 3.0); r._release(); r.spot = chair; r.slot = 0; r._claim(chair, 0); r.door_ref = dr
	var dp: Vector3 = dr["pos"]
	r.route = r._approach(dr) + [{ "pos": dp + Vector3(0, 0, 0.8), "act": "open" }, { "pos": dp + Vector3(0, 0, -1.3), "act": "close" }, { "pos": chair["pos"] + Vector3(0, 0, 0.35), "act": "" }]
	r.target = r.route[0]["pos"]; r.state = "walk"
	var last := ""
	for i in 900:
		await physics_frame
		var st := "%s door=%s tgt=%s" % [r.state, str(dr["open"]), str(r.target - dp)]
		if st != last or i % 60 == 0: print("PROBE t=%.1f %s pos=%s" % [i / 60.0, st, str(r.global_position - dp)]); last = st
		if i == 400 and r.state == "busy": r.busy_until = 0.0
	quit()
