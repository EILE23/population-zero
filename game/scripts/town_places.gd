class_name TownPlaces
extends TownBuild
## 마을의 새 장소들 — 북쪽 골목, 남쪽 강·돌다리·풀밭, 텃밭, 빵집 화덕, 전망 언덕. 상속 사슬: base → build → **places** → boat → systems → player → town3d.
## town_build.gd 가 500줄 한도에 닿아 장소(지도 조각) 단위로 떼어 냈다: 여기엔 "어디에 무엇이 있나"와 그 장소의 길찾기만 둔다.

const RIVER_N := RIVER_Z - RIVER_HW   # 강 북쪽 둑(z) — 강은 town_build._river(물 애셋, 헤엄칠 수 있다)
const RIVER_S := RIVER_Z + RIVER_HW   # 강 남쪽 둑 — 이 너머가 풀밭
const BRIDGE_W := BRIDGE_HW * 2.0     # 다리 폭(거룻배가 다리 밑을 못 지나는 범위 — town_boat)

const CROPS := ["tomato", "cabbage", "pumpkin"]   # 텃밭 세 이랑, 앞에서부터
const GROW_T := 30.0                              # 물 준 뒤 한 단계 자라는 데 걸리는 시간(초)
const STAGE_K := [0.3, 0.55, 0.8, 1.0]            # 단계별 풀 크기 — 3 이면 열매가 보인다(익음)

var rows: Array = []      # 텃밭 이랑 {kind, stage, plants: Array, fruit: Array, wet: MeshInstance3D, grow_at}
var garden_at := Vector3.INF   # 텃밭 가운데 — 울타리 안팎 판정과 문(앞쪽 가운데) 경유에 쓴다
const TERR_AT := Vector3(17, 0, 18.5)   # 전망 언덕 가운데(풀밭 동쪽 끝, run 73) — 선반 x 13..21, z 15.5..21.5
const TERR_W := 8.0; const TERR_D := 6.0
const TERR_H := 1.4                     # 선반 높이 — 꽉 찬 점프(1.25m)로는 못 오른다, 남쪽 낯의 돌계단이 유일한 길
var terr_steps: Array = []              # 계단 경유지 [발치 앞(땅), 꼭대기 안쪽(선반)] — crossings 가 끼운다

var oven: Dictionary = {}      # 빵집 화덕(run 72) {spot, counter, fire, dough, queue: 남은 덩이, done_at: 다음 빵이 나오는 시각, by: 반죽하는 이("player" | 주민 | null)}

## 북쪽 골목(2026-09-28 월요일 비전 런의 첫 조각 — 마을은 매달 눈에 띄게 넓어져야 한다): x=0 길이 북으로 이어져 동서 골목(z≈-13)과 만나고,
## 남향 집 세 채가 골목을 본다. 집 생성기가 문·침대·의자·선반을 등록하니 주민 명부의 집 배정(home_door = doors[i % n])에 저절로 들어가
## 밤에 여기서 자는 주민이 생긴다 — 새 집은 주인이 있어야 한다는 규칙. 골목 뒤는 담(세계 끝이 안 보이게)
func _lane(at: Vector3) -> void:
	_path(at + Vector3(-14, 0, 2), at + Vector3(14, 0, 2), 2.0)
	_house(at + Vector3(-8, 0, -1.5), Vector3(4.2, 2.7, 3.4), Color("8fb8cc"), "wood", false, 5)
	_house(at + Vector3(0, 0, -2), Vector3(3.8, 2.9, 3.2), Color("efe9e2"), "brick", false, 6)
	_house(at + Vector3(8, 0, -1.5), Vector3(4.6, 2.5, 3.6), Color("e6d3a5"), "wood", false, 7)
	_bench(at + Vector3(4, 0, 3.6)); _lamp(at + Vector3(-3.5, 0, 3.4))
	_tree(at + Vector3(-12.5, 0, -1), 1.2); _tree(at + Vector3(12.5, 0, -1), 1.05)
	_fence(at + Vector3(-13, 0, -4), 26.0)

## 남쪽 풀밭 — 다리 건너 첫 땅. 나무 둘(사과 달린), 벤치, 꽃 무더기, 강을 보는 물가 자리. 주민 일과에 자리가 등록되니 사람들이 다리를 건너온다
func _meadow(at: Vector3) -> void:
	_bench(at + Vector3(2.2, 0, -1.2))
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

