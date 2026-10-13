extends SceneTree
## 블록마다 필지 수·지은 수·종류 — 녹지가 어디서 나오나
func _init() -> void:
	var lots := TownPlan.lots()
	var per := {}
	for l in lots:
		var b: Vector2i = l["b"]
		if not per.has(b): per[b] = { "n": 0, "built": 0, "first": int(l["order"]), "kinds": {} }
		per[b]["n"] += 1
		if int(l["order"]) < 102: per[b]["built"] += 1
		var k := CityMap.lot_kind(l); per[b]["kinds"][k] = int(per[b]["kinds"].get(k, 0)) + 1
	var keys: Array = per.keys(); keys.sort_custom(func(a, b): return int(per[a]["first"]) < int(per[b]["first"]))
	for b in keys.slice(0, 22): print("LOTS %s first=%d n=%d built=%d %s zone=%s" % [str(b), per[b]["first"], per[b]["n"], per[b]["built"], str(per[b]["kinds"]), CityMap.zone_at(Vector2(TownPlan.OX + (b.x + 0.5) * 40, TownPlan.OZ + (b.y + 0.5) * 40))])
	quit()
