class_name ClimbRoller
extends RefCounted
## 통나무꾼 — 구르는 통나무 팩(climb_log.gd, run 166)의 주민 반쪽(run 167; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 통나무마다 하나, 집 쪽 말뚝(오른끝) 바깥 HOME 에 서서 통나무를 보는 주민.
## 탑의 1분(MINUTE)마다 한 번(층마다 어긋나게), 그리고 플레이어의 타기가 이 통나무에서 끝난 뒤(내려서거나 엎어지거나 — 팩이 me_off_t 에 적는다) REACT 초 뒤에 탄다 — 통나무로 걸어가(WALK, 얼음은 플레이어와 같은 ICE_K 가속)
## 가장자리 STAND 앞에 서서 steady(stick3d_steady.gd — 오른발을 얹어 눌러 본다) 한 번, 그 다음 같은 roll() 을 제 st 로 부르며(count false — 제 타기·엎어짐은 판에 안 센다) 같은 log 자세로 같은 WALK × slow 로 말뚝까지 타고, 말뚝에서 제 걸음으로 넘어 내려서 먼 끝 FAR 까지 걷고,
## 기존 wheel 로 돌아서며 앞길(lane_z — 통나무 끝 바깥, 발판 앞끝 안쪽)로 옮겨 서고 걸어 돌아와(back) 다시 wheel 로 돌아서 통나무를 보며 선다. 얕은 발판(앞길이 안 나오는)에선 되돌아올 때도 통나무를 밟아 굴린다(집 쪽으로 — 같은 roll).
## 얼음 발판에선 느린 출발에 발이 통나무를 못 따라가 세 번째 타기마다(SLIP_EVERY) SLIP_PX 를 구른 뒤 멈춰 서고 — 같은 roll 이 stop_s 뒤 엎는다(log_v 0 의 허둥댐, 그 뒤 플레이어와 같은 teeter, 통나무의 kick) — 집으로 걸어 돌아간다(오늘은 이만).
## 플레이어가 통나무에 서 있으면(me_t) 집에서 안 떠나고, 가는 길이면 WAIT 앞에 서서 기다린다(한 통나무에 둘은 안 탄다). 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 마을의 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 mind 는 아직 없다).
## 노드는 통나무의 노드(원점: 발판 가운데·윗면·절벽) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_log.gd 의 ROLLER 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 혼자서도 이만큼마다 한 번 탄다
const REACT := 0.8        # 플레이어의 타기가 끝난 뒤 이만큼 있다 간다 — 보고 따라 타는 사이(엎어진 통나무의 grace 0.6 보다 길다)
const HOME := 8.0         # 말뚝 바깥 이만큼에 선다(px)
const STAND := 6.0        # 올라타는 자리(radius + MOUNT) 이만큼 앞에 서서 발을 얹는다
const WAIT := 12.0        # 플레이어가 타고 있으면 그보다 이만큼 더 앞에서 기다린다
const LANE_GAP := 4.0     # 앞길과 통나무 끝 사이 여유(px)
const ICE_K := 1.6        # 얼음 가속 — climb.gd 의 같은 수(vx += (target − vx) · min(1, dt · ICE_K))
const SLIP_EVERY := 3     # 얼음에선 이 번째 타기마다 멈춰 선다
const SLIP_PX := 20.0     # 그 타기에서 이만큼 구른 뒤
const EPS := 0.000001     # 시계 비교의 여유 — 1/60 을 마흔여덟 번 더해도 0.8 에 닿게

