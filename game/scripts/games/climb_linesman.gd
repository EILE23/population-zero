class_name ClimbLinesman
extends RefCounted
## 선로지기 — 톱니 궤도차 팩(climb_railcar.gd, run 180)의 주민 반쪽(run 181; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 궤도마다 하나, 아랫역에서 틈 반대쪽 BACK(몸 둘 폭)에 카메라를 보고 선 주민 — 궤도를 돌보는 이.
## 탑의 1분(MINUTE)마다 한 번(층마다 어긋나게), 그리고 플레이어의 타기가 꼭대기에 닿은 뒤(팩이 count 참일 때 me_t 에 적는다) REACT 초 뒤에 역으로 걸어가(walk) 차가 집에 돌아오길 기다려(wait — 플레이어가 탄 차는 꼭대기에서 hold_s 쉬고 굴러온다; WAIT_S 넘으면 집으로),
## 바짓단을 집고(clip, stick3d_clip.gd — 숙여 발목의 천을 집어 0.4 s, 정강이를 털어 0.3 s, 일어서 0.3 s; 톱니에 물릴 천을 모으는 몸) 같은 mount(count 거짓 — 제 타기는 판의 날(day)에 안 세고 me_t 도 안 적는다)·같은 pedal 로 쉬지 않고 꼭대기까지 밟는다(C 를 내내 쥔 것과 같다 — 자유바퀴는 없다).
## 윗역에 내려서면(step_out) 차가 집으로 굴러가기 시작하길 기다리고(pause — 차가 선 역을 몸이 지나지 않게; 상한 PAUSE), 틈 끝(IN 안)으로 걸어가 탑의 뜀(ClimbJump.fit — 로더의 수: JUMP_MIN..JUMP_V 는 웅크린 만큼, 가로는 RUN 안, G)으로 아랫역의 역 곁(dock_x)에 뛰어 내린다(down — 진짜 포물선, 떨어지는 높이는 dy 60..160 으로 SPLAT 330 아래).
## 내려선 자리에서 집으로 걸어가(back) 카메라를 보고 선다. 어느 발판에도 안 닿고 VOID 아래로 지나면(틈이 탑의 뜀보다 넓을 때 — 진짜 탑의 태엽 층 틈은 83..125 px 라 일어날 일은 없다) 층을 떠난 것: 몸을 감추고 1분 뒤 집에 돌아와 있다.
## 플레이어가 아랫역 NEAR 안에 서 있으면(로더가 발판에 선 틱마다 부르는 mount 가 near_t 에 적는다) 집에서 기다린다 — 제 분은 타기 없이 지나고(skips), 걸어가던 중이면 돌아온다: 배려가 보인다. 플레이어가 타는 중이면 역에서 기다린다(차가 없다).
## 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 마을의 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 mind 는 아직 없다). 노드는 궤도의 노드(원점: 아랫역의 x, a 윗면, PLAYER_Z) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_railcar.gd 의 LINESMAN·CLIP 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 혼자서도 이만큼마다 한 번 탄다
const REACT := 1.5        # 플레이어의 타기가 꼭대기에 닿은 뒤 이만큼 있다 역으로 간다 — 멈춤쇠 소리를 듣는 사이
const BACK := 40.0        # 아랫역에서 틈 반대쪽 이만큼에 선다(px) — 몸 둘 폭(2 × 2 HW)
const STAND := 16.0       # 역에 섰을 때 역 가운데에서 틈 반대쪽 이만큼(px) — mount 의 HW + reach(24) 안
const NEAR_T := 0.2       # 플레이어를 마지막으로 역 곁에 본 뒤 이만큼은 가까운 것(s) — 로더는 선 틱마다 알린다
const WAIT_S := 16.0      # 역에서 차가 돌아오길 이보다 오래 기다리면 집으로(타기 3.5 + 내려섬 0.45 + 기다림 3 + 굴러옴 2 의 두 배 안)
const PAUSE := 4.0        # 윗역에 내려 차가 떠나길 기다리는 상한(s) — hold_s 3 + 여유
const IN := 4.0           # 틈 쪽 끝 안쪽 이만큼에서 뛴다(px)
const VOID := 400.0       # 아래 발판보다 이만큼 아래 → 층을 떠났다
const EPS := 0.000001     # 시계 비교의 여유

