class_name ClimbHighJumper
extends RefCounted
## 높이뛰기 선수 — 높이뛰기 바 팩(climb_bar.gd, run 170)의 주민 반쪽(run 171; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 바마다 하나, 들어오는 턱 안쪽(IN)에 서서 가로대를 보는 주민.
## (백로그는 climb_jumper.gd 라 했으나 그 이름은 풍경 점퍼(run 161, ClimbJumper)가 쓴다 — 그래서 highjumper.)
## 탑의 1분(MINUTE)마다 한 번(층마다 어긋나게), 그리고 플레이어의 비행이 이 바에서 끝난 뒤(팩의 flight 가 count 참일 때 me_t 에 적는다) REACT 초 뒤에 뛴다 — 그 층의 눈금이 필요한 만큼만 웅크려(ClimbJump.over: 꼭대기가 가로대 윗면 + bar_r + CLEAR, 반암시적 오일러의 보정 포함, JUMP_MIN..JUMP_V 는 웅크린 만큼),
## 턱에서 run 만큼의 자리를 WALK 로 달려(얼음이면 플레이어처럼 ICE_K 로 붙는 속도) 꼭대기가 가로대 위에 오는 자리(take_x)에서 뛰고, 같은 flight()(count 거짓 — 제 넘김은 판에 안 센다)로 같은 arch 자세로 넘어, 매트 윗면(mat_h — 선수에겐 매트가 바닥이다)에 로더의 squash 로 내려 가로대 쪽으로 돌아 눕는다(sprawl, stick3d_sprawl.gd — 털썩·숨 고르기·일어나 앉기 1.9 s).
## 다섯 번에 한 번(EVERY)은 일부러 짧게 뛴다(꼭대기가 가로대보다 SHORT 낮게 — 머리가 밑면에 닿아 떨어뜨린다, 같은 knocked·clatter·arch_hit): 그러면 팩의 혼자 돌아가는 눈금(reset_s)이 기다리고(held) 선수가 매트에서 일어나 기둥 앞(set_x)에 서서 두 손으로 세운다(reset, stick3d_reset.gd — REACH_T 에 fell_t 를 돌려놓아 팩의 lift 가 손을 따라 오른다).
## 집에 서 있다 가로대가 누워 있는 걸 보면(플레이어가 떨어뜨리고 간 것) 그것부터 세우러 간다(fetch — 기둥 사이를 지나 매트 쪽에 서서 wheel 로 돌아선다).
## 돌아올 땐 기둥을 돌아간다: 앞길(lane_z — 앞 기둥 앞, 발판 앞끝 안쪽)로 비스듬히 나가 걸어 집에 와서 wheel 로 돌아서 가로대를 보고 선다. 플레이어가 공중에서 가로대 곁에 있으면(me_t 가 방금) 떠나지 않는다.
## 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 마을의 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 mind 는 아직 없다). 어느 발판에도 안 닿고 VOID 아래로 지나면 층을 떠난 것: 몸을 감추고 1분 뒤 집에 돌아와 있다. 노드는 바의 노드(원점: 가로대의 x, 발판 윗면, 절벽) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_bar.gd 의 JUMPER 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 혼자서도 이만큼마다 한 번 뛴다
const REACT := 1.0        # 플레이어의 비행이 끝난 뒤 이만큼 있다 뛴다 — 보고 따라 뛰는 사이
const IN := 12.0          # 들어오는 턱 안쪽 이만큼에 선다(px) — HW + 2
const CLEAR := 6.0        # 꼭대기가 가로대 윗면 + bar_r 보다 더 가는 여유(px) — 틱의 오차보다 넉넉히
const SHORT := 10.0       # 일부러 짧은 뜀: 꼭대기가 가로대보다 이만큼 낮다 — 머리(44 px)가 밑면에 닿는다
const EVERY := 5          # 몇 번에 한 번 짧게 뛰나
const BEYOND := 8.0       # 매트 가운데보다 이만큼 더 가서 내린다 — 누운 가로대 너머에 눕는다
const SET_IN := 16.0      # 가로대를 세우는 자리: 기둥에서 매트 쪽으로 이만큼(px) — bar_r + 2 + HW + 2
const LANE_GAP := 4.0     # 앞길: 앞 기둥 + HZ + 이만큼(px)
const OUT_K := 0.5        # 앞길로 비스듬히 나갈 때 x 로 가는 WALK 의 몫 — 기둥을 지나기 전에 z 가 먼저 나간다
const ICE_K := 1.6        # 얼음 가속 — climb.gd 의 같은 수
const VOID := 400.0       # 발판보다 이만큼 아래 → 층을 떠났다
const EPS := 0.000001     # 시계 비교의 여유

