extends SceneTree
## 열린 세계 지도(헤드리스): ~ 호수, . 평지, , 초원, T 숲, d 마른 땅, ^ 솔숲 고지 — 8m 칸, ±320m
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	await process_frame
	var g: WorldGen = town.gen
	var t0 := Time.get_ticks_usec(); g._build(Vector2i(40, 40)); print("CHUNK build ms ", (Time.get_ticks_usec() - t0) / 1000.0)
	for zi in range(-40, 41, 2):
		var line := ""
		for xi in range(-40, 41):
			var x := xi * 8.0; var z := zi * 8.0
			var h := g.height(x, z)
			if g._h(x, z) < -0.05: line += "~"
			elif g.wild_k(x, z) < 0.3: line += "."
			else: line += {"meadow": ",", "forest": "T", "dry": "d", "high": "^"}[g._biome(x, z, h)]
		print("MAP ", "%5d " % (zi * 8), line)
	var hi := -99.0
	for i in 4000: hi = maxf(hi, g.height(randf_range(-600, 600), randf_range(-600, 600)))
	print("MAXH ", hi, " chunks ", g.chunks.size())
	quit()
