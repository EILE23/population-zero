extends SceneTree
## 필지 순서 앞쪽 — 계획을 바꿀 때 이미 지은 집(순번)이 자리를 옮기지 않는지 견준다
func _init() -> void:
	var ls := TownPlan.lots()
	var out := []
	for k in 40: out.append("%d:%s" % [k, str(ls[k]["c"])])
	print("LOTS ", ls.size(), " ", " ".join(out))
	quit()
