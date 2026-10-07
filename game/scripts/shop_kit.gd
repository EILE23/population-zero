class_name ShopKit
extends RefCounted
## 가게 방(운영자 2026-10-06: "카페에 배치된 컵들, 커피 진열 등도 가게마다 다 다르게") — 같은 종류 가게도 다르게:
## 진열 배치 셋(양벽+섬 / 뒷벽 두 줄+옆벽 / 통로 두 줄) × 종류마다 파는 것·꾸밈(카페: 커피 기계·케이크 진열장·메뉴판·탁자, 빵집: 큰 화덕·빵 선반, 식료품: 과일 통·저울 …)
## 진열대 C = 그 칸 물건을 집는다(값은 계산대에서). 꾸밈 가구는 room_kit 의 PIECES

const SELLS := { "CAFE": ["cup", "bread"], "BAKERY": ["bread"], "GROCER": ["apple", "can"], "BOOKSHOP": ["book"], "FISHMONGER": ["fish"], "CORNER SHOP": ["can", "letter", "apple"], "UMBRELLAS": ["umbrella"], "GENERAL STORE": ["cap", "scarf", "backpack", "flatpack"] }   # flatpack: 넷째 진열 = 문 옆 카탈로그 탁자(town_furnish, run 117)
## 한 진열대에 여러 가지(run 114, 잡화점): 칸마다 다른 것이 놓이고 집을 때마다 다음 것 — 모자 넷, 가방 칸엔 우산도
const MIX := { "cap": ["cap", "beanie", "straw", "tophat"], "backpack": ["backpack", "umbrella"], "flatpack": ["chair", "table_small", "bookshelf", "sofa", "bed", "rug", "floor_lamp", "plant"] }   # flatpack: RoomKit.PIECES 의 이름 그대로 — TownFurnish.FURN 이 이 목록을 읽는다
## [가구, x(벽 반폭 비율), z(벽 반깊이 비율), 각도°] — 계산대·진열대 자리를 피하게 가장자리 위주
const DECOR := {
	"CAFE": [["menu_board", 0.0, -0.98, 0], ["tea_table", 0.55, 0.35, 0], ["chair", 0.4, 0.35, 90], ["chair", 0.7, 0.35, -90], ["tea_table", -0.55, 0.35, 0], ["chair", -0.7, 0.35, 90], ["chair", -0.4, 0.35, -90], ["plant_big", 0.9, 0.7, 0]],
	"BAKERY": [["oven_big", 0.62, -0.88, 0], ["bread_rack", -0.85, 0.3, 90], ["flour_sacks", 0.85, 0.45, -90]],
	"GROCER": [["produce_bin", -0.6, 0.55, 0], ["produce_bin", 0.0, 0.62, 0], ["produce_bin", 0.6, 0.55, 0], ["plant", -0.9, 0.8, 0]],
	"BOOKSHOP": [["bookshelf", -0.9, 0.2, 90], ["bookshelf", 0.9, 0.2, -90], ["armchair", 0.55, 0.55, -40], ["floor_lamp", 0.85, 0.75, 0], ["books_pile", -0.5, 0.6, 0]],
	"FISHMONGER": [["ice_counter", 0.6, 0.4, -90], ["nets", 0.0, -0.98, 0], ["barrel", -0.85, 0.65, 0]],
	"CORNER SHOP": [["can_fridge", 0.88, -0.2, -90], ["magazine_rack", -0.88, 0.45, 90], ["snacks", 0.6, 0.65, 0]],
	"UMBRELLAS": [["umbrella_stand", -0.6, 0.55, 0], ["umbrella_stand", 0.6, 0.55, 0], ["mirror", 0.98, -0.1, -90], ["umbrella_stand", 0.0, 0.7, 0]],
	"GENERAL STORE": [["mirror", 0.98, -0.1, -90], ["umbrella_stand", 0.6, 0.65, 0], ["barrel", -0.85, 0.65, 0], ["plant", -0.9, 0.8, 0]],
}

