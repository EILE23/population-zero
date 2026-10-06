class_name TownStore
extends TownWages
## 잡화점(운영자 2026-10-06 "진짜 화폐로 키우자", money 2): 지도의 가게 종류에 GENERAL STORE 가 하나 더 — 번화가 필지가 돌아가며 받는다(data/map/town.json, CityMap.shop_of).
## 파는 것은 입는 것(Wear: 모자 넷·목도리·가방)과 우산 — 값은 data/prices.json "buy". 가게 방 진열대(ShopKit, SELLS·MIX)에서 집어 계산대에서 값을 치르고(town_interior) 그 자리에서 쓴다:
## 입는 것을 든 채 C = `don`(두 손으로 머리에, stick3d_wear.gd) — DON_ON 에 손의 것이 소켓으로. 빈손에 아무것도 없으면 C = `doff`(오른손으로 벗어 손에). 값을 안 치른 것은 쓸 수 없다("Pay at the counter first.").
## 주민도 산다(resident_store.gd): 주머니에 값이 있고 모자(또는 등의 것)가 없으면 열린 잡화점 문 앞에 가서 값을 내고(주인 주머니로) 같은 don 으로 쓴다 — 어울림이 높은 사람일수록 자주. 번 품삯(money 1)이 여기서 돈다.
## 사람이 쓴 것은 records["worn"]{slot: [kind, color]} 에 남아 다음에도 쓰고 있다. 사슬: … → social → wages → **store** → player → town3d

## 물건 만들기 — 입는 것(Wear.KINDS)이면 소켓용 노드, 아니면 보통 물건. 진열대·창구가 쓴다
func make_goods(kind: String, at: Vector3) -> Node3D:
	if kind in Wear.KINDS: return make_wearable(kind, at, Wear.palette(randi() % 6))
	return make_item(kind, at)

## 쓰기 — fig 의 손에 든 item 을 don 자세로 머리(소켓)에. keep_prev 면 같은 슬롯에 있던 것이 손으로 온다(사람), 아니면 사라진다(주민은 헌 것을 가방에 넣는다)
func don(fig: Stick3D, item: Node3D, keep_prev: bool) -> void:
	if fig.carrying != item: fig.hold(item)
	fig.pose_request = "don"
	get_tree().create_timer(WearPoses.DON_ON).timeout.connect(func() -> void:
		if not is_instance_valid(fig) or not is_instance_valid(item) or fig.pose_request != "don": return
		var prev := fig.wear(item)
		if prev and keep_prev: fig.hold(prev)
		elif prev: prev.queue_free()
		if fig == player: _save_worn())
	get_tree().create_timer(WearPoses.DON_T).timeout.connect(func() -> void:
		if is_instance_valid(fig) and fig.pose_request == "don": fig.pose_request = "")

## 벗기 — doff 자세로 그 슬롯의 것을 손에
func doff(fig: Stick3D, slot: String) -> void:
	fig.pose_request = "doff"
	get_tree().create_timer(WearPoses.DOFF_OFF).timeout.connect(func() -> void:
		if not is_instance_valid(fig) or fig.pose_request != "doff": return
		var it := fig.take_off(slot)
		if it: fig.hold(it)
		if fig == player: _save_worn())
	get_tree().create_timer(WearPoses.DOFF_T).timeout.connect(func() -> void:
		if is_instance_valid(fig) and fig.pose_request == "doff": fig.pose_request = "")

## 사람: 든 입는 것을 쓴다(town_player C). 값을 안 치른 것이면 계산대부터
func wear_held(now: float) -> void:
	if player.carrying.has_meta("unpaid"):
		say_toast("Pay at the counter first."); return
	don(player, player.carrying, true)
	use_until = now + WearPoses.DON_T; action_until = now + WearPoses.DON_T

## 사람: 근처에 아무것도 없고 빈손이면 모자를 벗어 손에(town_player)
func doff_hat(now: float) -> void:
	doff(player, "hat")
	use_until = now + WearPoses.DOFF_T; action_until = now + WearPoses.DOFF_T

## 쓴 것 저장·복원 — records["worn"] = {slot: [kind, "rrggbb"]}
func _save_worn() -> void:
	var w := {}
	for slot in player.worn: w[slot] = [String(player.worn[slot].get_meta("kind", "")), (player.worn[slot].get_meta("color", Color("ad7096")) as Color).to_html(false)]
	records["worn"] = w
	_save_records()

func _store_init() -> void:
	for slot in (records.get("worn", {}) as Dictionary):
		var e: Array = records["worn"][slot]
		if e.size() == 2 and String(e[0]) in Wear.KINDS: player.wear(make_wearable(String(e[0]), Vector3.ZERO, Color(String(e[1]))))

# ── 주민 손님(resident_store.gd 가 부른다) ──
## 열린 잡화점 중 가장 가까운 것 — 없으면 {}
func store_near(p: Vector3) -> Dictionary:
	var best: Dictionary = {}; var bd := 1e9
	for sh in shops:
		if String(sh["type"]) != "GENERAL STORE" or not shop_open(sh): continue
		var d: float = p.distance_to(sh["pos"])
		if d < bd: bd = d; best = sh
	return best

## 손님 자리 — 문 앞 옆(주인 자리는 문 한가운데). 한 칸
func store_front(sh: Dictionary) -> Dictionary:
	if not sh.has("buy"): sh["buy"] = { "kind": "store", "pos": (sh["keeper"]["pos"] as Vector3) + Vector3(0.9, 0, 0.4), "yaw": 0.0, "shop_id": int(sh["id"]) }
	return sh["buy"]

## 이 주민이 사고 싶은 것 — 모자가 없으면 모자, 등이 비면 목도리·가방, 다 있으면 지금 것과 다른 모자. 값은 prices.json
func store_wish(r: ResidentBase) -> String:
	var hats: Array = ShopKit.MIX["cap"]
	if not r.fig.worn.has("hat"): return String(hats[r.uid % hats.size()])
	if not r.fig.worn.has("back"): return ["scarf", "backpack"][r.uid % 2]
	var cur := String((r.fig.worn["hat"] as Node3D).get_meta("kind", ""))
	return String(hats[(hats.find(cur) + 1 + r.uid % 3) % hats.size()])

## 산다 — 값을 치르고(주인 주머니로) 그 자리에서 don. 값이 모자라거나 닫혔으면 false
func store_buy(r: ResidentBase, sh: Dictionary) -> bool:
	if not shop_open(sh): return false
	var kind := store_wish(r)
	var p := int((prices.get("buy", {}) as Dictionary).get(kind, 4))
	if r.coins < p: return false
	r.coins -= p
	var k := _keeper(sh)
	if k: k.coins += p; k.say(["Suits you.", "There you are.", "Thank you."][randi() % 3], 1.6)
	don(r.fig, make_wearable(kind, r.global_position + Vector3(0, 0.9, 0), Wear.palette(r.uid + p)), false)
	get_tree().create_timer(WearPoses.DON_T + 0.2).timeout.connect(func() -> void: if is_instance_valid(r): r.say(r.mind.line("bought"), 1.6))
	return true
