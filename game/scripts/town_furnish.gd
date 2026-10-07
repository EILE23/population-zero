class_name TownFurnish
extends TownPawn
## 내 집 꾸미기(운영자 2026-10-06 "진짜 화폐로 키우자" money 4, run 117): 산 필지에 지은 내 집(town_plots)은 빈 방으로 선다 — 가구는 잡화점에서 산다.
## 잡화점 문 옆 카탈로그 탁자(shop_kit 의 넷째 진열)에 납작 상자(flatpack: 의자·작은 탁자·책장·소파·침대·깔개·스탠드·화분)가 놓인다; 집어 계산대에서 값(prices.json buy)을 치르고 집으로 들고 간다.
## 내 집 안에서 상자를 든 채 C = `plonk`(stick3d_furnish.gd — 두 손으로 바닥에 내려놓는다): PLONK_DOWN 에 상자가 앞 0.8m 의 진짜 가구(RoomKit.PIECES — 앉고 눕고 읽는 자리까지)가 된다.
## 길게 C 로 도로 상자에(다시 놓거나 창구에 판다). 놓은 것은 records["my_plots"][k]["furn"] 에 방 좌표로 남아 다음에도 그 자리에(계정 저장에 같이 간다).
## 주민도 산다(resident_furnish.gd): 품삯이 모이면 같은 탁자에서 하나 사서 제 집 문 앞까지 들고 가 같은 plonk 으로 들인다 — 그 집 방에 가구가 는다(FURN_MAX 까지; 이 판에서만, 저장은 다음 조각).
## 사슬: … → jobs → pawn → **furnish** → player → town3d

const FURN_MAX := 3            # 주민 한 집에 들이는 가구 수 — 방이 꽉 차지 않게
var FURN: Array = ShopKit.MIX["flatpack"]   # 파는 것 — RoomKit.PIECES 의 이름 그대로(값은 prices.json; 목록은 진열대와 한 곳에)

var _extra := {}               # 문 번호 -> [[kind, x, z, yaw]] — 주민이 사 들인 가구(방 좌표)
var _placed := {}              # 문 번호 -> [{node, spots, e}] — 지금 서 있는 방의 산 가구(길게 C 로 도로 든다)

## 납작 상자 — 종이색 상자에 모브 띠와 윗면 이름표. 든 채 다니고, 내 집에서 plonk 으로 편다. 값은 가구 이름으로(prices.json)
func make_flatpack(kind: String, at: Vector3) -> Node3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new(); b.size = Vector3(0.3, 0.07, 0.22); mi.mesh = b; mi.material_override = _mat(Color("c9a27a"))
	mi.position = at + Vector3(0, 0.035, 0)
	_box(Vector3(0.3, 0.012, 0.05), Vector3(0, 0.035, 0), _mat(Color("ad7096")), false, mi)
	var lb := Label3D.new(); lb.text = kind.replace("_", " ").to_upper(); lb.font_size = 24; lb.pixel_size = 0.0025; lb.modulate = Color("1b0c15"); lb.outline_size = 0
	lb.rotation.x = -PI / 2.0; lb.position = Vector3(0, 0.05, -0.07); mi.add_child(lb)
	mi.set_meta("kind", kind); mi.set_meta("flatpack", true)
	add_child(mi)
	return mi

## 진열대·창구가 만드는 물건(town_store) — 가구면 납작 상자
func make_goods(kind: String, at: Vector3) -> Node3D:
	if kind in FURN: return make_flatpack(kind, at)
	return super(kind, at)

func _in_my_house() -> bool:
	return is_inside() and bool(doors[int(inside["door"])].get("mine", false))

## 내 집의 가구 목록(records) — 문에 적힌 필지 번호로
func _my_furn(rm: Dictionary) -> Array:
	var e: Dictionary = _mine().get(str(int(doors[int(rm["door"])].get("lot", -1))), {})
	if e.is_empty(): return []
	if not e.has("furn"): e["furn"] = []
	return e["furn"]

## 방 안으로 — 벽에서 0.6, 문길(앞 1.9)은 비워 둔다
func _clamp_room(rm: Dictionary, p: Vector3) -> Vector3:
	var o: Vector3 = rm["o"]; var w: float = rm["w"]; var d: float = rm["d"]
	return Vector3(clampf(p.x, o.x - w / 2.0 + 0.6, o.x + w / 2.0 - 0.6), o.y, clampf(p.z, o.z - d / 2.0 + 0.5, o.z + d / 2.0 - 1.9))

## 사람: 내 집 안에서 상자를 든 채 C(town_player) — plonk 으로 앞 0.8m 에 편다. 값을 안 치른 것이면 계산대부터; 내 집이 아니면 false(여느 내려놓기로)
func furnish_place(now: float) -> bool:
	var it: Node3D = player.carrying
	if it == null or not it.get_meta("flatpack", false) or not _in_my_house(): return false
	if it.has_meta("unpaid"): say_toast("Pay at the counter first."); return true
	var p := body.global_position
	var at := _clamp_room(inside, p + Vector3(sin(player.rotation.y), 0, cos(player.rotation.y)) * 0.8)
	if Vector2(at.x - p.x, at.z - p.z).length() < 0.45: say_toast("No room there."); return true   # 벽에 붙어 서면 제 발 밑에 놓인다
	var yaw := player.rotation.y + PI   # 가구의 앞(+z)이 사람을 본다
	var rm: Dictionary = inside
	player.pose_request = "plonk"; use_until = now + FurnishPoses.PLONK_T; action_until = now + FurnishPoses.PLONK_T
	get_tree().create_timer(FurnishPoses.PLONK_DOWN).timeout.connect(func() -> void:
		if player.pose_request != "plonk" or player.carrying != it or not is_same(inside, rm): return
		var kind := String(it.get_meta("kind", ""))
		player.release(self, Vector3.ZERO).queue_free()
		var e := [kind, at.x - (rm["o"] as Vector3).x, at.z - (rm["o"] as Vector3).z, yaw]
		_my_furn(rm).append(e); _save_records()
		_place(rm, e)
		say_toast("%s, there." % kind.replace("_", " ").capitalize()))
	return true

