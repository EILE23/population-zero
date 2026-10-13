extends SceneTree
## 게시판 보기 화면(창 모드) — user://shots/board.png
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await process_frame
	town.body.global_position = town.notice["pos"]
	for i in 30: await process_frame
	town.records["board_local"] = {}
	town.board_post("square", "Lost: one blue umbrella. Probably near the bakery.")
	town.board_post("square", "Bake sale Saturday at noon")
	town.open_board("square", "Town notice board", town.notice["at"], float(town.notice["yaw"]))
	print("BS view=%s" % str(town.board_view))
	for i in 120: await process_frame
	print("BS view2=%s cam=%s tf=%s" % [str(town.board_view), str(town.cam.global_position), str(town._board_cam_tf.origin)])
	root.get_texture().get_image().save_png("user://shots/board.png")
	quit()
