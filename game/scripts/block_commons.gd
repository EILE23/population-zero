class_name BlockCommons
extends RefCounted
## 블록 공용지(운영자 2026-10-08: "녹지가 여전히 많아 — 상호작용할 수 있는 무언가들로 싹 채워", "건물 주변에 녹지 범위가 엄청 많잖아") —
## 블록마다 뒤뜰 사이 빈 띠 둘(북쪽 골목 옆, 가운데 뒷골목 남쪽: 7m × 36m)을 반씩(16m) 네 칸으로 나눠 칸마다 하나.
## 주택가: 놀이터·운동기구·과수원·피크닉·낚시 연못·텃밭·꽃밭 / 번화가: 장터·노천 카페·피크닉·연못·꽃밭.
## 다 이미 있는 놀이(그네·시소·산스장 C·나무 흔들기·낚시·벤치·풀밭에 눕기)라 새 규칙은 없다. t = TownCity(_box·_mat·_bench… 를 빌려 쓴다)

const HOUSE := ["playground", "gym", "orchard", "picnic", "pond", "allotment", "flowers"]
const SHOP := ["market", "terrace", "picnic", "pond", "flowers"]

static func kinds_for(zone: String) -> Array: return SHOP if zone == "high_street" else HOUSE

## 한 칸(가운데 at, 폭 ~16m 깊이 ~6m)
static func build(t, at: Vector3, kind: String, seed: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var wood: Material = t._mat(Color("8a6a4a")); var iron: Material = t._mat(Color("4a4a52"))
	match kind:
		"playground":
			t._swing(at + Vector3(-5.5, 0, 0)); t._swing(at + Vector3(-2.6, 0, 0))
			var ss := Seesaw3D.new(); ss.set_meta("nomerge", true); ss.position = at + Vector3(1.8, 0, 0); t._add(ss); ss.build(t._mat(Color("b48a5a")), iron); t.seesaws.append(ss)
			t.spots.append({ "pos": ss.position, "kind": "seesaw", "yaw": 0.0, "ss": ss })
			t._box(Vector3(2.6, 0.15, 2.2), at + Vector3(5.6, 0, 0), t._mat(Color("e8d8a8")), false)   # 모래밭
			t._box(Vector3(2.8, 0.25, 0.12), at + Vector3(5.6, 0, -1.15), wood, false)
			t._bench(at + Vector3(-1.0, 0, 2.3))
		"gym":
			for s2 in [-0.65, 0.65]: t._box(Vector3(0.08, 2.3, 0.08), at + Vector3(-5.5 + s2, 0, 0), iron)
			t._box(Vector3(1.4, 0.05, 0.05), at + Vector3(-5.5, 2.18, 0), iron, false)
			t.spots.append({ "pos": at + Vector3(-5.5, 0, 0.05), "kind": "gym", "ex": "pullup", "yaw": 0.0 })
			t._box(Vector3(0.7, 0.04, 1.6), at + Vector3(-2.0, 0, 0), t._mat(Color("7b526c")), false)
			t.spots.append({ "pos": at + Vector3(-2.0, 0, 0.45), "kind": "gym", "ex": "situp", "yaw": 0.0 })
			var disc := MeshInstance3D.new(); var dm := CylinderMesh.new(); dm.top_radius = 0.38; dm.bottom_radius = 0.4; dm.height = 0.08; disc.mesh = dm; disc.material_override = t._mat(Color("d8a24a")); disc.position = at + Vector3(1.5, 0.04, 0); t._add(disc)
			t.spots.append({ "pos": at + Vector3(1.5, 0, 0), "kind": "gym", "ex": "twist", "yaw": 0.0 })
			t._box(Vector3(0.8, 0.03, 0.6), at + Vector3(4.5, 0, 0), t._mat(Color("efe9e2")), false)
			t.spots.append({ "pos": at + Vector3(4.5, 0, 0), "kind": "gym", "ex": "squat", "yaw": 0.0 })
			t._box(Vector3(14.0, 0.02, 3.2), at + Vector3(-0.5, 0, 0), t._mat(Color("c9a77a")), false)   # 고무 바닥
			t._bench(at + Vector3(6.8, 0, 2.2))
		"orchard":
			for q in 4:
				t._tree(at + Vector3(-6.0 + q * 4.0, 0, -1.4 + (q % 2) * 2.4), 0.95)   # 흔들면 열매(town_build _tree)
				(t.crowns.back()["node"] as Node3D).set_meta("nomerge", true)   # 과수원 나무는 합치지 않는다 — 흔들리고 열매가 떨어져야(마당 나무는 그리기를 아끼려 합친다)
			t._box(Vector3(0.6, 0.45, 0.4), at + Vector3(6.6, 0, 1.6), wood)   # 사과 상자
			t._bench(at + Vector3(0, 0, 2.6))
		"picnic":
			for q in 2:
				var tp := at + Vector3(-4.5 + q * 6.0, 0, -0.4)
				t._box(Vector3(1.6, 0.75, 0.8), tp, wood)
				t._bench(tp + Vector3(0, 0, 1.0))
			t._box(Vector3(0.6, 0.85, 0.5), at + Vector3(5.8, 0, -0.5), t._mat(Color("2a2a30")))   # 바비큐
			t.spots.append({ "pos": at + Vector3(5.8, 0, 0.4), "kind": "lookout", "yaw": PI })
			t.spots.append({ "pos": at + Vector3(0, 0, 2.2), "kind": "grass", "yaw": PI, "r": 1.6 })   # 돗자리 풀밭 — 눕는다
			t._box(Vector3(1.6, 0.02, 1.2), at + Vector3(0, 0, 2.2), t._mat(Color("ad7096")), false)
		"pond":   # 낚시 연못 — 둑 두 자리에서 낚는다(부두와 같은 낚시)
			t.water.disc(at, 2.9)
			for q in [-1.0, 1.0]: t.spots.append({ "pos": at + Vector3(q * 3.4, 0.02, 0), "kind": "bank", "yaw": -q * PI / 2.0, "fish": true })
			t._bench(at + Vector3(5.6, 0, 1.8))
			for q in 6: t._scatter(["Grass_Wispy_Tall", "Fern_1", "Plant_7", "Flower_3_Group"][q % 4], at + Vector3(-5.5 + q * 2.2, 0, -3.0), 0.75)
		"allotment":   # 텃밭 — 흙 이랑 넷과 채소, 창고, 물통, 풀밭
			for r in 4:
				var gz := at.z - 2.0 + r * 1.1
				t._box(Vector3(8.0, 0.1, 0.55), Vector3(at.x - 2.0, 0, gz), t._mat(Color("7a5a3a")), false)
				for q in 8: t._scatter(["Bush_Common", "Plant_1", "Fern_1", "Clover_2", "Plant_7"][(r * 3 + q) % 5], Vector3(at.x - 5.5 + q, 0.1, gz), 0.36)
			t._box(Vector3(2.0, 2.0, 1.6), at + Vector3(5.2, 0, -1.2), t._mat(Color("6f8a5a")))   # 창고
			t._box(Vector3(2.3, 0.08, 1.9), at + Vector3(5.2, 2.0, -1.2), t._mat(Color("3a3a42")), false)
			var butt := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius = 0.35; bm.bottom_radius = 0.35; bm.height = 0.9; butt.mesh = bm; butt.material_override = t._mat(Color("4a6a8a")); butt.position = at + Vector3(3.6, 0.45, -1.4); t._add(butt)
			t.spots.append({ "pos": at + Vector3(5.2, 0, 1.6), "kind": "grass", "yaw": PI, "r": 1.2 })
		"flowers":   # 꽃밭 — 둥근 화단 둘, 낮은 생울타리, 벤치 둘, 가로등
			for q in [-1.0, 1.0]:
				var fc := at + Vector3(q * 4.0, 0, 0)
				var bed := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.7; cm.bottom_radius = 1.8; cm.height = 0.2; bed.mesh = cm; bed.material_override = t._mat(Color("6a4a32")); bed.position = fc + Vector3(0, 0.1, 0); t._add(bed)
				for f in 16:   # 빽빽하게 — 작은 꽃 아홉 송이는 흙바닥만 보였다
					var a := f * TAU / 16.0 + rng.randf() * 0.3; var rr := 0.35 + (f % 3) * 0.5
					t._scatter(["Flower_3_Group", "Flower_4_Group", "Bush_Common_Flowers", "Flower_3_Group"][f % 4], fc + Vector3(cos(a) * rr, 0.2, sin(a) * rr), rng.randf_range(0.32, 0.45))
			t._box(Vector3(15.0, 0.6, 0.45), at + Vector3(0, 0, -3.0), t._mat(Color("5f8a3e")), false)   # 생울타리
			t._bench(at + Vector3(-1.0, 0, 2.3)); t._bench(at + Vector3(1.0, 0, 2.3))
			t._lamp(at + Vector3(0, 0, -1.8))
			t.spots.append({ "pos": at + Vector3(0, 0, 0.2), "kind": "grass", "yaw": PI, "r": 1.4 })
		"market":   # 장터 — 노점 둘(서서 고르는 자리), 상자 더미, 벤치
			t._stall(at + Vector3(-4.0, 0, -0.8), [Color("ad7096"), Color("d98a2a"), Color("5f8a3e")][rng.randi() % 3])
			t._stall(at + Vector3(1.6, 0, -0.8), [Color("7a90b0"), Color("f2c84b"), Color("b56a5a")][rng.randi() % 3])
			for q in 3: t._box(Vector3(0.6, 0.45, 0.45), at + Vector3(5.6 + (q % 2) * 0.3, q * 0.45, -1.0), wood)
			t._box(Vector3(14.0, 0.02, 4.6), at + Vector3(0, 0, 0), t._mat(Color("d8cfc2")), false)   # 돌 바닥
			t._bench(at + Vector3(5.8, 0, 2.2))
		_:   # terrace — 노천 카페: 둥근 탁자와 파라솔 셋, 의자 대신 벤치
			t._box(Vector3(15.0, 0.02, 5.0), at, t._mat(Color("d8cfc2")), false)
			for q in 3:
				var tp := at + Vector3(-5.0 + q * 5.0, 0, -0.6)
				var top := MeshInstance3D.new(); var tm := CylinderMesh.new(); tm.top_radius = 0.5; tm.bottom_radius = 0.5; tm.height = 0.05; top.mesh = tm; top.material_override = t._mat(Color("efe9e2")); top.position = tp + Vector3(0, 0.74, 0); t._add(top)
				t._box(Vector3(0.06, 0.72, 0.06), tp, iron)
				t._box(Vector3(0.04, 2.2, 0.04), tp + Vector3(0, 0.74, 0), iron, false)
				var um := MeshInstance3D.new(); var uc := CylinderMesh.new(); uc.top_radius = 0.05; uc.bottom_radius = 1.2; uc.height = 0.4; uc.radial_segments = 8; um.mesh = uc
				um.material_override = t._mat([Color("ad7096"), Color("f7f4ef"), Color("7a90b0")][(q + rng.randi()) % 3]); um.position = tp + Vector3(0, 2.75, 0); t._add(um)
				t._bench(tp + Vector3(0, 0, 0.9))
