class_name RoomKit
extends RefCounted
## 집 안 꾸미기(운영자 2026-10-06: "집 내부 인테리어도 진짜 다양해야 해 — 최소 20가지", "형태도 엄청 다양해져야", "주민들이 집 인테리어를 다 같게 꾸며? 아니잖아") —
## 1) 틀(data/interiors.json, 22가지 이상 — 늘리면 된다): 칸막이·바닥·벽지·가구 자리. 주민의 일(빵집 주인 → 부엌 집 …)이나 성격(호기심·어울림·게으름·배짱·성미·좋아하는 것)이 고른다
## 2) 그 사람의 손: 방 크기·비율·모양(네모·ㄱ자·길쭉·넓적·좌우 뒤집기), 벽지·바닥 빛깔, 천(소파·이불) 빛깔은 그 사람 몸 색, 게으르면 잡동사니, 부지런하면 화분·액자, 좋아하는 것(낚시 → 어항 …)
## 같은 틀이어도 집마다 다르다. 가구는 PIECES 표 하나(상자·원기둥·공·풀 모형 + C 자리) — 새 가구는 한 줄

const FILE := "res://data/interiors.json"
## 2층집이면 이것들은 위층으로(town_interior — 계단으로 올라간다)
const BEDROOM := ["bed", "bed_double", "bed_low", "bunk", "hammock", "nightstand", "wardrobe", "dresser", "mirror"]
## 가구 위의 진짜 물건(집어 들고 나갈 수 있다 — town_interior._room_item) [종류, x, y, z]
const ITEMS := {
	"table": [["cup", -0.3, 0.75, 0.0], ["apple", 0.3, 0.75, 0.1]], "table_small": [["cup", 0.0, 0.7, 0.0]], "tea_table": [["cup", 0.1, 0.7, 0.0]],
	"nightstand": [["book", 0.0, 0.5, 0.0]], "desk": [["book", -0.4, 0.75, 0.1], ["letter", 0.2, 0.75, 0.15]], "kitchen": [["bread", -0.6, 0.94, 0.0], ["cup", 0.2, 0.94, 0.0]],
	"island": [["apple", 0.0, 0.94, 0.0], ["apple", 0.3, 0.94, 0.1]], "books_pile": [["book", 0.0, 0.32, 0.0]], "paint_table": [["can", 0.35, 0.75, 0.0]],
}
static var _layouts: Array = []