## 전망 언덕(run 73, 구조 성장 — 동물의 숲 기준 "절벽과 단"): 풀밭 동쪽 끝에 바위 낯을 가진 풀 선반(8×6m, 1.4m). 오르는 길은 남쪽 낯의 돌계단 하나 —
## 보이는 단은 장식이고 충돌은 _ramp 의 보이지 않는 경사(계단집 _stairs 와 같은 요령: 단을 한 칸씩 넘는 방식은 가끔 걸렸다). 위엔 마을 쪽 난간 앞의 전망 자리(shade 자세),
## 벤치, 나무 한 그루 — 올라올 이유 셋. 주민 일과에 자리가 등록되니 사람들이 계단을 올라온다(crossings 가 계단 두 발치를 끼운다 — 곧장 가면 바위 낯에 막혀 포기한다)
func _terrace(at: Vector3) -> void:
	var rock := _mat(Color("9a8f86")); var dark := _mat(Color("7f746c"))
	_box(Vector3(TERR_W, TERR_H - 0.1, TERR_D), at, rock)   # 바위 몸통(충돌)
	_box(Vector3(TERR_W, 0.1, TERR_D), at + Vector3(0, TERR_H - 0.1, 0), _mat(Color.WHITE, _tex("ground/grass"), Vector3(TERR_W / TILE, TERR_D / TILE, 1)))   # 풀 뚜껑
	var rr := RandomNumberGenerator.new(); rr.seed = 73
	for i in 7:   # 바위 낯의 혹 — 남쪽 낯에 다섯, 서쪽 낯에 둘, 크기·높이가 조금씩 달라 벽돌처럼 안 읽힌다
		var b := MeshInstance3D.new(); var bs := SphereMesh.new(); var r := rr.randf_range(0.35, 0.6)
		bs.radius = r; bs.height = r * 1.3; bs.radial_segments = 10; bs.rings = 5; b.mesh = bs
		b.material_override = dark if i % 2 == 0 else rock
		var y := rr.randf_range(0.2, TERR_H - 0.6)
		b.position = at + (Vector3(-TERR_W / 2.0 + 2.9 + (i * 1.1), y, TERR_D / 2.0 - 0.1) if i < 5 else Vector3(-TERR_W / 2.0 - 0.1, y, -1.5 + (i - 5) * 2.2))
		_add(b)
	# 돌계단: 남쪽 낯 서쪽에서 북으로(−z) 오른다. 한 단 0.3 깊이, 꼭대기 단의 뒷면이 선반 남쪽 낯에 닿는다
	var n := int(ceil(TERR_H / 0.25)); var rise := TERR_H / n
	var foot := at + Vector3(-TERR_W / 2.0 + 1.5, 0, TERR_D / 2.0 + n * 0.3 - 0.15)
	for i in n:
		_box(Vector3(1.4, rise * (i + 1), 0.3), foot + Vector3(0, 0, -i * 0.3), _mat(Color("bfb6b0")), false)
	_ramp(foot + Vector3(0, 0, 0.15), 1.4, TERR_H, n * 0.3)
	terr_steps = [foot + Vector3(0, 0, 0.75), foot + Vector3(0, TERR_H, -n * 0.3 - 0.5)]
	# 위: 마을 쪽(북) 가장자리의 난간, 그 앞의 전망 자리, 벤치와 나무
	_fence(at + Vector3(-3.0, TERR_H, -TERR_D / 2.0 + 0.35), 6.0)
	spots.append({ "pos": at + Vector3(0.4, TERR_H, -TERR_D / 2.0 + 0.7), "kind": "lookout", "yaw": PI })
	_bench(at + Vector3(2.4, TERR_H, 1.4))
	_tree(at + Vector3(-2.2, TERR_H, 0.6), 0.9)

## 이 자리의 땅 높이 — 전망 언덕 선반 위면 TERR_H, 아니면 0. 던져진 것·떨어진 사과가 선반 위에 놓이게(_fly) — 바닥 0 까지 떨어지면 바위 속에 묻힌다
func ground_y(p: Vector3) -> float:
	return TERR_H if absf(p.x - TERR_AT.x) < TERR_W / 2.0 and absf(p.z - TERR_AT.z) < TERR_D / 2.0 else 0.0