var cr: ClimbRailcar
var s: Dictionary         # 궤도(climb_railcar.cars 의 것 — 참조라 sw·u·rider·me_t·near_t 를 같이 본다)
var hop: Dictionary       # mount 의 on — 팩은 id 만 읽는다
var seat: Dictionary = {} # 탄 안장(mount 가 준 사전)
var fig: Stick3D
var phase := "idle"       # idle | walk | wait | clip | ride | pause | step | charge | down | back | gone
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0        # 다음 혼자 타는 때(cr.t)
var seen_me := -99.0      # 따라간 플레이어의 me_t — 한 타기에 한 번
var x := 0.0; var y := 0.0; var vx := 0.0; var vy := 0.0
var dir := 1.0            # 궤도의 dir — 아랫역에서 윗역 쪽
var home_x := 0.0; var dock_x := 0.0; var jump_x := 0.0
var a_y := 0.0; var a_x0 := 0.0; var a_x1 := 0.0   # 아래 발판의 윗면과 x 폭(걷는 선 — HW 안)
var clip_t := 0.0         # clip 에 든 뒤 시간 — 메타 clip_t 로 자세에
var jump := Vector2.ZERO; var charge_s := 0.0       # 맞춘 뜀 (vx, vy)·웅크릴 시간
var rides := 0; var tops := 0; var drops := 0; var skips := 0; var falls := 0   # 점검용
var at_land := Vector2.ZERO
var trail: Array = []     # phase@t — 점검용

