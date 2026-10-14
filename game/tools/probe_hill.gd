extends SceneTree
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	var g: WorldGen = town.gen
	for p in [Vector2(-186, -180), Vector2(-220, -210), Vector2(-260, -250), Vector2(-300, -290)]:
		print("HP %s raw=%.1f wild=%.2f h=%.1f pk=%.2f" % [str(p), g.raw(p.x, p.y), g.wild_k(p.x, p.y), g.height(p.x, p.y), g.peak_k(p.x, p.y)])
	var hill: Array = TownPlan.lots().filter(func(l): return l.get("hill", false))
	for l in hill.slice(0, 5): print("HL %s y=%s c=%s" % [l["id"], str(l.get("y")), str(l["c"])])
	print("HL pads=%d lanes=%d" % [g._pads.size(), g._lanes.size()])
	quit()
