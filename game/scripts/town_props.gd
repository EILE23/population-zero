class_name TownProps
extends TownBase
## 작은 소품 빌더 — 창문, 가로등, 벤치, 쓰레기통, 울타리, 노점, 창구, 차양, 모자 거치대, 그네. 전부 원시 도형.
## (2026-09-28 스크린샷 검토: 창이 흰 스티커, 가로등이 노란 정육면체, 창구가 분홍 덩어리로 보여 여기서 다시 그렸다.) 사슬: base → props → build → …

## 창 — 벽면(at)에 붙는다. 나무 틀 네 변 + 살(십자) + 파란 유리 + 돌 창턱. 전엔 흰 상자 위에 흰 유리라 스티커처럼 보였다
func _window(at: Vector3, yaw: float, shutters := false, shutter_c := Color("7b526c")) -> Node3D:
	var n := Node3D.new(); n.position = at; n.rotation.y = yaw; add_child(n)
	var frame := _mat(Color("8a6a4a")); var glass := _mat(Color("7f9fb0"))
	_box(Vector3(0.6, 0.7, 0.05), Vector3(0, 0.07, -0.01), glass, false, n)
	_box(Vector3(0.72, 0.06, 0.08), Vector3(0, 0.45, 0.0), frame, false, n)
	_box(Vector3(0.72, 0.06, 0.08), Vector3(0, -0.31, 0.0), frame, false, n)
	_box(Vector3(0.06, 0.82, 0.08), Vector3(-0.33, 0.07, 0.0), frame, false, n)
	_box(Vector3(0.06, 0.82, 0.08), Vector3(0.33, 0.07, 0.0), frame, false, n)
	_box(Vector3(0.03, 0.7, 0.06), Vector3(0, 0.07, 0.005), frame, false, n)
	_box(Vector3(0.6, 0.03, 0.06), Vector3(0, 0.12, 0.005), frame, false, n)
	_box(Vector3(0.86, 0.06, 0.16), Vector3(0, -0.36, 0.05), _mat(Color("bfb6b0")), false, n)   # 창턱
	if shutters:
		_box(Vector3(0.22, 0.8, 0.05), Vector3(-0.5, 0.07, 0.0), _mat(shutter_c), false, n)
		_box(Vector3(0.22, 0.8, 0.05), Vector3(0.5, 0.07, 0.0), _mat(shutter_c), false, n)
	return n

## 그네 — 틀은 고정, 줄과 좌석은 윗봉의 피벗 아래에 매달려 진자로 흔들린다. 사람은 C 로 타고 ← → 로 밀고 SPACE 로 뛰어내린다
func _swing(at: Vector3) -> void:
	var iron := _mat(Color("4a4a52")); var wood := _mat(Color("b48a5a"))
	_box(Vector3(0.08, 2.2, 0.08), at + Vector3(-1.0, 0, 0), iron); _box(Vector3(0.08, 2.2, 0.08), at + Vector3(1.0, 0, 0), iron)
	_box(Vector3(2.2, 0.08, 0.08), at + Vector3(0, 2.2, 0), iron, false)
	var pivot := Node3D.new(); pivot.position = at + Vector3(0, 2.2, 0); _add(pivot)
	var L := 1.55
	for rx in [-0.25, 0.25]:
		var rope := MeshInstance3D.new(); var rm := BoxMesh.new(); rm.size = Vector3(0.02, L, 0.02); rope.mesh = rm; rope.material_override = iron
		rope.position = Vector3(rx, -L / 2.0, 0); pivot.add_child(rope)
	var seat := MeshInstance3D.new(); var sm := BoxMesh.new(); sm.size = Vector3(0.6, 0.05, 0.25); seat.mesh = sm; seat.material_override = wood
	seat.position = Vector3(0, -L, 0); pivot.add_child(seat)
	var sw := { "pivot": pivot, "len": L, "angle": 0.0, "vel": 0.0, "at": at, "rider": null, "pusher": null, "push_at": 0.0 }
	swings.append(sw)
	spots.append({ "pos": at, "kind": "swing", "yaw": 0.0, "swing": sw })  # 주민도 탄다(한 명), 누가 타면 다른 주민이 뒤에서 밀어 준다

## 모자 거치대 — 기둥 하나에 가지 넷, 가지마다 모자(집으면 새 것이 걸린다)
func _hatstand(at: Vector3) -> void:
	_box(Vector3(0.06, 1.7, 0.06), at, _mat(Color("8a6a4a")))
	for i in 4:
		var a := i * PI / 2.0
		var arm := _box(Vector3(0.04, 0.04, 0.3), at + Vector3(0, 1.5 - i * 0.12, 0), _mat(Color("8a6a4a")), false); arm.rotation.y = a; arm.position += Vector3(sin(a) * 0.15, 0, cos(a) * 0.15)
		var h := Wear.make(["cap", "straw", "tophat", "beanie"][i], Wear.palette(i * 7)); h.position = at + Vector3(sin(a) * 0.3, 1.58 - i * 0.12, cos(a) * 0.3); h.rotation.x = 0.3; _add(h)
	spots.append({ "pos": at + Vector3(0, 0, 0.7), "kind": "hatstand", "yaw": PI })

