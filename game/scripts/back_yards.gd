class_name BackYards
extends RefCounted
## 뒤뜰(운영자 2026-10-13: 동물의 숲 사진 — "녹지 블록 하나마다 이런 식으로 가득 차 있는 형태", "부딪히면 막혀야") — 집 뒤 5m 를 한 장면으로 빽빽하게.
## 팩 소품(kit_props: Kenney Furniture·Nature, 키 30cm 넘으면 충돌): 뒤 울타리·옆 울타리 따라 덤불·꽃 띠, 가운데엔 그 집 사람 성미대로 한 장면 —
##   사교적 → 다과 탁자(식탁보·방석 의자 넷·화분) / 물놀이 풀 · 게으름 → 선베드 둘과 협탁·화분, 해먹 · 호기심 → 화분 작업대(화분·모종·상자)
##   성미 → 장작 마당(장작더미·그루터기·창고) · 대담 → 마당 캠핑(작은 텐트·모닥불·통나무 의자) · 누구나 → 텃밭(이랑·당근·호박·옥수수), 그네
## 같은 성미라도 이름으로 조금 흔들어 이웃끼리 같은 뒤뜰이 안 나온다. 앉는 데는 bench, 눕는 데는 bed, 보는 데는 lookout(주민도 쓴다)
## 번화가 가게 뒤는 짐 마당(service) — 상자 더미·쓰레기통·직원 의자·화분

const BY_TRAIT := {
	"social": ["tea", "pool"], "lazy": ["lounge", "hammock"], "curious": ["potting", "tea"],
	"temper": ["woodyard", "potting"], "brave": ["camp", "swingset"],
}
const ANY := ["veggie", "veggie", "swingset"]

