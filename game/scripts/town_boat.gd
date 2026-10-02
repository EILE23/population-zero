class_name TownBoat
extends TownPlaces
## 부두와 거룻배(run 78, 구조 성장 — 규칙의 "dock, transit route"): 다리 동쪽 북쪽 둑의 나무 부두에 납작한 거룻배 한 척. 강은 run 68 이래 걸어서는 못 건너는 물 띠였다 —
## 배를 타면 물 위(다리 동쪽 x 5.8..21.5, 디딤돌까지)가 다닐 수 있는 땅이 된다. 빈손으로 부두 앞에서 C = 탄다, ← → = 노 젓기(row 자세, 노가 같은 박자로 물을 젓는다), 배 위에서 C = 그 자리 북쪽 둑에 내린다.
## 주민도 같은 자리(spots "boat")를 골라 타고 12m 나갔다 부두로 돌아와 내린다(resident.gd "boat"). 아무도 안 탄 배는 계류줄이 끌듯 부두로 흘러온다 — 강 한가운데 버려진 배는 없다.
## 다리 밑은 못 지난다(고개 숙이기 자세는 다음 조각): 다리가 배의 서쪽 끝.
## 남쪽 나루(run 94, 구조 성장 — 다리가 아닌 첫 건널목): 전망 언덕 발치 x 18 에 둘째 부두. 배는 가까운 둑에 내려 주고 거기서 기다린다(home);
## 주민은 x 8 동쪽에서 강을 건널 때 배가 제 편 부두에 비어 있으면 열에 셋 나룻배로 건넌다(crossings 의 board/land). 대 놓고 내리면 moor(말뚝에 밧줄 감기). 상속 사슬: base → build → places → **boat** → trades → critters → systems → combat → ride → player → town3d.

const DOCK_X := 4.0                       # 부두 x — 큰길 x=0 길(±1)과 북쪽 물가 자리(6.5) 사이, 울타리(x 9..14)의 서쪽
const BOAT_X_MIN := BRIDGE_W / 2.0 + 1.8  # 다리 동쪽 난간에서 1.8m — 뱃머리(±1.1)가 다리에 닿지 않는다
const BOAT_X_MAX := STONES_X - 1.5         # 디딤돌(run 84)이 배의 동쪽 끝 — 뱃머리(±1.1)가 돌에 닿지 않는다
const ROW_SPD := 2.0                      # 노 저어 가는 속도(m/s) — 걷기(2.6)보다 조금 느리다
const OUT_M := 12.0                       # 주민이 한 번에 나가는 거리
const SOUTH_X := 18.0                     # 남쪽 부두 x(run 94) — 언덕 바위(x 13..21, z 15.5..)의 북쪽, 자갈길로 디딤돌 남쪽 길에 닿는다
const SEAT_OFF := Vector3(0.1, -0.04, 0)  # 배 노드 기준 탄 이의 발끝 — 판자(x 0) 바로 뒤, 바닥판 윗면(-0.04)

var boat: Dictionary = {}   # {node, x, v, rider: null | "player" | Resident, oars, out: bool, from: 탄 부두 x, to: 나루 목적지 x(-1 = 나갔다 돌아오기), home: 빈 배가 기다리는 부두 x, tied: 밧줄로 매였나, rope}
var rowing := false         # 내가 배에 탄 중

