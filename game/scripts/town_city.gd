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
		var bc := CityMap.block_center(b)
		if bl["zone"] == "park": _park_block(bc, String(bl.get("name", "Park")))
		else: _civic(bc, String(bl.get("building", "")), String(bl.get("name", "")))
		var cells: Array = [[Vector3(-8, 0, 8), 0], [Vector3(8, 0, 8), 9]] if bl["zone"] == "park" else [[Vector3(-12.5, 0, -7), 27], [Vector3(12.5, 0, -7), 9], [Vector3(-12.5, 0, 7), 0], [Vector3(12.5, 0, 7), 18]]
		for cl in cells:   # 관공서 양옆·공원 남쪽의 빈 잔디 — 쌈지 마당 한 칸씩(운영자 2026-10-13: "녹지가 너무 많네")
			var at: Vector3 = bc + (cl[0] as Vector3)
			if not (_dry(at) and _dry(at + Vector3(3, 0, 4)) and _dry(at - Vector3(3, 0, 4))): continue
			var mark := _merge_mark()
			PocketLots.build(self, { "id": "civic/%d,%d,%d" % [b.x, b.y, int(cl[1])], "street_z": at.z + 10.0, "order": int(cl[1]) + absi(b.x * 7 + b.y) * 36 }, at)
			_merge_done(mark)
		if bl["zone"] != "park":   # 관공서 — 건물 뒤 나무·생울타리 줄, 광장 양옆 꽃 띠와 벤치
			var mark2 := _merge_mark()
			var rng := RandomNumberGenerator.new(); rng.seed = hash("civic/%d,%d" % [b.x, b.y])
			for k in 6: _tree(bc + Vector3(-7.5 + k * 3.0, 0, -13.5), 0.9 + 0.1 * (k % 2))
			KitProps.border(self, bc + Vector3(-8.0, 0, -11.8), bc + Vector3(8.0, 0, -11.8), rng, 0.7)
			for sx in [-1.0, 1.0]:
				KitProps.border(self, bc + Vector3(sx * 5.6, 0, -0.5), bc + Vector3(sx * 5.6, 0, 13.5), rng, 0.6)
				KitProps.f(self, "benchCushion", bc + Vector3(sx * 7.0, 0, 5.0), -sx * PI / 2.0)
			_merge_done(mark2)
	_hub_road()
	for s in WorldGen.SITES: _dress_road(s)
	_dress_loop()
	_green_belt()
	for sg in CityMap.data().get("signs", []):
		var at := Vector3(float(sg["at"][0]), 0, float(sg["at"][1]))
		_build_parent = _root_for(at); _signpost(at, String(sg["text"]))
	_build_parent = keep
	for i in doors.size():   # 가게 방은 처음에 다 — 주인이 창구 뒤에 서야 하니까
		if doors[i].has("shop_id"): call("_room", i)
	_hire_shopkeepers()
	_grow_streets(body.global_position, 150.0, 99, false)   # 둘레 계획 블록도 찻길·임시 마당으로(운영자 2026-10-13: "녹지 다 채우라니까")
	gen.rebuild_all(body.global_position)   # 깔린 찻길·새 평지에 맞춰 칸을 다시(찻길 위 나무를 걷는다)

