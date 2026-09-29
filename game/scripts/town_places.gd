class_name TownPlaces
extends TownBuild
## 마을의 새 장소들 — 북쪽 골목, 남쪽 강·돌다리·풀밭, 텃밭, 빵집 화덕. 상속 사슬: base → build → **places** → systems → player → town3d.
## town_build.gd 가 500줄 한도에 닿아 장소(지도 조각) 단위로 떼어 냈다: 여기엔 "어디에 무엇이 있나"와 그 장소의 길찾기만 둔다.

const RIVER_N := 9.0      # 강 북쪽 둑(z) — 큰길(z≈2)과 가운데 울타리(z≈7.5) 남쪽
const RIVER_S := 12.0     # 강 남쪽 둑 — 이 너머가 풀밭(z 12..25)
const BRIDGE_W := 2.0     # 다리 폭(x −1..1) — 가운데 x=0 길과 같은 폭
const BRIDGE_H := 0.35    # 다리 꼭대기 높이 — 오르막 1.4m 에 0.35m(14°), 주민도 그냥 걸어 오른다

var glints: Array = []    # 물 위를 흘러가는 반짝임(흐르는 강이 멈춘 파란 띠로 안 읽히게)

const CROPS := ["tomato", "cabbage", "pumpkin"]   # 텃밭 세 이랑, 앞에서부터
const GROW_T := 30.0                              # 물 준 뒤 한 단계 자라는 데 걸리는 시간(초)
const STAGE_K := [0.3, 0.55, 0.8, 1.0]            # 단계별 풀 크기 — 3 이면 열매가 보인다(익음)

var rows: Array = []      # 텃밭 이랑 {kind, stage, plants: Array, fruit: Array, wet: MeshInstance3D, grow_at}
var garden_at := Vector3.INF   # 텃밭 가운데 — 울타리 안팎 판정과 문(앞쪽 가운데) 경유에 쓴다
var oven: Dictionary = {}      # 빵집 화덕(run 72) {spot, counter, fire, dough, queue: 남은 덩이, done_at: 다음 빵이 나오는 시각, by: 반죽하는 이("player" | 주민 | null)}

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
	_garden(at + Vector3(-11.5, 0, 3.5))   # 텃밭(비전 3단계) — 다리 건너 왼쪽 끝, 꽃 무더기(x −7) 서쪽

## 텃밭(동물의 숲 기준, run 70): 울타리 친 흙, 세 이랑이 세 단계(갓 심은·자란·익은)로 시작해 물을 주면 30초 뒤 한 단계 자라고, 익으면 C 로 딴다.
## 펌프 옆에 물뿌리개(item "can")가 놓여 있다 — 들고 이랑 앞에서 C. 주민도 같은 자리(spots "plot")에 와서 같은 자세로 물을 주고 익은 걸 딴다(resident.gd)
func _garden(at: Vector3) -> void:
	garden_at = at
	_box(Vector3(6.4, 0.05, 3.6), at, _mat(Color("6b4a35")), false)
	var paper := _mat(Color("efe9e2"))
	_fence(at + Vector3(-3.3, 0, -1.9), 6.6); _fence(at + Vector3(-3.3, 0, 1.9), 2.4); _fence(at + Vector3(0.9, 0, 1.9), 2.4)   # 앞쪽 가운데(x −0.9..0.9)가 문
	for sx in [-3.3, 3.3]:
		for z in [-1.4, -0.5, 0.5, 1.4]: _box(Vector3(0.08, 0.7, 0.05), at + Vector3(sx, 0, z), paper)
		for y in [0.25, 0.5]:
			var rail := _box(Vector3(3.8, 0.06, 0.04), at + Vector3(sx, y, 0), paper, false); rail.rotation.y = PI / 2.0
	for i in 3:
		var z := -1.15 + i * 1.15
		var wet := _box(Vector3(5.4, 0.012, 0.8), at + Vector3(0, 0.05, z), _mat(Color("4e3526")), false); wet.visible = false
		var row := { "kind": CROPS[i], "stage": 0, "plants": [], "fruit": [], "wet": wet, "grow_at": -1.0 }
		for j in 4:
			var pl := Node3D.new(); pl.position = at + Vector3(-1.8 + j * 1.2, 0.05, z); _add(pl)
			var leaf := MeshInstance3D.new(); var ls := SphereMesh.new(); ls.radius = 0.2; ls.height = 0.3; leaf.mesh = ls
			leaf.material_override = _mat(Color("7fb05a") if (i + j) % 2 == 0 else Color("6aa04c")); leaf.position.y = 0.12; pl.add_child(leaf)
			var fr := MeshInstance3D.new(); var fs := SphereMesh.new(); var frr: float = [0.07, 0.11, 0.14][i]; fs.radius = frr; fs.height = frr * 1.8; fr.mesh = fs
			fr.material_override = _mat([Color("ff2d55"), Color("a9c96a"), Color("d98a2a")][i]); fr.position = Vector3(0.12, frr * 0.8, 0.1); pl.add_child(fr)
			(row["plants"] as Array).append(pl); (row["fruit"] as Array).append(fr)
		_set_stage(row, i)   # 세 이랑이 세 단계 — 처음부터 "자라는 밭"으로 읽힌다
		rows.append(row)
		spots.append({ "pos": at + Vector3(0, 0, z), "kind": "plot", "yaw": PI, "row": i })
	# 펌프: 돌 받침 + 쇠기둥 + 앞으로 숙인 주둥이 + 뒤로 든 손잡이. 물뿌리개는 그 옆 바닥에
	var iron := _mat(Color("4a4a52"))
	_box(Vector3(0.5, 0.15, 0.5), at + Vector3(2.2, 0, 2.6), _mat(Color("bfb6b0")))
	_box(Vector3(0.12, 0.9, 0.12), at + Vector3(2.2, 0.15, 2.6), iron, false)
	var spout := _box(Vector3(0.07, 0.07, 0.32), at + Vector3(2.2, 0.85, 2.75), iron, false); spout.rotation.x = -0.35
	var handle := _box(Vector3(0.05, 0.05, 0.4), at + Vector3(2.2, 0.98, 2.45), iron, false); handle.rotation.x = 0.7
	_item("can", at + Vector3(2.75, 0, 2.7))

