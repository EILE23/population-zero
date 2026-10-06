extends SceneTree
## 성장 화면(창 모드): 집 열 채를 곧장 짓고(일 쌓기) 공사장과 함께 내려다본다 — user://shots/growth-*.png
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await process_frame
	for h in 10:
		var sp: Dictionary = town.build_spot(town.residents[0])
		for i in 20: town.build_work(sp)
	var sp2: Dictionary = town.build_spot(town.residents[0])
	for i in 9: town.build_work(sp2)   # 하나는 짓는 중(벽 단계)
	town.body.global_position = Vector3(10, 0.5, -45)
	for z in [1.0, 5.0]:
		town.zoom_want = z; town.zoom = z
		for i in 200: await process_frame
		root.get_texture().get_image().save_png("user://shots/growth-%d.png" % int(z))
	quit()
