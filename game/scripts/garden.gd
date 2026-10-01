class_name Garden
extends RefCounted
## 텃밭 작물 한 포기(운영자 2026-10-01: "텃밭이나 이런 것도 디테일 살려서") — 전엔 초록 공 하나와 색 공 하나였다.
## 포기마다 단계별 묶음이 따로 있고(싹 · 어린 포기 · 꽃·풋열매 · 익은 열매) stage() 가 보일 것을 고른다. 크기는 town_places _set_stage 가 STAGE_K 로 키운다.
##   토마토: 지지대에 묶인 줄기, 어긋나는 겹잎, 노란 꽃 → 풋토마토 → 붉은 송이(꼭지 별)
##   양배추: 바깥잎이 둘러 퍼지고 가운데 결구가 차오른다(익으면 크고 흰빛 도는 결구)
##   호박: 땅을 기는 덩굴과 덩굴손, 큰 잎, 노란 나팔꽃 → 풋호박 → 골이 진 주황 호박(꼭지)
## 원시 도형뿐(외부 애셋 없음) — 마을의 다른 소품과 같은 툰 재질(town._mat)

static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position = at; mi.rotation = rot; parent.add_child(mi); return mi

static func _m(town: Node, c: Color) -> Material:
	return town.call("_mat", c)

