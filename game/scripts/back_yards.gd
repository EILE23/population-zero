class_name BackYards
extends RefCounted
## 뒤뜰(운영자 2026-10-12: "여전히 녹지가 많고", "상호작용 자꾸 복붙할래?") — 블록 안 집 뒤의 빈 띠(9m)를 공용 놀이터 도장 대신 집마다의 뒤뜰로.
## 뒤 울타리를 띠 끝(골목 바로 앞)까지 물리고, 그 안을 세 자리(집 쪽·가운데·끝)로 나눠 그 집 사람 성미대로 고른다:
##   사교적 → 바비큐·피크닉 / 물놀이 풀(헤엄) · 대담 → 트램펄린(올라서면 튄다) / 농구 골대 · 게으름 → 해먹(눕는다) / 볕 드는 데크
##   호기심 → 온실 / 꽃밭 · 성미 → 창고와 장작더미 / 작업대 · 누구나 → 텃밭, 그네 한 틀
## 같은 성미라도 이름으로 조금 흔들어 이웃끼리 같은 뒤뜰이 안 나온다. 놀이는 이미 있는 규칙(벤치·그네·눕기·헤엄·전망)에 트램펄린 하나를 더했다(town_social)
## 번화가 가게 뒤는 짐 마당(service) — 상자·팔레트·쓰레기통·직원 의자

const BY_TRAIT := {
	"social": ["bbq", "pool"], "brave": ["trampoline", "hoop"], "lazy": ["hammock", "deck"],
	"curious": ["greenhouse", "flowers"], "temper": ["shed", "bench_work"],
}
const ANY := ["garden", "swingset", "flowers", "garden"]

