class_name TownCity
extends TownGrowth
## 지도대로 짓는 마을(운영자 2026-10-06: "Climb 탑까지 가는 길에 마을에 아무것도 없잖아", "진짜 지형처럼 '맵'처럼") — data/map/town.json(CityMap)을 읽어:
##   필지: 번화가는 가게(주인 주민이 창구에 서야 연다 — resident_shop.gd, 사고팔기는 진짜 동전), 공방가는 차고, 주택가는 집(아홉에 하나는 쌈지공원)
##   블록 전체: 관공서(시청·도서관·학교 — 들어가는 큰 건물 + 광장·마당), 공원(연못·나무·벤치·그네)
##   거리: 골목이 깔리면 가로등·가로수, 장소(탑·호숫가·오두막·산)로 가는 길엔 가로등·나무, 갈림길엔 이정표
##   기본 마을: 처음부터 founded 필지가 지어져 있다(town_growth) — 그 위로 건축가가 계속 넓힌다. 다 같은 _house 라 문·실내·입주가 진짜다
## 지은 것은 블록마다 구역(district)이라 멀면 꺼진다(그리기·물리) — 줌을 빼면 더 멀리까지 켠다(town_systems _stream)

var shops: Array = []          # [{kind "shop", pos, yaw, item, type, id, keeper: {kind "keeper", pos, yaw, shop_id}}]
var _block_nodes := {}         # Vector2i -> Node3D(구역)

func _city_init() -> void:
	var keep := _build_parent
	for key in (CityMap.data()["blocks"] as Dictionary):
		var p := String(key).split(","); var b := Vector2i(int(p[0]), int(p[1]))
		var bl := CityMap.block(b)
		if not CityMap.whole_block(b): continue
		_build_parent = _root_for(CityMap.block_center(b))
		if bl["zone"] == "park": _park_block(CityMap.block_center(b), String(bl.get("name", "Park")))
		else: _civic(CityMap.block_center(b), String(bl.get("building", "")), String(bl.get("name", "")))
	for s in WorldGen.SITES: _dress_road(s)
	for sg in CityMap.data().get("signs", []):
		var at := Vector3(float(sg["at"][0]), 0, float(sg["at"][1]))
		_build_parent = _root_for(at); _signpost(at, String(sg["text"]))
	_build_parent = keep
	for i in doors.size():   # 가게 방은 처음에 다 — 주인이 창구 뒤에 서야 하니까
		if doors[i].has("shop_id"): call("_room", i)
	_hire_shopkeepers()

## 이 자리를 맡는 구역 — 블록마다 하나(멀면 꺼진다)
func _root_for(at: Vector3) -> Node3D:
	var b := CityMap.block_of(Vector2(at.x, at.z))
	if not _block_nodes.has(b):
		var n := Node3D.new(); n.name = "Block_%d_%d" % [b.x, b.y]; add_child(n)
		_block_nodes[b] = n
		districts.append({ "node": n, "center": CityMap.block_center(b), "on": true })
	return _block_nodes[b]

# ── 필지 ──
func _finish_lot(l: Dictionary, live: bool) -> void:
	var kind := CityMap.lot_kind(l)
	var c := Vector3(l["c"].x, 0, l["c"].y)
	if kind == "house":
		var keep_root := _built_root; _built_root = _root_for(c)
		super(l, live)
		_built_root = keep_root
		return
	var k := int(l["order"])
	if _done.has(k): return
	_done[k] = true
	if not live: built = maxi(built, k + 1)
	_pave(l)
	var keep := _build_parent; _build_parent = _root_for(c)
	match kind:
		"shop": _shop_lot(l, c)
		"workshop": _workshop_lot(l, c)
		_: _green_lot(l, c)
	_build_parent = keep
	if live:
		_dust(c + Vector3(0, 0.5, 0))
		say_toast("A new %s opened." % ("shop" if kind == "shop" else ("workshop" if kind == "workshop" else "green")))
		if kind == "shop": _hire_shopkeepers()