## 마당(운영자 2026-10-08 사진: "섹션마다 풍부한데 우린 뭐가 없잖아") — 집마다 다르게: 울타리(흰 말뚝·생울타리·돌담·없음), 마당 나무, 빨랫줄.
## 뒤 울타리는 띠 끝(골목 앞)까지 — 그 안은 그 집 사람 뒤뜰(back_yards). 길 쪽 가운데(문길)는 비운다. 울타리는 모양만(충돌 없음 — 주민 길을 막지 않게)
func _house_yard(l: Dictionary, c: Vector3, hs: Vector3) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash("yard/" + String(l["id"]))
	var lw: float = float(l.get("w", TownPlan.LOT + 0.55)) - 0.55
	var half := lw / 2.0 + 0.1
	var terrace := String(l.get("form", "")) == "terrace"
	var front := float(l["street_z"]) - TownPlan.ROAD_W / 2.0 - 0.15   # 인도 끝
	var back := back_line(l)
	var kind: int = rng.randi() % 4
	var col: Color = [Color("f7f4ef"), Color("5f8a3e"), Color("a8a29a"), Color.WHITE][kind]
	var hgt: float = [0.55, 0.8, 0.5, 0.0][kind]
	if terrace: kind = 1; col = Color("5f8a3e"); hgt = 0.6   # 붙은 집 줄은 앞뒤 생울타리만(옆은 이웃 벽)
	if hgt > 0.0:
		var thick := 0.06 if kind == 0 else 0.35
		for side in [-1.0, 1.0]:
			_box(Vector3(half - 0.9, hgt, thick), Vector3(c.x + side * (half + 0.9) / 2.0, 0, front), _mat(col), false)   # 앞(문길 빼고)
			if not terrace: _box(Vector3(thick, hgt, front - back), Vector3(c.x + side * half, 0, (front + back) / 2.0), _mat(col), false)   # 옆
		_box(Vector3(half * 2.0, hgt, thick), Vector3(c.x, 0, back), _mat(col), false)   # 뒤
	_tree(Vector3(c.x + (half - 0.8) * (1.0 if rng.randf() < 0.5 else -1.0), 0, back + 0.9), rng.randf_range(0.8, 1.0))   # 뒤 모서리 나무
	if rng.randf() < 0.45:   # 빨랫줄
		var lx := c.x + (hs.x / 2.0 + 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
		for e in [-1.2, 1.2]: _box(Vector3(0.05, 1.6, 0.05), Vector3(lx, 0, c.z + e), _mat(Color("8a6a4a")), false)
		_box(Vector3(0.02, 0.02, 2.4), Vector3(lx, 1.55, c.z), _mat(Color("efe9e2")), false)
		for q in 3: _box(Vector3(0.03, 0.4, 0.35), Vector3(lx, 1.15, c.z - 0.6 + q * 0.55), _mat([Color("ad7096"), Color("7a90b0"), Color("f2c84b"), Color("f7f4ef")][(q + rng.randi()) % 4]), false)
	if not doors.is_empty():   # 현관 — 문 양옆 화분, 발판, 문간 옆 우편함과 쓰레기통
		var dp: Vector3 = doors[doors.size() - 1]["pos"]
		if absf(dp.x - c.x) < 4.0 and absf(dp.z - (c.z + hs.z / 2.0)) < 1.5:
			for sx in [-0.85, 0.85]: KitProps.f(self, "pottedPlant", Vector3(dp.x + sx, 0, dp.z + 0.35), 0.0, false)
			KitProps.f(self, "rugDoormat", Vector3(dp.x, 0.01, dp.z + 0.45), 0.0, false)
		var gx := c.x + 1.3
		_box(Vector3(0.08, 1.0, 0.08), Vector3(gx, 0, front - 0.25), _mat(Color("4a4a52")), false)
		_box(Vector3(0.3, 0.25, 0.45), Vector3(gx, 1.0, front - 0.25), _mat([Color("b56a5a"), Color("4a6a8a"), Color("3f6b2f"), Color("1b0c15")][rng.randi() % 4]))
		KitProps.f(self, "trashcan", Vector3(c.x - 1.5, 0, front - 0.4), 0.0)
	var who: String = String(owner_row(int(l["order"])).get("handle", "")) if not _is_mine(int(l["order"])) else ""
	BackYards.build(self, c, back + 0.4, c.z - hs.z / 2.0 - 0.3, lw, who, hash("back/" + String(l["id"])))

## 뒤뜰 끝 — 집 뒤 찻길의 인도 앞(앞줄은 블록 북쪽 찻길, 뒷줄은 가운데 찻길)
static func back_line(l: Dictionary) -> float:
	return float(l["street_z"]) - TownPlan.PITCH / 2.0 + TownPlan.ROAD_W / 2.0 + 0.3   # 뒤 찻길(20m 북쪽)의 인도 끝

## 합치기(mesh_merge) — 지은 것의 움직이지 않는 메시를 재질 생김새끼리 한 덩이로. 문짝은 빼고
func _merge_mark() -> Array:
	return [_build_parent, _build_parent.get_child_count(), doors.size(), houses.size()]

func _merge_done(mark: Array) -> void:
	var par: Node3D = mark[0]
	var nodes: Array = []
	for i in range(int(mark[1]), par.get_child_count()): nodes.append(par.get_child(i))
	var ex: Array = []
	for k in range(int(mark[2]), doors.size()): ex.append(doors[k]["hinge"])
	MeshMerge.merge(par, nodes, ex)
	for k in range(int(mark[3]), houses.size()): houses[k]["merged"] = true

## 부술 수 있는 소품의 8m 칸 색인 — 차(car3d _smash_props)가 둘레 아홉 칸만 본다. 소품 수가 바뀌면 다시 짓는다(부서지고 다시 서는 것 포함)
var _wk_grid := {}
var _wk_count := -1
func wreck_near(p: Vector3) -> Array:
	if wreckables.size() != _wk_count:
		_wk_count = wreckables.size(); _wk_grid.clear()
		for w in wreckables:
			var k := Vector2i(floori((w["at"] as Vector3).x / 8.0), floori((w["at"] as Vector3).z / 8.0))
			if not _wk_grid.has(k): _wk_grid[k] = []
			_wk_grid[k].append(w)
	var out: Array = []
	var c := Vector2i(floori(p.x / 8.0), floori(p.z / 8.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]: out.append_array(_wk_grid.get(c + Vector2i(dx, dz), []))
	return out

## 위층(town_plots)이 정한다 — 사람이 고른 모양, 내 집인가
func _style_for(_l: Dictionary) -> String: return ""
func _is_mine(_k: int) -> bool: return false

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
	if _temp_lots.has(int(l["order"])):   # 텃밭이던 자리 — 걷고 짓는다
		if is_instance_valid(_temp_lots[int(l["order"])]): (_temp_lots[int(l["order"])] as Node3D).queue_free()
		_temp_lots.erase(int(l["order"]))
	var kind := CityMap.lot_kind(l)
	var c := TownPlan.spot_of(l)
	if kind == "house":   # 집 — 모양은 house_styles(오두막·타운하우스·방갈로·차고·날개채·탑·옥상 정원), 문·실내·입주는 같은 길
		var hk := int(l["order"])
		if _done.has(hk): return
		_done[hk] = true
		if not live: built = maxi(built, hk + 1)
		_pave(l)
		c += Vector3(0, 0, { "apartment": -1.3, "villa": -0.6 }.get(String(l.get("form", "")), 0.0))   # 깊은 집은 뒤로 — 앞마당을 남긴다
		var hsp := TownPlan.house_spec(l); var nd := doors.size()
		var hkeep := _build_parent; _build_parent = _root_for(c)
		var mark := _merge_mark()
		var hs := HouseStyles.build(self, c, l, hsp, _style_for(l))
		_flower_bed(c + Vector3(-hs.x / 2.0 - 0.6, 0, hs.z / 2.0 + 0.4))
		_house_yard(l, c, hs)
		_merge_done(mark)
		_build_parent = hkeep
		if doors.size() > nd and not _is_mine(hk): _move_in(doors[nd], live, owner_row(hk))   # 내가 산 필지면 주민이 들어오지 않는다(내 집)
		_footpath(l, c)
		if live: _dust(c + Vector3(0, 0.5, 0)); say_toast("A new house is finished.")
		return
	var k := int(l["order"])
	if _done.has(k): return
	_done[k] = true
	if not live: built = maxi(built, k + 1)
	_pave(l)
	var keep := _build_parent; _build_parent = _root_for(c)
	var mark := _merge_mark()
	match kind:
		"parking": _parking_lot(l, c)
		"plaza": _plaza_lot(l, c)
		"shop": _shop_lot(l, c)
		"workshop": _workshop_lot(l, c)
		_: _green_lot(l, c)
	_merge_done(mark)
	_build_parent = keep
	_footpath(l, c)
	if live:
		_dust(c + Vector3(0, 0.5, 0))
		say_toast("A new %s opened." % ("shop" if kind == "shop" else ("workshop" if kind == "workshop" else "green")))
		if kind == "shop": _hire_shopkeepers()

## 가게 — 집과 같은 건물(문·실내)에 차양·간판·창구. 창구 뒤 주인 자리에 주민이 서 있어야 판다
func _shop_lot(l: Dictionary, c: Vector3) -> void:
	var sp := TownPlan.house_spec(l)
	var shop := CityMap.shop_of(l)
	var wide := String(l.get("form", "")) == "wide"
	if wide: sp["size"] = Vector3(8.4, 3.0, 5.2)   # 큰 가게(블록 모양 wide) — 넓은 가게 셋이 한 줄
	var s := HouseStyles.build(self, c, l, sp, "cottage" if wide else ["townhouse", "terrace", "cottage", "bungalow", "townhouse", "turret"][int(l["order"]) % 6])   # 가게도 모양이 저마다
	doors[doors.size() - 1]["shop_id"] = shops.size()   # 이 문으로 들어가면 가게 방(town_interior)
	var hd := s.z / 2.0
	var aw := _box(Vector3(s.x + 0.3, 0.07, 1.1), c + Vector3(0, 2.25, hd + 0.5), _mat(Color(String(shop["awning"]))), false); aw.rotation.x = 0.28
	_box(Vector3(s.x * 0.8, 0.5, 0.06), c + Vector3(0, 2.45, hd + 0.04), _mat(Color("efe9e2")), false)
	var lb := Label3D.new(); lb.text = String(shop["type"]); lb.font_size = 64; lb.pixel_size = 0.005; lb.modulate = Color("1b0c15"); lb.outline_size = 0
	lb.position = c + Vector3(0, 2.7, hd + 0.08); _add(lb)
	var cx := -s.x / 2.0 + 0.8
	HouseStyles.shop_front(self, c, s, String(shop["type"]), String(shop["item"]))   # 가게 앞 — 카페 테라스·빵 바구니·과일 상자·책 수레…
	BackYards.service(self, c, back_line(l), c.z - s.z / 2.0 - 0.3, int(l["order"]))   # 가게 뒤 짐 마당
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
	var rd := "res://assets/models/kenney/roads/"   # 공방 마당 — 큰 쓰레기통, 고깔, 공사 울타리, 상자 더미(Kenney, 부딪힌다)
	KitProps.put(self, rd + "dumpster.glb", c + Vector3(-2.6, 0, -3.6), 0.0, 4.5)
	for i in 3: KitProps.put(self, rd + "construction-cone.glb", c + Vector3(2.0 + i * 0.6, 0, 2.6), 0.0, 4.5, false)
	KitProps.put(self, rd + "construction-barrier.glb", c + Vector3(2.6, 0, -3.4), 0.0, 4.5)
	BackYards.service(self, c, back_line(l), c.z - 2.4, int(l["order"]) * 3)

## 주차장(블록 모양 apartment — 연립 옆) — 아스팔트, 흰 칸선, 세운 차 셋(탈 수 있다), 가로등, 둘레 생울타리
func _parking_lot(l: Dictionary, c: Vector3) -> void:
	var front := float(l["street_z"]) - TownPlan.ROAD_W / 2.0
	var back := back_line(l)
	var w: float = float(l.get("w", 15.5)) - 1.0
	var d := front - back - 0.6
	var mid := Vector3(c.x, 0, (front + back) / 2.0)
	_box(Vector3(w, 0.04, d), mid, _mat(Color("5d5d66")), false)
	var n := int(w / 2.8)
	for k in n + 1:
		_box(Vector3(0.1, 0.05, 4.6), Vector3(c.x - w / 2.0 + 0.4 + k * (w - 0.8) / n, 0, back + 3.0), _mat(Color("efe9e2")), false)
	var rng := RandomNumberGenerator.new(); rng.seed = hash("park/" + String(l["id"]))
	for k in n:
		if rng.randf() < 0.55: _car(["sedan", "hatchback", "suv", "sedan", "van"][rng.randi() % 5], Vector3(c.x - w / 2.0 + 0.4 + (k + 0.5) * (w - 0.8) / n, 0, back + 3.0), 0.0)
	_lamp(Vector3(c.x + w / 2.0 - 0.6, 0, front - 1.0))
	KitProps.border(self, Vector3(c.x - w / 2.0, 0, back + 0.2), Vector3(c.x + w / 2.0, 0, back + 0.2), rng, 0.8)

## 광장(블록 모양 square — 번화가) — 돌바닥, 분수, 노점 둘, 벤치, 나무 넷, 가로등
func _plaza_lot(l: Dictionary, c: Vector3) -> void:
	var front := float(l["street_z"]) - TownPlan.ROAD_W / 2.0
	var back := back_line(l)
	var w: float = float(l.get("w", 15.5)) - 0.8
	var mid := Vector3(c.x, 0, (front + back) / 2.0)
	_box(Vector3(w, 0.03, front - back - 0.4), mid, _mat(Color("d8cfc2")), false)
	water.disc(mid, 1.8)
	KitProps.n(self, "statue_obelisk", mid, 0.0, 1.4)
	var rng := RandomNumberGenerator.new(); rng.seed = hash("plaza/" + String(l["id"]))
	for s in [-1.0, 1.0]:
		_stall(mid + Vector3(s * 4.6, 0, -3.0), [Color("ad7096"), Color("d98a2a"), Color("5f8a3e"), Color("7a90b0")][rng.randi() % 4])
		_bench(mid + Vector3(s * 3.4, 0, 2.6))
		_tree(mid + Vector3(s * (w / 2.0 - 0.8), 0, -5.0), 1.0); _tree(mid + Vector3(s * (w / 2.0 - 0.8), 0, 4.0), 0.95)
		_lamp(mid + Vector3(s * 2.0, 0, 4.4))

## 쌈지 마당 — 장터·화원·놀이·정원 중 하나(pocket_lots)
func _green_lot(l: Dictionary, c: Vector3) -> void:
	PocketLots.build(self, l, c)

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
	if _dry(c + Vector3(-8.0, 0, -8.0)): water.disc(c + Vector3(-8.0, 0, -8.0), 4.5)   # 공원이 호수를 끼면(world_gen 이 공원 안 호수는 안 깎는다) 물 위엔 아무것도 놓지 않는다
	for i in 14:
		var a := i * TAU / 14.0
		if _dry(c + Vector3(cos(a) * 15.5, 0, sin(a) * 15.5)): _tree(c + Vector3(cos(a) * 15.5, 0, sin(a) * 15.5), 1.0 + fmod(i * 0.37, 0.5))
	for p in [Vector3(3.5, 0, 2.2), Vector3(-3.5, 0, 2.2), Vector3(2.2, 0, -6.0), Vector3(8.0, 0, 2.2)]:
		if _dry(c + p): _bench(c + p)
	for p in [Vector3(2.0, 0, 1.8), Vector3(-2.0, 0, -1.8)]:
		if _dry(c + p): _lamp(c + p)
	if _dry(c + Vector3(8.0, 0, -8.0)): _swing(c + Vector3(8.0, 0, -8.0))
	for i in 24:
		var a := i * 2.399; var d := 4.0 + fmod(i * 1.7, 9.0)
		var fp := c + Vector3(cos(a) * d + 8.0, 0, sin(a) * d + 8.0)
		if _dry(fp): _scatter(["Flower_3_Group", "Flower_4_Group", "Bush_Common_Flowers", "Clover_1"][i % 4], fp, 0.6)
	_signpost(c + Vector3(-2.5, 0, 16.0), name.to_upper())

# ── 거리 ──
## 찻길(road_tiles) — 블록에 첫 필지가 서면 그 블록을 두르는 찻길을 다 깐다(동서 셋·남북 넷). 토막은 합치고(그리기 한 번), 노드 판은 이어진 팔에 맞춰 다시 고른다.
## 인도엔 가로등(Kenney 꺾인 등, 팔이 찻길 쪽)·가로수. 옛 마을 안의 큰길은 옛 판 그대로
var _segs := {}          # 토막 열쇠 -> true
var _node_tiles := {}    # Vector2i -> Node3D
var _node_props := {}    # Vector2i -> Node3D(신호등·표지)
func _pave(l: Dictionary) -> void:
	var b: Vector2i = l["b"]
	if _paved.has(b): return
	_paved[b] = true
	call_deferred("_fill_block", b)   # 이 블록의 필지 표시(_done·공사장)가 다 선 뒤에
	var keep := _build_parent
	for sg in RoadTiles.block_segs(b):
		var na: Vector2i = sg[0]; var nb: Vector2i = sg[1]
		var key := RoadTiles.seg_key(na, nb)
		if _segs.has(key) or RoadTiles.in_hub(RoadTiles.npos(na)) or RoadTiles.in_hub(RoadTiles.npos(nb)): continue
		_segs[key] = true
		var mid := (RoadTiles.npos(na) + RoadTiles.npos(nb)) / 2.0
		var par := _root_for(mid)
		MeshMerge.merge(par, RoadTiles.seg(self, na, nb, par), [])
		_build_parent = par
		var mark := _merge_mark(); _kerb(na, nb); _merge_done(mark)   # 가로수는 합친다(가로등은 nomerge — 넘어가야 하니까)
		_build_parent = keep
		for nd in [na, nb]: _retile(nd)
	_build_parent = keep

## 아직 안 지은 계획 블록도 미리 찻길을 깔고 자리마다 임시 마당을 채운다(운영자 2026-10-13: "녹지 다 채우라니까", 동물의 숲 사진처럼 빽빽하게) —
## 블록을 평지로(TownPlan.extra_flat) 깎고, 집이 설 자리엔 텃밭·장터·공방·정원… 이 놓였다가 공사가 시작되면 걷힌다. 걸어가면 둘레 150m 가 1초에 한 블록씩 채워진다
var _far_due := false
func _grow_streets(p: Vector3, radius: float, max_n: int, live := true) -> int:
	var c := CityMap.block_of(Vector2(p.x, p.z))
	var r := int(radius / TownPlan.PITCH) + 1
	var cand: Array = []
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var b := c + Vector2i(dx, dz)
			if _paved.has(b) or CityMap.whole_block(b) or gen._lots_near(b).is_empty(): continue
			var d := Vector2(p.x, p.z).distance_to(Vector2(CityMap.block_center(b).x, CityMap.block_center(b).z))
			if d < radius: cand.append([d, b])
	cand.sort_custom(func(a, b2): return float(a[0]) < float(b2[0]))
	var n := 0
	for e in cand.slice(0, max_n):
		var b: Vector2i = e[1]
		TownPlan.extra_flat[b] = true
		if live: gen.reflat(Vector2(CityMap.block_center(b).x, CityMap.block_center(b).z), false); _far_due = true
		_pave({ "b": b })
		n += 1
	return n

func _streets_tick() -> void:
	if _grow_streets(body.global_position, 150.0, 1) == 0 and _far_due:
		_far_due = false; gen._refresh_far()

## 빈 자리 채우기(운영자 2026-10-13: "녹지가 너무 많네") — 찻길이 깔린 블록의 여덟 자리 중 필지가 아닌 자리(강·장소 둘레에 걸려 계획에서 빠진)는 늘 있는 쌈지 마당으로,
## 아직 안 지은 필지는 지을 때까지 동네 텃밭으로(공사가 시작되면 걷는다 — _draw_site)
var _temp_lots := {}   # 필지 순번 -> Node3D(텃밭)
func _fill_block(b: Vector2i) -> void:
	var zn := TownPlan.OZ + b.y * TownPlan.PITCH
	if zn < RIVER_Z and zn + TownPlan.PITCH > RIVER_Z: _riverbank(b)
	if TownPlan.no_lane(b) and not CityMap.whole_block(b):
		var keep0 := _build_parent; _build_parent = _root_for(CityMap.block_center(b))
		var mark0 := _merge_mark(); Courtyard.build(self, b); _merge_done(mark0)
		_build_parent = keep0
	for sl in TownPlan.block_slots(b.x, b.y):
		var c2: Vector2 = sl["c"]
		var c := Vector3(c2.x, 0, c2.y)
		var l := TownPlan.lot_by_id(String(sl["id"]))
		var keep := _build_parent
		if l.is_empty():
			if not _filler_ok(c2): continue
			_build_parent = _root_for(c)
			var mark := _merge_mark()
			var fill: Dictionary = sl.duplicate(); fill["id"] = "slot/" + String(sl["id"]); fill["order"] = absi(hash(String(sl["id"]))) % 36 * 9
			PocketLots.build(self, fill, c)
			_merge_done(mark)
		elif not _done.has(int(l["order"])) and not _site_nodes.has(int(l["order"])):
			var holder := Node3D.new(); _root_for(c).add_child(holder); _build_parent = holder
			var hv := absi(hash("temp/" + String(l["id"])))
			if hv % 10 < 1: Allotment.build(self, l, c)   # 텃밭 하나, 나머지는 쌈지 마당 여덟 가지 중 하나(넓은 자리는 둘)
			else:
				var lw: float = float(l.get("w", 7.75))
				var parts := 2 if lw > 12.0 else 1
				for q in parts:
					var pc := c + Vector3((q - (parts - 1) / 2.0) * lw / parts, 0, 0)
					PocketLots.build(self, { "id": "temp/%s/%d" % [String(l["id"]), q], "street_z": float(l["street_z"]), "order": ((absi(hash("v/%d,%d" % [b.x, b.y])) + int(String(l["id"]).get_slice(",", 2)) * 3 + q * 5) % 8) * 9 }, pc)   # 블록 안 자리마다 다른 마당(같은 놀이터가 넷 줄지어 섰다)
			MeshMerge.merge(holder, holder.get_children(), [])
			_temp_lots[int(l["order"])] = holder
		_build_parent = keep

## 강둑(운영자 2026-10-13: "지형 지물 디테일 다 연결", "녹지가 너무 많네") — 마을 블록이 강을 끼면 그 폭만큼 강둑을 꾸민다.
## 북쪽 둑(큰길 인도와 강 사이 3m): 가로수·강을 보는 벤치·가로등. 남쪽 둑(강과 다음 찻길 사이): 갈대·바위·꽃, 낚시 자리(낚아 판다), 가끔 작은 나무 부두, 피크닉 탁자
func _riverbank(b: Vector2i) -> void:
	var x0 := TownPlan.OX + b.x * TownPlan.PITCH + TownPlan.ROAD_W / 2.0; var x1 := x0 + TownPlan.PITCH - TownPlan.ROAD_W
	if absf((x0 + x1) / 2.0) < WorldGen.HUB_X + 6.0: return   # 옛 마을 강가는 이미 꾸며져 있다
	var rng := RandomNumberGenerator.new(); rng.seed = hash("bank/%d,%d" % [b.x, b.y])
	var keep := _build_parent; _build_parent = _root_for(Vector3((x0 + x1) / 2.0, 0, RIVER_Z))
	var mark := _merge_mark()
	var nz := RIVER_Z - RIVER_HW - 1.4; var sz := RIVER_Z + RIVER_HW + 0.8
	for k in 4:
		var x := lerpf(x0 + 3.0, x1 - 3.0, k / 3.0)
		_tree(Vector3(x, 0, nz - 0.6), 0.9)
		if k < 3: _bench(Vector3(x + 4.0, 0, nz - 0.3))
	_lamp(Vector3((x0 + x1) / 2.0, 0, nz - 0.9))
	var reeds := ["grass_leafsLarge", "grass_large", "plant_flatTall", "grass_leafs"]
	for k in 22:
		var x := rng.randf_range(x0, x1); var z := sz + rng.randf_range(0.0, 3.0)
		if rng.randf() < 0.75: KitProps.n(self, reeds[rng.randi() % reeds.size()], Vector3(x, 0, z), rng.randf() * TAU, rng.randf_range(2.0, 2.8), false)
		else: KitProps.n(self, KitProps.FLOWERS[rng.randi() % KitProps.FLOWERS.size()], Vector3(x, 0, z + 1.0), 0.0, 1.8, false)
	for k in 3: KitProps.n(self, ["rock_largeA", "rock_largeC", "stone_largeB"][k], Vector3(rng.randf_range(x0, x1), 0, sz + rng.randf_range(0.2, 1.0)), rng.randf() * TAU, 1.3)
	for k in 2:
		var fx := lerpf(x0 + 6.0, x1 - 6.0, k)
		spots.append({ "pos": Vector3(fx, 0.02, sz - 0.2), "kind": "bank", "yaw": PI, "fish": true })
	if rng.randf() < 0.5:   # 작은 나무 부두 — 둑에서 물 위로
		var jx := rng.randf_range(x0 + 4.0, x1 - 4.0)
		_box(Vector3(1.4, 0.1, 2.4), Vector3(jx, 0.0, RIVER_Z + RIVER_HW - 0.6), _mat(Color("8a6a4a")))
		for px in [-0.6, 0.6]: _box(Vector3(0.12, 0.5, 0.12), Vector3(jx + px, -0.3, RIVER_Z + 0.2), _mat(Color("6b4a35")), false)
		spots.append({ "pos": Vector3(jx, 0.1, RIVER_Z + 0.3), "kind": "bank", "yaw": PI, "fish": true })
		var boat := KitProps.mesh_node("res://assets/models/kenney/watercraft/boat-row-small.glb"); boat.position = Vector3(jx + 1.8, Water3D.SURFACE_Y - 0.12, RIVER_Z); boat.rotation.y = PI / 2.0; boat.scale = Vector3.ONE * 0.5; _add(boat)   # 부두에 맨 거룻배
	else:
		KitProps.f(self, "tableCloth", Vector3(rng.randf_range(x0 + 4.0, x1 - 4.0), 0, sz + 2.2), 0.0)
	_merge_done(mark)
	_build_parent = keep

## 물(호수)이 아닌 땅인가
func _dry(p: Vector3) -> bool: return gen.height(p.x, p.z) >= -0.005

## 빈 자리에 마당을 놓아도 되나 — 강·옛 마을·장소(탑·호숫가·오두막·산 들머리)와 그리 가는 길 위가 아니면
func _filler_ok(c: Vector2) -> bool:
	if absf(c.y - RIVER_Z) < RIVER_HW + 3.5: return false
	if absf(c.x) < WorldGen.HUB_X + 6.0 and absf(c.y) < WorldGen.HUB_Z + 6.0: return false
	if CityMap.whole_block(CityMap.block_of(c)): return false
	for s in WorldGen.SITES:
		var sc: Vector3 = s["c"]
		if c.distance_to(Vector2(sc.x, sc.z)) < float(s["r"]) + 2.0: return false   # 장소 바로 둘레만 비운다(탑 길가 블록이 반쯤 비었다)
		if TownPlan._seg(c, Vector2(s["from"].x, s["from"].z), Vector2(sc.x, sc.z)) < 4.2: return false
	return gen.wild_k(c.x, c.y) < 0.05

func _draw_site(k: int) -> void:
	if _temp_lots.has(k):
		if is_instance_valid(_temp_lots[k]): (_temp_lots[k] as Node3D).queue_free()
		_temp_lots.erase(k)
	super(k)

## 옛 마을 안 큰길도 아스팔트로(개편 2026-10-13) — 자갈 판(3.6m) 위에 5.4m 찻길 판, 다리(x 0)·Tower Road(x 16) 앞엔 건널목. 길가 가게·벤치는 그대로 둔다
func _hub_road() -> void:
	var keep := _build_parent
	var x := -WorldGen.HUB_X - 4.0; var step := 8.0
	while x < WorldGen.HUB_X + 4.0:
		var at := Vector3(x + step / 2.0, 0, WorldGen.ROAD_Z)
		_build_parent = _root_for(at)
		var cross := absf(at.x - 0.0) < step / 2.0 or absf(at.x - 16.0) < step / 2.0
		MeshMerge.merge(_build_parent, [RoadTiles._piece(self, "road-crossing" if cross else "road-straight", at, 0.0, Vector3(step, 1, 5.4), _build_parent)], [])
		x += step
	_build_parent = keep

## 갈림길 규칙(car_rail) — 0 가도 된다, 1 빨간불, 2 멈춤 표지. from = 차가 들어오는 쪽(노드에서 본 방향)
## 큰길 사거리(신호등): 9초씩 동서·남북 번갈아 초록, 바뀌기 전 2초는 모두 빨강. 삼거리: 곁가지(없는 팔의 맞은편)에서 들어오면 멈춤
const SIGNAL_T := 9.0
func junction_rule(nd: Vector2i, from: Vector2i) -> int:
	if not _node_tiles.has(nd): return 0
	var arms := _arms_of(nd)
	if arms.size() == 4 and nd.y % 2 == 0:
		var t := Time.get_ticks_msec() / 1000.0
		var phase := int(t / SIGNAL_T) % 2   # 0 동서 초록, 1 남북 초록
		if fmod(t, SIGNAL_T) > SIGNAL_T - 2.0: return 1
		return 0 if (from.y == 0) == (phase == 0) else 1
	if arms.size() == 3:
		var dirs := { "W": Vector2i(-1, 0), "E": Vector2i(1, 0), "N": Vector2i(0, -1), "S": Vector2i(0, 1) }
		for k in dirs:
			if not k in arms: return 2 if from == -(dirs[k] as Vector2i) else 0
	return 0

func _arms_of(nd: Vector2i) -> Array:
	var arms: Array = []
	var dirs := { "W": Vector2i(-1, 0), "E": Vector2i(1, 0), "N": Vector2i(0, -1), "S": Vector2i(0, 1) }
	for k in dirs:
		if _segs.has(RoadTiles.seg_key(nd, nd + (dirs[k] as Vector2i))): arms.append(k)
	return arms

## 신호등 불빛 — 신호등마다 공 하나(첫째는 남북, 둘째는 동서 차를 위한 불), 2초마다 빛깔을 맞춘다(town_traffic)
var _signal_lamps: Array = []   # [{mat, axis}]
func _signal_tick() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var phase := int(t / SIGNAL_T) % 2; var amber := fmod(t, SIGNAL_T) > SIGNAL_T - 2.0
	_signal_lamps = _signal_lamps.filter(func(e: Dictionary) -> bool: return is_instance_valid(e["node"]))   # 다시 고른 노드 판의 옛 불은 버린다
	for s in _signal_lamps:
		var m: StandardMaterial3D = s["mat"]
		var green := int(s["axis"]) == phase
		m.albedo_color = Color("f2c84b") if (amber and green) else (Color("5fd35f") if green else Color("e05050"))
		m.emission = m.albedo_color

func _retile(nd: Vector2i) -> void:
	if RoadTiles.in_hub(RoadTiles.npos(nd)): return
	var arms: Array = []
	var dirs := { "W": Vector2i(-1, 0), "E": Vector2i(1, 0), "N": Vector2i(0, -1), "S": Vector2i(0, 1) }
	for k in dirs:
		if _segs.has(RoadTiles.seg_key(nd, nd + (dirs[k] as Vector2i))): arms.append(k)
	if _node_tiles.has(nd) and is_instance_valid(_node_tiles[nd]): (_node_tiles[nd] as Node3D).queue_free()
	_node_tiles[nd] = RoadTiles.node(self, nd, arms, _root_for(RoadTiles.npos(nd)))
	if _node_props.has(nd) and is_instance_valid(_node_props[nd]): (_node_props[nd] as Node3D).queue_free()
	_node_props.erase(nd)
	if _node_tiles[nd] and arms.size() >= 3:   # 모퉁이 — 큰길 사거리엔 신호등 둘, 나머지 갈림길엔 멈춤 표지 하나(노드 판과 같이 다시 고른다)
		var p := RoadTiles.npos(nd); var r := TownPlan.ROAD_W / 2.0 - 0.4
		var holder := Node3D.new(); _root_for(p).add_child(holder); _node_props[nd] = holder
		var keep := _build_parent; _build_parent = holder
		if arms.size() == 4 and nd.y % 2 == 0:
			for q in 2:
				var lp := Vector3(p.x + r, 0, p.z + r) if q == 0 else Vector3(p.x - r, 0, p.z - r)
				KitProps.put(self, RoadTiles.DIR + "traffic-light.glb", lp, 0.0 if q == 0 else PI, 9.0)
				var bulb := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.16; sm.height = 0.32; bulb.mesh = sm
				var mat := StandardMaterial3D.new(); mat.emission_enabled = true; mat.emission_energy_multiplier = 1.5; bulb.material_override = mat
				bulb.position = lp + Vector3(0, 4.9, 0); holder.add_child(bulb)
				_signal_lamps.append({ "mat": mat, "axis": 1 - q, "node": bulb })   # 첫째 공 = 남북 차, 둘째 = 동서 차
			_signal_tick()
		else:
			KitProps.put(self, RoadTiles.DIR + "road-sign-stop.glb", Vector3(p.x + r, 0, p.z + r), 0.0, 6.0)
		_build_parent = keep

## 인도 — 동서 토막엔 가로등 둘(남·북 번갈아)과 가로수 둘, 남북 토막엔 가로등 하나
func _kerb(na: Vector2i, nb: Vector2i) -> void:
	var pa := RoadTiles.npos(na); var pb := RoadTiles.npos(nb)
	var walk := TownPlan.ROAD_W / 2.0 - 0.55   # 인도 가운데
	if na.y == nb.y:
		for k in 2:
			var x := lerpf(pa.x, pb.x, 0.3 if k == 0 else 0.7); var side := -1.0 if (k + na.x) % 2 == 0 else 1.0
			_street_light(Vector3(x, 0, pa.z + side * walk), 0.0 if side > 0.0 else PI)
			_tree(Vector3(lerpf(pa.x, pb.x, 0.5 + (k - 0.5) * 0.9 * 0.5), 0, pa.z - side * walk), 0.85)
		var mx := (pa.x + pb.x) / 2.0
		if absi(na.x * 3 + na.y) % 3 == 0 and na.y % 2 == 0:   # 버스 정류장(블록 경계 찻길, 세 토막에 하나) — 지붕·유리 판·벤치·표지
			var bz := pa.z + walk * 1.02
			_box(Vector3(3.0, 0.08, 1.1), Vector3(mx, 2.3, bz), _mat(Color("4a4a52")), false)
			for ex in [-1.45, 1.45]: _box(Vector3(0.08, 2.3, 0.08), Vector3(mx + ex, 0, bz - 0.45), _mat(Color("4a4a52")))
			var gl := MeshInstance3D.new(); var gm := BoxMesh.new(); gm.size = Vector3(2.9, 1.6, 0.04); gl.mesh = gm; var glass := StandardMaterial3D.new(); glass.albedo_color = Color(0.8, 0.92, 0.95, 0.4); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gl.material_override = glass; gl.position = Vector3(mx, 1.4, bz - 0.5); _add(gl)
			KitProps.f(self, "benchCushion", Vector3(mx, 0, bz - 0.15), PI)
			spots.append({ "pos": Vector3(mx, 0, bz - 0.6), "kind": "bench", "yaw": 0.0 })
			KitProps.put(self, RoadTiles.DIR + "road-sign-street.glb", Vector3(mx + 2.0, 0, bz), 0.0, 6.0)
		else:   # 인도 벤치·휴지통
			KitProps.f(self, "bench", Vector3(mx, 0, pa.z - walk), 0.0)
			KitProps.f(self, "trashcan", Vector3(mx + 1.4, 0, pa.z - walk), 0.0)
	else:
		var lz := (pa.z + pb.z) / 2.0
		if absf(lz - RIVER_Z) < RIVER_HW + 2.0: lz = minf(pa.z, pb.z) + TownPlan.ROAD_W / 2.0 + 1.0   # 강을 건너는 토막 — 다리 위가 아니라 둑에
		_street_light(Vector3(pa.x + walk, 0, lz), -PI / 2.0)

## 가로등(Kenney light-curved, 9배 = 6m) — 기둥 충돌, 밤엔 켜진다(lamps), 차가 받으면 넘어간다(wreckables)
func _street_light(at: Vector3, yaw: float) -> void:
	var g := Node3D.new(); g.set_meta("nomerge", true); _add(g)
	var m := KitProps.mesh_node(RoadTiles.DIR + "light-curved.glb"); m.position = at; m.rotation.y = yaw; m.scale = Vector3.ONE * 9.0; g.add_child(m)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.15; cy.height = 2.0; cs.shape = cy; cs.position = at + Vector3(0, 1.0, 0); sb.add_child(cs); g.add_child(sb)
	var l := OmniLight3D.new(); l.light_color = Color("e8c766"); l.light_energy = 0.8; l.omni_range = 7.0
	l.position = at + Vector3(sin(yaw), 0, cos(yaw)) * -1.6 + Vector3(0, 5.6, 0); g.add_child(l); lamps.append(l)
	var sp := { "pos": at + Vector3(0.3, 0, 0), "kind": "lamp", "yaw": -PI / 2.0 }
	spots.append(sp)
	wreckables.append({ "node": g, "at": at, "r": 0.25, "out": Vector3(0, 0, 1), "spot": sp, "light": l, "whole": true, "rebuild": _street_light.bind(at, yaw) })

## 문 앞 흙길 — 문에서 앞으로 나와 골목까지, 집마다 조금씩 다르게 꺾인다(반듯한 자갈 골목 사이의 비포장 오솔길)
func _footpath(l: Dictionary, c: Vector3) -> void:
	if CityMap.lot_kind(l) == "green": return
	var rng := RandomNumberGenerator.new(); rng.seed = hash("path/" + String(l["id"]))
	var hd := float((TownPlan.house_spec(l)["size"] as Vector3).z) / 2.0
	var a := c + Vector3(0, 0, hd + 0.9)
	var keep := _build_parent; _build_parent = _root_for(c)
	var dirt := _mat(Color("b59a74"))
	var pts: Array[Vector3] = [a]
	var z1: float = float(l["street_z"]) - TownPlan.ROAD_W / 2.0   # 앞(남쪽) 찻길의 인도
	if z1 - a.z > 0.6:
		pts.append(a + Vector3(rng.randf_range(-0.5, 0.5), 0, (z1 - a.z) * 0.5))
		pts.append(Vector3(a.x + rng.randf_range(-0.9, 0.9), 0, z1))
	for k in pts.size() - 1:
		var p0 := pts[k]; var p1 := pts[k + 1]; var d := p1 - p0
		var seg := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(d.length() + 0.5, 0.015, rng.randf_range(0.8, 1.1)); seg.mesh = bm; seg.material_override = dirt
		seg.position = (p0 + p1) / 2.0 + Vector3(0, 0.012, 0); seg.rotation.y = -atan2(d.z, d.x); _add(seg)
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

## 녹지 띠 — 옛 마을(허브)과 첫 필지 사이 빈 띠(북 z −31.5, 남 z +34)에 7m 마다 나무, 사이사이 꽃밭, 21m 마다 벤치 — 길·장소 길은 비운다
## Tower Road 양옆은 6m 마다 가로수(운영자 2026-10-08: 탑 가는 길이 휑했다)
func _green_belt() -> void:
	var keep := _build_parent
	for z in [-31.5, 34.0]:
		var i := 0
		for xi in range(-70, 71, 7):
			var x := float(xi); i += 1
			var skip := false
			for s in WorldGen.SITES:
				if absf(x - float(s["from"].x)) < 4.0 and absf(z - float(s["from"].z)) < 40.0: skip = true
			if skip: continue
			var at := Vector3(x, 0, z)
			_build_parent = _root_for(at)
			var mark := _merge_mark()
			_tree(at, 0.95 + fmod(absf(x) * 0.13, 0.35))
			if i % 3 == 0: _bench(at + Vector3(3.5, 0, 0.9 if z < 0.0 else -0.9))
			else:
				_box(Vector3(2.2, 0.25, 0.9), at + Vector3(3.5, 0, 0), _mat(Color("7a5a3a")), false)
				for q in 4: _scatter(["Flower_3_Group", "Flower_4_Group", "Bush_Common_Flowers", "Clover_1"][(q + i) % 4], at + Vector3(2.7 + q * 0.55, 0.25, 0), 0.6)
			_merge_done(mark)
	for zi in range(-20, -70, -6):   # Tower Road(x 15.5) 양옆 가로수
		for side in [-1.0, 1.0]:
			var at := Vector3(15.5 + side * 3.6, 0, float(zi))
			_build_parent = _root_for(at)
			_tree(at, 0.9)
	_build_parent = keep

## 둘레길 — 60m 마다 벤치, 240m 마다 이정표(WorldGen.loop_at 이 길을 그린다). 길 바깥쪽 1.6m 에
func _dress_loop() -> void:
	var r0 := WorldGen.loop_r(0.0); var steps := int(TAU * r0 / 60.0)
	for i in steps:
		var a := i * TAU / steps
		var r := WorldGen.loop_r(a) + 1.9
		var p := Vector3(WorldGen.LOOP_C.x + cos(a) * r, 0, WorldGen.LOOP_C.y + sin(a) * r)
		if not gen.loop_at(p.x - cos(a) * 1.9, p.z - sin(a) * 1.9): continue
		p.y = gen.height(p.x, p.z)
		var keep := _build_parent; _build_parent = _root_for(p)
		if i % 4 == 0: _signpost(p, "TOWN LOOP
%d m around" % int(TAU * r0))
		else: _bench(p)
		_build_parent = keep

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

