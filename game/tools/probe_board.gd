extends SceneTree
## 게시판·같이 짓는 집(헤드리스): 판 보기 → 쓰기·고치기·지우기(연결 없음 = 이 컴퓨터), 남이 산 필지(방 이벤트 흉내) → 공사장 → 일 20 → 그 사람 집
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.records["board_local"] = {}
	town.open_board("square", "Town notice board", town.notice["at"], float(town.notice["yaw"]))
	print("BOARD open=%s typing=%s shared=%s" % [town.board_view != null, town.typing, town.board_shared()])
	town.board_post("square", "Lost: one umbrella, blue.")
	town.board_post("square", "Bake sale Saturday")
	var posts: Array = town.board_posts("square")
	print("BOARD posts=%d labels=%d" % [posts.size(), town._board_lbls.size()])
	town.board_edit("square", String(posts[0]["id"]), "Found it. Thanks.")
	town.board_remove("square", String(posts[1]["id"]))
	print("BOARD after edit/remove posts=%s" % str(town.board_posts("square").map(func(p): return p["body"])))
	for i in 20: await process_frame
	print("BOARD cam to board=%.1fm" % town.cam.global_position.distance_to(town.notice["at"]))
	town.board_view.close_view()
	await process_frame
	print("BOARD closed typing=%s" % town.typing)
	var lots := TownPlan.lots()
	var k := -1
	for i in range(town.built, lots.size()):
		if not town._done.has(i) and not town._claimed(i) and not town._site_nodes.has(i) and CityMap.lot_kind(lots[i]) == "house": k = i; break
	town._net_plot({ "k": "plot", "lot": k, "plot": { "uid": 999, "handle": "neighbour", "style": "villa", "work": 0 } })
	print("NET plot lot=%d site=%s claimed=%s me=%s" % [k, town._site_nodes.has(k), town._claimed(k), town._is_me(k)])
	var d0: int = town.doors.size()
	for w in range(1, 21): town._net_plot({ "k": "work", "lot": k, "plot": { "uid": 999, "handle": "neighbour", "style": "villa", "work": w } })
	print("NET done=%s owner=%s doors+%d" % [town._done.has(k), town.doors[town.doors.size() - 1].get("owner", ""), town.doors.size() - d0])
	quit()