## 가게 — 집과 같은 건물(문·실내)에 차양·간판·창구. 창구 뒤 주인 자리에 주민이 서 있어야 판다
func _shop_lot(l: Dictionary, c: Vector3) -> void:
	var sp := TownPlan.house_spec(l); var s: Vector3 = sp["size"]; s.x = maxf(s.x, 4.4)
	var shop := CityMap.shop_of(l)
	_house(c, s, sp["wall"], sp["roof"], true, sp["seed"])
	doors[doors.size() - 1]["shop_id"] = shops.size()   # 이 문으로 들어가면 가게 방(town_interior)
	var hd := s.z / 2.0
	var aw := _box(Vector3(s.x + 0.3, 0.07, 1.1), c + Vector3(0, 2.25, hd + 0.5), _mat(Color(String(shop["awning"]))), false); aw.rotation.x = 0.28
	_box(Vector3(s.x * 0.8, 0.5, 0.06), c + Vector3(0, 2.45, hd + 0.04), _mat(Color("efe9e2")), false)
	var lb := Label3D.new(); lb.text = String(shop["type"]); lb.font_size = 64; lb.pixel_size = 0.005; lb.modulate = Color("1b0c15"); lb.outline_size = 0
	lb.position = c + Vector3(0, 2.7, hd + 0.08); _add(lb)
	var cx := -s.x / 2.0 + 0.8
	_box(Vector3(1.2, 0.95, 0.55), c + Vector3(cx, 0, hd + 1.0), _mat(Color("8a6a4a")))
	for i in 3:
		var it := make_item(String(shop["item"]), c + Vector3(cx - 0.35 + i * 0.35, 0.95, hd + 1.0))
		it.set_meta("display", true); _add_display(it)
	var id := shops.size()
	var sh := { "kind": "shop", "pos": c + Vector3(cx, 0, hd + 1.75), "yaw": PI, "item": String(shop["item"]), "type": String(shop["type"]), "id": id,
		"keeper": { "kind": "keeper", "pos": c + Vector3(0, 0, hd + 1.0), "yaw": 0.0, "shop_id": id } }   # 주인은 문 앞까지 걸어와 안(방의 계산대 뒤, inner)으로 들어간다
	shops.append(sh)   # 사고팔기는 가게 방 안에서(town_interior) — 바깥 창구는 진열대일 뿐

## 진열품 — 집을 수 없게(items 에 안 넣는다) 구역 노드에 그냥 단다
func _add_display(it: Node3D) -> void:
	if it.get_parent(): it.get_parent().remove_child(it)
	_add(it)
	if it in items: items.erase(it)

## 차고(공방가) — 넓고 낮은 평지붕 건물, 간판, 상자·타이어, 둘에 하나는 마당에 차
func _workshop_lot(l: Dictionary, c: Vector3) -> void:
	var sp := TownPlan.house_spec(l)
	_house(c, Vector3(5.4, 2.6, 4.2), Color("cfc7c2"), "iron", true, sp["seed"])
	_box(Vector3(3.0, 0.45, 0.06), c + Vector3(0, 2.3, 2.14), _mat(Color("1b0c15")), false)
	var lb := Label3D.new(); lb.text = ["GARAGE", "TYRES", "PANEL BEATER", "SPARES"][int(l["order"]) % 4]; lb.font_size = 56; lb.pixel_size = 0.005; lb.modulate = Color("f2c84b"); lb.outline_size = 0
	lb.position = c + Vector3(0, 2.53, 2.2); _add(lb)
	for i in 3: _box(Vector3(0.6, 0.6, 0.6), c + Vector3(3.3, i * 0.0 + (0.6 if i == 2 else 0.0), -1.0 + (i % 2) * 0.7), _mat(Color("b48a5a")))
	for i in 4:
		var t := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.18; tm.outer_radius = 0.34; t.mesh = tm; t.material_override = _mat(Color("2a2a30"))
		t.position = c + Vector3(-3.3, 0.1 + i * 0.16, 0.6); _add(t)
	if int(l["order"]) % 2 == 0: _car(["truck", "suv", "hatchback", "sedan"][int(l["order"]) % 4], c + Vector3(0.5, 0, 4.6), PI / 2.0)

## 쌈지공원 — 나무 셋, 벤치 둘, 화단, 그네(진짜로 탄다)
func _green_lot(l: Dictionary, c: Vector3) -> void:
	for p in [Vector3(-4, 0, -3), Vector3(4, 0, -3.5), Vector3(-3.5, 0, 3.5)]: _tree(c + p, 1.1)
	_bench(c + Vector3(-1.2, 0, 2.6)); _bench(c + Vector3(2.2, 0, 2.6))
	_swing(c + Vector3(2.0, 0, -1.0))
	for i in 10: _scatter(["Flower_3_Group", "Flower_4_Group", "Bush_Common_Flowers", "Clover_1", "Grass_Wispy_Tall"][i % 5], c + Vector3(-5.0 + i * 1.1, 0, 5.0), 0.6)

