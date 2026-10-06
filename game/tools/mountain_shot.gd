extends SceneTree
## 산 화면(창 모드) — user://shots/mtn-*.png: 마을에서 본 산(줌 아웃), 계단 중턱, 꼭대기 산스장
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await process_frame
	var pk: Dictionary = WorldGen.PEAKS[0]
	var pts := WorldGen.trail_xz(pk)
	var shots := [["town", Vector3(-30, 0.05, -20), 4.0], ["head", Vector3(pts[0].x, 0, pts[0].y + 4.0), 1.6], ["mid", Vector3(pts[300].x, 0, pts[300].y), 1.4], ["top", Vector3(pk["c"].x, 0, pk["c"].z + 3.0), 1.5], ["topwide", Vector3(pk["c"].x, 0, pk["c"].z + 6.0), 3.0]]
	for s in shots:
		var p: Vector3 = s[1]
		p.y = town.gen.height(p.x, p.z) + 0.6
		if s[0] == "mid": p.y += 0.4
		town.body.global_position = p; town.body.velocity = Vector3.ZERO
		town.zoom_want = s[2]; town.zoom = s[2]
		town.gen.radius = clampi(int(3.0 + town.zoom * 0.55), 3, 11); town.gen.fill(p)
		for i in 150: await process_frame
		root.get_texture().get_image().save_png("user://shots/mtn-%s.png" % s[0])
	quit()
