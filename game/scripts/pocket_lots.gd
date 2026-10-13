class_name PocketLots
extends RefCounted
## 쌈지 마당(아홉 필지에 하나, CityMap "green") — 운영자 2026-10-13 동물의 숲 사진처럼 한 필지를 한 장면으로 빽빽하게. 넷 중 하나(필지 순번):
##   장터 마당: 노점(차양), 식탁보 탁자와 방석 의자, 상자 더미, 화분 / 화원: 화분 줄과 꽃 상자, 물뿌리개 탁자, 벤치
##   놀이 마당: 그네·시소·모래밭·벤치 / 정원: 돌길, 나무 둘, 분수, 벤치 둘
## 둘레는 덤불·꽃 띠, 길 쪽 가운데는 들어가는 돌길. 다 부딪힌다(kit_props)

static func build(t, l: Dictionary, c: Vector3) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash("pocket/" + String(l["id"]))
	var front := float(l["street_z"]) - TownPlan.ROAD_W / 2.0 - 0.4
	var back := float(l["street_z"]) - TownPlan.PITCH / 2.0 + TownPlan.ROAD_W / 2.0 + 0.4
	var hw := TownPlan.LOT / 2.0 - 0.3
	KitProps.border(t, Vector3(c.x - hw, 0, back), Vector3(c.x + hw, 0, back), rng)
	for s in [-1.0, 1.0]:
		KitProps.border(t, Vector3(c.x + s * hw, 0, back + 0.6), Vector3(c.x + s * hw, 0, front - 0.4), rng, 0.7)
		KitProps.border(t, Vector3(c.x + s * hw, 0, front), Vector3(c.x + s * 1.0, 0, front), rng)   # 앞(가운데 들목은 비운다)
	for k in 6: KitProps.n(t, "path_stone", Vector3(c.x, 0, front - 0.3 - k * 1.0), 0.0, 1.6, false)
	var mid := Vector3(c.x, 0, (front + back) / 2.0)
	match int(l["order"]) / 9 % 4:
		0:   # 장터 마당
			t._stall(Vector3(c.x, 0, back + 1.6), [Color("ad7096"), Color("d98a2a"), Color("5f8a3e"), Color("7a90b0")][rng.randi() % 4])
			KitProps.f(t, "tableCloth", mid + Vector3(-0.8, 0, 0.5), 0.0)
			for q in 3: KitProps.f(t, "chairCushion", mid + Vector3(-0.8 + (q - 1) * 0.9, 0, 1.45), PI)
			t.spots.append({ "pos": mid + Vector3(-0.8, 0, 1.9), "kind": "bench", "yaw": PI })
			for q in 4: KitProps.f(t, "cardboardBoxClosed", mid + Vector3(1.9 + (q % 2) * 0.5, (q / 2) * 0.62, -1.2), rng.randf() * 0.5)
			KitProps.f(t, "pottedPlant", mid + Vector3(1.9, 0, 1.6)); KitProps.f(t, "pottedPlant", mid + Vector3(-2.4, 0, -1.4))
		1:   # 화원
			for r in 3:
				for q in 5: KitProps.n(t, "pot_large" if (r + q) % 2 == 0 else "pot_small", mid + Vector3(-2.0 + q * 1.0, 0, -2.4 + r * 1.3), rng.randf() * TAU, 2.0 if (r + q) % 2 == 0 else 2.6)
				for q in 5: KitProps.n(t, KitProps.FLOWERS[(r * 5 + q) % KitProps.FLOWERS.size()], mid + Vector3(-2.0 + q * 1.0, 0.25, -2.4 + r * 1.3), 0.0, 1.5, false)
			KitProps.f(t, "table", mid + Vector3(0, 0, 2.0), 0.0)
			KitProps.f(t, "benchCushion", mid + Vector3(-1.8, 0, 3.4), 0.0)
			t.spots.append({ "pos": mid + Vector3(-1.8, 0, 3.8), "kind": "bench", "yaw": PI })
		2:   # 놀이 마당
			t._swing(mid + Vector3(-1.3, 0, -1.8))
			var ss := Seesaw3D.new(); ss.set_meta("nomerge", true); ss.position = mid + Vector3(1.2, 0, 1.0); ss.rotation.y = PI / 2.0; t._add(ss); ss.build(t._mat(Color("b48a5a")), t._mat(Color("4a4a52"))); t.seesaws.append(ss)
			t.spots.append({ "pos": ss.position, "kind": "seesaw", "yaw": 0.0, "ss": ss })
			t._box(Vector3(2.2, 0.15, 2.0), mid + Vector3(-1.4, 0, 1.8), t._mat(Color("e8d8a8")), false)   # 모래밭
			KitProps.f(t, "benchCushionLow", mid + Vector3(1.6, 0, -2.6), 0.0)
		_:   # 정원
			t._tree(mid + Vector3(-1.9, 0, -2.4), 1.0); t._tree(mid + Vector3(1.9, 0, 2.4), 0.95)
			t.water.disc(mid, 1.0)
			KitProps.n(t, "statue_ring", mid + Vector3(0, 0, -2.6), 0.0, 2.0)
			t._bench(mid + Vector3(-1.6, 0, 1.6)); t._bench(mid + Vector3(1.4, 0, -1.4))
