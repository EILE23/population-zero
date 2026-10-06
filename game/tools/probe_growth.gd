extends SceneTree
## 마을 성장 점검(헤드리스): 필지 수·첫 필지 위치, 건축가 둘, 공사장 둘, 일 20단위면 집이 서고 문·주민이 늘고 다음 공사장이 열리나, 건축가가 실제로 출근해 일을 쌓나
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var lots: Array = TownPlan.lots()
	print("PLAN lots=", lots.size(), " first=", lots[0]["c"], " second=", lots[1]["c"], " 20th=", lots[19]["c"])
	print("BUILDERS ", town.residents.filter(func(r): return r.job == "builder").map(func(r): return r.handle), " sites=", town._site_nodes.keys(), " built=", town.built)
	var doors0: int = town.doors.size(); var res0: int = town.residents.size()
	var sp: Dictionary = town.build_spot(town.residents[0])
	for i in 20: town.build_work(sp)
	for i in 10: await physics_frame
	print("FINISH built=", town.built, " doors +", town.doors.size() - doors0, " residents +", town.residents.size() - res0, " sites=", town._site_nodes.keys(), " newest=", town.residents[-1].handle)
	# 건축가 출근: 낮으로 맞추고 90초
	town.clock = 0.15
	var w0 := 0.0
	for k in town.site_work: w0 += town.site_work[k]
	for i in 60 * 90: await physics_frame
	var w1 := 0.0
	for k in town.site_work: w1 += town.site_work[k]
	print("WORK in 90s: work units ", w0, " -> ", w1, " builders states=", town.residents.filter(func(r): return r.job == "builder").map(func(r): return r.state + ":" + str(r.spot.get("kind", ""))))
	quit()