## 이랑의 단계 — 풀 크기와 열매 보임
func _set_stage(row: Dictionary, stage: int) -> void:
	row["stage"] = stage
	for pl in row["plants"]: (pl as Node3D).scale = Vector3.ONE * STAGE_K[stage]
	for fr in row["fruit"]: (fr as MeshInstance3D).visible = stage >= 3

## 물 주기 — 사람도 주민도 이걸 부른다. 젖은 표시가 생기고 GROW_T 뒤에 한 단계(_crops). 익었거나 이미 젖었으면 아무 일 없음(자세는 그래도 나온다)
func water_row(row: Dictionary, now: float) -> bool:
	if int(row["stage"]) >= 3 or float(row["grow_at"]) > 0.0: return false
	row["grow_at"] = now + GROW_T; (row["wet"] as MeshInstance3D).visible = true
	return true

## 따기 — 익은 이랑에서 작물 종류를 돌려주고 이랑은 처음(갓 심음)으로. 안 익었으면 ""
func pick_row(row: Dictionary) -> String:
	if int(row["stage"]) < 3: return ""
	_set_stage(row, 0)
	return String(row["kind"])

## 매 프레임: 젖은 이랑이 시간이 되면 자란다. 비가 오면 밭 전체에 물이 간다(하늘이 물뿌리개)
func _crops(now: float) -> void:
	for row in rows:
		if weather == "rain": water_row(row, now)
		if float(row["grow_at"]) > 0.0 and now >= float(row["grow_at"]):
			row["grow_at"] = -1.0; (row["wet"] as MeshInstance3D).visible = false
			_set_stage(row, mini(3, int(row["stage"]) + 1))

## 사람이 이랑 앞에서 C(town_player) — 물뿌리개를 들었으면 물 주기(water 자세 2.4초), 빈손이고 익었으면 따서 손에. 그 밖엔 아무 일도 없다
func garden_use(sp: Dictionary, now: float) -> void:
	var row: Dictionary = rows[int(sp["row"])]
	player.face(sp["yaw"])
	if player.carrying and String(player.carrying.get_meta("kind", "")) == "can":
		player.pose_request = "water"; use_until = now + StickPoses.WATER_T; action_until = now + StickPoses.WATER_T
		water_row(row, now)
	elif not player.carrying and carrying_big.is_empty() and int(row["stage"]) >= 3:
		var it := make_item(pick_row(row), body.global_position + Vector3(0, 0.9, 0))
		player.hold(it); player.action = "grab"; action_until = now + 0.4

## 강물 흐름 — 반짝임이 동쪽으로 흘러가고 끝에서 서쪽으로 돌아온다. 바람이 세면(비) 조금 빨라진다
func _flow(delta: float) -> void:
	var k := 1.6 if weather == "rain" else 1.0
	for g in glints:
		var n: Node3D = g["node"]
		n.position.x += float(g["v"]) * k * delta
		if n.position.x > WORLD_X: n.position.x -= WORLD_X * 2.0