static func build(t: Node, rm: Dictionary, sh: Dictionary) -> void:
	var o: Vector3 = rm["o"]; var w: float = rm["w"]; var d: float = rm["d"]
	var type := String(sh["type"]); var sells: Array = SELLS.get(type, [String(sh["item"])])
	var v := int(sh["id"]) % 3
	var wood: Material = t.call("_mat", Color(["8a6a4a", "6b4a35", "b48a5a"][v]))
	# 계산대 — 배치마다 자리가 다르다
	var ct: Vector3 = [o + Vector3(0, 0, -d / 2.0 + 1.8), o + Vector3(-w / 2.0 + 2.2, 0, -d / 2.0 + 1.8), o + Vector3(w / 2.0 - 2.4, 0, -0.6)][v]
	t.call("_box", Vector3(2.6, 0.95, 0.6), ct, wood)
	t.call("_box", Vector3(0.4, 0.25, 0.3), ct + Vector3(0.8, 0.95, 0), t.call("_mat", Color("4a4a52")), false)   # 금전등록기
	if type == "CAFE":
		RoomKit.piece(t, rm, "espresso", ct + Vector3(-0.7, 0.95, 0), 0.0, {})
		RoomKit.piece(t, rm, "cake_dome", ct + Vector3(0.1, 0.95, 0.05), 0.0, {})
		for k in 5:   # 계산대 위 컵 줄 — 바로 선 채로
			var cup: Node3D = t.call("make_item", "cup", ct + Vector3(-1.15 + k * 0.12, 0.95, -0.2)); t.call("_add_display", cup)
	elif type == "GROCER" or type == "FISHMONGER":
		RoomKit.piece(t, rm, "scale", ct + Vector3(-0.6, 0.95, 0), 0.0, {})
	t.call("_spot", rm, "counter", ct + Vector3(0, 0, 0.85), PI, {})
	sh["keeper"]["inner"] = ct + Vector3(0, 0.05, -0.75)
	sh["room"] = rm["door"]
	# 진열대 — 배치 셋
	var shelves: Array = []   # [가운데, 크기, 앞쪽(손님이 서는 쪽)]
	match v:
		0: shelves = [[o + Vector3(-w / 2.0 + 0.6, 0, -0.2), Vector3(0.6, 1.3, d - 4.0), Vector3(0.75, 0, 0)], [o + Vector3(w / 2.0 - 0.6, 0, -0.2), Vector3(0.6, 1.3, d - 4.0), Vector3(-0.75, 0, 0)], [o + Vector3(0, 0, 0.6), Vector3(2.4, 1.3, 0.6), Vector3(0, 0, 0.75)]]
		1: shelves = [[o + Vector3(1.6, 0, -d / 2.0 + 0.5), Vector3(3.6, 1.6, 0.5), Vector3(0, 0, 0.7)], [o + Vector3(w / 2.0 - 0.6, 0, 0.2), Vector3(0.6, 1.3, d - 4.5), Vector3(-0.75, 0, 0)], [o + Vector3(0.6, 0, 0.3), Vector3(2.8, 1.0, 0.6), Vector3(0, 0, 0.75)]]
		_: shelves = [[o + Vector3(-w / 2.0 + 2.2, 0, -0.6), Vector3(0.6, 1.4, d - 4.6), Vector3(0.75, 0, 0)], [o + Vector3(-w / 2.0 + 4.6, 0, -0.6), Vector3(0.6, 1.4, d - 4.6), Vector3(-0.75, 0, 0)], [o + Vector3(-w / 2.0 + 0.5, 0, -0.6), Vector3(0.5, 1.8, d - 4.6), Vector3(0.7, 0, 0)]]
	for i in shelves.size():
		var at: Vector3 = shelves[i][0]; var sz: Vector3 = shelves[i][1]; var face: Vector3 = shelves[i][2]
		t.call("_box", sz, at, wood)
		var kind: String = sells[i % sells.size()]
		var long_x := sz.x > sz.z
		var mix: Array = MIX.get(kind, [kind])
		for k in 4:
			var f := -0.38 + k * 0.25
			var p := at + (Vector3(f * sz.x, sz.y, 0) if long_x else Vector3(0, sz.y, f * sz.z))
			var it: Node3D = t.call("make_goods", String(mix[k % mix.size()]), p); t.call("_add_display", it)   # 입는 것도 진열된다(town_store)
		t.call("_spot", rm, "shelf", at + face, atan2(-face.x, -face.z), { "item": kind, "mix": mix, "next": 0 })
	for i in range(3, sells.size()):   # 넷째부터는 문 옆(오른쪽 앞) 낮은 탁자 — 세 배치의 진열대·꾸밈이 다 비켜 가는 자리(잡화점의 납작 상자, town_furnish run 117)
		var at := o + Vector3(w / 2.0 - 1.6, 0, d / 2.0 - 1.1 - (i - 3) * 1.0)
		t.call("_box", Vector3(1.4, 0.75, 0.6), at, wood)
		var kind: String = sells[i]; var mix: Array = MIX.get(kind, [kind])
		for k in 4:
			var it: Node3D = t.call("make_goods", String(mix[k % mix.size()]), at + Vector3(-0.5 + k * 0.33, 0.75, 0)); t.call("_add_display", it)
		t.call("_spot", rm, "shelf", at + Vector3(0, 0, 0.75), PI, { "item": kind, "mix": mix, "next": 0 })
	# 꾸밈 — 종류마다
	for dc in DECOR.get(type, []):
		var at := o + Vector3(float(dc[1]) * (w / 2.0 - 0.5), 0, float(dc[2]) * (d / 2.0 - 0.4))
		if absf(at.x - o.x) < 1.0 and at.z - o.z > d / 2.0 - 2.0: continue   # 문길
		RoomKit.piece(t, rm, String(dc[0]), at, deg_to_rad(float(dc[3])), { "cloth": Color("ad7096") })
	# 간판·값표
	var lb := Label3D.new(); lb.text = type; lb.font_size = 72; lb.pixel_size = 0.005; lb.modulate = Color("1b0c15"); lb.outline_size = 0
	lb.position = o + Vector3(0, 2.4, -d / 2.0 + 0.09); t.call("_add", lb)
	var buy: Dictionary = (t.get("prices") as Dictionary).get("buy", {})
	var price_lines := ", ".join(sells.map(func(k: String) -> String: return "%s %d" % [k.capitalize(), int(buy.get(k, 1))] if buy.has(k) else "%s from %d" % [k.capitalize(), (MIX.get(k, [k]) as Array).map(func(m: String) -> int: return int(buy.get(m, 1))).min()]))   # 섞어 파는 것(납작 상자)은 가장 싼 값부터
	var pr := Label3D.new(); pr.text = price_lines; pr.font_size = 40; pr.pixel_size = 0.004; pr.modulate = Color("7b526c"); pr.outline_size = 0
	pr.position = o + Vector3(0, 1.95, -d / 2.0 + 0.09); t.call("_add", pr)