## 언덕 위의 점이면 계단 두 발치(꼭대기 안쪽·발치 앞), 아니면 없음. inward 면 발치 → 꼭대기 순서
func _terr_steps(p: Vector3, inward: bool) -> Array:
	if terr_steps.is_empty() or ground_y(p) <= 0.0: return []
	var f := { "pos": terr_steps[0], "act": "" }; var t := { "pos": terr_steps[1], "act": "" }
	return [f, t] if inward else [t, f]

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

## 경유지 — 출발과 도착이 강의 다른 편이면 다리 두 발치를, 텃밭 울타리 안팎을 드나들면 앞문을, 전망 언덕을 오르내리면 계단을 거친다
## (곧장 가면 물 위 벽이나 울타리 기둥·바위 낯에 막혀 우회하다 포기했다 — polish run 71: 주민이 텃밭 이랑에 한 번도 못 닿았다)
## 출발과 도착이 같은 편이면(둘 다 언덕 위, 둘 다 울타리 안) 계단·문을 안 거친다 — 전망 벤치에서 3m 옆 전망 자리로 가는데 계단을 내려갔다 다시 올랐고, 이랑에서 옆 이랑으로 가는데 문 밖에 나갔다 들어왔다(polish 75)
func crossings(from: Vector3, to: Vector3) -> Array:
	var lvl := (ground_y(from) > 0.0) != (ground_y(to) > 0.0); var yard := _in_garden(from) != _in_garden(to)
	var out := (_gate_steps(from, false) if yard else []) + (_terr_steps(from, false) if lvl else [])
	var inn := (_terr_steps(to, true) if lvl else []) + (_gate_steps(to, true) if yard else [])
	var mid := (RIVER_N + RIVER_S) / 2.0
	if (from.z < mid) == (to.z < mid): return out + inn
	var n := { "pos": Vector3(randf_range(-0.4, 0.4), 0, RIVER_N - 1.1), "act": "" }
	var s := { "pos": Vector3(randf_range(-0.4, 0.4), 0, RIVER_S + 1.1), "act": "" }
	return out + ([n, s] if from.z < mid else [s, n]) + inn

## 텃밭 안(울타리 3.3×1.9 안쪽)의 점이면 문 안쪽·바깥쪽 두 점, 아니면 없음. inward 면 바깥 → 안 순서
func _gate_steps(p: Vector3, inward: bool) -> Array:
	if not _in_garden(p): return []
	var o := { "pos": garden_at + Vector3(0, 0, 2.7), "act": "" }; var i := { "pos": garden_at + Vector3(0, 0, 1.3), "act": "" }
	return [o, i] if inward else [i, o]

## 텃밭 울타리(3.3×1.9) 안의 점인가
func _in_garden(p: Vector3) -> bool:
	return garden_at != Vector3.INF and absf(p.x - garden_at.x) <= 3.3 and absf(p.z - garden_at.z) <= 1.9

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

# ── 우산꽂이("Weather people feel" 2조각, run 76): 카페 창구 오른쪽 양동이에 우산 셋(모브·잉크·종이색). 빈손으로 C = 하나 빌린다(재고 3 → 0, 창구와 같은 counter_take/_show_stock),
#    들고 C = 펴기/접기(umbr 자세 — 걷든 앉든 그대로, 아무것도 막지 않는다: 비는 벽이 아니다), 든 채 꽂이 앞에서 C = 돌려놓기. 비가 시작되면 10m 안의 밖에 있던 주민이 와서 빌려 펴고
#    비를 맞으며 일과를 잇는다 — 비를 피하지 않고 걷는 첫 존재(resident.gd _to_rack). 그치면 돌려놓는다. 셋뿐이라 나머지는 여전히 처마로 간다(평범한 결과가 가장 흔하다는 규칙) ──

const UMB_COLORS := [Color("ad7096"), Color("1b0c15"), Color("efe9e2")]
var rack: Dictionary = {}   # 우산꽂이 자리 {pos, kind "rack", yaw, stock, shown, taken(칸 셋 = 우산 수, 주민이 걸어오는 동안 잡아 둔다)}