var lg: ClimbLog
var g: Dictionary         # 통나무(climb_log.logs 의 것 — 참조라 lx·me_t·me_off_t 를 같이 본다)
var fig: Stick3D
var st := { "on_id": "", "riding": false, "still": 0.0, "ride": 0.0, "last": 1.0, "count": false }   # roll 의 제 상태 — 판에는 세지 않는다
var on: Dictionary = {}   # roll 에 주는 발판 {id, kind}
var phase := "idle"       # idle | walk | steady | ride | slip | teeter | wheel | back | wheel2
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0        # 다음 혼자 타는 때(lg.t)
var seen_off := -99.0     # 따라간 플레이어의 me_off_t — 한 번에 한 번
var x := 0.0; var z := 0.0; var vx := 0.0
var dir := -1.0           # 지금 가는 방향 — 타는 길은 집(오른끝) → 먼 끝(왼끝)
var home_x := 0.0; var far_x := 0.0; var ride_z := 0.0; var lane_z := 0.0
var hop_kind := "std"
var rides := 0; var spills := 0; var steadies := 0; var waited := 0.0; var max_ride := 0.0   # 점검용

func _init(pack: ClimbLog, s: Dictionary, parent: Node3D) -> void:
	lg = pack; g = s; hop_kind = String(s["hop_kind"])
	on = { "id": String(s["hop_id"]), "kind": hop_kind }
	home_x = float(s["x1"]) + HOME; far_x = float(s["x0"]) - HOME
	ride_z = float(s["z"])
	var clear := ride_z + lg.length() / 2.0 + C.HZ + LANE_GAP          # 통나무 끝 바깥 — roll 이 묻지 않는 z
	var front := C.WALL_Z + float(s.get("hd", C.DEPTH_HALF * 2.0)) - C.HZ - 2.0   # 발판 앞끝 안쪽
	lane_z = clear if front >= clear else ride_z                        # 얕은 발판엔 앞길이 없다 — 통나무를 밟아 되돌아온다
	x = home_x; z = ride_z
	next_at = lg.t + 20.0 + float(int(s["n"]) % 5) * 8.0               # 층마다 어긋나게 — 옛 회관의 다섯 층이 한꺼번에 타지 않는다
	fig = Stick3D.new(); fig.color = Color("5a4636"); fig.head_color = Color("5a4636")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "log-roller"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("5a4636"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	fig.face(-PI / 2.0)
	_drive()

## 플레이어가 지금 통나무 위에 있나
func player_on() -> bool:
	return lg.t - float(g.get("me_t", -99.0)) < 0.1

## 매 틱(climb_log._process)
func step(dt: float) -> void:
	if not is_instance_valid(fig) or dt <= 0.0: return
	since += dt
	match phase:
		"idle":
			var off := float(g.get("me_off_t", -99.0))
			if off > seen_off and lg.t - off >= REACT: seen_off = off; next_at = minf(next_at, lg.t)   # 플레이어의 타기가 끝났다 — 따라 탄다
			if lg.t >= next_at and not player_on(): _go("walk", -1.0)
		"walk":
			_approach(dt)
		"steady":
			if since >= SteadyPoses.STEADY_T - EPS: fig.pose_request = ""; _go("ride", -1.0)
		"ride", "back":
			_walk(dt)
		"slip":
			_slip(dt)
		"teeter":
			if since >= lg.spill_s(): fig.pose_request = ""; _turn("wheel")   # 엎어진 몸은 집으로 — 오늘은 이만
		"wheel", "wheel2":
			z = lerpf(z, lane_z if phase == "wheel" else ride_z, minf(1.0, dt * 8.0))   # 돌아서며 앞길로(다시 통나무 앞으로) 옮겨 선다
			if since >= WheelPoses.WHEEL_T - EPS:
				fig.look_yaw = 0.0; fig.pose_request = ""
				if phase == "wheel": z = lane_z; _go("back", 1.0)
				else: _rest()
	_drive()

## 통나무로 걸어가는 틱 — 가장자리 STAND 앞에 서면 발을 얹는다(steady); 플레이어가 타고 있거나 통나무가 막 엎어졌으면 WAIT 앞에서 선 채 기다린다
func _approach(dt: float) -> void:
	var edge := lg.radius() + ClimbLog.MOUNT + STAND
	var gap := (x - float(g["lx"])) * -dir   # 통나무 가장자리까지(가는 쪽으로 양수)
	if (player_on() or lg.t - float(g["spill_t"]) < lg.grace_s()) and gap <= edge + WAIT: vx = 0.0; waited += dt; return   # 플레이어가 위에 있거나 막 엎어졌으면(grace) 선다
	_accel(dt)
	x += vx * dt
	if (x - float(g["lx"])) * -dir > edge: return
	x = float(g["lx"]) + edge * -dir; vx = 0.0
	fig.pose_request = "steady"; phase = "steady"; since = 0.0; steadies += 1

## 걷는 틱(ride: 집 → 먼 끝, 통나무를 타고 / back: 앞길로 집에 — 얕은 발판이면 통나무를 밟아) — 플레이어와 같은 속도·같은 roll
func _walk(dt: float) -> void:
	_accel(dt)
	x += vx * dt
	var was := bool(st["riding"])
	var r := lg.roll(on, x, z, vx, dt, fig, false, st); x = float(r["x"])
	if bool(r["riding"]):
		fig.pose_request = "log"; max_ride = maxf(max_ride, float(st["ride"]))
		if hop_kind == "ice" and phase == "ride" and rides % SLIP_EVERY == SLIP_EVERY - 1 and float(st["ride"]) >= SLIP_PX:
			vx = 0.0; phase = "slip"; since = 0.0; return   # 얼음의 느린 출발 — 발이 통나무를 못 따라가 멈춘다
	elif fig.pose_request == "log": fig.pose_request = ""
	if was and not bool(r["riding"]): rides += 1
	var end := far_x if dir < 0.0 else home_x
	if (x - end) * dir < 0.0: return
	x = end; vx = 0.0
	_turn("wheel" if phase == "ride" else "wheel2")

## 멈춰 선 틱 — 같은 roll 이 stop_s 뒤 엎는다(그동안 log_v 0 의 허둥댐); 엎어지면 플레이어와 같은 teeter
func _slip(dt: float) -> void:
	var r := lg.roll(on, x, z, 0.0, dt, fig, false, st); x = float(r["x"])
	if bool(r["spill"]):
		fig.pose_request = "teeter"; phase = "teeter"; since = 0.0; spills += 1; rides += 1
	elif not bool(r["riding"]): fig.pose_request = ""; _turn("wheel")   # 일어날 일은 없다(그 자리에 선 몸은 엎을 때까지 탄 채다) — 그래도 집으로

## 걸음의 속도 — 얼음은 선 채로 출발해 climb.gd 와 같은 가속
func _accel(dt: float) -> void:
	var target := dir * C.WALK
	vx = vx + (target - vx) * minf(1.0, dt * ICE_K) if hop_kind == "ice" else target

## 돌아선다 — 먼 끝에서 wheel(앞길로), 집에서 wheel2(통나무 앞으로)
func _turn(p: String) -> void:
	fig.pose_request = "wheel"
	_go(p, 1.0 if p == "wheel" else -1.0)

func _go(p: String, d: float) -> void:
	phase = p; since = 0.0; dir = d
	fig.face(PI / 2.0 if d > 0.0 else -PI / 2.0)

## 집에서 통나무를 보고 선다 — 다음은 1분 뒤(또는 플레이어의 타기 뒤)
func _rest() -> void:
	phase = "idle"; since = 0.0; vx = 0.0; z = ride_z; fig.pose_request = ""; dir = -1.0
	fig.face(-PI / 2.0); next_at = lg.t + MINUTE; _drive()

## Stick3D 에 걸음을 — climb.gd 가 플레이어에게 하는 것과 같은 식(통나무 노드의 원점 기준; 탄 몸은 2·radius 위)
func _drive() -> void:
	fig.move_dir = Vector3(signf(vx), 0, 0) if absf(vx) > 20.0 else Vector3.ZERO
	fig.speed = absf(vx) * C.K
	var dy := lg.radius() * 2.0 if bool(st["riding"]) else 0.0
	fig.position = Vector3((x - float(g["cx"])) * C.K, dy * C.K, (z - C.WALL_Z) * C.K)
