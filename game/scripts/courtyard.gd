class_name Courtyard
extends RefCounted
## 안마당(블록 모양 courtyard — TownPlan) — 가운데 찻길 대신 앞줄 집들이 마주 보는 동네 마당. 동서로 자갈 길, 그 둘레에
## 나무·벤치·꽃 띠, 가운데엔 분수 광장이나 놀이터, 한쪽 끝엔 피크닉 탁자. 차는 못 들어온다(찻길이 없다 — car_rail 은 깔린 길만)

static func build(t, b: Vector2i) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash("court/%d,%d" % [b.x, b.y])
	var x0 := TownPlan.OX + b.x * TownPlan.PITCH + TownPlan.ROAD_W / 2.0; var x1 := x0 + TownPlan.PITCH - TownPlan.ROAD_W
	var z := TownPlan.OZ + b.y * TownPlan.PITCH + TownPlan.PITCH / 2.0
	var cx := (x0 + x1) / 2.0
	t._path(Vector3(x0 - 0.2, 0, z), Vector3(x1 + 0.2, 0, z), 2.2)   # 자갈 길 — 양 끝은 남북 찻길 인도에 닿는다
	for k in 4:   # 나무 넷(길 남쪽), 벤치 셋(북쪽 — 길을 본다)
		t._tree(Vector3(lerpf(x0 + 2.0, x1 - 2.0, k / 3.0), 0, z + 3.0), 0.95)
	for k in 3: t._bench(Vector3(lerpf(x0 + 5.0, x1 - 5.0, k / 2.0), 0, z - 2.6))
	KitProps.border(t, Vector3(x0 + 0.5, 0, z + 4.2), Vector3(x1 - 0.5, 0, z + 4.2), rng, 0.7)
	if rng.randf() < 0.5:   # 가운데 — 분수 광장
		t._box(Vector3(7.0, 0.03, 5.0), Vector3(cx, 0, z), t._mat(Color("d8cfc2")), false)
		t.water.disc(Vector3(cx, 0, z), 1.4)
		KitProps.n(t, "statue_column", Vector3(cx, 0, z), 0.0, 1.6)
	else:   # 놀이터
		t._swing(Vector3(cx - 1.5, 0, z + 1.6))
		t._box(Vector3(3.0, 0.15, 2.2), Vector3(cx + 2.0, 0, z + 1.4), t._mat(Color("e8d8a8")), false)
		KitProps.f(t, "benchCushionLow", Vector3(cx + 2.0, 0, z - 1.0), 0.0)
	KitProps.f(t, "tableCloth", Vector3(x1 - 3.0, 0, z + 1.4), 0.0)
	for s in [-1.0, 1.0]: KitProps.f(t, "chairCushion", Vector3(x1 - 3.0 + s * 1.2, 0, z + 1.4), -s * PI / 2.0)
	t.spots.append({ "pos": Vector3(x1 - 3.0, 0, z + 2.4), "kind": "bench", "yaw": PI })
	t._lamp(Vector3(cx - 7.0, 0, z - 1.4)); t._lamp(Vector3(cx + 7.0, 0, z - 1.4))