## 양동이 하나와 진열 우산 셋 — 손잡이가 위, 자루가 양동이 속으로, 셋이 조금씩 다르게 기운다(픽셀까지 대칭인 건 없다)
func _rack(at: Vector3) -> void:
	var bk := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.2; cm.bottom_radius = 0.16; cm.height = 0.45; bk.mesh = cm
	bk.material_override = _mat(Color("4a4a52")); bk.position = at + Vector3(0, 0.225, 0); _add(bk)
	var shown: Array = []
	for i in 3:
		var u := make_item("umbrella", Vector3.ZERO)
		(u.get_meta("umb") as MeshInstance3D).material_override = _mat(UMB_COLORS[i])
		u.position = at + Vector3(-0.08 + i * 0.08, 0.95 + i * 0.03, (i - 1) * 0.05); u.rotation = Vector3(PI / 2.0 + 0.1 * (i - 1), 0.0, 0.12 * (1 - i))
		shown.append(u)
	rack = { "pos": at + Vector3(0, 0, 0.75), "kind": "rack", "yaw": PI, "stock": 3, "shown": shown }
	spots.append(rack)

## 꽂이에서 우산 하나 — 방금 가려진 진열 우산과 같은 색. 비었으면 null. 사람도 주민도 이걸 부른다
func take_umbrella() -> Node3D:
	if rack.is_empty() or not counter_take(rack): return null
	var u := make_item("umbrella", Vector3.ZERO)
	(u.get_meta("umb") as MeshInstance3D).material_override = _mat(UMB_COLORS[int(rack["stock"]) % 3])
	return u

## 돌려놓기 — 재고 하나 늘고 진열 우산이 다시 보인다. 꽉 찼으면 false(바닥에 떨어진 우산을 누가 주워 온 뒤에야 생기는 일). 사람도 주민도 이걸 부른다
func rack_put() -> bool:
	if rack.is_empty() or int(rack["stock"]) >= 3: return false
	rack["stock"] = int(rack["stock"]) + 1; _show_stock(rack)
	return true

## 사람이 빈손으로 꽂이 앞에서 C(town_player) — 하나 빌려 손에(접힌 채, 지팡이처럼). 비었으면 아무 일도 없다
func rack_use(now: float) -> void:
	player.face(rack["yaw"])
	var u := take_umbrella()
	if u == null: return
	player.hold(u); player.action = "grab"; action_until = now + 0.4

## 사람이 우산을 들고 C(town_player) — 꽂이 앞(1.1m)이고 칸이 비었으면 돌려놓고, 아니면 펴기/접기(umbr, 0.3초 예비·회수는 Stick3D.umbr_k). 전엔 아래 '내려놓기'가 먼저 잡았다
func umbrella_use(now: float) -> void:
	if not rack.is_empty() and body.global_position.distance_to(rack["pos"]) < 1.1 and rack_put():
		player.release(self, Vector3.ZERO).queue_free(); player.pose_request = ""
		player.face(rack["yaw"]); player.action = "grab"; action_until = now + 0.4
		return
	for r in residents:
		if r.state != "down" and body.global_position.distance_to(r.global_position) < 1.3:
			# 우산을 든 채 주민 앞에서 C = 왼손 인사(run 77) — 빈손 인사와 같은 사거리(1.3m, town_player "resident"). 우산은 있던 대로(Stick3D 는 lwave 동안 umbr_k 를 안 건드린다)
			player.pose_request = "lwave"; use_until = now + StickPoses.LWAVE_T; action_until = now + 0.3
			player.face(atan2(r.global_position.x - body.global_position.x, r.global_position.z - body.global_position.z))
			r.greet(body)
			return
	player.pose_request = "" if player.pose_request == "umbr" else "umbr"
	action_until = now + StickPoses.UMBR_T