# ── 블록 전체 ──
## 관공서 — 큰 건물(들어간다), 기둥 넷, 앞 광장(자갈)·분수·벤치·가로등·깃대, 이름판
func _civic(c: Vector3, kind: String, name: String) -> void:
	var size: Vector3 = { "town_hall": Vector3(11.0, 3.6, 6.5), "library": Vector3(9.0, 3.2, 6.0), "school": Vector3(12.0, 3.0, 6.0) }.get(kind, Vector3(9, 3, 6))
	var wall: Color = { "town_hall": Color("efe9e2"), "library": Color("b56a5a"), "school": Color("e6d3a5") }.get(kind, Color("dfe6ea"))
	var at := c + Vector3(0, 0, -5.0)
	_house(at, size, wall, "brick", kind != "school", 900 + absi(int(c.x * 3.0 + c.z)))
	doors[doors.size() - 1]["civic"] = kind
	var front := at + Vector3(0, 0, size.z / 2.0)
	for x in [-3.0, -1.0, 1.0, 3.0]:
		if kind == "town_hall": _box(Vector3(0.36, size.y, 0.36), front + Vector3(x * size.x / 9.0, 0, 0.9), _mat(Color("f7f4ef")))
	_box(Vector3(size.x * 0.7, 0.6, 0.08), front + Vector3(0, size.y + 0.1, 0.05), _mat(Color("1b0c15")), false)
	var lb := Label3D.new(); lb.text = name.to_upper(); lb.font_size = 72; lb.pixel_size = 0.005; lb.modulate = Color("f7f4ef"); lb.outline_size = 0
	lb.position = front + Vector3(0, size.y + 0.4, 0.1); _add(lb)
	_path(front + Vector3(0, 0, 0.6), front + Vector3(0, 0, 14.0), 8.0)   # 광장
	water.disc(front + Vector3(0, 0, 8.0), 1.6)
	for s in [-1.0, 1.0]:
		_bench(front + Vector3(s * 5.6, 0, 6.5)); _lamp(front + Vector3(s * 4.6, 0, 11.0))
		_tree(front + Vector3(s * 9.5, 0, 4.0), 1.2); _tree(front + Vector3(s * 9.5, 0, 11.0), 1.1)
	var pole := _box(Vector3(0.08, 5.0, 0.08), front + Vector3(size.x / 2.0 + 1.5, 0, 1.5), _mat(Color("4a4a52")), false)
	_box(Vector3(1.0, 0.6, 0.03), front + Vector3(size.x / 2.0 + 2.05, 4.3, 1.5), _mat(Color("ad7096")), false)
	spots.append({ "pos": front + Vector3(-2.0, 0, 3.0), "kind": "lookout", "yaw": PI })   # 건물을 올려다본다
	match kind:
		"school":
			_swing(at + Vector3(-9.0, 0, 6.0)); _swing(at + Vector3(-6.5, 0, 6.0))
			_fence(at + Vector3(-11.0, 0, 9.0), 6.0)
		"library":
			var q := Label3D.new(); q.text = "Quiet, please."; q.font_size = 40; q.pixel_size = 0.004; q.modulate = Color("1b0c15"); q.position = front + Vector3(2.2, 1.6, 0.06); _add(q)

## 공원 블록 — 연못, 둘레 나무, 십자 산책로, 벤치 넷, 가로등, 그네, 꽃
func _park_block(c: Vector3, name: String) -> void:
	_path(c + Vector3(-17, 0, 0), c + Vector3(17, 0, 0), 2.2); _path(c + Vector3(0, 0, -17), c + Vector3(0, 0, 17), 2.2)
	water.disc(c + Vector3(-8.0, 0, -8.0), 4.5)
	for i in 14:
		var a := i * TAU / 14.0
		_tree(c + Vector3(cos(a) * 15.5, 0, sin(a) * 15.5), 1.0 + fmod(i * 0.37, 0.5))
	for p in [Vector3(3.5, 0, 2.2), Vector3(-3.5, 0, 2.2), Vector3(2.2, 0, -6.0), Vector3(8.0, 0, 2.2)]: _bench(c + p)
	_lamp(c + Vector3(2.0, 0, 1.8)); _lamp(c + Vector3(-2.0, 0, -1.8))
	_swing(c + Vector3(8.0, 0, -8.0))
	for i in 24:
		var a := i * 2.399; var d := 4.0 + fmod(i * 1.7, 9.0)
		_scatter(["Flower_3_Group", "Flower_4_Group", "Bush_Common_Flowers", "Clover_1"][i % 4], c + Vector3(cos(a) * d + 8.0, 0, sin(a) * d + 8.0), 0.6)
	_signpost(c + Vector3(-2.5, 0, 16.0), name.to_upper())

