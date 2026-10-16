class_name ClimbLeaper
extends RefCounted
## 리퍼 — 멀리뛰기 모래밭 팩(climb_pit.gd, run 162)의 주민 반쪽(run 163; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 구름판 뒤(오는 쪽 끝)에 서서 모래를 보는 주민 하나.
## 탑의 1분(MINUTE)마다 한 번(층마다 어긋나게), 그리고 플레이어가 이 모래밭에 기록을 낸 뒤 REACT 초 뒤(3 s 안)에 구름판으로 걸어가(walk, 같은 WALK) 다리를 털고(limber, stick3d_limber.gd) 로더의 웅크림으로 CHARGE 초 힘을 모아(charge — fig.crouch 0 → 0.9)
## 같은 takeoff() 로 뛴다(air — JUMP_V 860·RUN 300·G 2400, 로더와 같은 반암시적 오일러). 공중에선 플레이어가 하듯 늦게 민다: PUSH_T 뒤부터 AIR 1500 으로 뒤로 밀되, 지금 그만두면 내릴 자리(land_x)가 겨냥(aim — 모래의 AIMS 몫, 뜀마다 돌아가며)보다 먼 동안만.
## 같은 land() 로 내려 모래면 plant(제 st — count false: 말뚝은 플레이어의 기록이라 옮기지 않는다), 아니면 로더의 평이한 착지(squash −0.6); 일어나면(RISE_T) 모래 띠를 따라 집으로 걸어 돌아와(back) wheel 로 돌아서 모래를 보고 선다(idle).
## 바람은 없다: 모래밭 팩의 build 는 wind_of 를 받지 않는다(구름바다 층의 바람이 생기면 로더가 준다). 얼음 발판에선 climb.gd 와 같은 가속(ICE_K)으로 걸음이 붙는다.
## 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 다른 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 마을의 mind 는 아직 없다 — 백로그의 "the hurdler remembers" 가 그 자리). 노드는 모래밭의 노드(원점: 발판 가운데·윗면·절벽) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_pit.gd 의 LEAPER 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 혼자서도 이만큼마다 한 번 뛴다
const REACT := 1.5        # 플레이어의 기록 뒤 이만큼 있다 간다(3 s 안) — 보고 따라 뛰는 사이
const PUSH_T := 0.25      # 뛴 뒤 이만큼부터 뒤로 민다 — 온 힘의 뜀(215 px)은 어느 모래보다 길다
const ICE_K := 1.6        # 얼음 가속 — climb.gd 의 같은 수(vx += (target − vx) · min(1, dt · ICE_K))
const AIMS := [0.55, 0.72, 0.48, 0.65]   # 겨냥 — 모래(sand_x0..sand_x1)의 몫, 뜀마다 돌아가며(randf 가 아니다 — 점검이 같은 값을 본다)

var lj: ClimbPit
var pit: Dictionary       # 모래밭(climb_pit.pits 의 것 — 사전은 참조라 mark_t 를 같이 본다)
var fig: Stick3D
var st := { "pit": "", "x0": 0.0, "count": false }   # takeoff/land 의 제 상태 — 말뚝에는 세지 않는다
var on: Dictionary = {}   # takeoff/land 에 주는 발판 {id, kind}
var phase := "idle"       # idle | walk | limber | charge | air | plant | back | wheel
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0        # 다음 혼자 뛰는 때(lj.t)
var seen_mark := -99.0    # 따라 뛴 플레이어의 mark_t — 한 기록에 한 번
var jumps := 0            # 뛴 수 — AIMS 를 돌린다
var flights := 0          # takeoff 가 참이었던 수(점검용 — 늘 jumps 와 같다)
var marks := 0            # 모래에 내린 수(점검용)
var last_dist := 0.0      # 마지막 기록(px) — 말뚝에는 세지 않는다
var x := 0.0; var y := 0.0; var vx := 0.0; var vy := 0.0
var dir := 1.0            # 구름판 → 모래 쪽(모래밭의 dir)
var home_x := 0.0; var board_x := 0.0; var aim_x := 0.0; var y0 := 0.0
var hop_kind := "std"