## 부두(갑판 + 말뚝 둘)와 배(바닥판·양 옆판·양 끝판·가운데 판자·노 두 자루). 배는 충돌 없음 — 탄 몸은 강의 보이지 않는 벽을 지나야 하니(collision_mask 0) 배도 막지 않는다
func _jetty() -> void:
	var wood := _mat(Color("8a6a4a")); var pale := _mat(Color("b48a5a")); var iron := _mat(Color("4a4a52"))
	_box(Vector3(1.2, 0.12, 1.0), Vector3(DOCK_X, 0, RIVER_N - 0.6), wood)   # 갑판 z 7.9..8.9 — 둑 턱(8.88)을 덮는다, 물 위 벽(9.0)이 끝
	for x in [-0.45, 0.45]: _box(Vector3(0.14, 0.32, 0.14), Vector3(DOCK_X + x, 0.12, RIVER_N - 0.2), iron, false)
	var n := Node3D.new(); n.position = Vector3(DOCK_X, 0, (RIVER_N + RIVER_S) / 2.0); add_child(n)
	_box(Vector3(2.2, 0.06, 0.9), Vector3(0, -0.1, 0), pale, false, n)                     # 바닥판 -0.1..-0.04
	for sz in [-0.45, 0.45]: _box(Vector3(2.2, 0.3, 0.08), Vector3(0, -0.12, sz), wood, false, n)   # 옆판 -0.12..0.18(물 위 0.16)
	for sx in [-1.1, 1.1]: _box(Vector3(0.12, 0.3, 0.9), Vector3(sx, -0.12, 0), wood, false, n)     # 끝판 — 앞뒤가 같은 거룻배(양쪽으로 젓는다)
	_box(Vector3(0.36, 0.05, 0.9), Vector3(0, 0.12, 0), wood, false, n)                     # 가운데 판자(자리) — 윗면 0.17
	var oars: Array = []
	for sz in [-1.0, 1.0]:
		var oar := Node3D.new(); oar.position = Vector3(-0.15, 0.22, sz * 0.48); n.add_child(oar)   # 노걸이 — 탄 이(−x 를 본다)의 손 앞
		_box(Vector3(0.03, 0.03, 1.9), Vector3(0, -0.015, sz * 0.5), iron, false, oar)   # 자루: 안쪽(손) 0.45, 바깥 1.45
		_box(Vector3(0.16, 0.02, 0.32), Vector3(0, -0.01, sz * 1.3), pale, false, oar)   # 날
		oars.append(oar)
	# 남쪽 부두(run 94): 같은 갑판·말뚝을 남쪽 둑에, 동쪽으로 디딤돌 남쪽 길까지 자갈길 — 건너온 사람이 언덕 바위를 돌아 계단으로 간다
	_box(Vector3(1.2, 0.12, 1.0), Vector3(SOUTH_X, 0, RIVER_S + 0.6), wood)
	for x in [-0.45, 0.45]: _box(Vector3(0.14, 0.32, 0.14), Vector3(SOUTH_X + x, 0.12, RIVER_S + 0.2), iron, false)
	_path(Vector3(SOUTH_X + 0.6, 0, RIVER_S + 1.3), Vector3(STONES_X - 0.7, 0, RIVER_S + 1.3), 1.0)
	var rope := _box(Vector3(0.025, 0.025, 1.0), Vector3.ZERO, _mat(Color("e6d3a5")), false)   # 매인 밧줄 — 길이 1m 상자를 늘여 말뚝과 뱃전 사이에 건다(_rope)
	boat = { "node": n, "x": DOCK_X, "v": 0.0, "rider": null, "oars": oars, "out": false, "from": DOCK_X, "to": -1.0, "home": DOCK_X, "tied": true, "rope": rope }
	spots.append({ "pos": Vector3(DOCK_X, 0, RIVER_N - 0.6), "kind": "boat", "yaw": PI })
	spots.append({ "pos": Vector3(SOUTH_X, 0, RIVER_S + 0.6), "kind": "boat", "yaw": 0.0 })

## 배가 대어 있는 부두 x(북 DOCK_X, 남 SOUTH_X) — 어느 부두에도 없으면 -1
func docked_at() -> float:
	if boat.is_empty(): return -1.0
	for lx in [DOCK_X, SOUTH_X]:
		if absf(float(boat["x"]) - lx) <= 0.8: return lx
	return -1.0

## 이 점에서 가까운 부두 x — 강 북쪽이면 북쪽 부두, 남쪽이면 남쪽 부두(배 위면 배 x 로: 두 부두 가운데 서쪽이 북쪽)
func landing_of(p: Vector3, by_x := false) -> float:
	if by_x: return DOCK_X if p.x < (DOCK_X + SOUTH_X) / 2.0 else SOUTH_X
	return DOCK_X if p.z < RIVER_Z else SOUTH_X

