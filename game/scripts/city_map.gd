class_name CityMap
extends RefCounted
## 마을 지도(data/map/town.json) 읽기 — 블록마다 구역(번화가·주택가·공방가·관공서·공원), 가게 종류, 길 표지판. 나중에 맵 에디터가 쓸 형식이 이것이다.
## TownPlan(필지 격자)·TownCity(짓기)·TownGrowth(기본 마을 founded) 가 같이 읽는다

const FILE := "res://data/map/town.json"
static var _d: Dictionary = {}

static func data() -> Dictionary:
	if _d.is_empty():
		var f := FileAccess.open(FILE, FileAccess.READ)
		var v: Variant = JSON.parse_string(f.get_as_text()) if f else null
		_d = v if v is Dictionary else { "blocks": {}, "shops": [], "signs": [], "founded": 0 }
	return _d

static func block_of(c: Vector2) -> Vector2i:
	return Vector2i(floori((c.x - TownPlan.OX) / TownPlan.PITCH), floori((c.y - TownPlan.OZ) / TownPlan.PITCH))

static func block(b: Vector2i) -> Dictionary:
	return (data()["blocks"] as Dictionary).get("%d,%d" % [b.x, b.y], { "zone": "residential" })

static func zone_at(c: Vector2) -> String:
	return String(block(block_of(c)).get("zone", "residential"))

## 필지가 없는 블록(관공서·공원) — 블록 전체를 하나로 쓴다
static func whole_block(b: Vector2i) -> bool:
	return String(block(b).get("zone", "")) in ["civic", "park"]

## 블록 가운데(지면)
static func block_center(b: Vector2i) -> Vector3:
	return Vector3(TownPlan.OX + (b.x + 0.5) * TownPlan.PITCH, 0, TownPlan.OZ + (b.y + 0.5) * TownPlan.PITCH)

## 필지가 무엇이 되나 — house | shop | workshop | green
static func lot_kind(l: Dictionary) -> String:
	match zone_at(l["c"]):
		"high_street": return "shop"
		"workshop": return "workshop"
		_: return "green" if int(l["order"]) % 9 == 4 else "house"

## 가게 종류 — 필지 순번으로 돌린다(같은 거리에 같은 가게가 붙지 않게)
static func shop_of(l: Dictionary) -> Dictionary:
	var shops: Array = data()["shops"]
	return shops[int(l["order"]) % shops.size()] if not shops.is_empty() else { "type": "SHOP", "item": "apple", "awning": "6f9a5a" }

static func founded() -> int:
	return int(data().get("founded", 0))
