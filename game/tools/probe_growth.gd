extends SceneTree
## 같은 시계 성장(헤드리스) — 지금 시각의 built, 공사장 진행, 시계를 1시간 앞으로 돌리면 몇 채가 더 서나
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var t: float = town.world_time()
	print("GROW built=%d target=%d done=%d due=%d sites=%s" % [town.built, town.target_built(), town._done.size(), town._due.size(), str(town._site_nodes.keys().map(func(k): return "%d:%.0f%%" % [k, town.site_progress(k, t) * 100.0]))])
	var d0: int = town._done.size()
	town.net.clock_dt = 3600.0
	for i in 400: await physics_frame
	print("GROW +1h built=%d target=%d done+%d due=%d" % [town.built, town.target_built(), town._done.size() - d0, town._due.size()])
	quit()
