class_name TownBoat
extends TownPlaces
## 부두와 거룻배(run 78, 구조 성장 — 규칙의 "dock, transit route"): 다리 동쪽 북쪽 둑의 나무 부두에 납작한 거룻배 한 척. 강은 run 68 이래 걸어서는 못 건너는 물 띠였다 —
## 배를 타면 물 위(다리 동쪽 x 2.8..44)가 다닐 수 있는 땅이 된다. 빈손으로 부두 앞에서 C = 탄다, ← → = 노 젓기(row 자세, 노가 같은 박자로 물을 젓는다), 배 위에서 C = 그 자리 북쪽 둑에 내린다.
## 주민도 같은 자리(spots "boat")를 골라 타고 12m 나갔다 부두로 돌아와 내린다(resident.gd "boat"). 아무도 안 탄 배는 계류줄이 끌듯 부두로 흘러온다 — 강 한가운데 버려진 배는 없다.
## 다리 밑은 못 지난다(고개 숙이기 자세는 다음 조각): 다리가 배의 서쪽 끝. 상속 사슬: base → build → places → **boat** → trades → critters → systems → combat → ride → player → town3d.

const DOCK_X := 4.0                       # 부두 x — 큰길 x=0 길(±1)과 북쪽 물가 자리(6.5) 사이, 울타리(x 9..14)의 서쪽
const BOAT_X_MIN := BRIDGE_W / 2.0 + 1.8  # 다리 동쪽 난간에서 1.8m — 뱃머리(±1.1)가 다리에 닿지 않는다
const BOAT_X_MAX := WORLD_X - 2.0
const ROW_SPD := 2.0                      # 노 저어 가는 속도(m/s) — 걷기(2.6)보다 조금 느리다
const OUT_M := 12.0                       # 주민이 한 번에 나가는 거리
const SEAT_OFF := Vector3(0.1, -0.04, 0)  # 배 노드 기준 탄 이의 발끝 — 판자(x 0) 바로 뒤, 바닥판 윗면(-0.04)

var boat: Dictionary = {}   # {node, x, v, rider: null | "player" | Resident, oars: [Node3D, Node3D], out: bool}
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
	boat = { "node": n, "x": DOCK_X, "v": 0.0, "rider": null, "oars": oars, "out": false }
	spots.append({ "pos": Vector3(DOCK_X, 0, RIVER_N - 0.6), "kind": "boat", "yaw": PI })

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
		if not boat["out"]:
			want = ROW_SPD
			if float(boat["x"]) >= DOCK_X + OUT_M: boat["out"] = true
		elif float(boat["x"]) > DOCK_X + 0.08:
			want = -ROW_SPD
		else:
			rider.busy_until = now   # 부두로 돌아왔다 — 일과가 끝나 _leave 가 내려 준다
	else:
		if rv != null: boat["rider"] = null   # 사라진 주민
		want = clampf((DOCK_X - float(boat["x"])) * 1.5, -0.6, 0.6)   # 계류줄: 빈 배는 부두로 흘러온다
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
	if rv is String:
		player.swing_k = boat_k()
		body.global_position = boat_seat(); body.velocity = Vector3.ZERO
		player.pose_request = "row"; player.face(-PI / 2.0)

## 빈손으로 부두 앞에서 C(town_player) — 배가 부두에 비어 있으면 탄다. 아니면(주민이 타고 나갔다) 아무 일도 없다: 돌아오는 배가 보인다
func boat_use(now: float) -> void:
	if boat.is_empty() or boat["rider"] != null or absf(float(boat["x"]) - DOCK_X) > 0.8: return
	boat["rider"] = "player"; boat["out"] = false; rowing = true
	body.collision_layer = 0; body.collision_mask = 0   # 강의 보이지 않는 벽(z 9..12)을 지나야 한다 — 앉기와 같은 요령
	seat = {}; player.seated = false; player.push_t = 0.0; player.pose_request = "row"
	player.move_dir = Vector3.ZERO; player.speed = 0.0
	player.action = "grab"; action_until = now + 0.4

## 배 위에서 C(town_player) — 그 자리 북쪽 둑에 내린다(부두면 갑판 위로 떨어진다). 배는 두고 간다 — 빈 배는 _boats 가 부두로 흘려보낸다
func boat_leave(now: float) -> void:
	rowing = false; boat["rider"] = null
	body.collision_layer = 4; body.collision_mask = 7   # 사람의 층(4)·마스크(7)로 — 1/1 은 주민·차가 나를 세계로 읽었다(polish 79)
	body.global_position = Vector3(float(boat["x"]), 0.3, RIVER_N - 0.75); body.velocity = Vector3.ZERO
	player.pose_request = ""; player.swing_k = 0.0; player.push_t = 9.0; player.face(0.0)
	player.action = "grab"; action_until = now + 0.4

## 주민이 부두 자리에 닿아 탄다(resident.gd _arrive "boat") — 사람과 같은 조건: 배가 부두에 비어 있을 때만 true
func board(r: ResidentBase) -> bool:
	if boat.is_empty() or boat["rider"] != null or absf(float(boat["x"]) - DOCK_X) > 0.8: return false
	boat["rider"] = r; boat["out"] = false
	r.in_boat = true; r.collision_layer = 0; r.collision_mask = 0
	r.fig.push_t = 0.0; r.fig.pose_request = "row"; r.fig.face(-PI / 2.0)
	return true

## 주민이 내린다(resident.gd _leave·hit) — 사람과 같은 규칙: 그 자리 북쪽 둑에
func unboard(r: ResidentBase) -> void:
	if boat.get("rider") == r: boat["rider"] = null
	r.in_boat = false
	r.global_position = Vector3(float(boat["x"]), 0.3, RIVER_N - 0.75); r.velocity = Vector3.ZERO
	r.fig.swing_k = 0.0; r.fig.push_t = 9.0
