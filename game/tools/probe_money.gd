extends SceneTree
## 진짜 화폐 점검(헤드리스): 빈 주머니로 빵은 거절, 사과·호박 팔기, 값대로 빵 사기, 상금
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	var bc: Dictionary = town.spots.filter(func(s): return s["kind"] == "counter" and s.has("stock"))[0]
	town.body.global_position = (bc["pos"] as Vector3) + Vector3(0, 0.05, 0.3)
	town.coins = 0
	while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
	town.counter_use(bc, 0.0)
	print("BUY empty pocket: holding=", town.player.carrying != null, " coins=", town.coins)
	for k in ["apple", "pumpkin"]:
		town.player.hold(town.make_item(k, Vector3.ZERO)); town.action_until = 0.0
		var sold: bool = town.sell_here(0.0)
		print("SELL ", k, " sold=", sold, " coins=", town.coins)
	bc["stock"] = 3
	town.counter_use(bc, 0.0)
	print("BUY bread: holding=", (town.player.carrying.get_meta("kind", "") if town.player.carrying else ""), " coins=", town.coins, " till=", bc.get("till", 0))
	town._game_prize("race", { "place": 1 }); town._game_prize("climb", { "score": 1000.0 })
	print("PRIZE coins=", town.coins)
	quit()
