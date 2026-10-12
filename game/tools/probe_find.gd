extends SceneTree
## 필지 모양 찾기 — 탑집(turret) 옆에 차고집(garage)이 붙은 자리
func _init() -> void:
	var lots := TownPlan.lots()
	for k in 140:
		var l: Dictionary = lots[k]
		var st := HouseStyles.style_of(l)
		if st != "turret": continue
		for k2 in 140:
			var l2: Dictionary = lots[k2]
			if HouseStyles.style_of(l2) == "garage" and (l2["c"] as Vector2).distance_to(l["c"]) < 8.0 and CityMap.lot_kind(l) == "house" and CityMap.lot_kind(l2) == "house":
				print("FIND turret %d at %s garage %d at %s" % [k, str(l["c"]), k2, str(l2["c"])])
	quit()
