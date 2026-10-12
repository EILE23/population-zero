extends SceneTree
## 지은 블록마다 게임 시점 한 장 — 줄여서 한 장(user://shots/blocks-N.png, 4×3 칸)에 모은다. 묻힌 집·빈 녹지 훑어보기
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await process_frame
	var blocks := {}
	for h in town.houses:
		var c: Vector3 = ((h["min"] as Vector3) + (h["max"] as Vector3)) / 2.0
		if absf(c.x) < 74.0 and absf(c.z) < 28.0: continue
		if c.length() > 260.0: continue
		blocks[CityMap.block_of(Vector2(c.x, c.z))] = true
	var keys: Array = blocks.keys(); keys.sort()
	var sheet: Image = null; var n := 0; var page := 0
	for b in keys:
		var bc: Vector3 = CityMap.block_center(b) + Vector3(0, 0, 14)
		bc.y = town.gen.height(bc.x, bc.z) + 0.3
		town.body.global_position = bc; town.body.velocity = Vector3.ZERO; town.gen.fill(bc)
		town.zoom_want = 3.2; town.zoom = 3.2
		for i in 60: await process_frame
		var img := root.get_texture().get_image(); img.resize(500, 280)
		if sheet == null: sheet = Image.create(2000, 840, false, img.get_format())
		sheet.blit_rect(img, Rect2i(0, 0, 500, 280), Vector2i((n % 4) * 500, (n / 4) * 280))
		print("CELL page %d #%d block %s" % [page, n, str(b)])
		n += 1
		if n == 12:
			sheet.save_png("user://shots/blocks-%d.png" % page); sheet = null; n = 0; page += 1
	if sheet: sheet.save_png("user://shots/blocks-%d.png" % page)
	quit()
