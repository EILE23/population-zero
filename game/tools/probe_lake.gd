extends SceneTree
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	for b in [Vector2i(-2, -3), Vector2i(0, -3)]:
		var row := ""
		for gz in range(-2, 11):
			row = ""
			for gx in range(-2, 11):
				var x: float = TownPlan.OX + b.x * 40.0 + gx * 4.0; var z: float = TownPlan.OZ + b.y * 40.0 + gz * 4.0
				var r: float = town.gen.wild_k(x, z) * town.gen.raw(x, z)
				row += ("~" if r < -0.05 else ("^" if r > 0.3 else ".")) 
			print("L %s z=%d %s  raw=%.1f" % [str(b), int(TownPlan.OZ + b.y * 40.0 + gz * 4.0), row, town.gen.raw(TownPlan.OX + b.x * 40.0 + 20, TownPlan.OZ + b.y * 40.0 + gz * 4.0)])
	quit()