func _init(pack: ClimbRailcar, rail: Dictionary, parent: Node3D) -> void:
	cr = pack; s = rail; dir = float(s["dir"])
	hop = { "id": String(s["a_id"]) }
	a_y = float(s["a_y"]); y = a_y
	a_x0 = float(s["a_x"]) + C.HW; a_x1 = a_x0 + float(s["a_w"]) - 2.0 * C.HW
	var x0 := float(s["x0"])
	dock_x = clampf(x0 - dir * STAND, a_x0, a_x1)
	home_x = clampf(x0 - dir * BACK, a_x0, a_x1)   # 좁은 발판이면 끝 안쪽까지만
	jump_x = float(s["x1"]) - dir * (cr.dock_in() + IN)   # 윗역의 틈 쪽 끝 안
	x = home_x
	next_at = cr.t + 30.0 + float(int(s["n"]) % 5) * 6.0   # 층마다 어긋나게 — 태엽의 다섯 층이 한꺼번에 타지 않는다
	fig = Stick3D.new(); fig.color = Color("4e5a6b"); fig.head_color = Color("4e5a6b")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "linesman"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("4e5a6b"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	fig.face(0.0)
	_drive()

## 플레이어가 지금 아랫역 곁에 서 있나 — 팩의 mount 가 선 틱마다 적는 near_t
func player_near() -> bool:
	return cr.t - float(s.get("near_t", -99.0)) < NEAR_T

## 차가 집에 비어 서 있나
func car_home() -> bool:
	return String(s["sw"]) == "" and s["rider"] == null and float(s["u"]) <= 0.0

## 매 틱(climb_railcar._process)
func step(delta: float) -> void:
	if not is_instance_valid(fig) or delta <= 0.0: return
	since += delta
	var dt := minf(delta, 1.0 / 30.0)   # 로더의 dt 상한 — 안장과 공중은 이걸로
	match phase:
		"idle":
			var me := float(s.get("me_t", -99.0))
			if me > seen_me and cr.t - me >= REACT - EPS: seen_me = me; next_at = minf(next_at, cr.t)   # 플레이어가 꼭대기에 닿았다 — 따라 탄다
			if cr.t >= next_at:
				seen_me = me
				if player_near(): skips += 1; next_at = cr.t + MINUTE   # 플레이어가 역 곁에 — 이번 분은 넘긴다
				else: _go("walk")
		"walk":
			if player_near(): _go("back")   # 플레이어가 역으로 왔다 — 플레이어의 차가 먼저
			elif _walk(dock_x, delta): _go("wait")
		"wait":
			if player_near(): _go("back")
			elif car_home(): _clip()
			elif since >= WAIT_S: _go("back")
			else: fig.face(PI / 2.0 if dir > 0.0 else -PI / 2.0)   # 차가 굴러오길 궤도를 보며 기다린다
		"clip":
			if player_near(): _end_clip(); _go("back")
			else: _clip_tick(delta)
		"ride":
			_ride(dt)
		"pause":
			if float(s["u"]) < 1.0 - EPS or since >= PAUSE - EPS: _go("step")   # 차가 집으로 굴러가기 시작했다
		"step":
			if _walk(jump_x, delta): _prep(dt)
		"charge":
			fig.crouch = minf(since, charge_s) / C.CHARGE * 0.9   # 로더의 웅크림과 같은 식 — 맞춘 vy 만큼만
			if since >= charge_s - EPS: _launch()
		"down":
			_air(dt)
		"back":
			if _walk(home_x, delta): _rest()
		"gone":
			if cr.t >= next_at: _home()
	_drive()

## target 까지 플레이어의 걸음(WALK)으로 — 닿으면 true 를 주고 카메라를 본다
func _walk(target: float, dt: float) -> bool:
	var d := signf(target - x)
	if d == 0.0 or (target - x) * d <= C.WALK * dt:
		x = target; vx = 0.0; fig.face(0.0); return true
	vx = d * C.WALK
	x += vx * dt; fig.face(PI / 2.0 if d > 0.0 else -PI / 2.0)
	return false

## 바짓단을 집는다 — 카메라를 보고 서서 clip
func _clip() -> void:
	clip_t = 0.0; fig.set_meta("clip_t", 0.0)
	fig.face(0.0); fig.pose_request = "clip"; _go("clip")

## 집기의 시계 — 메타 clip_t 를 적고, 다 하면 오른다
func _clip_tick(dt: float) -> void:
	clip_t += dt; fig.set_meta("clip_t", clip_t)
	if clip_t >= ClipPoses.TOTAL - EPS: _end_clip(); _mount()

## clip 의 메타와 자세를 거둔다
func _end_clip() -> void:
	if fig.has_meta("clip_t"): fig.remove_meta("clip_t")
	if fig.pose_request == "clip": fig.pose_request = ""

## 오른다 — 같은 mount(count 거짓); 빈 사전이면(그새 차가 떠났거나 남이 탔다) 집으로
func _mount() -> void:
	seat = cr.mount(hop, x, C.PLAYER_Z, true, fig, false)
	if seat.is_empty(): _go("back"); return
	rides += 1; fig.pose_request = "pedal"; _go("ride")

## 안장의 틱 — 같은 stand 를 C 를 쥔 채(쉬지 않고 밟는다); 내려선 틱은 윗역이면 쉬고(pause) 아니면 집으로
func _ride(dt: float) -> void:
	var r := cr.stand(seat, true, dt, fig)
	x = float(r["x"]); y = float(r["y"])
	if bool(r["off"]):
		fig.pose_request = ""; seat = {}; vx = 0.0
		if float(r["u"]) >= 1.0: tops += 1; _go("pause")
		else: _go("back")

## 뜀을 맞춘다 — 윗역의 틈 끝에서 아랫역의 역 곁(dock_x)에 내리게(ClimbJump.fit, 로더의 수 그대로)
func _prep(dt: float) -> void:
	var j := ClimbJump.fit(x, y, dock_x, a_y, dt)
	jump = Vector2(float(j["vx"]), float(j["vy"])); charge_s = float(j["charge_s"])
	_go("charge")

func _launch() -> void:
	fig.crouch = 0.0; vx = jump.x; vy = jump.y
	fig.face(PI / 2.0 if vx >= 0.0 else -PI / 2.0); _go("down")

## 공중의 틱 — 로더와 같은 순서(중력 → 자리 → 착지): 아래 발판의 윗면을 내려 지나며 x 가 그 발판 위면 같은 squash 로 내린다
func _air(dt: float) -> void:
	vy -= C.G * dt
	var ny := y + vy * dt
	x += vx * dt
	if vy <= 0.0 and y >= a_y and ny <= a_y and x >= a_x0 - C.HW and x <= a_x1 + C.HW:
		y = a_y; vy = 0.0; vx = 0.0; fig.squash = -0.6   # 로더의 평이한 착지와 같은 squash
		drops += 1; at_land = Vector2(x, y); _go("back"); return
	if ny < a_y - VOID: _gone(); return
	y = ny

## 집에서 카메라를 보고 선다 — 다음은 1분 뒤(또는 플레이어의 타기 뒤)
func _rest() -> void:
	vx = 0.0; vy = 0.0; fig.face(0.0); fig.pose_request = ""; fig.crouch = 0.0
	next_at = cr.t + MINUTE; _go("idle")

func _gone() -> void:
	fig.visible = false; fig.pose_request = ""; vx = 0.0; vy = 0.0; falls += 1
	next_at = cr.t + MINUTE; _go("gone")

## 집에 바로 세운다(점검·돌아옴) — 타던 차는 팩에서 풀고, 다음 차례는 지금
func _home() -> void:
	if s["rider"] == fig: cr._leave(s)
	x = home_x; y = a_y; vx = 0.0; vy = 0.0; fig.visible = true; cr.leave(fig); _end_clip(); fig.pose_request = ""; fig.crouch = 0.0; seat = {}
	seen_me = float(s.get("me_t", -99.0)); next_at = cr.t; fig.face(0.0); _go("idle")

func _go(p: String) -> void:
	phase = p; since = 0.0; trail.append("%s@%.2f" % [p, cr.t])
	if trail.size() > 40: trail.pop_front()

## Stick3D 에 걸음·공중·자리를 — climb.gd 가 플레이어에게 하는 것과 같은 식(궤도 노드의 원점 기준: 아랫역의 x, a 윗면, PLAYER_Z); 타는 동안은 궤도가 오르는 쪽을 본다(로더가 플레이어에게 하는 것과 같이)
func _drive() -> void:
	var air := phase == "down"
	fig.airborne = air; fig.vertical = vy * C.K if air else 0.0
	fig.move_dir = Vector3(signf(vx), 0.0, 0.0) if absf(vx) > 20.0 and not air else Vector3.ZERO
	fig.speed = absf(vx) * C.K if not air else 0.0
	if phase == "ride": fig.face(PI / 2.0 if dir > 0.0 else -PI / 2.0)
	fig.position = Vector3((x - float(s["x0"])) * C.K, (y - float(s["y0"])) * C.K, 0.0)