## 이 집 뒤뜰 — 띠 [back_z, house_back] 사이, 가운데 x = c.x, 폭 w
static func build(t, c: Vector3, back_z: float, house_back: float, w: float, handle: String, seed: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var tr := ResidentMind.traits_of(handle) if handle != "" else { "social": rng.randf(), "temper": rng.randf(), "curious": rng.randf(), "lazy": rng.randf(), "brave": rng.randf() }
	var score := {}
	for k in BY_TRAIT:
		for f in BY_TRAIT[k]: score[f] = maxf(float(score.get(f, 0.0)), float(tr[k]) + rng.randf() * 0.45)
	for f in ANY: score[f] = maxf(float(score.get(f, 0.0)), 0.35 + rng.randf() * 0.45)
	var picks: Array = score.keys()
	picks.sort_custom(func(a, b): return float(score[a]) > float(score[b]))
	var depth := house_back - back_z
	var slots := 3 if depth > 7.5 else 2
	var used := {}
	var n := 0
	for f in picks:
		if n >= slots: break
		if f == "pool" and used.has("trampoline") or f == "trampoline" and used.has("pool"): continue   # 둘 다면 마당이 놀이공원
		var z := house_back - 1.6 - n * (depth - 1.0) / slots
		_feature(t, f, Vector3(c.x, 0, z), w, rng, n == 0)
		used[f] = true; n += 1

static func _feature(t, f: String, at: Vector3, w: float, rng: RandomNumberGenerator, near_house: bool) -> void:
	var wood: Material = t._mat(Color("8a6a4a")); var iron: Material = t._mat(Color("4a4a52"))
	var sx := rng.randf_range(-0.6, 0.6)   # 자리 안에서 조금씩 비켜
	match f:
		"bbq":
			t._box(Vector3(0.6, 0.85, 0.5), at + Vector3(-2.0 + sx, 0, 0), t._mat(Color("2a2a30")))
			t._box(Vector3(0.7, 0.04, 0.6), at + Vector3(-2.0 + sx, 0.85, 0), iron, false)
			t.spots.append({ "pos": at + Vector3(-2.0 + sx, 0, 0.7), "kind": "lookout", "yaw": PI })
			t._box(Vector3(1.6, 0.75, 0.8), at + Vector3(1.0 + sx, 0, 0), wood)
			t._bench(at + Vector3(1.0 + sx, 0, 0.9))
		"pool":   # 물놀이 풀 — 진짜 물(헤엄 규칙 그대로)
			t.water.disc(at + Vector3(sx, 0, 0), 1.25)
			t._box(Vector3(0.5, 0.45, 0.5), at + Vector3(2.4, 0, 0.4), t._mat(Color("f2c84b")), false)   # 튜브 상자
		"trampoline":
			var tp := at + Vector3(sx, 0, 0)
			var leg := MeshInstance3D.new(); var lm := CylinderMesh.new(); lm.top_radius = 1.35; lm.bottom_radius = 1.35; lm.height = 0.5; leg.mesh = lm; leg.material_override = t._mat(Color("4a6a8a")); leg.position = tp + Vector3(0, 0.25, 0); t._add(leg)
			var mat := MeshInstance3D.new(); var mm := CylinderMesh.new(); mm.top_radius = 1.15; mm.bottom_radius = 1.15; mm.height = 0.04; mat.mesh = mm; mat.material_override = t._mat(Color("1b1b20")); mat.position = tp + Vector3(0, 0.51, 0); t._add(mat)
			var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 1.35; cy.height = 0.53; cs.shape = cy; cs.position = tp + Vector3(0, 0.265, 0); sb.add_child(cs); t._add(sb)
			t._box(Vector3(0.6, 0.25, 0.4), tp + Vector3(0, 0, 1.55), t._mat(Color("8a6a4a")))   # 디딤대
			t.trampolines.append(tp)
		"hoop":   # 농구 골대 — 장식 + 서서 보는 자리
			t._box(Vector3(0.1, 2.9, 0.1), at + Vector3(2.2, 0, -0.6), iron)
			t._box(Vector3(1.1, 0.75, 0.05), at + Vector3(2.2, 2.75, -0.5), t._mat(Color("f7f4ef")), false)
			var ring := MeshInstance3D.new(); var rmesh := TorusMesh.new(); rmesh.inner_radius = 0.2; rmesh.outer_radius = 0.24; ring.mesh = rmesh; ring.material_override = t._mat(Color("d98a2a")); ring.position = at + Vector3(2.2, 3.0, -0.25); t._add(ring)
			t._box(Vector3(3.6, 0.02, 2.4), at + Vector3(1.2, 0, 0), t._mat(Color("b8b0aa")), false)   # 콘크리트 바닥
			t.spots.append({ "pos": at + Vector3(1.4, 0, 0.6), "kind": "lookout", "yaw": PI })
		"hammock":   # 해먹 — 기둥 둘 사이, 누워 쉰다(침대와 같은 bed 자리)
			for s in [-1.3, 1.3]: t._box(Vector3(0.12, 1.4, 0.12), at + Vector3(s + sx, 0, 0), wood)
			t._box(Vector3(2.2, 0.06, 0.8), at + Vector3(sx, 0.55, 0), t._mat([Color("ad7096"), Color("e6d3a5"), Color("7a90b0")][rng.randi() % 3]), false)
			t.spots.append({ "pos": at + Vector3(sx, 0.62, 0), "kind": "bed", "yaw": PI / 2.0 })
		"deck":   # 볕 드는 데크 — 나무 판, 의자 둘(벤치), 화분
			t._box(Vector3(w - 1.2, 0.12, 2.2), at, wood, false)
			t._bench(at + Vector3(-1.2, 0.12, 0.2)); t._bench(at + Vector3(1.2, 0.12, 0.2))
			for s in [-1.0, 1.0]: t._scatter("Bush_Common_Flowers", at + Vector3(s * (w / 2.0 - 1.0), 0.12, -0.7), 0.5)
		"greenhouse":
			var gp := at + Vector3(sx, 0, 0)
			var glass := StandardMaterial3D.new(); glass.albedo_color = Color(0.82, 0.92, 0.9, 0.45); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var gh := MeshInstance3D.new(); var gm := BoxMesh.new(); gm.size = Vector3(3.0, 2.0, 2.0); gh.mesh = gm; gh.material_override = glass; gh.position = gp + Vector3(0, 1.0, 0); t._add(gh)
			for q in 4: t._box(Vector3(0.05, 2.0, 0.05), gp + Vector3(-1.5 + (q % 2) * 3.0, 0, -1.0 + (q / 2) * 2.0), t._mat(Color("f7f4ef")), false)
			for q in 5: t._scatter(["Plant_1", "Fern_1", "Plant_7", "Bush_Common", "Flower_3_Group"][q], gp + Vector3(-1.1 + q * 0.55, 0, 0.3), 0.45)
		"flowers":
			t._box(Vector3(w - 1.6, 0.18, 1.0), at, t._mat(Color("6a4a32")), false)
			for q in 8: t._scatter(["Flower_3_Group", "Flower_4_Group", "Bush_Common_Flowers"][q % 3], at + Vector3(-(w - 2.2) / 2.0 + q * (w - 2.2) / 7.0, 0.18, rng.randf_range(-0.25, 0.25)), rng.randf_range(0.3, 0.42))
			t._bench(at + Vector3(0, 0, 1.1))
		"shed":
			t._box(Vector3(2.0, 2.0, 1.6), at + Vector3(-1.8, 0, -0.2), t._mat([Color("6f8a5a"), Color("b56a5a"), Color("7a90b0")][rng.randi() % 3]))
			t._box(Vector3(2.3, 0.08, 1.9), at + Vector3(-1.8, 2.0, -0.2), t._mat(Color("3a3a42")), false)
			for q in 6:   # 장작더미
				var lg := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.12; cm.bottom_radius = 0.12; cm.height = 1.0; lg.mesh = cm; lg.material_override = t._mat(Color("8a6a4a"))
				lg.rotation.z = PI / 2.0; lg.position = at + Vector3(1.4, 0.12 + (q / 3) * 0.22, -0.4 + (q % 3) * 0.25); t._add(lg)
		"bench_work":   # 작업대 — 판·바이스·공구
			t._box(Vector3(1.8, 0.85, 0.7), at + Vector3(sx, 0, 0), wood)
			t._box(Vector3(0.25, 0.2, 0.2), at + Vector3(sx - 0.6, 0.85, 0), iron, false)
			t.spots.append({ "pos": at + Vector3(sx, 0, 0.75), "kind": "lookout", "yaw": PI })
		"swingset":
			t._swing(at + Vector3(sx, 0, 0))
		_:   # garden — 흙 이랑 셋과 채소
			for r in 3:
				t._box(Vector3(w - 2.0, 0.08, 0.4), at + Vector3(0, 0, -0.6 + r * 0.6), t._mat(Color("7a5a3a")), false)
				for q in 5: t._scatter(["Bush_Common", "Plant_1", "Fern_1", "Clover_2"][(r + q) % 4], at + Vector3(-(w - 2.5) / 2.0 + q * (w - 2.5) / 4.0, 0.08, -0.6 + r * 0.6), 0.34)

## 가게 뒤 짐 마당 — 상자 더미·팔레트·쓰레기통·직원 의자
static func service(t, c: Vector3, back_z: float, house_back: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var wood: Material = t._mat(Color("8a6a4a"))
	var mid := (back_z + house_back) / 2.0
	for q in 2 + rng.randi() % 3: t._box(Vector3(0.6, 0.45, 0.45), Vector3(c.x - 2.0 + (q % 2) * 0.65, q / 2 * 0.45, house_back - 1.2), wood)
	t._box(Vector3(1.2, 0.14, 1.0), Vector3(c.x + 1.5, 0, house_back - 1.4), t._mat(Color("b48a5a")), false)   # 팔레트
	t._bin(Vector3(c.x + 2.6, 0, mid)); t._bin(Vector3(c.x + 2.0, 0, mid + 0.6))
	t._bench(Vector3(c.x - 1.0, 0, mid))
