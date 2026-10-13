class_name PocketLots
extends RefCounted
## 쌈지 마당(아홉 필지에 하나, CityMap "green") — 운영자 2026-10-13 동물의 숲 사진처럼 한 필지를 한 장면으로 빽빽하게. 여덟 중 하나(필지 순번):
##   장터 마당 / 화원 / 놀이 마당 / 분수 정원 / 노천 다과 / 동네 공방 / 마당 야영 / 과수원 가판 — 여덟 가지(Kenney Furniture·Nature·Fantasy Town·Survival·Food·Holiday·Retro Urban·Mini Market·Platformer)
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
	match int(l["order"]) / 9 % 8:
		0:   # 장터 마당 — 차양 노점 둘(Fantasy Town), 수레, 깃발, 등, 과일 진열대, 식탁보 탁자와 방석 의자, 상자
			KitProps.k(t, "fantasy", "stall-green", Vector3(c.x - 1.5, 0, back + 1.6), 0.0)
			KitProps.k(t, "fantasy", "stall-red", Vector3(c.x + 1.5, 0, back + 1.6), 0.0)
			KitProps.k(t, "fantasy", "cart-high", mid + Vector3(2.0, 0, 0.8), 0.3, 0.9)
			KitProps.k(t, "market", "display-fruit", mid + Vector3(-2.2, 0, -0.6), 0.0)
			KitProps.k(t, "fantasy", "lantern", mid + Vector3(-2.6, 0, 2.6), 0.0, 0.75)
			KitProps.f(t, "tableCloth", mid + Vector3(-0.6, 0, 1.2), 0.0)
			for q in 2: KitProps.f(t, "chairCushion", mid + Vector3(-1.2 + q * 1.2, 0, 2.2), PI)
			KitProps.k(t, "food", ["cake", "pie", "cupcake"][rng.randi() % 3], mid + Vector3(-0.6, 0.75, 1.2), 0.0, 1.0, false)
			t.spots.append({ "pos": mid + Vector3(-0.6, 0, 2.6), "kind": "bench", "yaw": PI })
			for q in 3: KitProps.k(t, "platformer", "crate", mid + Vector3(2.4 - (q % 2) * 0.8, (q / 2) * 0.75, -1.4), rng.randf() * 0.4)
		4:   # 노천 다과 — 둥근 탁자 셋, 의자, 케이크·찻잔, 오색 전구 줄, 화분
			for q in 3:
				var tp := mid + Vector3(-2.0 + q * 2.0, 0, -1.6 + (q % 2) * 2.4)
				KitProps.f(t, "tableRound", tp, 0.0)
				for a in [0.0, PI]: KitProps.f(t, "chairModernCushion", tp + Vector3(0, 0, 0.9 if a == 0.0 else -0.9), a)
				KitProps.k(t, "food", ["cake-birthday", "cup-tea", "cupcake", "pie"][(q + rng.randi()) % 4], tp + Vector3(0, 0.82, 0), 0.0, 1.0, false)
				t.spots.append({ "pos": tp + Vector3(0, 0, 1.3), "kind": "bench", "yaw": PI })
			for q in 2: KitProps.k(t, "holiday", "lights-colored", mid + Vector3(-1.5 + q * 3.0, 2.4, 0.4), 0.0, 3.0, false)
			for s2 in [-1.0, 1.0]: t._box(Vector3(0.08, 2.5, 0.08), mid + Vector3(s2 * 3.0, 0, 0.4), t._mat(Color("4a4a52")))
			KitProps.f(t, "pottedPlant", mid + Vector3(-2.9, 0, 3.4)); KitProps.f(t, "pottedPlant", mid + Vector3(2.9, 0, -3.4))
		5:   # 동네 공방 — 작업대·모루·숫돌, 통, 궤짝, 연장, 장작·널빤지 더미, 팔레트
			KitProps.k(t, "survival", "workbench", mid + Vector3(-1.6, 0, -1.8), 0.0)
			KitProps.k(t, "survival", "workbench-anvil", mid + Vector3(0.4, 0, -1.8), 0.0)
			KitProps.k(t, "survival", "workbench-grind", mid + Vector3(2.2, 0, -1.6), 0.0)
			for q in 3: KitProps.k(t, "survival", "barrel" if q != 1 else "barrel-open", mid + Vector3(-2.6 + q * 0.75, 0, 1.6), 0.0)
			KitProps.k(t, "survival", "chest", mid + Vector3(1.4, 0, 1.4), 0.4)
			KitProps.k(t, "survival", "resource-planks", mid + Vector3(2.2, 0, 0.2), 0.2)
			KitProps.k(t, "survival", "resource-wood", mid + Vector3(-1.0, 0, 0.0), 0.9)
			KitProps.k(t, "urban", "pallet", mid + Vector3(0.6, 0, 3.0), 0.0)
			for q in 3: KitProps.k(t, "survival", ["tool-axe", "tool-hammer", "tool-shovel"][q], mid + Vector3(-0.4 + q * 0.4, 0.88, -1.8), 0.0, 1.0, false)
			t.spots.append({ "pos": mid + Vector3(-1.6, 0, -1.0), "kind": "lookout", "yaw": PI })
		6:   # 마당 야영 — 텐트, 모닥불, 깔개, 통나무 의자, 낚시 걸이, 양동이
			KitProps.k(t, "survival", "tent", mid + Vector3(-1.6, 0, -1.8), 0.4)
			KitProps.k(t, "survival", "campfire-pit", mid + Vector3(0.8, 0, 0.6), 0.0, 1.0, false)
			KitProps.k(t, "survival", "campfire-fishing-stand", mid + Vector3(0.8, 0, 0.6), 0.0, 1.0, false)
			KitProps.k(t, "survival", "bedroll", mid + Vector3(-1.4, 0, 0.8), 0.3, 1.0, false)
			for s2 in [-1.0, 1.0]: KitProps.n(t, "log", mid + Vector3(0.8 + s2 * 1.2, 0, 0.6), PI / 2.0, 2.4)
			KitProps.k(t, "survival", "bucket", mid + Vector3(2.4, 0, -1.4), 0.0)
			t.spots.append({ "pos": mid + Vector3(0.8, 0, 1.6), "kind": "lookout", "yaw": PI })
		7:   # 과수원 가판 — 나무 넷, 짐수레(호박·사과), 궤짝, 팻말
			for q in 4: t._tree(mid + Vector3(-1.8 + (q % 2) * 3.6, 0, -2.6 + (q / 2) * 2.6), 0.9)
			KitProps.k(t, "fantasy", "cart", mid + Vector3(0, 0, 2.2), PI / 2.0, 0.9)
			for q in 3: KitProps.k(t, "food", ["pumpkin", "apple", "pear"][q], mid + Vector3(-0.4 + q * 0.4, 0.95, 2.2), 0.0, 1.4, false)
			KitProps.k(t, "survival", "signpost-single", mid + Vector3(-2.6, 0, 3.4), 0.0)
			for q in 2: KitProps.k(t, "platformer", "crate", mid + Vector3(2.4, q * 0.75, 2.6), 0.2)
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
		3:   # 정원 — 분수(Fantasy Town), 생울타리, 나무, 벤치, 등
			KitProps.k(t, "fantasy", "fountain-round", mid, 0.0, 0.9)
			for s2 in [-1.0, 1.0]:
				KitProps.k(t, "fantasy", "hedge-large", mid + Vector3(s2 * 2.8, 0, -1.2), PI / 2.0, 1.0)
				KitProps.k(t, "holiday", "bench", mid + Vector3(s2 * 1.6, 0, 3.0), PI)
				KitProps.k(t, "fantasy", "lantern", mid + Vector3(s2 * 2.8, 0, 2.6), 0.0, 0.7)
			t._tree(mid + Vector3(-2.2, 0, -3.6), 1.0); t._tree(mid + Vector3(2.2, 0, -3.6), 0.95)