## 줄무늬 차양 — 가게색과 종이색이 번갈아, 앞에 늘어진 자락. at 은 차양 뒤쪽 중심(벽 쪽), 앞으로 d 만큼 내려온다
func _awning(at: Vector3, w: float, d: float, c: Color) -> Node3D:
	var n := Node3D.new(); n.position = at; n.rotation.x = 0.22; _add(n)
	var stripes := maxi(3, int(w / 0.28)); var sw := w / stripes
	for i in stripes:
		var sc := c if i % 2 == 0 else Color("f7f4ef")
		_box(Vector3(sw + 0.005, 0.04, d), Vector3(-w / 2.0 + sw * (i + 0.5), 0, d / 2.0), _mat(sc), false, n)
		_box(Vector3(sw + 0.005, 0.1, 0.03), Vector3(-w / 2.0 + sw * (i + 0.5), -0.05, d), _mat(sc), false, n)   # 자락
	return n

## 창구 — 벽 앞의 나무 카운터(밝은 상판, 앞판 색띠), 줄무늬 차양, 간판, 진열된 물건. C 로 물건을 받는다(spots kind "counter")
func _counter(at: Vector3, item: String, c: Color) -> void:
	_box(Vector3(1.2, 0.9, 0.5), at, _mat(Color("8a6a4a")))
	_box(Vector3(1.3, 0.05, 0.6), at + Vector3(0, 0.9, 0), _mat(Color("e6d3a5")), false)   # 상판
	_box(Vector3(1.0, 0.3, 0.02), at + Vector3(0, 0.3, 0.25), _mat(c), false)              # 앞판 색띠
	_awning(at + Vector3(0, 1.95, -0.2), 1.6, 0.8, c)
	_box(Vector3(0.9, 0.3, 0.05), at + Vector3(0, 2.15, -0.2), _mat(Color("7b526c")), false)   # 간판(테두리)
	_box(Vector3(0.8, 0.2, 0.06), at + Vector3(0, 2.2, -0.2), _mat(Color("f7f4ef")), false)
	for i in 3:
		var g := make_item(item, at + Vector3(-0.35 + i * 0.35, 0.95, 0.05)); items.erase(g)   # 진열용(집을 수 없음)
	spots.append({ "pos": at + Vector3(0, 0, 0.8), "kind": "counter", "yaw": PI, "item": item })

## 노점 — 나무 판매대(밝은 상판·앞 색띠), 기둥 둘, 줄무늬 차양, 물건 셋
func _stall(at: Vector3, awning: Color) -> void:
	var wood := _mat(Color("8a6a4a"))
	_box(Vector3(2.2, 0.9, 0.9), at, wood)                                                     # 판매대
	_box(Vector3(2.3, 0.05, 1.0), at + Vector3(0, 0.9, 0), _mat(Color("e6d3a5")), false)         # 상판
	_box(Vector3(2.0, 0.35, 0.02), at + Vector3(0, 0.3, 0.45), _mat(awning), false)              # 앞 색띠
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.08, 2.2, 0.08), at + Vector3(sx, 0, -0.4), wood, false)
	_awning(at + Vector3(0, 2.15, -0.6), 2.6, 1.4, awning)
	for i in 3:
		var g := MeshInstance3D.new(); var gs := SphereMesh.new(); gs.radius = 0.09; gs.height = 0.18; g.mesh = gs
		g.material_override = _mat([Color("d98a2a"), Color("ff2d55"), Color("e8c766")][i]); g.position = at + Vector3(-0.6 + i * 0.6, 1.02, -0.1); _add(g)
	spots.append({ "pos": at + Vector3(0, 0, 1.0), "kind": "door", "yaw": PI })   # 손님 자리(서서 고른다)

## 꽃 — Quaternius MegaKit(CC0) 꽃 모델(색은 모델 고정, 두 종). 2 유닛 높이 → 0.13~0.18 배로 25~35cm
func _flower(at: Vector3, _c: Color, seed := 0) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed + int(at.x * 31.0 + at.z * 17.0)
	var id: String = ["Flower_3_Single", "Flower_4_Single", "Flower_3_Group", "Flower_4_Group"][rng.randi() % 4]
	var m := _model("nature/quaternius/" + id); m.position = at; m.rotation.y = rng.randf_range(0.0, TAU); m.scale = Vector3.ONE * rng.randf_range(0.13, 0.18); _add(m)

## 풀 포기·덤불·돌 — 초원과 길가에 흩뿌리는 작은 것들(MegaKit)
func _scatter(id: String, at: Vector3, sc := 1.0, yaw := -1.0) -> Node3D:
	var m := _model("nature/quaternius/" + id); m.position = at; m.rotation.y = (randf_range(0.0, TAU) if yaw < 0.0 else yaw); m.scale = Vector3.ONE * sc; _add(m)
	return m