static func _ball(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = h; s.radial_segments = 10; s.rings = 6; return s

static func _rod(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h; c.radial_segments = 6; return c

static func _group(pl: Node3D, name: String) -> Node3D:
	var g := Node3D.new(); g.name = name; pl.add_child(g); return g

## 잎 한 장 — 납작한 타원(길이 len), 줄기에서 바깥으로 yaw 방향, 위로 tilt 만큼 들림
static func _leaf(parent: Node3D, mat: Material, at: Vector3, len: float, yaw: float, tilt: float) -> void:
	var piv := Node3D.new(); piv.position = at; piv.rotation = Vector3(0, yaw, 0); parent.add_child(piv)
	_mesh(piv, _ball(len * 0.5, len * 0.16), mat, Vector3(0, 0, len * 0.45), Vector3(-tilt, 0, 0)).scale = Vector3(0.6, 1.0, 1.0)

## 한 포기 — 돌려주는 ripe 는 익었을 때만 보이는 열매 묶음(town_places 의 fruit 목록)
static func plant(kind: String, town: Node, rng: RandomNumberGenerator) -> Dictionary:
	var pl := Node3D.new()
	var g1: Color = [Color("6aa04c"), Color("7fb05a"), Color("5c9442")][rng.randi() % 3]
	var leaf := _m(town, g1); var leaf2 := _m(town, g1.darkened(0.15)); var stem := _m(town, Color("5d8a3c"))
	var sprout := _group(pl, "s0"); var young := _group(pl, "s1"); var bloom := _group(pl, "s2"); var ripe := _group(pl, "s3")
	# 싹: 떡잎 두 장(모든 작물 공통)
	_mesh(sprout, _rod(0.012, 0.08), stem, Vector3(0, 0.04, 0))
	for s in [-1.0, 1.0]: _leaf(sprout, leaf, Vector3(0, 0.08, 0), 0.08, s * PI / 2.0, 0.35)
	match kind:
		"tomato":
			var stake := _m(town, Color("8a6a4a"))
			_mesh(young, BoxMesh.new(), stake, Vector3(0.06, 0.45, -0.04)).scale = Vector3(0.03, 0.9, 0.03)
			_mesh(young, _rod(0.016, 0.42), stem, Vector3(0, 0.21, 0), Vector3(0, 0, 0.08))
			_mesh(young, _rod(0.014, 0.36), stem, Vector3(0.02, 0.58, 0), Vector3(0, 0, -0.1))
			for tie in [0.3, 0.6]: _mesh(young, _rod(0.035, 0.015), _m(town, Color("efe9e2")), Vector3(0.04, tie, -0.02), Vector3(PI / 2.0, 0, 0))   # 끈으로 묶었다
			for i in 7:
				var y := 0.14 + i * 0.1
				_leaf(young, leaf if i % 2 == 0 else leaf2, Vector3(0.01, y, 0), 0.17 - i * 0.01, i * 2.4 + rng.randf_range(-0.3, 0.3), 0.15 + rng.randf_range(0.0, 0.25))
			var flower := _m(town, Color("f3d34a")); var green := _m(town, Color("8fbf5a")); var red := _m(town, Color("e8473c")); var calyx := _m(town, Color("4f7f34"))
			for i in 4:
				var p := Vector3(cos(i * 1.7) * 0.11, 0.32 + (i % 2) * 0.18, sin(i * 1.7) * 0.11)
				_mesh(bloom, _ball(0.025, 0.03), flower, p)
				_mesh(bloom, _ball(0.04, 0.07), green, p + Vector3(0.03, -0.06, 0))   # 풋토마토
			for i in 5:   # 송이: 아래로 늘어지는 붉은 열매 다섯, 꼭지마다 초록 별
				var p := Vector3(cos(i * 1.3) * 0.12, 0.26 + (i % 3) * 0.13, sin(i * 1.3) * 0.12)
				_mesh(ripe, _ball(0.055, 0.1), red, p)
				_mesh(ripe, _ball(0.03, 0.012), calyx, p + Vector3(0, 0.048, 0))
		"cabbage":
			for i in 6:   # 바깥잎: 둘러 퍼진 넓은 잎
				_leaf(young, leaf if i % 2 == 0 else leaf2, Vector3(0, 0.04, 0), 0.24, i * TAU / 6.0 + rng.randf_range(-0.2, 0.2), 0.45)
			var head := _m(town, Color("c9e3a0")); var vein := _m(town, Color("a8cc7c"))
			_mesh(bloom, _ball(0.09, 0.15), head, Vector3(0, 0.09, 0))
			_mesh(ripe, _ball(0.15, 0.24), head, Vector3(0, 0.12, 0))   # 꽉 찬 결구
			for i in 3:   # 결구를 감싸는 속잎
				var piv := Node3D.new(); piv.rotation.y = i * TAU / 3.0; ripe.add_child(piv)
				_mesh(piv, _ball(0.12, 0.05), vein, Vector3(0, 0.13, 0.09), Vector3(-1.1, 0, 0)).scale = Vector3(1.0, 1.0, 0.7)
		"pumpkin":
			var vine := _m(town, Color("6a8f3a"))
			for i in 3:   # 땅을 기는 덩굴 세 토막과 덩굴손
				var a := i * 2.1 + 0.4
				_mesh(young, _rod(0.018, 0.4), vine, Vector3(cos(a) * 0.2, 0.03, sin(a) * 0.2), Vector3(PI / 2.0, -a, 0))
				_mesh(young, _rod(0.006, 0.12), vine, Vector3(cos(a) * 0.4, 0.06, sin(a) * 0.4), Vector3(0.6, a, 0.4))
			for i in 4:   # 큰 잎(손바닥만 한 원판이 줄기에 들려 있다)
				var a := i * 1.6 + 0.2
				_mesh(young, _rod(0.01, 0.16), stem, Vector3(cos(a) * 0.14, 0.08, sin(a) * 0.14))
				_mesh(young, _ball(0.15, 0.03), leaf if i % 2 == 0 else leaf2, Vector3(cos(a) * 0.16, 0.17, sin(a) * 0.16), Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3)))
			var trumpet := CylinderMesh.new(); trumpet.top_radius = 0.06; trumpet.bottom_radius = 0.01; trumpet.height = 0.08; trumpet.radial_segments = 8
			_mesh(bloom, trumpet, _m(town, Color("f2b632")), Vector3(0.12, 0.2, 0.05))
			_mesh(bloom, _ball(0.07, 0.11), _m(town, Color("9cbf4e")), Vector3(-0.1, 0.06, 0.1))   # 풋호박
			var orange := _m(town, Color("e08a2a")); var orange2 := _m(town, Color("c9761f"))
			for i in 6:   # 골: 납작한 공 여섯이 둘러 붙어 호박 골이 생긴다
				var a := i * TAU / 6.0
				_mesh(ripe, _ball(0.17, 0.28), orange if i % 2 == 0 else orange2, Vector3(cos(a) * 0.1, 0.13, sin(a) * 0.1)).scale = Vector3(0.75, 1.0, 0.75)
			_mesh(ripe, _rod(0.025, 0.1), _m(town, Color("6b5232")), Vector3(0, 0.3, 0), Vector3(0.3, 0, 0.2))   # 잎 위로 보이게 크게(잎에 가려 작았다)
	return { "node": pl, "ripe": ripe }

