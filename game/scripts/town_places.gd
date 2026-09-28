class_name TownPlaces
extends TownBuild
## 마을의 새 장소들 — 북쪽 골목, 남쪽 강·돌다리·풀밭. 상속 사슬: base → build → **places** → systems → player → town3d.
## town_build.gd 가 500줄 한도에 닿아 장소(지도 조각) 단위로 떼어 냈다: 여기엔 "어디에 무엇이 있나"와 그 장소의 길찾기만 둔다.

const RIVER_N := 9.0      # 강 북쪽 둑(z) — 큰길(z≈2)과 가운데 울타리(z≈7.5) 남쪽
const RIVER_S := 12.0     # 강 남쪽 둑 — 이 너머가 풀밭(z 12..25)
const BRIDGE_W := 2.0     # 다리 폭(x −1..1) — 가운데 x=0 길과 같은 폭
const BRIDGE_H := 0.35    # 다리 꼭대기 높이 — 오르막 1.4m 에 0.35m(14°), 주민도 그냥 걸어 오른다

var glints: Array = []    # 물 위를 흘러가는 반짝임(흐르는 강이 멈춘 파란 띠로 안 읽히게)

## 북쪽 골목(2026-09-28 월요일 비전 런의 첫 조각 — 마을은 매달 눈에 띄게 넓어져야 한다): x=0 길이 북으로 이어져 동서 골목(z≈-13)과 만나고,
## 남향 집 세 채가 골목을 본다. 집 생성기가 문·침대·의자·선반을 등록하니 주민 명부의 집 배정(home_door = doors[i % n])에 저절로 들어가
## 밤에 여기서 자는 주민이 생긴다 — 새 집은 주인이 있어야 한다는 규칙. 골목 뒤는 담(세계 끝이 안 보이게)
func _lane(at: Vector3) -> void:
	_path(at + Vector3(-14, 0, 2), at + Vector3(14, 0, 2), 2.0)
	_house(at + Vector3(-8, 0, -1.5), Vector3(4.2, 2.7, 3.4), Color("8fb8cc"), "wood", false, 5)
	_house(at + Vector3(0, 0, -2), Vector3(3.8, 2.9, 3.2), Color("efe9e2"), "brick", false, 6)
	_house(at + Vector3(8, 0, -1.5), Vector3(4.6, 2.5, 3.6), Color("e6d3a5"), "accent-deep", false, 7)
	_bench(at + Vector3(4, 0, 3.6)); _lamp(at + Vector3(-3.5, 0, 3.4))
	_tree(at + Vector3(-12.5, 0, -1), 1.2); _tree(at + Vector3(12.5, 0, -1), 1.05)
	_fence(at + Vector3(-13, 0, -4), 26.0)

## 남쪽 강(비전 2단계, 구조 성장): 세계 폭 전체를 가로지르는 물 띠. 건너는 길은 가운데 돌다리 하나 — 강은 장식이 아니라 지도를 둘로 나누는 선이라
## 물 위엔 보이지 않는 벽(높이 3m, 점프로 못 넘는다)을 세우고 다리 폭만 비운다. 구역이 아니라 마을에 직접 붙인다(스트리밍은 x 거리로 끄는데 강은 어디서나 보인다)
func _river() -> void:
	var mid := (RIVER_N + RIVER_S) / 2.0; var w := RIVER_S - RIVER_N; var span := WORLD_X * 2.0 + 30.0   # 양 끝이 세계 밖까지 — 강이 뚝 끊겨 보이지 않게
	_box(Vector3(span, 0.02, w), Vector3(0, 0.01, mid), _mat(Color("8fb8cc")), false)
	var kerb := _mat(Color("cfc7c2"))
	for z in [RIVER_N - 0.12, RIVER_S + 0.12]:   # 둑: 연못 테두리와 같은 돌색 턱 — 물가가 선으로 읽힌다
		_box(Vector3(span, 0.08, 0.26), Vector3(0, 0, z), kerb, false)
	var half := BRIDGE_W / 2.0 + 0.1
	for sx in [-1.0, 1.0]:
		var wall := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new()
		bs.size = Vector3(span / 2.0 - half, 3.0, w); cs.shape = bs; wall.add_child(cs)
		wall.position = Vector3(sx * (half + bs.size.x / 2.0), 1.5, mid)
		add_child(wall)
	var gr := RandomNumberGenerator.new(); gr.seed = 31
	var gm := _mat(Color("dfe6ea"))
	for i in 36:
		var g := _box(Vector3(gr.randf_range(0.3, 0.8), 0.005, 0.04), Vector3(gr.randf_range(-WORLD_X, WORLD_X), 0.025, gr.randf_range(RIVER_N + 0.3, RIVER_S - 0.3)), gm, false)
		glints.append({ "node": g, "v": gr.randf_range(0.35, 0.7) })
	_bridge()
	_path(Vector3(0, 0, 3.2), Vector3(0, 0, RIVER_N - 0.6), 2.0)   # 큰길에서 다리 북쪽 발치까지
	spots.append({ "pos": Vector3(6.5, 0, RIVER_N - 0.7), "kind": "bank", "yaw": 0.0 })   # 북쪽 물가에 서서 강을 본다(다리를 안 건너도 가는 자리)

