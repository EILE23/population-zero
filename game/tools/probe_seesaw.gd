extends SceneTree
## 시소 같이 타기(헤드리스): 사람이 한쪽에 앉으면 주민이 와서 반대쪽에 앉고, 판이 오르내린다
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var ss: Seesaw3D = town.seesaws[0]
	town.body.global_position = ss.global_position + Vector3(-1.2, 0, 0)
	ss.sit("player", 0); town.seesaw_ride = ss; town.body.collision_layer = 0; town.body.collision_mask = 0
	var amin := 9.0; var amax := -9.0; var who := ""
	for f in 60 * 40:
		await physics_frame
		var r = ss.riders[1]
		if r is Resident:
			who = r.handle
			if f % 50 == 0: ss.push(0)   # 사람도 박찬다
			amin = minf(amin, ss.angle); amax = maxf(amax, ss.angle)
	print("SEESAW partner=%s angle %.2f..%.2f riders=%s" % [who, amin, amax, str(ss.riders)])
	quit()
