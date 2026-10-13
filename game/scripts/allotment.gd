class_name Allotment
extends RefCounted
## 동네 텃밭 — 아직 안 지은 필지(지을 때까지, town_city _fill_block). 낮은 울타리, 이랑 넷(당근·순무·호박·옥수수), 창고, 물통, 팻말.
## 공사가 시작되면 통째로 걷는다(_draw_site). 주민이 들여다보는 자리(lookout)

static func build(t, l: Dictionary, c: Vector3) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash("plot/" + String(l["id"]))
	var front := float(l["street_z"]) - TownPlan.ROAD_W / 2.0 - 0.5
	var back := float(l["street_z"]) - TownPlan.PITCH / 2.0 + TownPlan.ROAD_W / 2.0 + 0.5
	var hw := TownPlan.LOT / 2.0 - 0.3
	for s in [-1.0, 1.0]:   # 낮은 울타리(문간은 비운다)
		for k in int((front - back) / 2.0): KitProps.n(t, "fence_simpleLow", Vector3(c.x + s * hw, 0, back + 1.0 + k * 2.0), PI / 2.0, 2.0, false)
	for k in int(hw): KitProps.n(t, "fence_simpleLow", Vector3(c.x - hw + 1.0 + k * 2.0, 0, back), 0.0, 2.0, false)
	var crops := ["crop_carrot", "crop_turnip", "crop_pumpkin", "crops_leafsStageB", "crops_cornStageC", "crop_melon"]
	for r in 4:
		var rz := back + 1.4 + r * (front - back - 3.4) / 3.0
		for hx in [-1.5, 1.5]: KitProps.n(t, "crops_dirtRow", Vector3(c.x + hx, 0, rz), 0.0, 2.8, false)
		var kind: String = crops[(r + rng.randi()) % crops.size()]
		for q in 6: KitProps.n(t, kind, Vector3(c.x - 2.6 + q * 1.04, 0.05, rz), rng.randf() * TAU, 1.3 if kind.begins_with("crops_corn") else 1.1, kind.begins_with("crops_corn"))
	t._box(Vector3(1.6, 1.9, 1.3), Vector3(c.x + hw - 1.0, 0, front - 1.0), t._mat([Color("6f8a5a"), Color("8a6a4a"), Color("7a90b0")][rng.randi() % 3]))   # 창고
	t._box(Vector3(1.9, 0.08, 1.6), Vector3(c.x + hw - 1.0, 1.9, front - 1.0), t._mat(Color("3a3a42")), false)
	KitProps.n(t, "pot_large", Vector3(c.x - hw + 0.8, 0, front - 0.8), 0.0, 2.0)
	var sg := KitProps.n(t, "sign", Vector3(c.x - 1.4, 0, front - 0.2), 0.0, 2.2)
	var lb := Label3D.new(); lb.text = "Community plot"; lb.font_size = 32; lb.pixel_size = 0.004; lb.modulate = Color("1b0c15"); lb.position = Vector3(c.x - 1.4, 1.05, front - 0.1); t._add(lb)
	t.spots.append({ "pos": Vector3(c.x, 0, front - 0.6), "kind": "lookout", "yaw": PI })