# ── 거리 ──
## 골목이 깔리면(_pave, 처음 공사 시작 때) 그 토막에 가로등 하나·가로수 둘 — 집 앞 문길(필지 가운데)은 비운다
func _pave(l: Dictionary) -> void:
	var b: Vector2i = l["b"]
	var fresh := not _paved.has("%d,%d,%d" % [b.x, b.y, int(l["row"])])
	super(l)
	if not fresh: return
	var z: float = l["street_z"]; var x0 := TownPlan.OX + b.x * TownPlan.PITCH + TownPlan.PATH_W / 2.0
	var s := -1.0 if int(l["row"]) == 1 else 1.0
	var vz := z + s * (TownPlan.PATH_W / 2.0 + 0.9)
	var keep := _build_parent; _build_parent = _root_for(Vector3(x0 + 20.0, 0, vz))
	_lamp(Vector3(x0 + 12.3, 0, vz))
	_tree(Vector3(x0 + 24.5, 0, vz + s * 0.6), 1.0); _tree(Vector3(x0 + 2.0, 0, vz + s * 0.6), 0.95)
	_build_parent = keep

## 장소로 가는 길 — 16m 마다 가로등(번갈아 양쪽), 그 사이 나무
func _dress_road(s: Dictionary) -> void:
	var a: Vector3 = s["from"]; var c: Vector3 = s["c"]
	var d := Vector3(c.x - a.x, 0, c.z - a.z); var len := d.length() - 8.0
	var dir := d.normalized(); var side := Vector3(-dir.z, 0, dir.x)
	var off := 2.6 if s["name"] == "tower" else 2.0
	var t := 6.0; var i := 0
	while t < len:
		var p := a + dir * t
		var keep := _build_parent; _build_parent = _root_for(p)
		if absf(p.x) > WorldGen.HUB_X - 2.0 or absf(p.z) > WorldGen.HUB_Z - 2.0:   # 허브 안은 이미 마을이다
			_lamp(p + side * off * (1.0 if i % 2 == 0 else -1.0))
			_tree(p + dir * 8.0 + side * (off + 1.4) * (-1.0 if i % 2 == 0 else 1.0), 1.0)
		_build_parent = keep
		t += 16.0; i += 1

## 이정표 — 기둥과 판, 양면 글씨
func _signpost(at: Vector3, text: String) -> void:
	_box(Vector3(0.1, 2.0, 0.1), at, _mat(Color("6b4a35")), false)
	_box(Vector3(1.6, 0.55, 0.05), at + Vector3(0, 1.5, 0), _mat(Color("efe9e2")), false)
	for f in [1.0, -1.0]:
		var lb := Label3D.new(); lb.text = text; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("1b0c15"); lb.outline_size = 0
		lb.position = at + Vector3(0, 1.78, 0.03 * f); lb.rotation.y = 0.0 if f > 0.0 else PI; _add(lb)

# ── 가게 주인 ──
## 주인 없는 가게마다 일 없는 어른 하나(가게에서 가장 가까운) — job "shopkeep"(resident_shop.gd)
func _hire_shopkeepers() -> void:
	for sh in shops:
		if residents.any(func(r: Resident) -> bool: return r.job == "shopkeep" and int(r.get_meta("shop_id", -1)) == int(sh["id"])): continue
		var best: Resident = null; var bd := 1e9
		for r in residents:
			if r.job != "" or r is ResidentKid or r.state == "drive": continue
			var d: float = r.global_position.distance_to(sh["pos"])
			if d < bd: bd = d; best = r
		if best == null: return
		best.job = "shopkeep"; best.set_meta("shop_id", int(sh["id"]))

## 열었나 — 주인이 창구 뒤 자리에 서 있다
func shop_open(sh: Dictionary) -> bool:
	for r in residents:
		if r.job == "shopkeep" and int(r.get_meta("shop_id", -1)) == int(sh["id"]) and r.state == "busy" and String(r.spot.get("kind", "")) == "keeper": return true
	return false

func _keeper(sh: Dictionary) -> Resident:
	for r in residents:
		if r.job == "shopkeep" and int(r.get_meta("shop_id", -1)) == int(sh["id"]): return r
	return null

## C 로 사기 — 열었고 동전이 있으면 값(data/prices.json buy)을 내고 하나 받는다. 값은 주인 주머니로 간다(돈이 돈다)
func shop_use(sh: Dictionary, now: float) -> void:
	player.face(float(sh["yaw"]))
	if not shop_open(sh):
		say_toast("%s — closed. Nobody at the counter." % String(sh["type"]).capitalize() if not is_night() else "%s — closed for the night." % String(sh["type"]).capitalize())
		return
	var p := price_of(sh)
	if coins < p:
		say_toast("That's %d coins. Sell something here, or win in a game." % p); return
	_set_coins(coins - p)
	var k := _keeper(sh)
	if k: k.coins += p; k.say(["Thank you.", "There you are.", "Anything else?", "Mind how you go."][randi() % 4], 1.6)
	var it := make_item(String(sh["item"]), body.global_position + Vector3(0, 0.9, 0))
	player.hold(it); player.action = "grab"; action_until = now + 0.4
	say_toast("%s · -%d" % [String(sh["item"]).capitalize(), p])
