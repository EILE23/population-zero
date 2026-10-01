extends SceneTree
## 교통 점검(헤드리스): 차선에 세운 차 앞에서 택시가 서고(들이받지 않고) 비켜 가나, 마주 선 두 차가 한쪽이 양보해 풀리나, 남의 차 위에 올라탄 차가 떨어지나
## godot --headless --path game -s res://tools/probe_cars.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var taxi: Car3D = town.cars.filter(func(c): return c.kind == "taxi")[0]
	var dl: Car3D = town.cars.filter(func(c): return c.kind == "delivery")[0]
	var suv: Car3D = town.cars.filter(func(c): return c.kind == "suv")[0]
	var sedan: Car3D = town.cars.filter(func(c): return c.kind == "sedan")[0]
	dl.global_position = Vector3(60, 0, 20); dl.ai = false   # 배달차는 잠깐 치워 둔다
	# 1) 택시(동쪽으로 달림) 12m 앞 차선에 세운 SUV
	taxi._ri = 0; taxi.global_position = Vector3(-30, 0, 2.9); taxi.rotation.y = -PI / 2.0; taxi.v = 6.0
	suv.global_position = taxi.global_position + Vector3(12, 0, 0); suv.rotation.y = -PI / 2.0; suv.v = 0.0
	var min_gap := 99.0; var crashed := false
	for i in 600:
		await physics_frame
		min_gap = minf(min_gap, taxi.global_position.distance_to(suv.global_position))
		if taxi._crash_at > 0.5: crashed = true
	print("LANE min_gap=%.2f crashed=%s passed=%s taxi x=%.1f" % [min_gap, crashed, taxi.global_position.x > suv.global_position.x + 2.0, taxi.global_position.x])
	suv.global_position = Vector3(-12.5, 0, 4.6); suv.rotation.y = PI / 2.0
	# 2) 맞서기: 같은 차선에서 마주 보는 택시와 배달차
	dl.ai = true; taxi._detour = Vector3.INF; dl._detour = Vector3.INF
	taxi.global_position = Vector3(0, 0, 2.9); taxi.rotation.y = -PI / 2.0; taxi._ri = 0; taxi.v = 0.0
	dl.global_position = Vector3(9, 0, 2.9); dl.rotation.y = PI / 2.0; dl._ri = 5; dl.v = 0.0   # 서쪽으로
	var solved := -1.0
	for i in 900:
		await physics_frame
		if solved < 0.0 and absf(taxi.global_position.x - dl.global_position.x) > 0.1 and signf(taxi.global_position.x - dl.global_position.x) > 0.0: solved = i / 60.0
	print("STANDOFF solved_at=%.1fs taxi x=%.1f dl x=%.1f taxi temper=%.2f dl temper=%.2f" % [solved, taxi.global_position.x, dl.global_position.x, taxi.driver.mind.temper, dl.driver.mind.temper])
	# 3) 올라타기: 세단을 SUV 위에 얹는다
	sedan.global_position = suv.global_position + Vector3(0.4, 1.2, 0.2)
	for i in 120: await physics_frame
	print("STACK sedan y=%.2f suv y=%.2f dist=%.2f" % [sedan.global_position.y, suv.global_position.y, Vector2(sedan.global_position.x - suv.global_position.x, sedan.global_position.z - suv.global_position.z).length()])
	# 4) 집 안에 갇힌 차: 집 한가운데 넣으면 1초 안에 집 앞 길가로 나온다
	var h: Dictionary = town.houses[0]
	var mid: Vector3 = (h["min"] + h["max"]) / 2.0; mid.y = 0.0
	sedan.global_position = mid; sedan.v = 0.0
	for i in 90: await physics_frame
	var q := sedan.global_position
	var inside: bool = q.x > h["min"].x and q.x < h["max"].x and q.z > h["min"].z and q.z < h["max"].z
	print("RESCUE inside_after=", inside, " at ", q.snapped(Vector3.ONE * 0.1))
	quit()