func _init(pack: ClimbPit, p: Dictionary, parent: Node3D) -> void:
	lj = pack; pit = p; dir = float(p["dir"]); hop_kind = String(p["hop_kind"])
	on = { "id": String(p["hop_id"]), "kind": hop_kind }
	board_x = float(p["board_x"]); y0 = float(p["y"])
	home_x = board_x - dir * (lj.board_w() / 2.0 + 2.0)   # 구름판 뒤 — 발판 오는 쪽 끝(HW 안쪽)
	x = home_x; y = y0
	next_at = lj.t + 20.0 + float(int(p["n"]) % 5) * 8.0   # 층마다 어긋나게 — 구름바다의 다섯 층이 한꺼번에 뛰지 않는다
	fig = Stick3D.new(); fig.color = Color("5a6b4e"); fig.head_color = Color("5a6b4e")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "leaper"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("5a6b4e"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	fig.face(PI / 2.0 if dir > 0.0 else -PI / 2.0)
	_drive()

## 매 틱(climb_pit._process)
func step(dt: float) -> void:
	if not is_instance_valid(fig) or dt <= 0.0: return
	since += dt
	match phase:
		"idle":
			var mk := float(pit.get("mark_t", -99.0))
			if lj.t >= next_at: _go("walk", dir)
			elif mk != seen_mark and lj.t - mk >= REACT and lj.t - mk < 3.0: seen_mark = mk; _go("walk", dir)   # 플레이어가 기록을 냈다 — 따라 뛴다
		"walk", "back":
			_walk(dt)
		"limber":
			if since >= LimberPoses.LIMBER_T: fig.pose_request = ""; phase = "charge"; since = 0.0
		"charge":
			fig.crouch = minf(1.0, since / C.CHARGE) * 0.9   # 로더의 웅크림과 같은 식
			if since >= C.CHARGE: _leap()
		"air":
			_fly(dt)
		"plant":
			if since >= PlantPoses.RISE_T: fig.pose_request = ""; _go("back", -dir)   # 자세의 시계를 묻지 않는다(헤드리스 점검은 프레임을 안 돌린다)
		"wheel":
			if since >= WheelPoses.WHEEL_T: fig.look_yaw = 0.0; fig.pose_request = ""; _rest()
	_drive()

## 걷는 틱 — walk 는 구름판에 닿아 몸을 풀고, back 은 집에 닿아 돌아선다
func _walk(dt: float) -> void:
	var d := dir if phase == "walk" else -dir
	var target := d * C.WALK
	vx = vx + (target - vx) * minf(1.0, dt * ICE_K) if hop_kind == "ice" else target
	x += vx * dt
	var end := board_x if phase == "walk" else home_x
	if (x - end) * d < 0.0: return
	x = end; vx = 0.0
	if phase == "walk": fig.pose_request = "limber"; phase = "limber"; since = 0.0
	else: fig.pose_request = "wheel"; _go("wheel", dir)

## 구름판에서 온 힘으로 — 로더의 모아 뛰는 가지와 같은 수; 겨냥은 모래의 AIMS 몫
func _leap() -> void:
	fig.crouch = 0.0
	var sx0 := float(pit["sand_x0"]); var sx1 := float(pit["sand_x1"])
	aim_x = sx0 + dir * absf(sx1 - sx0) * float(AIMS[jumps % AIMS.size()]); jumps += 1
	if lj.takeoff(on, x, C.PLAYER_Z, 1.0, st): flights += 1   # 구름판 위·힘 끝까지 — 늘 참
	vx = dir * C.RUN; vy = C.JUMP_V; phase = "air"; since = 0.0

## 지금 밀기를 그만두면 내릴 x — 발판 윗면(y0)으로 돌아오는 때까지 vx 로
func land_x() -> float:
	var tr := (vy + sqrt(maxf(0.0, vy * vy + 2.0 * C.G * (y - y0)))) / C.G
	return x + vx * tr

## 공중의 틱 — 로더와 같은 순서(중력 → 밀기 → 자리 → 착지 판정); PUSH_T 뒤 겨냥보다 멀리 내릴 동안 뒤로 민다(AIR, ±RUN 안)
func _fly(dt: float) -> void:
	vy -= C.G * dt
	if since >= PUSH_T and (land_x() - aim_x) * dir > 0.0: vx = clampf(vx - dir * C.AIR * dt, -C.RUN, C.RUN)
	var ny := y + vy * dt
	x += vx * dt
	if vy <= 0.0 and y >= y0 and ny <= y0:
		y = y0; vx = 0.0; vy = 0.0
		var r := lj.land(on, x, C.PLAYER_Z, st)
		if bool(r["sand"]): fig.pose_request = "plant"; marks += 1; last_dist = float(r["dist"])
		else: fig.squash = -0.6   # 로더의 plain 착지 — 같은 squash(모래 밖은 겨냥상 없지만 식은 같다)
		phase = "plant"; since = 0.0
		return
	y = ny

func _go(p: String, d: float) -> void:
	phase = p; since = 0.0
	fig.face(PI / 2.0 if d > 0.0 else -PI / 2.0)

## 집에서 모래를 보고 선다 — 다음은 1분 뒤(또는 플레이어의 기록 뒤)
func _rest() -> void:
	phase = "idle"; since = 0.0; vx = 0.0; vy = 0.0; fig.pose_request = ""; fig.crouch = 0.0
	fig.face(PI / 2.0 if dir > 0.0 else -PI / 2.0); next_at = lj.t + MINUTE; _drive()

## Stick3D 에 걸음·공중을 — climb.gd 가 플레이어에게 하는 것과 같은 식(모래밭 노드의 원점 기준)
func _drive() -> void:
	var air := phase == "air"
	fig.airborne = air; fig.vertical = vy * C.K if air else 0.0
	fig.move_dir = Vector3(signf(vx), 0, 0) if absf(vx) > 20.0 and not air else Vector3.ZERO
	fig.speed = absf(vx) * C.K
	fig.position = Vector3((x - float(pit["cx"])) * C.K, (y - y0) * C.K, (C.PLAYER_Z - C.WALL_Z) * C.K)