## 사람: 내 집 안에서 빈손으로 길게 C(town_player) — 가장 가까운 산 가구(1.3m)를 도로 상자에. 앉아 있으면 아니다
func furnish_take(now: float) -> bool:
	if player.carrying or not carrying_big.is_empty() or not seat.is_empty() or not _in_my_house(): return false
	var best: Dictionary = {}; var bd := 1.3
	for pl in (_placed.get(int(inside["door"]), []) as Array):
		var d: float = body.global_position.distance_to((pl["node"] as Node3D).global_position)
		if d < bd: bd = d; best = pl
	if best.is_empty(): return false
	_unplace(inside, best)
	_my_furn(inside).erase(best["e"]); _save_records()
	player.hold(make_flatpack(String(best["e"][0]), Vector3.ZERO)); player.action = "grab"; action_until = now + 0.4
	return true

## 가구 하나를 방에 — RoomKit.piece 로(C 자리까지); 든 것을 기억해 둔다(길게 C). 방 밖이면 안으로 당긴다(주민 집은 방 크기를 모른 채 자리를 골랐다)
func _place(rm: Dictionary, e: Array) -> void:
	var n: Node3D = rm["node"]; var spots: Array = rm["spots"]
	var n0 := n.get_child_count(); var s0 := spots.size()
	var kit: Dictionary = rm.get("kit", {})
	if not kit.has("cloth"): kit = { "cloth": Color("ad7096") }
	var keep := _build_parent; _build_parent = n
	RoomKit.piece(self, rm, String(e[0]), _clamp_room(rm, (rm["o"] as Vector3) + Vector3(float(e[1]), 0, float(e[2]))), float(e[3]), kit)
	_build_parent = keep
	if n.get_child_count() <= n0: return
	var list: Array = _placed.get(int(rm["door"]), [])
	list.append({ "node": n.get_child(n0), "spots": spots.slice(s0), "e": e }); _placed[int(rm["door"])] = list

func _unplace(rm: Dictionary, pl: Dictionary) -> void:
	(pl["node"] as Node3D).queue_free()
	for sp in pl["spots"]: (rm["spots"] as Array).erase(sp)
	(_placed[int(rm["door"])] as Array).erase(pl)

## 방이 설 때(town_interior._house_room 이 부른다) — 내 집은 records 의 가구를, 주민 집은 이 판에 사 들인 것을 그 자리에
func furnish_restore(rm: Dictionary) -> void:
	var i := int(rm["door"])
	_placed.erase(i)
	var mine := bool(doors[i].get("mine", false))
	var list: Array = _my_furn(rm) if mine else _extra.get(i, [])
	for e in list: _place(rm, e)
	if mine and list.is_empty() and not _tool_run(): say_toast("An empty house. The general store sells furniture.")

# ── 주민 손님(resident_furnish.gd 가 부른다) ──
## 이 주민이 들일 것 — 호기심은 책장, 어울림은 소파, 게으름은 침대, 아니면 번호로 하나
func furn_wish(r: ResidentBase) -> String:
	var m: ResidentMind = r.mind
	if m.curious > 0.65: return "bookshelf"
	if m.social > 0.65: return "sofa"
	if m.lazy > 0.65: return "bed"
	return ["chair", "table_small", "rug", "floor_lamp", "plant"][r.uid % 5]

func furn_count(door: Dictionary) -> int:
	var i := doors.find(door)
	return (_extra.get(i, []) as Array).size() if i >= 0 else FURN_MAX

## 산다 — 값을 치르고(주인 주머니로) 상자를 손에. 닫혔거나 값이 모자라거나 손이 차 있으면 false
func furn_buy(r: ResidentBase, sh: Dictionary) -> bool:
	if not shop_open(sh) or r.fig.carrying: return false
	var kind := furn_wish(r)
	var p := int((prices.get("buy", {}) as Dictionary).get(kind, 4))
	if r.coins < p: return false
	r.coins -= p
	var k := _keeper(sh)
	if k: k.coins += p; k.say(["Mind the corners.", "There you are.", "Thank you."][randi() % 3], 1.6)
	r.fig.hold(make_flatpack(kind, Vector3.ZERO)); r.fig.action = "grab"; r.fig.action_t = 0.0
	return true

## 들인다(주민이 제 집 문 앞에서 plonk 을 마쳤다) — 그 집 방의 빈자리에(뒤 모서리의 ㄱ자 벽과 문길은 피한다); 방이 서 있으면 지금 세운다
func furn_add(r: ResidentBase, kind: String) -> void:
	var i := doors.find(r.home_door)
	if i < 0: return
	var list: Array = _extra.get(i, [])
	var rng := RandomNumberGenerator.new(); rng.seed = hash("%d/%d" % [i, list.size()])
	var rm: Dictionary = _rooms.get(i, {})
	var w := float(rm.get("w", 8.0)); var d := float(rm.get("d", 7.0))
	var x := rng.randf_range(1.3, w / 2.0 - 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)   # 문길(|x| < 1.2)은 비워 둔다
	var e := [kind, x, rng.randf_range(-d * 0.1, d / 2.0 - 2.4), rng.randf() * TAU]
	list.append(e); _extra[i] = list
	if not rm.is_empty(): _place(rm, e)
