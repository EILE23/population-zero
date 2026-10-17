class_name ClimbRider
extends RefCounted
## 타는 이 — 핀 바퀴 팩(climb_escape.gd, run 168)의 주민 반쪽(run 169; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 바퀴마다 하나, 아래 발판의 틈 쪽 끝(IN 안)에 서서 바퀴를 보는 주민.
## 탑의 1분(MINUTE)마다 한 번(층마다 어긋나게), 그리고 플레이어의 타기가 이 바퀴에서 끝난 뒤(팩의 ride 가 count 참일 때 me_t 에 적는다) REACT 초 뒤에 탄다 — 로더의 뜀 수로(JUMP_MIN..JUMP_V 는 웅크린 만큼 CHARGE 에 비례, 가로는 RUN 안; 톡 뜀이면 웅크림 없이)
## 바닥 핀 가운데에 내리게 맞춘 뜀을, 내릴 때가 핀이 멎어 있는 창(step_s + MARGIN .. tick_s − MARGIN)에 들도록 박자를 기다렸다(beat) 뛴다(hop — 진짜 포물선, 같은 land() 가 받는다, 착지 squash). 그 다음 같은 ride() 를 count 거짓으로 매 틱 부르며(제 타기는 판에 안 센다) 같은 jolt 로 덜컥덜컥 오르고,
## 핀이 꼭대기 한 칸 전(135°)에 멎으면 poise(stick3d_poise.gd — 무릎 깊이, 팔은 뒤로, 고개는 위 턱으로, 떨며 버틴다)로 모았다가 다음 박자에 핀이 꼭대기에 멎으면(POISE_T 와 모아야 할 웅크림이 지난 뒤) 위 발판의 틈 쪽 끝(IN 안)으로 톡 뛴다(off).
## 위 발판에 내려 PAUSE 숨 돌리고 wheel 로 돌아서서 집으로 뛰어 내린다(down — 외줄꾼의 발판 사이 뜀을 아래로: 같은 식으로 맞춘 vy·vx, 집 끝에 내려 다시 wheel 로 돌아서 바퀴를 보고 선다). 틈 위를 지나는 길에 바퀴는 안 묻는다(핀은 hop 에서만 받는다).
## 플레이어가 핀 위에 있으면(me_t 가 방금) 집에서 안 떠나고 박자도 안 뛴다(한 바퀴에 둘이 같이 오르진 않는다 — 이미 탄 뒤 플레이어가 오르면 둘 다 간다). 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 마을의 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 mind 는 아직 없다).
## 핀 밖으로 떨어지거나(일어날 일은 없다 — 서서 안 걷는다) 어느 발판에도 안 닿고 VOID 아래로 지나면 층을 떠난 것: 몸을 감추고 1분 뒤 집에 돌아와 있다. 노드는 바퀴의 노드(원점: 축 hx, cy, 절벽) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_escape.gd 의 RIDER 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 혼자서도 이만큼마다 한 번 탄다
const REACT := 1.0        # 플레이어의 타기가 끝난 뒤 이만큼 있다 간다 — 보고 따라 타는 사이
const IN := 4.0           # 발판 끝 안쪽 이만큼에 선다(px)
const PAUSE := 1.0        # 위 발판에 내린 뒤 숨 돌리는 시간(s)
const MARGIN := 0.03      # 박자 창의 여유(s) — 핀이 멎은 뒤 이만큼 지나서, 다음 덜컥 이만큼 전까지 내린다
const VOID := 400.0       # 아래 발판보다 이만큼 아래 → 층을 떠났다
const EPS := 0.000001     # 시계 비교의 여유 — 1/60 을 예순 번 더해도 1.0 에 닿게

var ew: ClimbEscape
var s: Dictionary         # 바퀴(climb_escape.wheels 의 것 — 참조라 me_t 를 같이 본다)
var fig: Stick3D
var on: Dictionary = {}   # ride 에 주는 핀(land 가 준 사전)
var phase := "idle"       # idle | charge | beat | hop | ride | poise | off | pause | turn | down | turn2 | gone
var after := ""           # charge 다음에 뛸 것(hop 은 박자를 기다린다)
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0        # 다음 혼자 타는 때(ew.t)
var seen_me := -99.0      # 따라간 플레이어의 me_t — 한 타기에 한 번
var x := 0.0; var y := 0.0; var vx := 0.0; var vy := 0.0
var dir := 1.0            # 바퀴의 dir — 아래 발판에서 위 발판 쪽
var home_x := 0.0; var a_y := 0.0; var b_edge := 0.0; var b_y := 0.0
var jump := Vector2.ZERO; var fly_t := 0.0; var charge_s := 0.0   # 맞춘 뜀 (vx, vy)·비행 시간·웅크릴 시간
var boards := 0; var overs := 0; var falls := 0; var last_pin := -1   # 점검용
var at_board := Vector2.ZERO; var at_top := Vector2.ZERO; var at_b := Vector2.ZERO; var at_home := Vector2.ZERO