## 나루(run 94, crossings 가 부른다) — 배가 출발 쪽 부두에 비어 있고, 두 부두를 거치는 걸음이 다리·디딤돌보다 6m 넘게 길지 않으면 열에 셋은 배로:
## [탈 부두(board), 내릴 부두(land)] + 남쪽 부두와 풀밭 사이 모퉁이. 아니면 [] — 다리나 디딤돌로 간다. 배가 그새 떠났으면 resident.gd 가 다시 짠다
func ferry(from: Vector3, to: Vector3) -> Array:
	var lx := landing_of(from); var ly := SOUTH_X if lx == DOCK_X else DOCK_X
	if boat.is_empty() or boat["rider"] != null or docked_at() != lx: return []
	var walk := absf(from.x - lx) + absf(to.x - ly)
	if walk > minf(absf(from.x) + absf(to.x), absf(from.x - STONES_X) + absf(to.x - STONES_X)) + 6.0 or randf() >= 0.3: return []
	var n := { "pos": Vector3(DOCK_X, 0, RIVER_N - 0.6), "act": "board" }
	var s := { "pos": Vector3(SOUTH_X, 0, RIVER_S + 0.6), "act": "land" }
	if lx == DOCK_X: return [n, s] + _landing_bend(to)
	n["act"] = "land"; s["act"] = "board"
	var back := _landing_bend(from); back.reverse()
	return back + [s, n]

## 남쪽 부두와 풀밭 안쪽 사이 — 언덕 바위(x 13..21) 동쪽이나 언덕 위·남쪽이면 자갈길 끝(디딤돌 남쪽 길)을 거쳐 디딤돌과 같은 모퉁이로. 부두에서 곧장 가면 바위 북쪽 낯에 막힌다
func _landing_bend(p: Vector3) -> Array:
	var foot := { "pos": Vector3(STONES_X - 0.6, 0, RIVER_S + 1.3), "act": "" }
	if p.x > TERR_AT.x + TERR_W / 2.0: return [foot]
	var b := _stones_bend(p)
	return ([foot] + b) if not b.is_empty() and (b[0]["pos"] as Vector3).x > TERR_AT.x else b

## 그 부두 쪽 둑(내리는 자리 z, 바라보는 쪽) — 북은 북쪽을, 남은 남쪽을 보고 내린다
func _bank_z(lx: float) -> float:
	return RIVER_N - 0.75 if lx == DOCK_X else RIVER_S + 0.75

## 탄 이의 발끝(세계 좌표) — 사람은 _boats 가, 주민은 resident.gd 가 프레임마다 여기로 온다
func boat_seat() -> Vector3:
	return (boat["node"] as Node3D).global_position + SEAT_OFF

## 배 속도 정규화(-1..1) — 자세(row)의 박자와 노의 방향이 이걸 탄다
func boat_k() -> float:
	return clampf(float(boat["v"]) / ROW_SPD, -1.0, 1.0)