## 동쪽 마을(운영자 2026-09-30: "마을 좀 확장해 나가자") — 시장 동쪽 끝(x 46)을 지나 큰길이 이어지는 둘째 동네.
## 분수 광장(물 애셋 원 + 돌 받침 + 물줄기), 광장을 둘러싼 집 넷(북쪽 둘은 골목을 보고, 남쪽 둘은 광장을 본다 — 새 집마다 주인이 생긴다),
## 주차장(선 그은 아스팔트, 세워 둔 차 둘), 벤치·가로등·나무. 주민 일과가 자리를 쓰니 사람들이 걸어서, 차로 온다
func _east(at: Vector3) -> void:
	var plaza := MeshInstance3D.new(); var pm := BoxMesh.new(); pm.size = Vector3(14, 0.02, 10); plaza.mesh = pm
	plaza.material_override = _mat(Color("d8d2cc"), _tex("ground/cobble"), Vector3(14 / 0.8, 10 / 0.8, 1)); plaza.position = at + Vector3(0, 0.01, -3.5); _add(plaza)
	# 분수: 물 원(헤엄 판정도 된다 — 발 담그기) + 돌 테두리는 물 애셋이, 가운데 돌 기둥과 솟는 물줄기
	water.disc(at + Vector3(0, 0, -3.5), 1.8)
	_box(Vector3(0.5, 0.9, 0.5), at + Vector3(0, 0, -3.5), _mat(Color("bfb6b0")))
	var jet := CPUParticles3D.new(); jet.amount = 60; jet.lifetime = 1.1; jet.direction = Vector3.UP; jet.spread = 14.0
	jet.initial_velocity_min = 3.2; jet.initial_velocity_max = 3.8; jet.gravity = Vector3(0, -9.0, 0)
	var dm := SphereMesh.new(); dm.radius = 0.04; dm.height = 0.08; dm.radial_segments = 6; dm.rings = 3; jet.mesh = dm
	var jm := StandardMaterial3D.new(); jm.albedo_color = Color(0.8, 0.9, 0.96, 0.85); jm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; jm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	jet.material_override = jm; jet.position = at + Vector3(0, 0.95, -3.5); _add(jet)
	spots.append({ "pos": at + Vector3(0, 0, -1.2), "kind": "bank", "yaw": PI })       # 분수 보기
	spots.append({ "pos": at + Vector3(2.4, 0, -3.5), "kind": "bank", "yaw": -PI / 2.0 })
	_bench(at + Vector3(-4.5, 0, -0.1)); _bench(at + Vector3(4.5, 0, -0.1))
	_lamp(at + Vector3(-6.5, 0, 0.9)); _lamp(at + Vector3(6.5, 0, 0.9)); _lamp(at + Vector3(0, 0, -8.7))
	# 집 넷 — 시드가 다르니 층수·벽·지붕·창이 다 다르다
	_house(at + Vector3(-7.5, 0, -11.5), Vector3(4.2, 2.7, 3.4), Color("e6d3a5"), "brick", false, 21)
	_house(at + Vector3(0.5, 0, -12.5), Vector3(4.6, 2.9, 3.6), Color("dfe6ea"), "wood", false, 22)
	_house(at + Vector3(8.5, 0, -11.5), Vector3(3.8, 2.6, 3.2), Color("efe9e2"), "shingle", false, 23)
	_house(at + Vector3(-10, 0, -5.0), Vector3(3.6, 2.6, 3.2), Color("b56a5a"), "wood", false, 24)
	doors[doors.size() - 1]["job"] = "cobbler"   # 이 집 주민이 구두장이 — 광장 서쪽 끝 작업대(town_trades)가 낮 일터(run 80)
	_path(at + Vector3(0, 0, -7.1), at + Vector3(0, 0, -10.7), 1.6)   # 광장에서 북쪽 집 현관으로
	for t in [Vector3(-12, 0, -9.0), Vector3(12.5, 0, -7.5), Vector3(11, 0, 3.0), Vector3(-12.5, 0, 3.0)]:
		_tree(at + t, 1.0 + fmod(absf(t.x) * 0.31, 0.4))
	# 주차장: 광장 동쪽, 어두운 아스팔트에 흰 선 넷, 세워 둔 차 둘
	var lot := at + Vector3(12, 0, -3.5)
	_box(Vector3(6.5, 0.02, 7.5), lot, _mat(Color("5b5b63")), false)
	for i in 4: _box(Vector3(0.08, 0.025, 3.0), lot + Vector3(-2.4 + i * 1.6, 0.0, -1.8), _mat(Color("f7f4ef")), false)
	_car("van", lot + Vector3(-1.6, 0, -4.3), 0.0); _car("sedan", lot + Vector3(1.6, 0, -4.3), 0.0)
	_fence(at + Vector3(-14, 0, -15.5), 28.0)   # 동네 뒤 울타리
