extends SceneTree
## 글 남기는 판들(창 모드) — 종류별 수, 우편함 하나를 열어 user://shots/msg.png
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await process_frame
	var mb: Array = town.spots.filter(func(s): return s["kind"] == "msgboard")
	var by := {}
	for s in mb: by[String(s["key"]).substr(0, 1)] = int(by.get(String(s["key"]).substr(0, 1), 0)) + 1
	print("MSG boards=%d by=%s" % [mb.size(), str(by)])
	var sp: Dictionary = mb.filter(func(s): return String(s["key"]).begins_with("h"))[0]
	town.body.global_position = sp["pos"]
	for i in 30: await process_frame
	town.records["board_local"] = {}
	town.board_post(String(sp["key"]), "Your hedge looks great this week.")
	town.open_board(String(sp["key"]), String(sp["title"]), sp["at"], float(sp["yaw"]), sp["pos"])
	for i in 120: await process_frame
	root.get_texture().get_image().save_png("user://shots/msg.png")
	quit()