## 매 프레임: 탄 이의 뜻대로(사람은 ← →, 주민은 나갔다 돌아오기), 빈 배는 부두로. 노는 탄 이의 젓기 진행(StickPoses.row_k)으로 물을 젓는다 — 손과 노가 한 박자
func _boats(delta: float, now: float) -> void:
	if boat.is_empty(): return
	var n: Node3D = boat["node"]; var rv: Variant = boat["rider"]
	var rider: ResidentBase = rv if (rv is ResidentBase and is_instance_valid(rv)) else null
	var want := 0.0
	if rv is String:
		want = Input.get_axis("move_left", "move_right") * ROW_SPD
	elif rider != null:
		# 주민: 나루(to ≥ 0)면 건너편 부두까지 가서 내려 준다(걷던 길을 이어 간다), 아니면 탄 부두에서 건너편 쪽으로 12m 나갔다 돌아온다
		var from := float(boat["from"]); var to := float(boat["to"])
		var goal := to if to >= 0.0 else (from if boat["out"] else from + signf((DOCK_X + SOUTH_X) / 2.0 - from) * OUT_M)
		want = clampf((goal - float(boat["x"])) * 1.5, -ROW_SPD, ROW_SPD)   # 다 와 가면 늦춘다 — 일정 속도로 오다 서면 0.7m 를 지나쳤다
		if absf(goal - float(boat["x"])) < 0.15:
			if to >= 0.0: unboard(rider, now)
			elif not boat["out"]: boat["out"] = true
			else: rider.busy_until = now   # 부두로 돌아왔다 — 일과가 끝나 _leave 가 내려 준다
	else:
		if rv != null: boat["rider"] = null   # 사라진 주민
		want = clampf((float(boat["home"]) - float(boat["x"])) * 1.5, -0.6, 0.6)   # 계류줄: 빈 배는 마지막에 내린 쪽 부두로 흘러온다(run 94 — 늘 북쪽이 아니다)
	boat["v"] = move_toward(float(boat["v"]), want, delta * 3.0)
	boat["x"] = clampf(float(boat["x"]) + float(boat["v"]) * delta, BOAT_X_MIN, BOAT_X_MAX)
	n.position.x = float(boat["x"]); n.position.y = sin(wind_t * 1.3 + float(boat["x"])) * 0.012   # 물결에 조금 뜬다
	n.rotation.z = -float(boat["v"]) * 0.03
	var fig: Stick3D = player if rv is String else (rider.fig if rider != null else null)
	var k := StickPoses.row_k(fig) if fig != null else 0.35
	var going: bool = fig != null and absf(fig.swing_k) > 0.05
	var wet: bool = going and fmod(fig.push_t, StickPoses.ROW_T) < 0.5   # 젓는 반(날이 물속), 회수 반은 물 밖
	var dir: float = signf(fig.swing_k) if going else 1.0
	for i in 2:
		var sz: float = [-1.0, 1.0][i]; var oar: Node3D = boat["oars"][i]
		oar.rotation.y = sz * (0.5 - k) * dir   # 캐치(k 0)엔 날이 뱃머리 쪽, 피니시(k 1)엔 고물 쪽
		oar.rotation.x = sz * (0.32 if wet else 0.1)
	_rope()
	if rv is String:
		player.swing_k = boat_k()
		body.global_position = boat_seat(); body.velocity = Vector3.ZERO
		player.pose_request = "row"; player.face(-PI / 2.0)

## 빈손으로 부두 앞에서 C(town_player) — 배가 부두에 비어 있으면 탄다. 아니면(주민이 타고 나갔다) 아무 일도 없다: 돌아오는 배가 보인다
func boat_use(now: float) -> void:
	if boat.is_empty() or boat["rider"] != null or docked_at() != landing_of(body.global_position): return   # 배가 내 쪽 부두에 있어야 — 건너편에 매인 배는 보이기만 한다
	boat["rider"] = "player"; boat["out"] = false; boat["tied"] = false; rowing = true
	body.collision_layer = 0; body.collision_mask = 0   # 강의 보이지 않는 벽(z 9..12)을 지나야 한다 — 앉기와 같은 요령
	seat = {}; player.seated = false; player.push_t = 0.0; player.pose_request = "row"
	player.move_dir = Vector3.ZERO; player.speed = 0.0
	player.action = "grab"; action_until = now + 0.4

