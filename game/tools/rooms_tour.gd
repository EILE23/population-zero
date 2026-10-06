extends SceneTree
## 집 안 둘러보기(창 모드) — user://shots/home-*.png, 집마다 틀·모양·주인
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await process_frame
	var n := 0
	for i in town.doors.size():
		var dr: Dictionary = town.doors[i]
		if dr.has("shop_id") or dr.has("civic"): continue
		town._enter_room(i)
		for f in 40: await process_frame
		var rm: Dictionary = town.inside
		var kit: Dictionary = rm.get("kit", {})
		print("HOME %d layout=%s shape=%s size=%.1fx%.1f mirror=%s spots=%d" % [i, kit.get("layout", {}).get("name", "?"), kit.get("shape", ""), rm["w"], rm["d"], kit.get("mirror", false), (rm["spots"] as Array).size()])
		root.get_texture().get_image().save_png("user://shots/home-%02d.png" % n)
		town._leave_room()
		for f in 20: await process_frame
		n += 1
		if n >= 12: break
	quit()
