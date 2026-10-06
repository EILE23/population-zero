extends SceneTree
## 잡화점 점검(헤드리스, run 114, money 2): 지도에 GENERAL STORE 가 선다; 주인이 서면 열린다; 사람은 방의 모자 진열대에서 집고(안 치른 채 쓰려면 거절) 계산대에서 값을 치르고 don 으로 쓴다,
## 빈손 C 로 doff 해 손에; 주민은 문 앞에서 값을 내고(주인 주머니로) 같은 don 으로 쓴다; 쓴 것은 records["worn"] 에 남는다
## godot --headless --path game -s res://tools/probe_store.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"; town.weather_until = 1e12; town.clock = 0.15
	var stores: Array = town.shops.filter(func(s: Dictionary) -> bool: return String(s["type"]) == "GENERAL STORE")
	print("STORES n=", stores.size())
	if stores.is_empty(): quit(); return
	var sh: Dictionary = stores[0]
	var k: Resident = town._keeper(sh)
	print("KEEPER hired=", k != null)
	k.state = "busy"; k.spot = sh["keeper"]; k.busy_until = 1e9; k.global_position = sh["keeper"]["inner"]
	print("OPEN=", town.shop_open(sh))
	# 사람: 방 안 — 모자 진열대 → 안 치른 채 쓰기(거절) → 계산대 → don
	town.inside = town._room(int(sh["room"]))
	var shelf: Dictionary = (town.inside["spots"] as Array).filter(func(s: Dictionary) -> bool: return s["kind"] == "shelf" and s["item"] == "cap")[0]
	var till: Dictionary = (town.inside["spots"] as Array).filter(func(s: Dictionary) -> bool: return s["kind"] == "counter")[0]
	town.coins = 10
	while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
	town.body.global_position = shelf["pos"]; town.action_until = 0.0
	town.inner_use(0.0)
	var held: Node3D = town.player.carrying
	print("SHELF took=", held.get_meta("kind", "") if held else "", " unpaid=", held.has_meta("unpaid") if held else false, " wearable=", held.get_meta("wearable", false) if held else false)
	var now := Time.get_ticks_msec() / 1000.0
	town.wear_held(now)
	print("WEAR unpaid refused: worn_hat=", town.player.worn.has("hat"), " pose=", town.player.pose_request)
	town.body.global_position = till["pos"]; town.action_until = 0.0
	town.inner_use(0.0)
	print("TILL paid: coins=", town.coins, " unpaid=", held.has_meta("unpaid"), " keeper_coins=", k.coins)
	now = Time.get_ticks_msec() / 1000.0
	town.wear_held(now)
	print("DON start pose=", town.player.pose_request)
	for i in 70: await physics_frame
	print("DON done: worn_hat=", town.player.worn.has("hat"), " kind=", (town.player.worn["hat"].get_meta("kind", "") if town.player.worn.has("hat") else ""), " carrying=", town.player.carrying != null, " pose=", town.player.pose_request, " worn_rec=", town.records.get("worn", {}))
	town.inside = {}
	town.doff_hat(Time.get_ticks_msec() / 1000.0)
	for i in 70: await physics_frame
	print("DOFF done: worn_hat=", town.player.worn.has("hat"), " carrying=", (town.player.carrying.get_meta("kind", "") if town.player.carrying else ""), " pose=", town.player.pose_request)
	# 주민: 문 앞에서 산다
	var r: Resident = null
	for x: Resident in town.residents:
		if not (x is ResidentKid) and x != k and x.job == "" and not x.fig.worn.has("hat") and x.state != "drive": r = x; break
	print("CUSTOMER found=", r != null)
	r.coins = 10
	var sp: Dictionary = town.store_front(sh)
	r.global_position = sp["pos"]; r.spot = sp; r.state = "busy"
	var ok: bool = r._store_arrive(0.0)
	print("BUY arrive=", ok, " coins=", r.coins, " keeper_coins=", k.coins, " pose=", r.fig.pose_request)
	for i in 70: await physics_frame
	print("BUY done: worn_hat=", r.fig.worn.has("hat"), " kind=", (r.fig.worn["hat"].get_meta("kind", "") if r.fig.worn.has("hat") else ""), " carrying=", r.fig.carrying != null)
	# 고르기 — 어울림이 높은 사람은 결국 간다
	var picks := 0
	for x: Resident in town.residents:
		if x is ResidentKid or x == k or x.state == "drive": continue
		x.coins = 10
		if x.global_position.distance_to(sh["pos"]) > 60.0: x.global_position = (sh["pos"] as Vector3) + Vector3(6, 0, 6)
		for t in 40:
			if x._store_pick(0.0): picks += 1; break
		if picks >= 3: break
	print("PICK residents_who_chose_store=", picks)
	k.state = "walk"   # 주인이 자리를 뜨면 닫힌다 — 손님은 한마디 하고 돌아선다
	r.coins = 10; r.spot = sp; r.state = "busy"
	print("CLOSED open=", town.shop_open(sh), " buy=", town.store_buy(r, sh), " arrive=", r._store_arrive(0.0), " coins=", r.coins, " wish=", town.store_wish(r))
	quit()
