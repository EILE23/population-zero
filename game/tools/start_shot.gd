extends SceneTree
## 시작 화면 그대로(창 모드) — user://shots/start.png. 웹에서 빈 화면이 나왔을 때(2026-10-06) 데스크톱과 견주려고
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 240: await process_frame
	print("MON objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("CAM pos=", town.cam.global_position, " far=", town.cam.far, " zoom=", town.zoom, " body=", town.body.global_position, " ui=", (town.get_node("UI") as CanvasLayer).get_child_count())
	root.get_texture().get_image().save_png("user://shots/start.png")
	quit()
