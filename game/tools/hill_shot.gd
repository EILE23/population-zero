extends SceneTree
## 산 마을(창 모드) — 산 블록 필지 몇 개를 바로 지어 보고 user://shots/hill-*.png
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await process_frame
	var lots := TownPlan.lots()
	var hill: Array = lots.filter(func(l): return l.get("hill", false))
	print("HILL lots=%d hill=%d first_order=%d built=%d" % [lots.size(), hill.size(), int(hill.map(func(l): return int(l["order"])).min()) if not hill.is_empty() else -1, town.built])
	var pk: Dictionary = WorldGen.PEAKS[0]
	var head: Vector3 = pk["head"]
	var picked: Array = hill.filter(func(l): return (l["c"] as Vector2).distance_to(Vector2(head.x, head.z)) < 90.0)
	for l in picked: town._finish_lot(l, false)
	print("HILL built near head=%d" % picked.size())
	var avg := Vector3.ZERO
	for l in picked: avg += Vector3(l["c"].x, 0, l["c"].y)
	avg /= maxf(1.0, picked.size())
	print("HILL avg=%s" % str(avg))
	for s in [["a", avg + Vector3(0, 0, 25), 5.0], ["b", avg + Vector3(0, 0, 8), 2.5], ["c", avg + Vector3(0, 0, 60), 10.0]]:
		var p: Vector3 = s[1]; p.y = town.gen.height(p.x, p.z) + 0.3
		town.body.global_position = p; town.gen.fill(p); town.zoom_want = s[2]; town.zoom = s[2]
		for i in 120: await process_frame
		root.get_texture().get_image().save_png("user://shots/hill-%s.png" % s[0])
	quit()
