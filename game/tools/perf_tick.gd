extends SceneTree
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 120: await physics_frame
	TownSystems.TT.clear()
	for i in 300: await physics_frame
	var ks: Array = TownSystems.TT.keys(); ks.sort_custom(func(a, b): return TownSystems.TT[a] > TownSystems.TT[b])
	for k in ks.slice(0, 10): print("TK %s %.2f ms/step" % [k, TownSystems.TT[k] / 300.0 / 1000.0])
	print("TK crowns=%d houses=%d spots=%d animals=%d" % [town.crowns.size(), town.houses.size(), town.spots.size(), town.animals.size()])
	quit()