## 경유지 — 출발과 도착이 강의 다른 편이면 다리 두 발치를, 텃밭 울타리 안팎을 드나들면 앞문을 거친다
## (곧장 가면 물 위 벽이나 울타리 기둥에 막혀 우회하다 포기했다 — polish run 71: 주민이 텃밭 이랑에 한 번도 못 닿았다)
func crossings(from: Vector3, to: Vector3) -> Array:
	var out := _gate_steps(from, false); var inn := _gate_steps(to, true)
	var mid := (RIVER_N + RIVER_S) / 2.0
	if (from.z < mid) == (to.z < mid): return out + inn
	var n := { "pos": Vector3(randf_range(-0.4, 0.4), 0, RIVER_N - 1.1), "act": "" }
	var s := { "pos": Vector3(randf_range(-0.4, 0.4), 0, RIVER_S + 1.1), "act": "" }
	return out + ([n, s] if from.z < mid else [s, n]) + inn

## 텃밭 안(울타리 3.3×1.9 안쪽)의 점이면 문 안쪽·바깥쪽 두 점, 아니면 없음. inward 면 바깥 → 안 순서
func _gate_steps(p: Vector3, inward: bool) -> Array:
	if garden_at == Vector3.INF or absf(p.x - garden_at.x) > 3.3 or absf(p.z - garden_at.z) > 1.9: return []
	var o := { "pos": garden_at + Vector3(0, 0, 2.7), "act": "" }; var i := { "pos": garden_at + Vector3(0, 0, 1.3), "act": "" }
	return [o, i] if inward else [i, o]

## 사람 쪽 이랑 거리 — 이랑 가운데가 아니라 이랑 줄(x ±2.2)까지. 가운데만 재면 끝의 포기 앞에서 C 가 안 먹었다
func plot_dist(p: Vector3, sp: Dictionary) -> float:
	var c: Vector3 = sp["pos"]
	return Vector2(p.x - clampf(p.x, c.x - 2.2, c.x + 2.2), p.z - c.z).length()

## 가장 가까운 이랑(1.2m 안), 없으면 {}
func near_plot(p: Vector3) -> Dictionary:
	var best: Dictionary = {}; var best_d := 1.2
	for sp in spots:
		if sp["kind"] != "plot": continue
		var d := plot_dist(p, sp)
		if d < best_d: best = sp; best_d = d
	return best

# ── 빵집(비전 4단계, run 72): 창구의 빵은 셋뿐이고 사면 준다. 비면 "Sold out." — 빵집 주인(문에 job 이 적힌 집의 주민)이 문 옆 화덕에서 반죽해 채운다.
#    사람도 같은 화덕에서 C 로 반죽할 수 있고(주민만의 힘은 없다), 주민도 창구에서 빵을 받아 세 입에 먹는다(resident.gd "counter"). 빵은 누가 반죽하는 동안에만 나온다 ──

## 화덕 — 문 옆 바깥(빵집 안은 침대·식탁·선반으로 꽉 찼다): 돌 받침(윗면 0.55 = 반죽판), 그 뒤 벽돌 아치와 검은 아궁이, 연통, 판 위의 반죽 덩이. 반죽하는 동안 아궁이가 달아오른다
func _oven(at: Vector3, counter: Dictionary) -> void:
	_box(Vector3(1.0, 0.55, 0.7), at, _mat(Color("bfb6b0")))
	_box(Vector3(0.8, 0.55, 0.36), at + Vector3(0, 0.55, -0.17), _mat(Color("b56a5a")), false)
	_box(Vector3(0.44, 0.3, 0.05), at + Vector3(0, 0.62, 0.02), _mat(Color("1b0c15")), false)
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("d98a2a"); fm.emission_enabled = true; fm.emission = Color("d98a2a"); fm.emission_energy_multiplier = 1.6
	var fire := _box(Vector3(0.36, 0.18, 0.03), at + Vector3(0, 0.65, 0.05), fm, false); fire.visible = false
	_box(Vector3(0.14, 0.5, 0.14), at + Vector3(0.25, 1.1, -0.2), _mat(Color("4a4a52")), false)
	var dough := MeshInstance3D.new(); var ds := SphereMesh.new(); ds.radius = 0.11; ds.height = 0.14; dough.mesh = ds
	dough.material_override = _mat(Color("efe9e2")); dough.position = at + Vector3(0, 0.6, 0.15); _add(dough)
	var sp := { "pos": at + Vector3(0, 0, 0.85), "kind": "oven", "yaw": PI }
	spots.append(sp)
	oven = { "spot": sp, "counter": counter, "fire": fire, "dough": dough, "queue": 0, "done_at": -1.0, "by": null }