## 이 집 뒤뜰 — z 는 [back_z, house_back], x 는 c.x ± w/2
static func build(t, c: Vector3, back_z: float, house_back: float, w: float, handle: String, seed: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var tr := ResidentMind.traits_of(handle) if handle != "" else { "social": rng.randf(), "temper": rng.randf(), "curious": rng.randf(), "lazy": rng.randf(), "brave": rng.randf() }
	var score := {}
	for k in BY_TRAIT:
		for f in BY_TRAIT[k]: score[f] = maxf(float(score.get(f, 0.0)), float(tr[k]) + rng.randf() * 0.45)
	for f in ANY: score[f] = maxf(float(score.get(f, 0.0)), 0.3 + rng.randf() * 0.5)
	var picks: Array = score.keys()
	picks.sort_custom(func(a, b): return float(score[a]) > float(score[b]))
	if c.y > 0.3: picks.erase("pool")   # 비탈 터엔 물놀이 풀이 없다(수면은 높이 0)
	var hw := w / 2.0 - 0.45
	KitProps.border(t, Vector3(c.x - hw, c.y, back_z + 0.3), Vector3(c.x + hw, c.y, back_z + 0.3), rng)   # 뒤 울타리 덤불·꽃
	for s in [-1.0, 1.0]: KitProps.border(t, Vector3(c.x + s * hw, c.y, back_z + 0.9), Vector3(c.x + s * hw, c.y, house_back - 0.6), rng, 0.8)
	var mid := Vector3(c.x, c.y, (back_z + 0.8 + house_back) / 2.0)
	_scene(t, String(picks[0]), mid, w - 2.0, house_back - back_z - 1.2, rng)

static func _scene(t, f: String, at: Vector3, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var sx := rng.randf_range(-0.4, 0.4)
	match f:
		"tea":   # 다과 탁자 — 식탁보 탁자, 방석 의자 넷, 화분 둘, 바구니(상자)
			var tc := at + Vector3(sx, 0, 0)
			KitProps.f(t, "tableCloth", tc, 0.0)
			for q in 4:
				var a := q * PI / 2.0
				var off := Vector3(sin(a) * (1.25 if q % 2 == 1 else 0.85), 0, cos(a) * (1.25 if q % 2 == 1 else 0.85))
				KitProps.f(t, "chairCushion", tc + off, a + PI)
			t.spots.append({ "pos": tc + Vector3(0, 0, 1.3), "kind": "bench", "yaw": PI })
			KitProps.f(t, "pottedPlant", tc + Vector3(-w / 2.0 + 0.3, 0, -d / 2.0 + 0.3)); KitProps.f(t, "pottedPlant", tc + Vector3(w / 2.0 - 0.3, 0, d / 2.0 - 0.3))
			KitProps.f(t, "cardboardBoxOpen", tc + Vector3(w / 2.0 - 0.4, 0, -d / 2.0 + 0.4), rng.randf())
			for q in 2: KitProps.k(t, "food", ["cake", "cup-tea", "cupcake", "pie", "mug"][(q + rng.randi()) % 5], tc + Vector3(-0.3 + q * 0.6, 0.73, 0), rng.randf(), 1.0, false)   # 상 위 다과
		"pool":   # 물놀이 풀 — 진짜 물(헤엄 규칙 그대로), 둘레 화분
			t.water.disc(at + Vector3(sx, 0, 0), 1.2)
			KitProps.f(t, "loungeChairRelax", at + Vector3(sx + 2.0, 0, 0.2), -PI / 2.0)
			KitProps.n(t, "pot_large", at + Vector3(sx - 2.0, 0, -0.6), 0.0, 2.4)
		"lounge":   # 선베드 둘, 협탁, 화분, 깔개
			KitProps.f(t, "rugRound", at, 0.0, false)
			for s in [-1.0, 1.0]: KitProps.f(t, "loungeChair", at + Vector3(s * 1.1 + sx, 0, 0), PI)
			KitProps.f(t, "sideTable", at + Vector3(sx, 0, -0.2))
			t.spots.append({ "pos": at + Vector3(1.1 + sx, 0.35, 0), "kind": "bed", "yaw": PI })
			KitProps.f(t, "pottedPlant", at + Vector3(-w / 2.0 + 0.3, 0, -d / 2.0 + 0.3))
			KitProps.k(t, "food", "cocktail", at + Vector3(sx, 0.6, -0.2), 0.0, 1.0, false)
			KitProps.k(t, "holiday", "lantern", at + Vector3(w / 2.0 - 0.3, 0, -d / 2.0 + 0.3), 0.0, 0.8)
		"hammock":   # 해먹 — 기둥 둘 사이, 누워 쉰다(침대와 같은 bed 자리)
			var wood: Material = t._mat(Color("8a6a4a"))
			for s in [-1.3, 1.3]: t._box(Vector3(0.12, 1.4, 0.12), at + Vector3(s + sx, 0, 0), wood)
			t._box(Vector3(2.2, 0.06, 0.8), at + Vector3(sx, 0.55, 0), t._mat([Color("ad7096"), Color("e6d3a5"), Color("7a90b0")][rng.randi() % 3]), false)
			t.spots.append({ "pos": at + Vector3(sx, 0.62, 0), "kind": "bed", "yaw": PI / 2.0 })
			KitProps.f(t, "pottedPlant", at + Vector3(-w / 2.0 + 0.3, 0, d / 2.0 - 0.3))
		"potting":   # 화분 작업대 — 탁자 위 작은 화분·모종, 큰 화분, 상자 더미
			var tb := at + Vector3(sx, 0, -0.3)
			KitProps.f(t, "table", tb, 0.0)
			for q in 3: KitProps.n(t, "pot_small", tb + Vector3(-0.6 + q * 0.6, 0.73, 0), rng.randf() * TAU, 2.0, false)
			KitProps.f(t, "plantSmall%d" % (1 + rng.randi() % 3), tb + Vector3(0.3, 0.73, 0.15), 0.0, false)
			for q in 2: KitProps.n(t, "pot_large", at + Vector3(-w / 2.0 + 0.5 + q * 0.9, 0, d / 2.0 - 0.4), 0.0, 2.2)
			for q in 3: KitProps.f(t, "cardboardBoxClosed", at + Vector3(w / 2.0 - 0.4, q * 0.62, d / 2.0 - 0.4 - (q % 2) * 0.1), rng.randf() * 0.4)
			t.spots.append({ "pos": tb + Vector3(0, 0, 0.8), "kind": "lookout", "yaw": PI })
		"woodyard":   # 장작 마당 — 창고, 장작더미 둘, 그루터기(도끼질 자리)
			t._box(Vector3(2.0, 2.0, 1.5), at + Vector3(-w / 2.0 + 1.1, 0, -0.2), t._mat([Color("6f8a5a"), Color("b56a5a"), Color("7a90b0")][rng.randi() % 3]))
			t._box(Vector3(2.3, 0.08, 1.8), at + Vector3(-w / 2.0 + 1.1, 2.0, -0.2), t._mat(Color("3a3a42")), false)
			KitProps.n(t, "log_stack", at + Vector3(0.6 + sx, 0, -0.4), PI / 2.0, 3.0)
			KitProps.n(t, "log_stackLarge", at + Vector3(w / 2.0 - 0.6, 0, 0.1), 0.0, 2.6)
			KitProps.n(t, "stump_round", at + Vector3(0.4 + sx, 0, 0.8), 0.0, 2.6)
			KitProps.k(t, "survival", "tool-axe", at + Vector3(0.4 + sx, 0.55, 0.8), 0.3, 1.0, false)
			KitProps.k(t, "survival", "workbench", at + Vector3(w / 2.0 - 0.6, 0, -d / 2.0 + 0.5), 0.0)
			t.spots.append({ "pos": at + Vector3(0.4 + sx, 0, 1.4), "kind": "lookout", "yaw": PI })
		"camp":   # 마당 캠핑 — 작은 텐트, 모닥불, 통나무 의자 둘
			KitProps.k(t, "survival", "tent-canvas", at + Vector3(-w / 2.0 + 1.1, 0, -0.2), 0.3)
			KitProps.k(t, "survival", "bedroll", at + Vector3(-w / 2.0 + 1.0, 0, 1.0), 0.0, 1.0, false)
			KitProps.n(t, "campfire_stones", at + Vector3(0.8 + sx, 0, 0.1), 0.0, 2.6, false)
			for s in [-1.0, 1.0]: KitProps.n(t, "log", at + Vector3(0.8 + sx + s * 1.0, 0, 0.1), PI / 2.0, 2.4)
			t.spots.append({ "pos": at + Vector3(0.8 + sx, 0, 1.0), "kind": "lookout", "yaw": PI })
		"swingset":
			t._swing(at + Vector3(sx, 0, 0))
			KitProps.f(t, "benchCushionLow", at + Vector3(w / 2.0 - 0.6, 0, 0.3), -PI / 2.0)
		_:   # veggie — 흙 이랑 셋, 당근·순무·호박·옥수수
			var crops := ["crop_carrot", "crop_turnip", "crop_pumpkin", "crops_leafsStageB", "crops_cornStageC"]
			for r in 3:
				var rz := at.z - d / 2.0 + 0.5 + r * (d - 1.0) / 2.0
				for hx in [-w / 4.0, w / 4.0]: KitProps.n(t, "crops_dirtRow", Vector3(at.x + hx, at.y, rz), PI / 2.0, 3.0, false)
				var kind: String = crops[(r + rng.randi()) % crops.size()]
				for q in 5: KitProps.n(t, kind, Vector3(at.x - w / 2.0 + 0.5 + q * (w - 1.0) / 4.0, 0.05, rz), rng.randf() * TAU, 1.3 if kind.begins_with("crops_corn") else 1.1, kind.begins_with("crops_corn"))
			KitProps.k(t, "survival", "bucket", at + Vector3(w / 2.0 - 0.3, 0, d / 2.0 - 0.2), 0.0)   # 물통·괭이
			KitProps.k(t, "survival", "tool-hoe", at + Vector3(w / 2.0 - 0.7, 0, d / 2.0 - 0.2), 0.4, 1.0, false)

## 가게 뒤 짐 마당 — 상자 더미·쓰레기통·직원 의자·화분·덤불 띠
static func service(t, c: Vector3, back_z: float, house_back: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	KitProps.border(t, Vector3(c.x - 3.0, c.y, back_z + 0.3), Vector3(c.x + 3.0, c.y, back_z + 0.3), rng)
	var mid := (back_z + house_back) / 2.0
	for q in 3 + rng.randi() % 3: KitProps.f(t, "cardboardBoxClosed", Vector3(c.x - 2.2 + (q % 3) * 0.55, c.y + (q / 3) * 0.62, house_back - 0.8), rng.randf() * 0.5)
	t._bin(Vector3(c.x + 2.6, c.y, mid)); t._bin(Vector3(c.x + 2.0, c.y, mid + 0.6))
	KitProps.f(t, "benchCushion", Vector3(c.x - 0.6, c.y, mid), 0.0)
	t.spots.append({ "pos": Vector3(c.x - 0.6, c.y, mid + 0.5), "kind": "bench", "yaw": PI })
	KitProps.f(t, "pottedPlant", Vector3(c.x + 0.8, c.y, mid - 0.5))
