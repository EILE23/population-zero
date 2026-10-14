class_name District
extends RefCounted
## 동네(운영자 2026-10-14: "각 블록들이 섹션별로 어우러져야 — 개성 있게 모여서 베네치아 도시가 되는 것처럼, 정리가 돼야") —
## 블록 3×3(120m)이 한 동네. 동네마다 한 가지 얼굴: 벽 빛깔 묶음, 지붕 빛깔, 벽 재질, 집 모양 식구, 울타리, 생울타리 빛, 꽃 한 가지, 가로수 한 가지.
## 집·마당·가로수·울타리가 다 이걸 따른다 — 블록끼리는 달라도 한 동네 안은 한 결로 어우러지고, 마당은 깎은 생울타리로 정리된다

const SIZE := 3   # 블록 수(한 변)
const THEMES := [
	{ "name": "Brick Quarter", "walls": ["b56a5a", "a0584a", "9a6450", "c07a5e"], "roof": ["5a4a52", "4a4a52"], "mat": "brick", "styles": ["townhouse", "terrace", "cottage"], "fence": 1, "hedge": "4f7a36", "flower": "flower_redA", "tree": "CommonTree_3" },
	{ "name": "Pastel Row", "walls": ["e8bfa4", "c4b0d0", "b5c9a8", "8fb8cc", "f0c8d0"], "roof": ["e0875a", "d06a50"], "mat": "colour", "styles": ["townhouse", "cottage", "terrace"], "fence": 0, "hedge": "6f9a4a", "flower": "flower_purpleA", "tree": "CommonTree_1" },
	{ "name": "Garden Suburb", "walls": ["efe9e2", "f7f4ef", "e6d3a5"], "roof": ["7c9a62", "6f8a5a"], "mat": "plank", "styles": ["bungalow", "cottage", "garage", "wing"], "fence": 1, "hedge": "5f8a3e", "flower": "flower_yellowA", "tree": "CommonTree_2" },
	{ "name": "Stone Village", "walls": ["bfb6b0", "a8a29a", "cfc7c2"], "roof": ["4a4a52", "6a6470"], "mat": "stucco", "styles": ["cottage", "wing", "turret"], "fence": 2, "hedge": "4a6a3a", "flower": "flower_yellowB", "tree": "Pine_1" },
	{ "name": "Harbour Blue", "walls": ["dfe6ea", "8fb8cc", "f7f4ef", "7a90b0"], "roof": ["7a90b0", "4a6a8a"], "mat": "colour", "styles": ["cottage", "townhouse", "bungalow"], "fence": 0, "hedge": "5f8a3e", "flower": "flower_redB", "tree": "CommonTree_5" },
	{ "name": "Orchard Lane", "walls": ["e6d3a5", "e8bfa4", "efe9e2"], "roof": ["c45a4a", "e0875a"], "mat": "plank", "styles": ["cottage", "bungalow", "wing"], "fence": 0, "hedge": "6f9a4a", "flower": "flower_redC", "tree": "CommonTree_4" },
]

static func of_block(b: Vector2i) -> Dictionary:
	var d := Vector2i(floori(b.x / float(SIZE)), floori(b.y / float(SIZE)))
	return THEMES[absi(hash("district/%d,%d" % [d.x, d.y])) % THEMES.size()]

static func at(p: Vector3) -> Dictionary:
	return of_block(CityMap.block_of(Vector2(p.x, p.z)))

## 이 동네 집 모양 — 사람이 고른 모양이 동네 식구면 그대로, 아니면 동네 식구 중 하나(이름으로 고른다)
static func style_in(theme: Dictionary, want: String, key: String) -> String:
	var fam: Array = theme["styles"]
	if want in fam: return want
	return String(fam[absi(hash("st/" + key)) % fam.size()])