func _init(pack: ClimbEscape, wheel: Dictionary, parent: Node3D) -> void:
	ew = pack; s = wheel; dir = float(s["dir"])
	var half := float(s["gap"]) / 2.0 + IN
	home_x = float(s["hx"]) - dir * half; b_edge = float(s["hx"]) + dir * half
	a_y = float(s["a_y"]); b_y = float(s["b_y"])
	x = home_x; y = a_y
	next_at = ew.t + 20.0 + float(int(s["n"]) % 5) * 8.0   # 층마다 어긋나게 — 태엽의 다섯 층이 한꺼번에 타지 않는다
	fig = Stick3D.new(); fig.color = Color("6b5a3e"); fig.head_color = Color("6b5a3e")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "rider"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("6b5a3e"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	_face(dir)
	_drive()

## 플레이어가 지금 핀 위에 있나
func player_on() -> bool:
	return ew.t - float(s.get("me_t", -99.0)) < 0.1

## 매 틱(climb_escape._process)
func step(dt: float) -> void:
	if not is_instance_valid(fig) or dt <= 0.0: return
	since += dt
	match phase:
		"idle":
			var me := float(s.get("me_t", -99.0))
			if me > seen_me and ew.t - me >= REACT - EPS: seen_me = me; next_at = minf(next_at, ew.t)   # 플레이어의 타기가 끝났다 — 따라 탄다
			if ew.t >= next_at and not player_on(): seen_me = me; _prep(float(s["hx"]), a_y + ew.pin_r(), "hop", dt)   # 떠나며 본 타기는 본 것 — 돌아와 또 따라 타지 않는다
		"charge":
			fig.crouch = minf(since, charge_s) / C.CHARGE * 0.9   # 로더의 웅크림과 같은 식 — 맞춘 vy 만큼만
			if since >= charge_s - EPS:
				if after == "hop": phase = "beat"; since = 0.0
				else: _launch(after)
		"beat":
			if _on_beat(): _launch("hop")
		"hop", "off", "down":
			_air(dt)
		"ride", "poise":
			_ride(dt)
		"pause":
			if since >= PAUSE - EPS: _turn("turn", -dir)
		"turn", "turn2":
			if since >= WheelPoses.WHEEL_T - EPS:
				fig.look_yaw = 0.0; fig.pose_request = ""
				if phase == "turn": _prep(home_x, a_y, "down", dt)
				else: _rest()
		"gone":
			if ew.t >= next_at: _home()
	_drive()

## 뜀을 맞춘다 — 로더의 수로 (ox, oy) 에서 (tx, ty) 에 내리게(ClimbJump.fit, run 171 — 식은 run 169 그대로: 가로를 RUN × 0.9 로 가는 시간에 그 높이를 오르내릴 vy, 반암시적 오일러의 G·dt/2 보정, RUN 안의 vx, vy 가 JUMP_MIN 을 넘는 몫 × CHARGE 의 웅크림)
func _fit(ox: float, oy: float, tx: float, ty: float, dt: float) -> void:
	var j := ClimbJump.fit(ox, oy, tx, ty, dt)
	fly_t = float(j["fly_t"]); jump = Vector2(float(j["vx"]), float(j["vy"])); charge_s = float(j["charge_s"])

func _prep(tx: float, ty: float, nxt: String, dt: float) -> void:
	_fit(x, y, tx, ty, dt); after = nxt; phase = "charge"; since = 0.0

## 지금 뛰면 핀이 멎어 있을 때 내리나 — 바닥 핀은 phase 0 이면 걸음마다 hx 에 멎는다(escape.json 의 조각이 다 0); 플레이어가 핀 위면 안 뛴다
func _on_beat() -> bool:
	if player_on(): return false
	var u := fposmod(ew.t + fly_t, ew.tick_s())
	return u >= ew.step_s() + MARGIN and u <= ew.tick_s() - MARGIN

func _launch(p: String) -> void:
	fig.crouch = 0.0; vx = jump.x; vy = jump.y
	phase = p; since = 0.0; _face(1.0 if vx >= 0.0 else -1.0)

## 공중의 틱 — 로더와 같은 순서(중력 → 자리 → 착지 판정); hop 은 팩의 land 가 핀을 주고, off 는 위 발판의 윗면을, down 은 아래 발판의 윗면을 틈 쪽 끝 안(HW)에서 지나며 내린다
func _air(dt: float) -> void:
	vy -= C.G * dt
	var ny := y + vy * dt
	x += vx * dt
	if vy <= 0.0:
		if phase == "hop":
			var hit := ew.land(x, y, ny, C.PLAYER_Z)
			if not hit.is_empty(): _board(hit); return
		elif _lands(ny): return
	if ny < a_y - VOID: _gone(); return
	y = ny

## off·down 의 착지 — 발판 윗면을 내려 지나고 x 가 그 발판 쪽(틈 끝에서 HW 안)이면: 같은 squash 로 내려 off 는 숨 돌리고 down 은 돌아선다
func _lands(ny: float) -> bool:
	var ty := b_y if phase == "off" else a_y
	if not (y >= ty and ny <= ty): return false
	var edge := float(s["hx"]) + dir * float(s["gap"]) / 2.0 * (1.0 if phase == "off" else -1.0)   # 그 발판의 틈 쪽 끝
	var side := (x - edge) * dir
	if (phase == "off" and side < -C.HW) or (phase == "down" and side > C.HW): return false
	y = ty; vy = 0.0; vx = 0.0; fig.squash = -0.6   # 로더의 평이한 착지와 같은 squash
	if phase == "off": at_b = Vector2(x, y); x = b_edge; phase = "pause"; since = 0.0
	else: at_home = Vector2(x, y); x = home_x; _turn("turn2", dir)
	return true

## 핀에 내렸다 — 같은 land 가 준 핀, 같은 squash, 그 다음은 jolt
func _board(hit: Dictionary) -> void:
	on = hit; y = float(hit["y"]); vx = 0.0; vy = 0.0
	boards += 1; last_pin = int(hit["pin"]); at_board = Vector2(x, y)
	fig.squash = -0.6; fig.pose_request = "jolt"; phase = "ride"; since = 0.0

## 핀 위의 틱 — 같은 ride(count 거짓)로 실려 간다; 핀이 135° 에 멎으면 poise 로 모으고(뜀은 꼭대기에서 맞춘다), 꼭대기에 멎으면 버팀·웅크림이 찼을 때 위 발판으로 뛴다; 못 뛰고 지나치면 jolt 로 돌아가 한 바퀴 더(일어날 일은 없다: 0.7 s 의 박자가 둘 다보다 길다)
func _ride(dt: float) -> void:
	var r := ew.ride(on, x, dt, fig, false)
	if bool(r["off"]): _fall(); return
	x = float(r["x"]); y = float(r["y"])
	if ew.since(ew.t) < ew.step_s(): return   # 덜컥 가는 중
	var a := fposmod(ew.ang(s, int(on["pin"]), ew.t), TAU)
	if phase == "ride" and absf(a - (PI - ew.arc())) < 0.01:
		_fit(float(s["hx"]), float(s["cy"]) + float(s["r"]) + ew.pin_r(), b_edge, b_y, dt)
		fig.pose_request = "poise"; phase = "poise"; since = 0.0
	elif phase == "poise" and absf(a - PI) < 0.01 and since >= maxf(PoisePoses.POISE_T, charge_s) - EPS:
		at_top = Vector2(x, y); overs += 1; on = {}; fig.pose_request = ""; _launch("off")
	elif phase == "poise" and a > PI + 0.01: fig.pose_request = "jolt"; phase = "ride"; since = 0.0

## 핀 밖으로 — 서서 안 걷는 몸이라 일어날 일은 없다; 그래도 맨 떨어짐(아래 발판에 안 닿으면 VOID 로 층을 떠난다)
func _fall() -> void:
	on = {}; fig.pose_request = ""; vx = 0.0; vy = 0.0; falls += 1; phase = "down"; since = 0.0

func _turn(p: String, d: float) -> void:
	fig.pose_request = "wheel"; phase = p; since = 0.0; _face(d)

## 집에서 바퀴를 보고 선다 — 다음은 1분 뒤(또는 플레이어의 타기 뒤)
func _rest() -> void:
	phase = "idle"; since = 0.0; vx = 0.0; vy = 0.0; on = {}; fig.pose_request = ""; fig.crouch = 0.0
	_face(dir); next_at = ew.t + MINUTE

func _gone() -> void:
	fig.visible = false; fig.pose_request = ""; on = {}; phase = "gone"; since = 0.0; vx = 0.0; vy = 0.0; next_at = ew.t + MINUTE

## 층을 떠났다 돌아온다 — 집에, 바로 다음 차례
func _home() -> void:
	x = home_x; y = a_y; fig.visible = true; phase = "idle"; since = 0.0; next_at = ew.t; _face(dir)

func _face(dd: float) -> void:
	fig.face(PI / 2.0 if dd > 0.0 else -PI / 2.0)

## Stick3D 에 공중·자리를 — climb.gd 가 플레이어에게 하는 것과 같은 식(바퀴 노드의 원점 축 기준; 걷지 않는 몸이라 move_dir 은 늘 0)
func _drive() -> void:
	var air := phase == "hop" or phase == "off" or phase == "down"
	fig.airborne = air; fig.vertical = vy * C.K if air else 0.0
	fig.move_dir = Vector3.ZERO; fig.speed = 0.0
	fig.position = Vector3((x - float(s["hx"])) * C.K, (y - float(s["cy"])) * C.K, (C.PLAYER_Z - C.WALL_Z) * C.K)