## 차 한 대 세워 두기(Kenney Car Kit, CC0) — C 로 타고 내린다
func _car(kind: String, at: Vector3, yaw: float) -> Car3D:
	var c := Car3D.new(); c.setup(kind, self); c.position = at + Vector3(0, 0.02, 0); c.rotation.y = yaw
	add_child(c); cars.append(c)
	return c

## 쓰레기통 — 통 + 어두운 뚜껑 테
func _bin(at: Vector3) -> void:
	var b := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.28; cm.bottom_radius = 0.24; cm.height = 0.8
	b.mesh = cm; b.material_override = _mat(Color("5b5b63")); b.position = at + Vector3(0, 0.4, 0); _add(b)
	var lid := MeshInstance3D.new(); var lm := CylinderMesh.new(); lm.top_radius = 0.3; lm.bottom_radius = 0.3; lm.height = 0.06
	lid.mesh = lm; lid.material_override = _mat(Color("3a3a42")); lid.position = at + Vector3(0, 0.83, 0); _add(lid)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = 0.28; sh.height = 0.8; cs.shape = sh; sb.add_child(cs); b.add_child(sb)

func _bench(at: Vector3) -> void:
	var wood := _mat(Color("8a6a4a")); var iron := _mat(Color("4a4a52"))
	var g := Node3D.new(); _add(g)   # 한 덩어리 — 차가 들이받으면 통째로 부서진다
	_box(Vector3(1.5, 0.06, 0.45), at + Vector3(0, 0.42, 0), wood, true, g)
	var back := _box(Vector3(1.5, 0.06, 0.4), at + Vector3(0, 0.62, -0.2), wood, true, g)
	back.rotation.x = -1.35
	for sx in [-0.6, 0.6]:
		_box(Vector3(0.06, 0.42, 0.06), at + Vector3(sx, 0, 0.15), iron, true, g)
		_box(Vector3(0.06, 0.42, 0.06), at + Vector3(sx, 0, -0.15), iron, true, g)
	var b := { "pos": at, "yaw": 0.0 }; var sp := { "pos": at, "kind": "bench", "yaw": 0.0 }
	benches.append(b); spots.append(sp)
	wreckables.append({ "node": g, "at": at, "r": 0.8, "out": Vector3(0, 0, 1), "bench": b, "spot": sp, "rebuild": _bench.bind(at) })

## 가로등 — 기둥 + 받침 + 유리 등갓 + 어두운 지붕. 전엔 기둥 위 노란 정육면체
func _lamp(at: Vector3) -> void:
	var iron := _mat(Color("4a4a52"))
	var post := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.035; cm.bottom_radius = 0.05; cm.height = 2.2
	post.mesh = cm; post.material_override = iron
	post.position = at + Vector3(0, 1.1, 0)
	_add(post)
	var base := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius = 0.07; bm.bottom_radius = 0.1; bm.height = 0.12
	base.mesh = bm; base.material_override = iron; base.position = at + Vector3(0, 0.06, 0); _add(base)
	_box(Vector3(0.16, 0.05, 0.16), at + Vector3(0, 2.2, 0), iron, false)                       # 받침
	_box(Vector3(0.2, 0.26, 0.2), at + Vector3(0, 2.25, 0), _mat(Color("f4de8a")), false)        # 유리
	var cap := MeshInstance3D.new(); var cp := CylinderMesh.new(); cp.top_radius = 0.02; cp.bottom_radius = 0.17; cp.height = 0.12; cp.radial_segments = 4
	cap.mesh = cp; cap.material_override = iron; cap.position = at + Vector3(0, 2.57, 0); cap.rotation.y = PI / 4.0; _add(cap)
	spots.append({ "pos": at + Vector3(0.25, 0, 0), "kind": "lamp", "yaw": -PI / 2.0 })
	var l := OmniLight3D.new(); l.light_color = Color("e8c766"); l.light_energy = 0.6; l.omni_range = 4.0
	l.position = at + Vector3(0, 2.3, 0)
	_add(l)
	lamps.append(l)

func _fence(at: Vector3, len: float) -> void:
	# Kenney fence_simple(1m 토막, 원점이 왼끝 아님: -0.5..0.5) — +x 로 이어 붙인다
	var n := int(round(len))
	for i in n:
		_fence_bit(at + Vector3(i + 0.5, 0, 0))

## 울타리 한 토막 — 부서지면 이 토막만 날아가고, 수리공이 이 자리에 다시 세운다
func _fence_bit(at: Vector3) -> void:
	var m := _model("nature/fence_simple"); m.position = at; m.scale = Vector3(1.0, 1.15, 1.0); _add(m)
	wreckables.append({ "node": m, "at": at, "r": 0.4, "out": Vector3(0, 0, 1), "rebuild": _fence_bit.bind(at) })
	# 충돌체 없음: 주민 경로가 울타리를 지나간다(전 울타리도 기둥 사이로 통과됐다). 막으면 울타리 앞에서 뛰며 갇힌다(운영자 2026-09-29) — 경로 탐색이 생기면 다시