var cb: ClimbBar
var s: Dictionary         # 바(climb_bar.bars 의 것 — 참조라 me_t·held·fell_t 를 같이 본다)
var fig: Stick3D
var phase := "idle"       # idle | charge | run | air | sprawl | fetch | turn | reset | back | wheel | gone
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0        # 다음 혼자 뛰는 때(cb.t)
var seen_me := -99.0      # 따라간 플레이어의 me_t — 한 비행에 한 번
var x := 0.0; var y := 0.0; var z := 0.0; var vx := 0.0; var vy := 0.0
var dir := 1.0            # 바의 dir — 들어오는 턱에서 매트 쪽
var facing := 1.0
var home_x := 0.0; var take_x := 0.0; var set_x := 0.0; var hy := 0.0; var mat_y := 0.0; var lane_z := 0.0
var jump := Vector2.ZERO; var fly_t := 0.0; var charge_s := 0.0
var jumps := 0; var clears := 0; var knocks := 0; var sets := 0; var misses := 0   # 점검용
var lifted_bar := false   # 이번 reset 에서 가로대를 올리기 시작했나
var apex := 0.0           # 이번 비행의 꼭대기(px, 발판 윗면 기준) — 점검용
var trail: Array = []     # phase@t — 점검용

func _init(pack: ClimbBar, bar: Dictionary, parent: Node3D) -> void:
	cb = pack; s = bar; dir = float(s["dir"]); facing = dir
	hy = float(s["y"]); mat_y = hy + cb.mat_h()
	home_x = float(s["bx"]) - dir * (float(s["run"]) - IN)
	set_x = float(s["bx"]) + dir * SET_IN
	var front := C.WALL_Z + float(s.get("hd", C.DEPTH_HALF * 2.0)) - C.HZ - 2.0   # 발판 앞끝 안쪽
	lane_z = C.WALL_Z + cb.bar_d() + C.HZ + LANE_GAP
	if lane_z > front: lane_z = C.PLAYER_Z   # 얕은 발판엔 앞길이 없다 — 기둥 사이로 돌아온다(단단한 것이 없다)
	x = home_x; y = hy; z = C.PLAYER_Z
	next_at = cb.t + 20.0 + float(int(s["n"]) % 5) * 8.0   # 층마다 어긋나게 — 바람 절벽의 다섯 층이 한꺼번에 뛰지 않는다
	fig = Stick3D.new(); fig.color = Color("5a6b4e"); fig.head_color = Color("5a6b4e")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "high jumper"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("5a6b4e"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	_face(dir)
	_drive()

## 플레이어가 지금 이 가로대 곁의 공중에 있나
func player_on() -> bool:
	return cb.t - float(s.get("me_t", -99.0)) < 0.1

## 가로대가 누워 있고 아무도(팩의 lift 도) 올리고 있지 않나
func bar_down() -> bool:
	return not cb.up(s) and not bool(s["lifted"])

## 매 틱(climb_bar._process)
func step(dt: float) -> void:
	if not is_instance_valid(fig) or dt <= 0.0: return
	since += dt
	match phase:
		"idle":
			var me := float(s.get("me_t", -99.0))
			if me > seen_me and cb.t - me >= REACT - EPS: seen_me = me; next_at = minf(next_at, cb.t)   # 플레이어의 비행이 끝났다 — 따라 뛴다
			if player_on(): pass
			elif bar_down(): s["held"] = true; _go("fetch")   # 누운 가로대부터 — 혼자 돌아가는 눈금은 기다린다
			elif cb.t >= next_at: seen_me = me; _charge(dt)
		"charge":
			fig.crouch = minf(since, charge_s) / C.CHARGE * 0.9   # 로더의 웅크림과 같은 식 — 맞춘 vy 만큼만
			if since >= charge_s - EPS: fig.crouch = 0.0; _go("run")
		"run":
			_run(dt)
		"air":
			_air(dt)
		"sprawl":
			if since >= SprawlPoses.SPRAWL_T - EPS:
				fig.pose_request = ""
				if bar_down(): s["held"] = true; _go("fetch")
				else: _go("back")
		"fetch":
			_fetch(dt)
		"turn", "wheel":
			if phase == "wheel": z = lerpf(z, C.PLAYER_Z, minf(1.0, dt * 8.0))   # 돌아서며 다시 가로대 앞으로 옮겨 선다
			if since >= WheelPoses.WHEEL_T - EPS:
				fig.look_yaw = 0.0; fig.pose_request = ""
				if phase == "turn": _start_reset()
				else: _rest()
		"reset":
			if not lifted_bar and since >= ResetPoses.REACH_T - EPS:
				lifted_bar = true; sets += 1; s["held"] = false; s["fell_t"] = cb.t - cb.reset_s()   # 손이 닿았다 — 팩의 lift 가 지금부터
			if since >= ResetPoses.RESET_T - EPS: fig.pose_request = ""; _go("back")
		"back":
			_back(dt)
		"gone":
			if cb.t >= next_at: _home()
	_drive()

## 뜀을 맞춘다 — 그 층의 눈금이 필요한 만큼: 꼭대기가 가로대 윗면 + bar_r + CLEAR(짧은 뜀은 가로대 − SHORT), 매트 윗면에 내린다; 꼭대기가 가로대 위에 오게 뛰는 자리(take_x)와 매트 가운데 너머에 내리는 vx(RUN 안)
func _charge(dt: float) -> void:
	var short := jumps % EVERY == EVERY - 1
	var top := float(s["h"]) + (cb.bar_r() + CLEAR if not short else -SHORT)
	var j := ClimbJump.over(top, cb.mat_h(), dt)
	fly_t = float(j["fly_t"]); charge_s = float(j["charge_s"])
	var l_out := cb.bar_r() + 2.0 + float(s["mat"]) / 2.0 + BEYOND
	var vxa := minf(C.RUN, l_out / maxf(float(j["t_down"]), 0.01))
	var bx := float(s["bx"])
	take_x = bx - dir * vxa * float(j["t_up"])
	if (take_x - home_x) * dir < 0.0: take_x = home_x   # 좁은 발판 — 집에서 바로 뛴다(꼭대기가 가로대를 조금 지나 온다)
	jump = Vector2(dir * vxa, float(j["vy"]))
	_go("charge")

## 턱에서 뛰는 자리까지 — 플레이어의 걸음(WALK, 얼음은 ICE_K 로 붙는다); 닿으면 뛴다
func _run(dt: float) -> void:
	var target := dir * C.WALK
	vx = vx + (target - vx) * minf(1.0, dt * ICE_K) if String(s.get("hop_kind", "std")) == "ice" else target
	x += vx * dt
	if (x - take_x) * dir >= 0.0:
		x = take_x; vx = jump.x; vy = jump.y; jumps += 1; apex = 0.0; _go("air")

## 공중의 틱 — 로더와 같은 순서(중력 → 자리 → 같은 flight → 착지): 매트 위면 매트 윗면에, 아니면 발판 윗면에 내린다(미스 — 세지 않고 집으로)
func _air(dt: float) -> void:
	vy -= C.G * dt
	var ny := y + vy * dt
	var ox := x
	x += vx * dt
	apex = maxf(apex, ny - hy)
	var r := cb.flight(ox, x, ny, C.PLAYER_Z, fig, false)
	if bool(r["in_flight"]): fig.pose_request = "arch"
	elif fig.pose_request == "arch": fig.pose_request = ""
	if bool(r["cleared"]): clears += 1
	if bool(r["knocked"]): knocks += 1; s["held"] = true   # 내가 떨어뜨렸다 — 혼자 돌아가는 눈금은 기다리고 내가 세운다
	if vy <= 0.0:
		if _on_mat(x) and y >= mat_y and ny <= mat_y: _land(mat_y, true); return
		if not _on_mat(x) and y >= hy and ny <= hy: misses += 1; _land(hy, false); return
	if ny < hy - VOID: _gone(); return
	y = ny

## 매트의 x 안인가
func _on_mat(px: float) -> bool:
	var m0 := float(s["bx"]) + dir * (cb.bar_r() + 2.0)
	return (px - m0) * dir >= 0.0 and (px - m0) * dir <= float(s["mat"])

## 내렸다 — 로더의 평이한 착지와 같은 squash, 자세와 메타를 비운다; 매트면 가로대 쪽으로 돌아 눕는다(머리가 가로대 반대쪽 — 배면뛰기의 착지)
func _land(ty: float, on_mat: bool) -> void:
	y = ty; vx = 0.0; vy = 0.0; fig.squash = -0.6
	if fig.pose_request == "arch": fig.pose_request = ""
	cb.leave(fig)
	if on_mat: _face(-dir); fig.pose_request = "sprawl"; _go("sprawl")
	else: _go("back")

## 누운 가로대를 세우러 — set_x 로 걷는다(집에서면 기둥 사이를 지나 매트 쪽으로, 매트에서면 가로대 쪽으로 몇 걸음); 닿으면 기둥을 보고 선다(매트 쪽에서 왔으면 바로, 집에서 왔으면 wheel 로 돌아서)
func _fetch(dt: float) -> void:
	var d := signf(set_x - x)
	if d == 0.0 or (set_x - x) * d <= C.WALK * dt:
		x = set_x; vx = 0.0
		if facing == -dir: _start_reset()
		else: _turn("turn", -dir)
		return
	vx = d * C.WALK; x += vx * dt; _face(d); _ground()

func _start_reset() -> void:
	lifted_bar = false; fig.pose_request = "reset"; _go("reset")

## 집으로 — 매트 쪽이면 앞길로 비스듬히 나가 기둥을 돌고, 집 끝에 닿으면 wheel 로 돌아선다
func _back(dt: float) -> void:
	var bx := float(s["bx"])
	var out := (x - bx) * dir > -C.HW and absf(z - lane_z) > 1.0
	if out:
		var dz := signf(lane_z - z)
		z = z + dz * C.WALK * dt if absf(lane_z - z) > C.WALK * dt else lane_z
		vx = -dir * C.WALK * OUT_K
	else: vx = -dir * C.WALK
	x += vx * dt; _ground()
	fig.move_dir = Vector3(-dir, 0.0, signf(lane_z - z) if out else 0.0).normalized()
	if (x - home_x) * dir <= 0.0:
		x = home_x; vx = 0.0; _turn("wheel", dir)

## 걷는 발밑 — 매트 위면 매트 윗면, 아니면 발판 윗면(매트에서 내려 걸어 집에 올 때 0.39 m 떠 있지 않게, 집에서 매트로 갈 때 매트 속을 걷지 않게)
func _ground() -> void:
	y = mat_y if _on_mat(x) else hy

func _turn(p: String, d: float) -> void:
	fig.pose_request = "wheel"; _face(d); _go(p)

## 집에서 가로대를 보고 선다 — 다음은 1분 뒤(또는 플레이어의 비행 뒤)
func _rest() -> void:
	vx = 0.0; vy = 0.0; z = C.PLAYER_Z; fig.pose_request = ""; fig.crouch = 0.0
	_face(dir); next_at = cb.t + MINUTE; _go("idle")

func _gone() -> void:
	fig.visible = false; fig.pose_request = ""; cb.leave(fig); s["held"] = false   # 떠난 몸은 세우러 못 온다 — 눈금이 혼자 돌아간다
	phase = "gone"; since = 0.0; vx = 0.0; vy = 0.0; next_at = cb.t + MINUTE

## 층을 떠났다 돌아온다 — 집에, 바로 다음 차례(점검도 이걸로 집에 세운다)
func _home() -> void:
	x = home_x; y = hy; z = C.PLAYER_Z; vx = 0.0; vy = 0.0; fig.visible = true; fig.pose_request = ""; fig.crouch = 0.0; cb.leave(fig)
	next_at = cb.t; _face(dir); _go("idle")

func _go(p: String) -> void:
	phase = p; since = 0.0; trail.append("%s@%.2f" % [p, cb.t])
	if trail.size() > 40: trail.pop_front()

func _face(dd: float) -> void:
	facing = dd; fig.face(PI / 2.0 if dd > 0.0 else -PI / 2.0)

## Stick3D 에 걸음·공중·자리를 — climb.gd 가 플레이어에게 하는 것과 같은 식(바 노드의 원점 기준: 가로대의 x, 발판 윗면, 절벽)
func _drive() -> void:
	var air := phase == "air"
	fig.airborne = air; fig.vertical = vy * C.K if air else 0.0
	if phase != "back": fig.move_dir = Vector3(signf(vx), 0.0, 0.0) if absf(vx) > 20.0 and not air else Vector3.ZERO
	fig.speed = (absf(vx) / (OUT_K if phase == "back" and fig.move_dir.z != 0.0 else 1.0)) * C.K if not air else 0.0
	fig.position = Vector3((x - float(s["bx"])) * C.K, (y - hy) * C.K, (z - C.WALL_Z) * C.K)