## 단계 — 0 싹 · 1 어린 포기 · 2 꽃·풋열매(포기는 그대로) · 3 익음(꽃 지고 열매)
static func stage(pl: Node3D, s: int) -> void:
	pl.get_node("s0").visible = s == 0
	pl.get_node("s1").visible = s >= 1
	pl.get_node("s2").visible = s == 2
	pl.get_node("s3").visible = s >= 3

## 허수아비 — 말뚝·가로대에 헌 셔츠, 밀짚 머리와 챙 모자, 소매 끝에 지푸라기. 바람에 살짝 기운다
static func scarecrow(town: Node, at: Vector3) -> Node3D:
	var n := Node3D.new(); n.position = at; n.rotation = Vector3(0, 0.4, 0.05)
	var wood := _m(town, Color("8a6a4a")); var straw := _m(town, Color("e3c46a")); var shirt := _m(town, Color("b5584a")); var hat := _m(town, Color("c9a45c"))
	_mesh(n, _rod(0.035, 1.5), wood, Vector3(0, 0.75, 0))
	_mesh(n, _rod(0.03, 0.9), wood, Vector3(0, 1.15, 0), Vector3(0, 0, PI / 2.0))
	_mesh(n, BoxMesh.new(), shirt, Vector3(0, 1.0, 0)).scale = Vector3(0.36, 0.42, 0.12)
	for s in [-1.0, 1.0]:
		_mesh(n, BoxMesh.new(), shirt, Vector3(s * 0.3, 1.15, 0)).scale = Vector3(0.26, 0.12, 0.12)
		for k in 3: _mesh(n, _rod(0.008, 0.12), straw, Vector3(s * 0.46, 1.12 + k * 0.03, 0), Vector3(0, 0, s * (1.2 + k * 0.2)))
	_mesh(n, _ball(0.13, 0.26), straw, Vector3(0, 1.42, 0))
	var brim := CylinderMesh.new(); brim.top_radius = 0.24; brim.bottom_radius = 0.24; brim.height = 0.02; brim.radial_segments = 12
	_mesh(n, brim, hat, Vector3(0, 1.52, 0))
	var crown := CylinderMesh.new(); crown.top_radius = 0.09; crown.bottom_radius = 0.12; crown.height = 0.12; crown.radial_segments = 10
	_mesh(n, crown, hat, Vector3(0, 1.59, 0))
	return n

## 갈퀴 — 울타리에 기대 세운다
static func rake(town: Node, at: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new(); n.position = at; n.rotation = Vector3(0, yaw, -0.25)
	var wood := _m(town, Color("9a7650")); var iron := _m(town, Color("5b5b63"))
	_mesh(n, _rod(0.015, 1.3), wood, Vector3(0, 0.65, 0))
	_mesh(n, BoxMesh.new(), iron, Vector3(0, 1.3, 0)).scale = Vector3(0.3, 0.03, 0.03)
	for i in 6: _mesh(n, _rod(0.006, 0.08), iron, Vector3(-0.13 + i * 0.052, 1.26, 0.0))
	return n