## 배 위에서 C(town_player) — 가까운 부두 쪽 둑에 내린다(run 94: 두 부두 가운데 동쪽이면 남쪽 둑). 부두에 대었으면 말뚝에 밧줄을 감고(moor) 배는 거기서 기다린다
func boat_leave(now: float) -> void:
	var lx := landing_of(boat_seat(), true); var tie := docked_at() >= 0.0
	rowing = false; boat["rider"] = null; boat["home"] = lx
	body.collision_layer = 4; body.collision_mask = 7   # 사람의 층(4)·마스크(7)로 — 1/1 은 주민·차가 나를 세계로 읽었다(polish 79)
	body.global_position = Vector3(float(boat["x"]), 0.3, _bank_z(lx)); body.velocity = Vector3.ZERO
	player.swing_k = 0.0; player.push_t = 9.0; player.face(0.0 if lx == DOCK_X else PI)   # 둑 안쪽을 본다
	if tie:
		player.face(PI if lx == DOCK_X else 0.0); player.pose_request = "moor"   # 매려면 물(말뚝)을 본다; use_until = now + DockPoses.MOOR_T; action_until = use_until
		get_tree().create_timer(DockPoses.MOOR_TIGHT).timeout.connect(func() -> void: if boat["rider"] == null: boat["tied"] = true)
	else:
		player.pose_request = ""; player.action = "grab"; action_until = now + 0.4

## 주민이 부두 자리에 닿아 탄다(resident.gd _arrive "boat", 나루면 걷던 길의 "board") — 사람과 같은 조건: 배가 제 쪽 부두에 비어 있을 때만 true.
## cross(나루)면 건너편 부두가 목적지(_boats 가 거기서 unboard), 아니면 나갔다 돌아오기
func board(r: ResidentBase, cross := false) -> bool:
	var lx := landing_of(r.global_position)
	if boat.is_empty() or boat["rider"] != null or docked_at() != lx: return false
	boat["rider"] = r; boat["out"] = false; boat["tied"] = false; boat["from"] = lx
	boat["to"] = (SOUTH_X if lx == DOCK_X else DOCK_X) if cross else -1.0
	r.in_boat = true; r.collision_layer = 0; r.collision_mask = 0
	r.fig.push_t = 0.0; r.fig.pose_request = "row"; r.fig.face(-PI / 2.0)
	return true

## 주민이 내린다(resident.gd _leave·hit, 나루 끝은 _boats) — 사람과 같은 규칙: 가까운 부두 쪽 둑에. 나루로 부두에 닿았으면 사람처럼 moor 하고(걷던 길은 그동안 기다린다) 배는 거기 매인다
func unboard(r: ResidentBase, now := -1.0) -> void:
	var lx := landing_of(boat_seat(), true); var tie := now >= 0.0 and docked_at() >= 0.0
	if boat.get("rider") == r: boat["rider"] = null; boat["home"] = lx; boat["to"] = -1.0
	r.in_boat = false
	r.collision_layer = 4; r.collision_mask = 7   # 나루(걷는 중)엔 _leave 가 안 돌아 층을 돌려줄 곳이 여기뿐
	r.global_position = Vector3(float(boat["x"]), 0.3, _bank_z(lx)); r.velocity = Vector3.ZERO
	r.fig.swing_k = 0.0; r.fig.push_t = 9.0
	if tie:
		r.fig.pose_request = "moor"; r.fig.face(PI if lx == DOCK_X else 0.0); r._door_wait = now + DockPoses.MOOR_T
		r.say(r.mind.line("moored"), 1.4)
		get_tree().create_timer(DockPoses.MOOR_TIGHT).timeout.connect(func() -> void: if boat["rider"] == null: boat["tied"] = true)

## 매인 밧줄 — 배가 비어 부두에 매여 있으면 그 부두의 동쪽 말뚝에서 뱃전(가까운 쪽)까지. 누가 타면 풀린다
func _rope() -> void:
	var rope: Node3D = boat["rope"]; var lx := docked_at()
	rope.visible = bool(boat["tied"]) and boat["rider"] == null and lx >= 0.0
	if not rope.visible: return
	var n: Node3D = boat["node"]; var north := lx == DOCK_X
	var a := Vector3(lx + 0.45, 0.4, RIVER_N - 0.2 if north else RIVER_S + 0.2)
	var b := n.global_position + Vector3(0.9, 0.12, -0.45 if north else 0.45)
	rope.look_at_from_position((a + b) / 2.0, b, Vector3.UP)
	rope.scale = Vector3(1, 1, a.distance_to(b))
