extends SceneTree
## 내 집 꾸미기 점검(헤드리스, run 117, money 4): 필지를 사 지은 내 집은 빈 방; 잡화점 문 옆 탁자에서 납작 상자를 집어 계산대에서 값을 치르고,
## 내 집 안에서 plonk 으로 편다(자리가 생기고 records 에 남는다) → 길게 C 로 도로 상자에 → 다시 놓고 방을 허물었다 다시 세우면 그 자리에;
## 주민은 문 앞에서 사서(주인 주머니로) 제 집 문 앞까지 들고 가 같은 plonk 으로 들인다(그 집 방에 선다); 닫힌 가게에선 못 산다
## godot --headless --path game -s res://tools/probe_furnish.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"; town.weather_until = 1e12; town.clock = 0.15
	# 내 집
	var sales: Array = town.spots.filter(func(s: Dictionary) -> bool: return s["kind"] == "sale")
	town.coins = 100
	var k: int = int(sales[0]["lot"])
	town._buy(k, "cottage")
	var sp: Dictionary = town.build_spot_of(k)
	for i in 25:
		if not town._site_nodes.has(k): break
		town.build_work(sp)
	var dr: Dictionary = town.doors[town.doors.size() - 1]
	var di: int = town.doors.size() - 1
	print("HOUSE mine=", dr.get("mine", false), " lot=", dr.get("lot", -1), " coins=", town.coins)
	var home: Dictionary = town._room(di)
	print("EMPTY layout=", home["kit"]["layout"]["name"], " spots=", (home["spots"] as Array).size(), " placed=", (town._placed.get(di, []) as Array).size())
	# 잡화점 — 탁자의 납작 상자
	var stores: Array = town.shops.filter(func(s: Dictionary) -> bool: return String(s["type"]) == "GENERAL STORE")
	var sh: Dictionary = stores[0]
	var kp: Resident = town._keeper(sh)
	kp.state = "busy"; kp.spot = sh["keeper"]; kp.busy_until = 1e9; kp.global_position = sh["keeper"]["inner"]
	town.inside = town._room(int(sh["room"]))
	var shelf: Array = (town.inside["spots"] as Array).filter(func(s: Dictionary) -> bool: return s["kind"] == "shelf" and s["item"] == "flatpack")
	var till: Dictionary = (town.inside["spots"] as Array).filter(func(s: Dictionary) -> bool: return s["kind"] == "counter")[0]
	print("TABLE flatpack_shelf=", shelf.size(), " open=", town.shop_open(sh))
	while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
	town.body.global_position = shelf[0]["pos"]; town.action_until = 0.0
	town.inner_use(0.0)
	var held: Node3D = town.player.carrying
	print("SHELF took=", held.get_meta("kind", "") if held else "", " flatpack=", held.get_meta("flatpack", false) if held else false, " unpaid=", held.has_meta("unpaid") if held else false)
	var c0: int = town.coins
	town.body.global_position = till["pos"]; town.action_until = 0.0
	town.inner_use(0.0)
	print("TILL paid=", c0 - town.coins, " unpaid=", held.has_meta("unpaid"))
	# 내 집에서 편다
	town.inside = home
	town.body.global_position = (home["entry"] as Vector3) + Vector3(0, 0, -1.0); town.player.rotation.y = PI; town.action_until = 0.0
	var now := Time.get_ticks_msec() / 1000.0
	var ok: bool = town.furnish_place(now)
	print("PLONK start=", ok, " pose=", town.player.pose_request)
	for i in 70: await physics_frame
	var placed: Array = town._placed.get(di, [])
	print("PLACED n=", placed.size(), " spots=", (home["spots"] as Array).size(), " carrying=", town.player.carrying != null, " pose=", town.player.pose_request, " rec=", str(town.records["my_plots"][str(k)].get("furn", [])))
	# 도로 든다
	town.body.global_position = (placed[0]["node"] as Node3D).global_position + Vector3(0.5, 0, 0.5)
	var took: bool = town.furnish_take(Time.get_ticks_msec() / 1000.0)
	print("TAKE ok=", took, " carrying=", (town.player.carrying.get_meta("kind", "") if town.player.carrying else ""), " placed=", (town._placed.get(di, []) as Array).size(), " spots=", (home["spots"] as Array).size(), " rec=", str(town.records["my_plots"][str(k)].get("furn", [])))
	# 다시 놓고 방을 허물었다 세운다
	town.body.global_position = (home["entry"] as Vector3) + Vector3(1.5, 0, -1.5); town.player.rotation.y = -PI / 2.0; town.action_until = 0.0
	town.furnish_place(Time.get_ticks_msec() / 1000.0)
	for i in 70: await physics_frame
	town.inside = {}
	town._free_room(di)
	home = town._room(di)
	print("REBUILD placed=", (town._placed.get(di, []) as Array).size(), " spots=", (home["spots"] as Array).size(), " kinds=", str(home["spots"].map(func(s: Dictionary) -> String: return String(s["kind"]))))
	# 주민: 가게 문 앞에서 사서 집으로, 문 앞에서 plonk
	var r: Resident = null
	for x: Resident in town.residents:
		if not (x is ResidentKid) and x != kp and x.job == "" and not x.home_door.is_empty() and x.fig.carrying == null and x.state != "drive": r = x; break
	print("CUSTOMER found=", r != null)
	r.coins = 12; r.mind.lazy = 0.1
	if r.global_position.distance_to(sh["pos"]) > 60.0: r.global_position = (sh["pos"] as Vector3) + Vector3(6, 0, 6)
	var picked := false
	for t in 80:
		if r._furnish_pick(0.0): picked = true; break
	print("PICK chose=", picked, " act=", r.get_meta("furn_act", ""), " wish=", town.furn_wish(r))
	var front: Dictionary = town.store_front(sh)
	r.global_position = front["pos"]; r.spot = front; r.state = "busy"
	var kc0: int = kp.coins
	var bought: bool = r._furnish_arrive(0.0)
	print("BUY arrive=", bought, " carrying=", (r.fig.carrying.get_meta("kind", "") if r.fig.carrying else ""), " keeper+=", kp.coins - kc0, " act=", r.get_meta("furn_act", ""), " state=", r.state, " spot=", r.spot.get("kind", ""))
	var hi: int = town.doors.find(r.home_door)
	r.global_position = r.spot["pos"]; r.state = "busy"
	var arrived: bool = r._furnish_arrive(Time.get_ticks_msec() / 1000.0)
	print("HOME arrive=", arrived, " pose=", r.fig.pose_request)
	for i in 70: await physics_frame
	print("ADDED extra=", (town._extra.get(hi, []) as Array).size(), " carrying=", r.fig.carrying != null, " pose=", r.fig.pose_request, " count=", town.furn_count(r.home_door))
	var rr: Dictionary = town._room(hi)
	print("ROOM placed=", (town._placed.get(hi, []) as Array).size(), " layout=", rr["kit"]["layout"]["name"])
	kp.state = "walk"
	r.coins = 12
	if r.fig.carrying: r.fig.release(town, Vector3.ZERO).queue_free()
	print("CLOSED open=", town.shop_open(sh), " buy=", town.furn_buy(r, sh), " coins=", r.coins)
	quit()