## 아치형 돌다리 — 오르막·평판·내리막(보이는 판 = 충돌 판, 걸리는 턱이 없다) + 양쪽 난간 + 물 위로 보이는 아치 그림자
func _bridge() -> void:
	var stone := _mat(Color("bfb6b0")); var dark := _mat(Color("6f8fa0"))
	var run := 1.4; var top_n := RIVER_N + 0.8; var top_s := RIVER_S - 0.8
	for d in [[RIVER_N - 0.6, 1.0], [RIVER_S + 0.6, -1.0]]:   # [발치 z, 오르는 방향]
		var foot: float = d[0]; var dir: float = d[1]
		var slope := _box(Vector3(BRIDGE_W, 0.08, sqrt(run * run + BRIDGE_H * BRIDGE_H)), Vector3(0, BRIDGE_H / 2.0 - 0.06, foot + dir * run / 2.0), stone)
		slope.rotation.x = -dir * atan2(BRIDGE_H, run)
		for sx in [-1.0, 1.0]:   # 난간: 판과 같은 기울기의 낮은 돌담
			var rail := _box(Vector3(0.12, 0.44, sqrt(run * run + BRIDGE_H * BRIDGE_H)), Vector3(sx * (BRIDGE_W / 2.0 + 0.06), BRIDGE_H / 2.0 - 0.12, foot + dir * run / 2.0), stone)
			rail.rotation.x = slope.rotation.x
	_box(Vector3(BRIDGE_W, 0.1, top_s - top_n), Vector3(0, BRIDGE_H - 0.1, (top_n + top_s) / 2.0), stone)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.12, 0.44, top_s - top_n), Vector3(sx * (BRIDGE_W / 2.0 + 0.06), BRIDGE_H - 0.1, (top_n + top_s) / 2.0), stone)
		# 아치 밑 그늘: 다리 옆면에 짙은 반원 — 물 위 동물의 숲 다리처럼 "밑으로 물이 지나간다"가 읽힌다
		var arch := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.1; cm.bottom_radius = 1.1; cm.height = 0.02
		arch.mesh = cm; arch.material_override = dark; arch.rotation.z = PI / 2.0
		arch.position = Vector3(sx * (BRIDGE_W / 2.0 + 0.13), -0.75, (RIVER_N + RIVER_S) / 2.0); add_child(arch)

## 남쪽 풀밭 — 다리 건너 첫 땅. 나무 둘(사과 달린), 벤치, 꽃 무더기, 강을 보는 물가 자리. 주민 일과에 자리가 등록되니 사람들이 다리를 건너온다
func _meadow(at: Vector3) -> void:
	_path(Vector3(0, 0, RIVER_S + 0.6), at + Vector3(0, 0, -1.5), 1.6)
	_bench(at + Vector3(2.2, 0, -1.2))
	_tree(at + Vector3(-5, 0, -1), 1.15); _tree(at + Vector3(6, 0, 2.5), 1.3)
	for c in [Vector3(-2.5, 0, 1.5), Vector3(3.5, 0, 3.5), Vector3(-7, 0, 3)]:
		for i in 5:
			var fl := MeshInstance3D.new(); var fs := SphereMesh.new(); fs.radius = 0.06; fs.height = 0.12; fl.mesh = fs
			fl.material_override = _mat([Color("ff2d55"), Color("e8c766"), Color("ad7096"), Color("ffffff"), Color("e8c766")][i])
			fl.position = at + c + Vector3(cos(i * 1.3) * 0.35, 0.08, sin(i * 1.3) * 0.25); _add(fl)
	spots.append({ "pos": Vector3(-3, 0, RIVER_S + 0.7), "kind": "bank", "yaw": PI })   # 남쪽 물가 — 북쪽을(강을) 보고 선다

## 강물 흐름 — 반짝임이 동쪽으로 흘러가고 끝에서 서쪽으로 돌아온다. 바람이 세면(비) 조금 빨라진다
func _flow(delta: float) -> void:
	var k := 1.6 if weather == "rain" else 1.0
	for g in glints:
		var n: Node3D = g["node"]
		n.position.x += float(g["v"]) * k * delta
		if n.position.x > WORLD_X: n.position.x -= WORLD_X * 2.0

## 강 건너기 경유지 — 출발과 도착이 강의 다른 편이면 다리 두 발치를 거친다(곧장 가면 보이지 않는 벽에 막혀 우회하다 포기했다)
func river_route(from: Vector3, to: Vector3) -> Array:
	var mid := (RIVER_N + RIVER_S) / 2.0
	if (from.z < mid) == (to.z < mid): return []
	var n := { "pos": Vector3(randf_range(-0.4, 0.4), 0, RIVER_N - 1.1), "act": "" }
	var s := { "pos": Vector3(randf_range(-0.4, 0.4), 0, RIVER_S + 1.1), "act": "" }
	return [n, s] if from.z < mid else [s, n]