static func layouts() -> Array:
	if _layouts.is_empty():
		var f := FileAccess.open(FILE, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
		_layouts = (d as Dictionary).get("layouts", []) if d is Dictionary else []
	return _layouts

## 가구 — b: 상자 [크기x,y,z, 자리x,y,z, 빛깔("cloth"=그 집 천, "wood", "metal" 또는 "#hex")], c: 원기둥 [반지름, 높이, x,y,z, 빛깔], s: 공 [반지름, x,y,z, 빛깔], m: 풀 모형 [id, x, z, 배율],
## spot: [종류, 앞으로 몇 m, 더할 것] — 종류 sit·bed·read·stove·fridge·pose·emote·play·search·tv·board(town_interior.inner_use). solid: 몸이 막히나(앉는 가구는 아니다)
const PIECES := {
	"bed": { "b": [[1.6, 0.35, 2.1, 0, 0, 0, "wood"], [1.5, 0.12, 1.9, 0, 0.35, 0.05, "#f7f4ef"], [1.5, 0.06, 0.7, 0, 0.45, 0.68, "cloth"], [0.7, 0.1, 0.32, 0, 0.47, -0.75, "#efe9e2"]], "spot": ["bed", 0.1, { "top": 0.58 }], "solid": true },
	"bed_double": { "b": [[2.2, 0.35, 2.2, 0, 0, 0, "wood"], [2.1, 0.12, 2.0, 0, 0.35, 0.05, "#f7f4ef"], [2.1, 0.06, 0.8, 0, 0.45, 0.62, "cloth"], [0.6, 0.1, 0.32, -0.5, 0.47, -0.78, "#efe9e2"], [0.6, 0.1, 0.32, 0.5, 0.47, -0.78, "#efe9e2"]], "spot": ["bed", 0.1, { "top": 0.58 }], "solid": true },
	"bed_low": { "b": [[1.5, 0.15, 2.0, 0, 0, 0, "#efe9e2"], [1.4, 0.05, 0.7, 0, 0.15, 0.6, "cloth"]], "spot": ["bed", 0.1, { "top": 0.21 }], "solid": true },
	"bunk": { "b": [[1.0, 0.3, 2.0, 0, 0, 0, "wood"], [1.0, 0.1, 2.0, 0, 1.3, 0, "wood"], [0.08, 1.8, 0.08, 0.46, 0, 0.96, "wood"], [0.08, 1.8, 0.08, -0.46, 0, 0.96, "wood"], [0.9, 0.08, 1.8, 0, 0.3, 0, "cloth"], [0.9, 0.08, 1.8, 0, 1.4, 0, "#ad7096"]], "spot": ["bed", 0.0, { "top": 0.39 }], "solid": true },
	"hammock": { "b": [[0.08, 1.6, 0.08, 0, 0, -1.1, "wood"], [0.08, 1.6, 0.08, 0, 0, 1.1, "wood"], [0.7, 0.06, 2.0, 0, 0.75, 0, "cloth"]], "spot": ["bed", 0.0, { "top": 0.82 }], "solid": true },
	"nightstand": { "b": [[0.5, 0.5, 0.45, 0, 0, 0, "wood"]], "s": [[0.07, 0, 0.6, 0, "#f2c84b"]] },
	"wardrobe": { "b": [[1.2, 2.0, 0.6, 0, 0, 0, "wood"], [0.02, 1.8, 0.02, 0, 0.1, 0.31, "#4a4a52"]] },
	"dresser": { "b": [[1.3, 0.9, 0.5, 0, 0, 0, "wood"], [0.5, 0.6, 0.04, 0, 0.95, -0.2, "#bfe3f2"]] },
	"kitchen": { "b": [[2.2, 0.9, 0.6, 0, 0, 0, "#cfc7c2"], [2.2, 0.04, 0.62, 0, 0.9, 0, "#efe9e2"], [0.5, 0.03, 0.4, 0.5, 0.94, 0, "#8a8a92"]], "spot": ["stove", 0.8] },
	"stove": { "b": [[0.8, 0.9, 0.6, 0, 0, 0, "#4a4a52"], [0.7, 0.03, 0.5, 0, 0.9, 0, "#2a2a30"]], "spot": ["stove", 0.8] },
	"island": { "b": [[1.8, 0.9, 0.8, 0, 0, 0, "#cfc7c2"], [1.9, 0.04, 0.9, 0, 0.9, 0, "#efe9e2"]] },
	"fridge": { "b": [[0.75, 1.9, 0.65, 0, 0, 0, "#f7f4ef"], [0.03, 0.5, 0.03, 0.3, 1.2, 0.33, "#8a8a92"]], "spot": ["fridge", 0.9] },
	"jars": { "c": [[0.08, 0.2, -0.3, 1.0, 0, "#d8a24a"], [0.07, 0.25, 0.0, 1.0, 0, "#b56a5a"], [0.08, 0.18, 0.3, 1.0, 0, "#6f9a5a"]] },
	"table": { "b": [[1.4, 0.75, 0.9, 0, 0, 0, "wood"]], "solid": true },
	"table_small": { "b": [[0.8, 0.7, 0.8, 0, 0, 0, "wood"]] },
	"tea_table": { "c": [[0.45, 0.7, 0, 0, 0, "wood"]], "s": [[0.06, -0.15, 0.75, 0, "#f7f4ef"], [0.06, 0.15, 0.75, 0.1, "#f7f4ef"]] },
	"chair": { "b": [[0.45, 0.45, 0.45, 0, 0, 0, "wood"], [0.45, 0.5, 0.06, 0, 0.45, -0.2, "wood"]], "spot": ["sit", 0.0], "solid": false },
	"stool": { "c": [[0.2, 0.55, 0, 0, 0, "wood"]], "spot": ["sit", 0.0], "solid": false },
	"cushion": { "b": [[0.5, 0.12, 0.5, 0, 0, 0, "cloth"]], "spot": ["sit", 0.0], "solid": false },
	"beanbag": { "s": [[0.42, 0, 0.25, 0, "cloth"]], "spot": ["sit", 0.0], "solid": false },
	"sofa": { "b": [[2.2, 0.42, 0.85, 0, 0, 0, "cloth"], [2.2, 0.5, 0.2, 0, 0.42, -0.33, "cloth"], [0.2, 0.25, 0.85, -1.0, 0.42, 0, "cloth"], [0.2, 0.25, 0.85, 1.0, 0.42, 0, "cloth"]], "spot": ["sit", 0.05], "spot2": ["sit", 0.05, 0.55], "solid": false },
	"armchair": { "b": [[0.9, 0.42, 0.85, 0, 0, 0, "cloth"], [0.9, 0.55, 0.2, 0, 0.42, -0.33, "cloth"]], "spot": ["sit", 0.05], "solid": false },
	"rocker": { "b": [[0.6, 0.45, 0.6, 0, 0, 0, "wood"], [0.6, 0.6, 0.06, 0, 0.45, -0.27, "wood"], [0.06, 0.06, 0.9, -0.28, 0, 0, "wood"], [0.06, 0.06, 0.9, 0.28, 0, 0, "wood"]], "spot": ["sit", 0.0], "solid": false },
	"rug": { "b": [[2.6, 0.01, 1.7, 0, 0, 0, "#c9b18a"]], "solid": false },
	"bookshelf": { "b": [[1.5, 2.0, 0.4, 0, 0, 0, "wood"]], "books": true, "spot": ["read", 0.8] },
	"books_pile": { "b": [[0.4, 0.12, 0.3, 0, 0, 0, "#b56a5a"], [0.38, 0.1, 0.28, 0.02, 0.12, 0, "#5a6f9a"], [0.36, 0.1, 0.3, -0.02, 0.22, 0, "#d8a24a"]], "spot": ["read", 0.6], "solid": false },
	"desk": { "b": [[1.4, 0.75, 0.7, 0, 0, 0, "wood"], [0.4, 0.3, 0.05, 0.3, 0.75, -0.2, "#2a2a30"]], "spot": ["pose", 0.8, { "pose": "scan", "text": "You sit at the desk and look busy." }] },
	"globe": { "c": [[0.05, 0.8, 0, 0, 0, "wood"]], "s": [[0.25, 0, 1.0, 0, "#5a6f9a"]], "spot": ["pose", 0.6, { "pose": "shade", "text": "You spin the globe. It stops on the sea." }] },
	"floor_lamp": { "c": [[0.04, 1.6, 0, 0, 0, "#4a4a52"], [0.22, 0.25, 0, 1.6, 0, "#f4de8a"]], "solid": false },
	"lamp_paper": { "s": [[0.3, 0, 0.3, 0, "#f7f4ef"]], "solid": false },
	"lava_lamp": { "c": [[0.1, 0.5, 0, 0, 0, "#ad7096"]], "solid": false },
	"fireplace": { "b": [[1.6, 1.2, 0.5, 0, 0, 0, "#b56a5a"], [0.9, 0.6, 0.1, 0, 0.1, 0.22, "#2a1e26"], [0.6, 0.2, 0.08, 0, 0.12, 0.25, "#f2a24b"]], "spot": ["pose", 0.9, { "pose": "wait", "text": "You warm your hands. The fire does the rest." }] },
	"clock": { "b": [[0.5, 1.9, 0.35, 0, 0, 0, "wood"]], "s": [[0.18, 0, 1.55, 0.18, "#f7f4ef"]], "spot": ["board", 0.7, { "text": "The clock says it is a little later than you thought." }] },
	"frames": { "b": [[0.5, 0.4, 0.03, -0.9, 1.5, 0, "#ad7096"], [0.4, 0.5, 0.03, 0, 1.55, 0, "#5a6f9a"], [0.5, 0.35, 0.03, 0.9, 1.45, 0, "#d8a24a"]], "solid": false },
	"posters": { "b": [[0.7, 0.9, 0.02, -0.5, 1.4, 0, "#ad7096"], [0.6, 0.8, 0.02, 0.5, 1.5, 0, "#6f9a5a"]], "solid": false },
	"mirror": { "b": [[0.6, 1.5, 0.04, 0, 0.4, 0, "#bfe3f2"]], "solid": false, "spot": ["board", 0.6, { "text": "You look fine. Mostly." }] },
	"plant": { "m": [["Plant_1", 0, 0, 0.7]], "solid": false },
	"plant_big": { "c": [[0.25, 0.4, 0, 0, 0, "#b56a5a"]], "m": [["Plant_1_Big", 0, 0, 0.6]] },
	"planter": { "b": [[1.4, 0.4, 0.5, 0, 0, 0, "wood"]], "m": [["Flower_3_Group", -0.4, 0, 0.6], ["Flower_4_Group", 0.4, 0, 0.6]], "spot": ["pose", 0.7, { "pose": "water", "text": "You water the planter. It looks pleased, for a planter." }] },
	"watering": { "c": [[0.12, 0.25, 0, 0, 0, "#6f9a5a"]], "solid": false },
	"tv": { "b": [[1.2, 0.5, 0.4, 0, 0, 0, "wood"], [1.1, 0.65, 0.06, 0, 0.5, 0, "#2a2a30"]], "spot": ["tv", 1.6] },
	"tv_old": { "b": [[0.8, 0.7, 0.6, 0, 0, 0, "wood"], [0.55, 0.45, 0.02, 0, 0.12, 0.31, "#5a6f6a"]], "spot": ["tv", 1.4] },
	"console": { "b": [[0.3, 0.06, 0.2, 0, 0.5, 0.15, "#4a4a52"]], "solid": false },
	"snacks": { "b": [[0.6, 0.9, 0.5, 0, 0, 0, "#cfc7c2"]], "c": [[0.05, 0.12, -0.15, 0.9, 0, "#b56a5a"], [0.05, 0.12, 0.1, 0.9, 0, "#d8a24a"]], "spot": ["fridge", 0.7] },
	"piano": { "b": [[1.5, 1.2, 0.6, 0, 0, 0, "#2a2a30"], [1.4, 0.06, 0.3, 0, 0.72, 0.35, "#f7f4ef"]], "spot": ["play", 0.9] },
	"guitar": { "b": [[0.08, 1.0, 0.04, 0, 0.1, 0, "#8a6a4a"]], "s": [[0.18, 0, 0.3, 0.02, "#d8a24a"]], "spot": ["pose", 0.6, { "pose": "strum", "text": "You play the one chord you know." }], "solid": false },
	"record_player": { "b": [[0.6, 0.7, 0.45, 0, 0, 0, "wood"]], "c": [[0.18, 0.02, 0, 0.7, 0, "#2a2a30"]], "spot": ["play", 0.7, { "tune": true }] },
	"records": { "b": [[0.8, 0.5, 0.35, 0, 0, 0, "wood"], [0.7, 0.32, 0.3, 0, 0.5, 0, "#ad7096"]] },
	"radio_old": { "b": [[0.5, 0.35, 0.3, 0, 0.75, 0, "wood"], [0.6, 0.75, 0.35, 0, 0, 0, "wood"]], "spot": ["play", 0.7, { "tune": true }] },
	"easel": { "b": [[0.06, 1.5, 0.06, -0.3, 0, 0, "wood"], [0.06, 1.5, 0.06, 0.3, 0, 0, "wood"], [0.75, 0.6, 0.03, 0, 0.9, 0.05, "#f7f4ef"], [0.4, 0.3, 0.01, 0.05, 1.0, 0.07, "cloth"]], "spot": ["pose", 0.8, { "pose": "pin", "text": "You add a little blue. It was already blue." }], "solid": false },
	"canvases": { "b": [[0.8, 0.6, 0.05, 0, 0, 0, "#f7f4ef"], [0.7, 0.5, 0.05, 0.1, 0, 0.08, "#ad7096"], [0.6, 0.7, 0.05, -0.1, 0, 0.16, "#6f9a5a"]] },
	"paint_table": { "b": [[1.0, 0.75, 0.5, 0, 0, 0, "wood"]], "c": [[0.04, 0.12, -0.3, 0.75, 0, "#b56a5a"], [0.04, 0.12, -0.15, 0.75, 0, "#5a6f9a"], [0.04, 0.12, 0.0, 0.75, 0, "#d8a24a"]] },
	"workbench": { "b": [[1.8, 0.85, 0.7, 0, 0, 0, "wood"], [0.3, 0.2, 0.2, 0.5, 0.85, 0, "#4a4a52"]], "spot": ["pose", 0.8, { "pose": "hammer", "text": "You fix something that was not broken." }] },
	"tool_wall": { "b": [[1.8, 0.9, 0.04, 0, 1.0, 0, "#8a6a4a"], [0.04, 0.4, 0.04, -0.5, 1.2, 0.04, "#4a4a52"], [0.3, 0.06, 0.04, 0.2, 1.4, 0.04, "#4a4a52"]], "solid": false },
	"boxes": { "b": [[0.6, 0.6, 0.6, 0, 0, 0, "#b48a5a"], [0.5, 0.5, 0.5, 0.05, 0.6, 0.05, "#c9a27a"], [0.55, 0.45, 0.55, 0.6, 0, 0.1, "#b48a5a"]], "spot": ["search", 0.8] },
	"tyres": { "c": [[0.35, 0.22, 0, 0, 0, "#2a2a30"], [0.35, 0.22, 0, 0.22, 0, "#2a2a30"]] },
	"toys": { "b": [[0.2, 0.2, 0.2, -0.3, 0, 0, "#f2c84b"], [0.15, 0.15, 0.15, 0.2, 0, 0.2, "#5a6f9a"]], "s": [[0.12, 0.3, 0.12, -0.2, "#b56a5a"]], "solid": false },
	"display_case": { "b": [[1.4, 0.9, 0.5, 0, 0, 0, "wood"], [1.36, 0.6, 0.46, 0, 0.9, 0, "#bfe3f2"]], "s": [[0.1, -0.4, 1.1, 0, "#d8a24a"], [0.08, 0.1, 1.08, 0, "#ad7096"], [0.09, 0.45, 1.09, 0, "#6f9a5a"]], "spot": ["board", 0.7, { "text": "A label says: 'Do not touch the spoons.'" }] },
	"trophies": { "b": [[1.2, 1.2, 0.35, 0, 0, 0, "wood"]], "c": [[0.08, 0.3, -0.35, 1.2, 0, "#d8a24a"], [0.08, 0.22, 0.0, 1.2, 0, "#cfc7c2"], [0.08, 0.26, 0.35, 1.2, 0, "#b48a5a"]], "spot": ["board", 0.7, { "text": "Third place, 1998. Second place, 1999. No comment on 2000." }] },
	"ship_wheel": { "c": [[0.04, 1.2, 0, 0, 0, "wood"]], "s": [[0.4, 0, 1.3, 0, "wood"]], "spot": ["pose", 0.7, { "pose": "shade", "text": "Steady as she goes. She is a house." }], "solid": false },
	"map_table": { "b": [[1.4, 0.8, 0.9, 0, 0, 0, "wood"], [1.2, 0.01, 0.75, 0, 0.8, 0, "#efe2cf"]], "spot": ["board", 0.8, { "text": "The map has the town on it, and then a lot of sea." }] },
	"aquarium": { "b": [[1.2, 0.7, 0.5, 0, 0, 0, "wood"], [1.15, 0.6, 0.45, 0, 0.7, 0, "#7fc4d8"]], "s": [[0.06, -0.2, 1.0, 0, "#f2a24b"], [0.05, 0.25, 0.9, 0.05, "#f2c84b"]], "spot": ["board", 0.7, { "text": "Two fish. They do not get along." }] },
	"rope_coil": { "c": [[0.35, 0.18, 0, 0, 0, "#c9a27a"]], "solid": false },
	"barrel": { "c": [[0.35, 0.9, 0, 0, 0, "#8a6a4a"]], "spot": ["search", 0.7] },
	"telescope": { "b": [[0.06, 1.2, 0.06, 0, 0, 0, "#4a4a52"], [0.14, 0.14, 0.9, 0, 1.2, -0.1, "#5a6f9a"]], "spot": ["pose", 0.7, { "pose": "shade", "text": "You look through the telescope. A roof. Then the moon." }], "solid": false },
	"star_chart": { "b": [[1.4, 0.9, 0.02, 0, 1.2, 0, "#2f3a5a"]], "s": [[0.03, -0.3, 1.5, 0.02, "#f7f4ef"], [0.03, 0.2, 1.4, 0.02, "#f7f4ef"], [0.03, 0.4, 1.8, 0.02, "#f7f4ef"]], "solid": false },
	"cat_bed": { "c": [[0.35, 0.12, 0, 0, 0, "cloth"]], "s": [[0.15, 0, 0.15, 0, "#d8a24a"]], "solid": false, "spot": ["board", 0.6, { "text": "The cat bed is occupied by an idea of a cat." }] },
	"scratch_post": { "c": [[0.08, 1.1, 0, 0, 0, "#c9a27a"]], "b": [[0.5, 0.06, 0.5, 0, 0, 0, "cloth"], [0.4, 0.06, 0.4, 0, 1.1, 0, "cloth"]] },
	"yarn": { "s": [[0.1, 0, 0.1, 0, "#ad7096"], [0.09, 0.25, 0.09, 0.1, "#5a6f9a"]], "solid": false },
	"sewing": { "b": [[1.1, 0.75, 0.6, 0, 0, 0, "wood"], [0.4, 0.3, 0.2, 0, 0.75, 0, "#f7f4ef"]], "spot": ["pose", 0.8, { "pose": "sew", "text": "You sew a straight line. Mostly straight." }] },
	"mannequin": { "c": [[0.03, 1.0, 0, 0, 0, "#4a4a52"], [0.2, 0.6, 0, 1.0, 0, "cloth"]], "solid": false },
	"fabric_rolls": { "c": [[0.12, 1.4, -0.3, 0, 0, "#ad7096"], [0.12, 1.3, 0.0, 0, 0, "#5a6f9a"], [0.12, 1.5, 0.3, 0, 0, "#d8a24a"]] },
	"exercise_mat": { "b": [[0.7, 0.03, 1.7, 0, 0, 0, "#7b526c"]], "spot": ["emote", 0.0, { "move": "situp" }], "solid": false },
	"weights": { "b": [[0.9, 0.5, 0.4, 0, 0, 0, "#4a4a52"]], "c": [[0.08, 0.3, -0.25, 0.5, 0, "#2a2a30"], [0.08, 0.3, 0.25, 0.5, 0, "#2a2a30"]], "spot": ["emote", 0.8, { "move": "squat" }] },
	"pullup_bar": { "b": [[0.08, 2.3, 0.08, -0.6, 0, 0, "#4a4a52"], [0.08, 2.3, 0.08, 0.6, 0, 0, "#4a4a52"], [1.3, 0.05, 0.05, 0, 2.15, 0, "#4a4a52"]], "spot": ["emote", 0.1, { "move": "pullup" }], "solid": false },
	"blackboard": { "b": [[2.4, 1.2, 0.04, 0, 0.9, 0, "#2f4a3a"]], "label": ["E = mc² (probably)", 1.5], "solid": false },
	"bath": { "b": [[1.7, 0.55, 0.8, 0, 0, 0, "#f7f4ef"], [1.5, 0.05, 0.6, 0, 0.5, 0, "#bfe3f2"]], "spot": ["pose", 0.8, { "pose": "wait", "text": "The bath. You consider it." }] },
	"sink": { "b": [[0.6, 0.85, 0.45, 0, 0, 0, "#efe9e2"], [0.5, 0.6, 0.03, 0, 1.0, -0.2, "#bfe3f2"]], "spot": ["board", 0.7, { "text": "You wash your hands. Good." }] },
	# 가게 꾸밈(shop_kit.gd)
	"espresso": { "b": [[0.5, 0.45, 0.4, 0, 0, 0, "#8a8a92"], [0.4, 0.06, 0.3, 0, 0.45, 0, "#4a4a52"], [0.06, 0.1, 0.06, -0.1, 0.12, 0.2, "#2a2a30"], [0.06, 0.1, 0.06, 0.1, 0.12, 0.2, "#2a2a30"]], "solid": false, "spot": ["pose", 0.9, { "pose": "grind", "text": "The machine hisses. Nobody knows what it is doing." }] },
	"cake_dome": { "c": [[0.22, 0.04, 0, 0, 0, "#f7f4ef"], [0.16, 0.12, 0, 0.04, 0, "#e8bfa4"]], "s": [[0.24, 0, 0.0, 0, "#dff2f7"]], "solid": false },
	"scale": { "b": [[0.3, 0.12, 0.25, 0, 0, 0, "#8a8a92"]], "c": [[0.14, 0.02, 0, 0.12, 0, "#cfc7c2"]], "solid": false },
	"menu_board": { "b": [[1.6, 0.9, 0.04, 0, 1.3, 0, "#2f3a2f"]], "label": ["COFFEE  2
TEA  2
CAKE  ask", 1.75], "solid": false },
	"oven_big": { "b": [[1.6, 1.4, 0.8, 0, 0, 0, "#b56a5a"], [0.8, 0.5, 0.05, 0, 0.4, 0.4, "#2a1e26"], [0.6, 0.15, 0.04, 0, 0.45, 0.42, "#f2a24b"]], "spot": ["pose", 1.0, { "pose": "knead", "text": "You check the oven. It is very much on." }] },
	"bread_rack": { "b": [[1.6, 1.6, 0.4, 0, 0, 0, "wood"], [1.5, 0.03, 0.38, 0, 0.5, 0, "wood"], [1.5, 0.03, 0.38, 0, 1.0, 0, "wood"]], "s": [[0.1, -0.5, 0.53, 0, "#d8a24a"], [0.1, 0.0, 0.53, 0, "#c9a27a"], [0.1, 0.5, 1.03, 0, "#d8a24a"], [0.1, -0.2, 1.03, 0, "#c9a27a"]] },
	"flour_sacks": { "b": [[0.5, 0.6, 0.35, 0, 0, 0, "#efe9e2"], [0.5, 0.5, 0.35, 0.55, 0, 0.05, "#efe2cf"]], "solid": true },
	"produce_bin": { "b": [[0.9, 0.55, 0.6, 0, 0, 0, "#b48a5a"]], "s": [[0.08, -0.25, 0.55, 0, "#ff2d55"], [0.08, 0.0, 0.55, 0.1, "#6f9a5a"], [0.08, 0.25, 0.55, -0.1, "#f2a24b"], [0.08, -0.1, 0.6, -0.15, "#ff2d55"]], "spot": ["board", 0.8, { "text": "Today's apples. Yesterday's apples are in the other bin." }] },
	"ice_counter": { "b": [[2.0, 0.85, 0.7, 0, 0, 0, "#dfe6ea"], [1.9, 0.06, 0.6, 0, 0.85, 0, "#f7fbfd"]], "s": [[0.07, -0.6, 0.9, 0, "#8a9aa8"], [0.07, -0.2, 0.9, 0.1, "#a88a8a"], [0.07, 0.3, 0.9, -0.1, "#8a9aa8"]] },
	"nets": { "b": [[2.0, 1.0, 0.02, 0, 1.2, 0, "#c9b18a"]], "solid": false },
	"can_fridge": { "b": [[1.0, 1.9, 0.6, 0, 0, 0, "#f7f4ef"], [0.9, 1.6, 0.02, 0, 0.15, 0.31, "#bfe3f2"]], "c": [[0.05, 0.12, -0.25, 0.5, 0.15, "#b56a5a"], [0.05, 0.12, 0.0, 0.5, 0.15, "#5a6f9a"], [0.05, 0.12, 0.25, 1.1, 0.15, "#d8a24a"]], "spot": ["fridge", 0.9] },
	"magazine_rack": { "b": [[1.0, 1.2, 0.3, 0, 0, 0, "#4a4a52"], [0.25, 0.32, 0.02, -0.3, 0.8, 0.16, "#ad7096"], [0.25, 0.32, 0.02, 0.0, 0.8, 0.16, "#f2c84b"], [0.25, 0.32, 0.02, 0.3, 0.8, 0.16, "#5a6f9a"]], "spot": ["board", 0.7, { "text": "MONTHLY BENCH. This month: benches." }] },
	"umbrella_stand": { "c": [[0.25, 0.5, 0, 0, 0, "#4a4a52"], [0.02, 0.9, -0.08, 0.3, 0, "#2a2a30"], [0.02, 0.9, 0.08, 0.3, 0.05, "#2a2a30"]], "s": [[0.12, -0.08, 1.15, 0, "#ad7096"], [0.12, 0.08, 1.15, 0.05, "#5a6f9a"]] },
}

## 이 집의 틀과 손질 — 문 번호와 주인(없으면 문패 이름)으로 늘 같게 정해진다
static func plan(t: Node, door_i: int, owner: Node) -> Dictionary:
	var ls := layouts()
	var rng := RandomNumberGenerator.new(); rng.seed = hash("%s/%d" % [owner.get("handle") if owner else "", door_i])
	var pick: Dictionary = ls[door_i % ls.size()] if not ls.is_empty() else {}
	if owner:
		var job := String(owner.get("job"))
		var by_job := ls.filter(func(l: Dictionary) -> bool: return job != "" and job in l.get("jobs", []))
		if not by_job.is_empty(): pick = by_job[rng.randi() % by_job.size()]
		else: pick = _by_mind(ls, owner.get("mind"), rng)
	var shape: String = ["rect", "rect", "ell", "long", "wide", "ell"][rng.randi() % 6]
	var sw := rng.randf_range(0.9, 1.2); var sd := rng.randf_range(0.9, 1.15)
	if shape == "long": sw *= 1.25; sd *= 0.88
	elif shape == "wide": sd *= 1.18
	var hue := rng.randf_range(-0.06, 0.06)
	var wall := Color(String(pick.get("wall", "efe2cf"))); wall.h = fposmod(wall.h + hue, 1.0)
	var floor := Color(String(pick.get("floor", "c9a27a"))).lerp(Color(["c9a27a", "8a6a4a", "b8b0aa", "e6d9c8"][rng.randi() % 4]), rng.randf_range(0.0, 0.35))
	var cloth: Color = owner.get("fig").color.lerp(Color("f7f4ef"), 0.25) if owner and owner.get("fig") else Color("ad7096")
	return { "layout": pick, "w": float(pick.get("w", 10)) * sw, "d": float(pick.get("d", 8)) * sd, "sx": sw, "sz": sd, "shape": shape, "mirror": rng.randf() < 0.5,
		"wall": wall, "floor": floor, "cloth": cloth, "seed": rng.randi(), "mind": owner.get("mind") if owner else null }

## 성격으로 고르기 — 틀마다 어울리는 성격(아래 표)과의 점수 + 좋아하는 것. 점수 상위 넷 중 하나(같은 성격끼리도 집이 다르게)
const FIT := {
	"Bookworm": { "curious": 1.0, "social": -0.4 }, "Scholar": { "curious": 1.0, "lazy": -0.5 }, "Night Owl": { "curious": 0.7, "social": -0.6 }, "Collector": { "curious": 0.6, "temper": 0.3 },
	"Tea Room": { "social": 1.0, "temper": -0.4 }, "Family House": { "social": 0.9 }, "Cosy Cottage": { "social": 0.4, "lazy": 0.2 }, "Cat Person": { "social": -0.3, "lazy": 0.4 },
	"Gamer": { "lazy": 1.0 }, "Studio Flat": { "lazy": 0.5, "social": -0.2 }, "Hoarder": { "lazy": 0.8, "temper": 0.3 }, "Retro": { "lazy": 0.3, "social": 0.3 },
	"Sailor": { "brave": 1.0 }, "Fitness": { "brave": 0.8, "lazy": -0.8 }, "Tinkerer": { "brave": 0.4, "curious": 0.4 }, "Minimalist": { "temper": 0.6, "lazy": -0.4 },
	"Painter's Loft": { "curious": 0.5, "temper": -0.3 }, "Gardener": { "lazy": -0.5, "temper": -0.4 }, "Tailor": { "temper": -0.2, "lazy": -0.4 }, "Old Timer": { "lazy": 0.3, "brave": -0.3 },
	"Musician": { "social": 0.5, "brave": 0.3 }, "Cook's Kitchen": { "social": 0.4, "lazy": -0.3 },
}
static func _by_mind(ls: Array, m: Variant, rng: RandomNumberGenerator) -> Dictionary:
	if m == null: return ls[rng.randi() % ls.size()]
	var scored: Array = []
	for l in ls:
		var f: Dictionary = FIT.get(String(l["name"]), {})
		var s := 0.0
		for k in f: s += float(f[k]) * (float(m.get(k)) - 0.5)
		var likes: Array = m.get("likes")
		if "boat" in likes and l["name"] == "Sailor": s += 0.4
		if ("tree" in likes or "grass" in likes) and l["name"] == "Gardener": s += 0.4
		if "lookout" in likes and l["name"] == "Night Owl": s += 0.4
		scored.append([s + rng.randf() * 0.15, l])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return scored[rng.randi() % mini(4, scored.size())][1]

## 짓기 — 바닥·벽(town_interior._shell)이 선 뒤. ㄱ자면 뒤 모서리 하나를 막고 그 안 가구는 뺀다. 좌우 뒤집기, 크기 비율대로 자리
static func build(t: Node, rm: Dictionary, p: Dictionary, mode := "all") -> void:
	var o: Vector3 = rm["o"]; var w: float = rm["w"]; var d: float = rm["d"]
	var rng := RandomNumberGenerator.new(); rng.seed = int(p["seed"])
	var mx := -1.0 if p["mirror"] else 1.0
	var wall_m: Material = t.call("_mat", (p["wall"] as Color).darkened(0.12))
	var cut := Rect2()
	if p["shape"] == "ell" and mode != "upper":   # ㄱ자 — 뒤쪽 한 모서리를 벽으로 막는다(위층은 통으로)
		var cw := w * 0.32; var cd := d * 0.38; var side := 1.0 if rng.randf() < 0.5 else -1.0
		cut = Rect2(Vector2(w / 2.0 - cw if side > 0 else -w / 2.0, -d / 2.0), Vector2(cw, cd))
		t.call("_box", Vector3(cw, 2.8, cd), o + Vector3(cut.position.x + cw / 2.0, 0, cut.position.y + cd / 2.0), wall_m)
	var lay: Dictionary = p["layout"]
	for wl in (lay.get("walls", []) if mode != "upper" else []):
		var a := Vector2(float(wl[0]) * mx * p["sx"], float(wl[1]) * p["sz"]); var b := Vector2(float(wl[2]) * mx * p["sx"], float(wl[3]) * p["sz"])
		var mid := (a + b) / 2.0; var len := a.distance_to(b)
		var wb: MeshInstance3D = t.call("_box", Vector3(0.12 if absf(a.x - b.x) < 0.01 else len, 2.4, len if absf(a.x - b.x) < 0.01 else 0.12), o + Vector3(mid.x, 0, mid.y), wall_m)
	var stair: Rect2 = rm.get("stair", Rect2())   # 계단 자리(2층집) — 그 위엔 가구를 두지 않는다
	for pc in lay.get("pieces", []):
		var kind := String(pc[0])
		if (mode == "ground" and kind in BEDROOM) or (mode == "upper" and not kind in BEDROOM): continue
		var at := Vector2(float(pc[1]) * mx * p["sx"], float(pc[2]) * p["sz"])
		at.x = clampf(at.x, -w / 2.0 + 0.5, w / 2.0 - 0.5); at.y = clampf(at.y, -d / 2.0 + 0.35, d / 2.0 - 1.9)
		if cut.has_area() and cut.grow(0.4).has_point(at): continue
		if absf(at.x) < 1.0 and at.y > d / 2.0 - 2.2: continue   # 문길
		if stair.has_area() and stair.grow(0.6).has_point(at): continue
		var yaw := deg_to_rad(float(pc[3])) * mx
		piece(t, rm, String(pc[0]), o + Vector3(at.x, 0, at.y), yaw, p)
	# 그 사람의 손 — 게으르면 잡동사니, 부지런하면 화분·액자, 좋아하는 것
	if mode == "upper" and not (rm["spots"] as Array).any(func(sp: Dictionary) -> bool: return sp["kind"] == "bed"):   # 틀의 침대가 계단 자리에 걸렸다 — 계단 반대쪽 뒤에
		var far := -signf(stair.position.x + stair.size.x / 2.0) if stair.has_area() else 1.0
		piece(t, rm, "bed", o + Vector3(far * (w / 2.0 - 1.3), 0, -d / 2.0 + 1.5), 0.0, p)
		piece(t, rm, "wardrobe", o + Vector3(far * (w / 2.0 - 3.0), 0, -d / 2.0 + 0.45), 0.0, p)
	if mode == "upper":   # 위층 — 욕실 한쪽, 러그, 화분
		piece(t, rm, "bath", o + Vector3(-w / 2.0 + 1.3, 0, d / 2.0 - 2.4), PI / 2.0 * mx, p)
		piece(t, rm, "sink", o + Vector3(-w / 2.0 + 0.5, 0, d / 2.0 - 1.0), PI / 2.0 * mx, p)
		piece(t, rm, "rug", o + Vector3(0.6, 0, 0.4), 0.0, p); piece(t, rm, "plant", o + Vector3(w / 2.0 - 0.6, 0, d / 2.0 - 0.8), 0.0, p)
		return
	var m: Variant = p["mind"]
	var lazy := float(m.get("lazy")) if m else 0.5
	var extras: Array = []
	if lazy > 0.62: extras += ["books_pile", "boxes", "yarn"].slice(0, 1 + rng.randi() % 3)
	elif lazy < 0.38: extras += ["plant", "plant", "frames"].slice(0, 1 + rng.randi() % 3)
	if m and "boat" in (m.get("likes") as Array): extras.append("aquarium")
	for e in extras:
		for tries in 8:
			var at := Vector2(rng.randf_range(-w / 2.0 + 0.8, w / 2.0 - 0.8), rng.randf_range(-d / 2.0 + 0.8, d / 2.0 - 2.2))
			if (cut.has_area() and cut.grow(0.4).has_point(at)) or absf(at.x) < 1.2 or (stair.has_area() and stair.grow(0.6).has_point(at)): continue
			piece(t, rm, e, o + Vector3(at.x, 0, at.y), rng.randf() * TAU if e != "frames" else 0.0, p); break

## 가구 하나 — 표(PIECES)대로
static func piece(t: Node, rm: Dictionary, kind: String, at: Vector3, yaw: float, p: Dictionary) -> void:
	var spec: Dictionary = PIECES.get(kind, {})
	if spec.is_empty(): return
	var root := Node3D.new(); root.position = at; root.rotation.y = yaw
	t.call("_add", root)
	var solid: bool = spec.get("solid", true)
	for b in spec.get("b", []):
		t.call("_box", Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), _col(t, b[6], p), solid, root)
	for c in spec.get("c", []):
		var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = c[0]; cm.bottom_radius = c[0]; cm.height = c[1]; mi.mesh = cm
		mi.material_override = _col(t, c[5], p); mi.position = Vector3(c[2], c[3] + float(c[1]) / 2.0, c[4]); root.add_child(mi)
	for s in spec.get("s", []):
		var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = s[0]; sm.height = float(s[0]) * 2.0; mi.mesh = sm
		mi.material_override = _col(t, s[4], p); mi.position = Vector3(s[1], s[2] + float(s[0]), s[3]); root.add_child(mi)
	for m in spec.get("m", []):
		var n: Node3D = t.call("_scatter", String(m[0]), Vector3.ZERO, float(m[3]))
		if n:
			n.get_parent().remove_child(n); root.add_child(n); n.position = Vector3(m[1], 0.4 if kind == "plant_big" or kind == "planter" else 0.0, m[2])
	if spec.get("books", false):
		for r in 4:
			for k in 6: t.call("_box", Vector3(0.18, 0.32, 0.25), Vector3(-0.6 + k * 0.24, 0.12 + r * 0.48, 0.1), _col(t, ["#b56a5a", "#5a6f9a", "#d8a24a", "#6f9a5a"][(r + k) % 4], p), false, root)
	for it in ITEMS.get(kind, []):   # 가구 위 진짜 물건
		t.call("_room_item", String(it[0]), root.to_global(Vector3(it[1], it[2], it[3])))
	if spec.has("label"):
		var lb := Label3D.new(); lb.text = String(spec["label"][0]); lb.font_size = 56; lb.pixel_size = 0.004; lb.modulate = Color("f7f4ef"); lb.outline_size = 0
		lb.position = Vector3(0, float(spec["label"][1]), 0.03); root.add_child(lb)
	for key in ["spot", "spot2"]:
		if not spec.has(key): continue
		var sp: Array = spec[key]
		var side := float(sp[2]) if sp.size() > 2 and (sp[2] is float or sp[2] is int) else 0.0
		var extra: Dictionary = sp[2] if sp.size() > 2 and sp[2] is Dictionary else {}
		var local := Vector3(side if key == "spot2" else (-0.55 if kind == "sofa" else 0.0), 0, float(sp[1]))
		var world := at + local.rotated(Vector3.UP, yaw)
		if extra.has("top"): world.y += float(extra["top"])   # 침대 위 — 누운 몸이 이불에 묻히지 않게(운영자 2026-10-06)
		t.call("_spot", rm, String(sp[0]), world, yaw + (0.0 if String(sp[0]) in ["sit", "bed"] else PI), extra)

static func _col(t: Node, c: Variant, p: Dictionary) -> Material:
	var s := String(c)
	if s == "cloth": return t.call("_mat", p["cloth"])
	if s == "wood": return t.call("_mat", Color("8a6a4a"))
	return t.call("_mat", Color(s))
