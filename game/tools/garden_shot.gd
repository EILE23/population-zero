extends SceneTree
## 텃밭 화면(창 모드) — 이랑을 단계별로 맞춰 두 시점 + 가까이 — user://shots/garden-*.png
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await process_frame
	var ga: Vector3 = town.garden_at
	for i in town.rows.size(): town._set_stage(town.rows[i], [3, 2, 3][i])
	town.body.global_position = ga + Vector3(0.0, 0.05, 3.2)
	for v in [false, true]:
		town.view_25d = v
		for i in 90: await process_frame
		root.get_texture().get_image().save_png("user://shots/garden-%s.png" % ("25d" if v else "34"))
	for i in town.rows.size(): town._set_stage(town.rows[i], [1, 0, 2][i])
	for i in 30: await process_frame
	root.get_texture().get_image().save_png("user://shots/garden-young.png")
	quit()
