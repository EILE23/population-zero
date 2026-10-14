extends SceneTree
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var rs := Valley.roads()
	var t1 := Time.get_ticks_msec()
	var ls := Valley.lots()
	var t2 := Time.get_ticks_msec()
	var total := 0.0
	for r in rs:
		var p: PackedVector2Array = r["pts"]
		for i in p.size() - 1: total += p[i].distance_to(p[i + 1])
	var kinds := {}
	for l in ls: kinds[l["kind"]] = int(kinds.get(l["kind"], 0)) + 1
	print("VAL roads=%d len=%.0fm lots=%d kinds=%s slope=%d t_roads=%dms t_lots=%dms" % [rs.size(), total, ls.size(), str(kinds), ls.filter(func(l): return l["slope"]).size(), t1 - t0, t2 - t1])
	var img := Image.create(1000, 600, false, Image.FORMAT_RGB8)
	for py in 600:
		for px in 1000:
			var x := -500.0 + px; var z := -400.0 + py * 1.0
			var h := Valley.base_h(x, z)
			var c := Color(0.55, 0.75, 0.45).lerp(Color(0.4, 0.4, 0.38), clampf(h / 120.0, 0, 1))
			if h > 160.0: c = Color.WHITE
			if absf(z - 11.5) < 1.5: c = Color(0.4, 0.6, 0.9)
			img.set_pixel(px, py, c)
	for r in rs:
		for p in (r["pts"] as PackedVector2Array):
			var px := int(p.x + 500.0); var py := int(p.y + 400.0)
			if px >= 0 and px < 1000 and py >= 0 and py < 600: img.set_pixel(px, py, Color(0.2, 0.2, 0.2))
	for l in ls:
		var c: Vector2 = l["c"]
		var px := int(c.x + 500.0); var py := int(c.y + 400.0)
		for dx in 3:
			for dy in 3:
				if px + dx < 1000 and py + dy < 600 and px >= 0 and py >= 0: img.set_pixel(px + dx, py + dy, Color(0.85, 0.3, 0.25) if l["kind"] == "house" else Color(0.9, 0.8, 0.2))
	img.save_png("user://shots/valley_map.png")
	quit()
