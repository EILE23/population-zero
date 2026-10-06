extends SceneTree
## 내가 짓는 집 점검(헤드리스): 팔 필지 표지판 → 모양 골라 사기 → 망치질로 다 짓기 → 내 집(문패·주민 안 들어옴), 건축가 수·판자 나르기
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var sales: Array = town.spots.filter(func(s): return s["kind"] == "sale")
	var builders: Array = town.residents.filter(func(r): return r.job == "builder")
	print("SALE signs=%d builders=%d sites=%s built=%d" % [sales.size(), builders.size(), str(town._site_nodes.keys()), town.built])
	town.coins = 100
	var k: int = int(sales[0]["lot"])
	town.sale_use(sales[0], 0.0)
	print("MENU open=%s typing=%s" % [town.get_meta("menu_open", false), town.typing])
	town._buy(k, "turret")
	print("BOUGHT lot=%d coins=%d mine=%s site=%s sales_now=%d" % [k, town.coins, town._is_mine(k), town._site_nodes.has(k), town.spots.filter(func(s): return s["kind"] == "sale").size()])
	var sp: Dictionary = town.build_spot_of(k)
	var doors0: int = town.doors.size(); var res0: int = town.residents.size()
	for i in 25:
		if not town._site_nodes.has(k): break
		town.build_work(sp)
	var dr: Dictionary = town.doors[town.doors.size() - 1]
	print("DONE finished=%s doors+%d residents+%d owner=%s mine=%s saved=%s" % [town._done.has(k), town.doors.size() - doors0, town.residents.size() - res0, dr.get("owner", ""), dr.get("mine", false), str(town.records["my_plots"])])
	var carried := 0
	for f in 60 * 90:
		await physics_frame
		if f % 60 == 0: carried = maxi(carried, town.residents.filter(func(r): return r.has_meta("plank")).size())
	print("HAUL max builders carrying planks at once=%d work=%s" % [carried, str(town.site_work)])
	quit()