## 창구 재고 하나 줄이기 — 진열 빵이 하나 사라지고, 다 떨어지면 팻말. 없으면 false. 사람도 주민도 이걸 부른다
func counter_take(sp: Dictionary) -> bool:
	if int(sp.get("stock", 0)) <= 0: return false
	sp["stock"] = int(sp["stock"]) - 1
	_show_stock(sp)
	return true

func _show_stock(sp: Dictionary) -> void:
	var shown: Array = sp.get("shown", [])
	for i in shown.size(): (shown[i] as Node3D).visible = i < int(sp["stock"])
	if sp.has("sign"): (sp["sign"] as Label3D).visible = int(sp["stock"]) <= 0

## 반죽 시작 — by 가 n 덩이를 KNEAD_T 마다 하나씩 빵으로. 이미 누가 반죽 중이면 그 줄은 그대로(둘이 한 판을 쓰진 않는다)
func bake(now: float, n: int, by: Variant) -> void:
	if oven.is_empty() or (int(oven["queue"]) > 0 and oven["by"] != by): return
	oven["queue"] = n; oven["by"] = by
	if float(oven["done_at"]) < 0.0: oven["done_at"] = now + StickPoses.KNEAD_T
	(oven["fire"] as Node3D).visible = true

## 반죽하던 이가 판을 떠나면(맞거나, 걸어가거나) 남은 덩이는 없던 일 — 빵은 누가 반죽하는 동안에만 나온다
func _oven_stop() -> void:
	oven["queue"] = 0; oven["done_at"] = -1.0; oven["by"] = null
	(oven["fire"] as Node3D).visible = false; (oven["dough"] as Node3D).scale = Vector3.ONE

## 매 프레임: 반죽하는 이가 아직 판 앞에 있으면 덩이가 눌리고, 한 바퀴가 끝날 때마다 창구에 빵 하나(셋까지). 줄이 끝나면 불을 끈다
func _bakery(now: float) -> void:
	if oven.is_empty() or int(oven["queue"]) <= 0: return
	var by: Variant = oven["by"]
	var kneading: bool = player.pose_request == "knead" if by is String else (by is ResidentBase and (by as ResidentBase).fig.pose_request == "knead")
	if not kneading:
		_oven_stop(); return
	var sq := absf(sin(now * 7.0))
	(oven["dough"] as Node3D).scale = Vector3(1.0 + 0.25 * sq, 1.0 - 0.3 * sq, 1.0 + 0.25 * sq)
	if now < float(oven["done_at"]): return
	var c: Dictionary = oven["counter"]
	c["stock"] = mini(3, int(c.get("stock", 0)) + 1); _show_stock(c)
	var q := int(oven["queue"]) - 1
	oven["queue"] = q; oven["done_at"] = now + StickPoses.KNEAD_T
	if q <= 0: _oven_stop()

## 빵집 주인이 화덕에 갈 이유(resident.gd _pick_spot) — 창구가 덜 찼고, 판이 비었고, 빈손이면 화덕 자리. 아니면 {}
func bake_spot(r: ResidentBase) -> Dictionary:
	if oven.is_empty() or r.fig.carrying or int(oven["queue"]) > 0: return {}
	var sp: Dictionary = oven["spot"]
	if int((oven["counter"] as Dictionary).get("stock", 0)) >= 3 or r._free_slot(sp) < 0: return {}
	return sp

## 사람이 화덕 앞에서 C(town_player) — 빈손이면 반죽 한 바퀴(knead 자세 KNEAD_T), 끝나면 창구에 빵 하나. 창구가 이미 셋이면 반죽만 하고 빵은 안 는다(자세는 그래도 나온다)
func oven_use(sp: Dictionary, now: float) -> void:
	player.face(sp["yaw"])
	player.pose_request = "knead"; use_until = now + StickPoses.KNEAD_T + 0.15; action_until = now + StickPoses.KNEAD_T + 0.15   # 자세가 빵보다 먼저 풀리면 _bakery 가 '떠났다'로 읽어 빵이 안 나온다 — 0.15 뒤에 푼다
	bake(now, 1, "player")

## 사람이 창구 앞에서 C(town_player) — 재고가 있으면 빵(빵집)이나 컵(카페, 재고 없음 = 늘 있음)을 손에. 빵집이 비었으면 팻말이 답한다(코인 결제는 다음 조각)
func counter_use(sp: Dictionary, now: float) -> void:
	player.face(sp["yaw"])
	if sp.has("stock") and not counter_take(sp): return
	var it := make_item(sp["item"], body.global_position + Vector3(0, 0.9, 0))
	player.hold(it); player.action = "grab"; action_until = now + 0.4
