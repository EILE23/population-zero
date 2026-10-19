class_name ClimbThrower
extends RefCounted
## 던지는 이 — 절벽 투창 팩(climb_javelin.gd, run 178)의 주민 반쪽(run 179; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 투창장마다 하나, 받침대에서 고리 쪽으로 BACK(몸 둘 폭)에 카메라를 보고 선 주민 — 투창장의 지킴이.
## 받침대 뒤가 아니라 앞에 서는 이유: 받침대는 발판 뒷끝에서 rack_in(26) 안쪽이라 뒤엔 HW 를 빼면 16 px 뿐 — 거기 서면 받침대 속에 선다. 앞 40 px 는 창의 길 아래지만 창은 손(48 위)을 떠나 60° 로 오르니 거기선 96 px 위를 지난다(머리 50 위).
## 탑의 1분(MINUTE)마다 한 번(층마다 어긋나게), 그리고 플레이어가 던진 뒤(팩이 count 참일 때 me_t 에 적는다) REACT 초 뒤에 받침대로 걸어가 — 고리가 차 있으면(남의 창이 꽂혀 있다) 고리를 보며 기다리고(WAIT_S 넘으면 집으로), 받침대가 비었어도 기다린다 —
## 바람을 읽고(lick, stick3d_lick.gd — 손가락을 입술에 0.3 s, 들어 0.8 s 고개는 바람 아래쪽, 내림 0.2 s) 같은 throw(count 거짓 — 제 명중은 판의 날(day)에 안 세고 me_t 도 안 적는다; 꽂힌 창은 플레이어의 발판이 된다)로 같은 hurl 로 던진다.
## 모으는 양은 바람째 푼다: aim_k(wind) 가 손에서 고리 가운데까지의 비행을 층의 바람(던지는 쪽으로 dir × wind)과 같이 0.005 걸음으로 훑어 고리에 가장 가까운 모음을 고른다(백로그의 '−wind × 0.0008' 어림은 버렸다 — 고리가 비행의 꼭대기 가까이라 맞바람 60 엔 모음이 거의 안 변하고(0.390) 맞바람 120 엔 0.410, 뒷바람 60 엔 0.415 가 든다: 부호가 아니라 비행이 답이다);
## 층·던진 차례(n + throws) % 4 에 따라 OFFS 만큼 어긋난다: 둘에 하나는 꽂히고(0) 하나는 넘거나(+0.14) 짧다(−0.06) — 점검 투창장의 명중 창은 모음 0.36..0.50(가운데 0.389 는 아래쪽 가까이)이라 양쪽 다 0.03 밖이다(백로그의 ±0.05 는 둘 다 꽂혔을 것). 빗나가면 다음 모음을 빗나간 부호로 CORR 고친다(짧으면 더, 넘으면 덜 — ±CORR_MAX 안; 고친 뒤의 가운데 0.419 도 꽂히고 고친 뒤의 넘김 0.559 도 넘는다).
## 플레이어가 당기거나 모으는 동안은 집에서 기다린다(걸어가던 중이면 돌아온다 — 플레이어의 받침대가 먼저). 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 마을의 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 mind 는 아직 없다). 투창장 발판을 벗어나지 않는다(걷는 길이 받침대와 집 사이뿐이라 VOID 가 없다).
## 노드는 투창장의 노드(원점: 받침대의 x, 발판 윗면, 절벽) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_javelin.gd 의 THROWER·LICK 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 혼자서도 이만큼마다 한 번 던진다
const REACT := 1.5        # 플레이어가 던진 뒤 이만큼 있다 받침대로 간다 — 창이 나는 걸 보는 사이
const BACK := 40.0        # 받침대에서 고리 쪽 이만큼에 선다(px) — 몸 둘 폭(2 × 2 HW)
const WAIT_S := 16.0      # 받침대에서 고리가 비길 이보다 오래 기다리면 집으로(stay_s 12 + 떨어짐)
const OFFS := [0.14, 0.0, -0.06, 0.0]  # 던진 차례의 모음 어긋남 — 넘는다·가운데·짧다·가운데(둘에 하나 꽂힌다; 명중 창 0.36..0.50 의 바깥)
const CORR := 0.03        # 빗나간 뒤 다음 모음을 고치는 폭
const CORR_MAX := 0.1
const STEP := 0.005       # aim_k 가 모음을 훑는 걸음
const EPS := 0.000001     # 시계 비교의 여유

var cj: ClimbJavelin
var s: Dictionary         # 투창장(climb_javelin.ranges 의 것 — 참조라 sw·sw_fig·javs·me_t 를 같이 본다)
var hop: Dictionary       # throw() 의 on — 팩은 id 만 읽는다
var fig: Stick3D
var phase := "idle"       # idle | walk | wait | lick | swing | back | gone
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0        # 다음 혼자 던지는 때(cj.t)
var seen_me := -99.0      # 따라간 플레이어의 me_t — 한 던지기에 한 번
var x := 0.0; var z := 0.0; var vx := 0.0
var dir := 1.0            # 투창장의 dir — 받침대에서 고리 쪽
var wx := 0.0; var home_x := 0.0
var lick_t := 0.0         # lick 에 든 뒤 시간 — 메타 lick_t 로 자세에
var c_target := 0.0       # 이번 던지기에 모을 양
var bias := 0.0           # 빗나간 뒤의 고침(모음) — 짧으면 +, 넘으면 −
var my_j: Dictionary = {} # 내가 던져 아직 나는 창(javs 의 것)
var cross_y := NAN        # 그 창이 고리의 x 를 지난 높이 — 안 지났으면 NAN(짧다)
var throws := 0; var sticks := 0
var charges: Array = []   # 점검용 — 놓은 때의 모음
var ends: Array = []      # 점검용 — 창의 끝(stuck | short | long)
var trail: Array = []     # phase@t — 점검용

func _init(pack: ClimbJavelin, range_: Dictionary, parent: Node3D) -> void:
	cj = pack; s = range_; dir = float(s["dir"]); wx = float(s["wx"]); z = C.PLAYER_Z
	hop = { "id": String(s["hop_id"]) }
	var x0 := float(s["hop_x"]) + C.HW; var x1 := x0 + float(s["hop_w"]) - 2.0 * C.HW
	home_x = clampf(wx + dir * BACK, x0, x1)   # 좁은 발판(110)이면 끝 안쪽까지만
	x = home_x
	next_at = cj.t + 25.0 + float(int(s["n"]) % 5) * 7.0   # 층마다 어긋나게 — 바람 절벽의 다섯 층이 한꺼번에 던지지 않는다
	fig = Stick3D.new(); fig.color = Color("6b5a4e"); fig.head_color = Color("6b5a4e")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "thrower"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("6b5a4e"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	fig.face(0.0)
	_drive()

## 남(플레이어)이 이 받침대에서 당기고·모으고·던지는 중인가
func other_throwing() -> bool:
	return String(s["sw"]) != "" and (s["sw_fig"] as Stick3D) != fig

## 던질 수 있나 — 고리가 비고 받침대에 창이 있다
func ready() -> bool:
	return cj._ring_empty(s) and not cj._in_rack(s).is_empty()

## 손에서 고리 가운데까지, 층의 바람과 함께 나르는 모음 0..1 — 비행(loft, G, 던지는 쪽으로 dir × wind)을 STEP 걸음으로 훑어 고리의 x 에서 고리 높이에 가장 가까운 것
func aim_k(wind: float) -> float:
	var dx := cj.range_dx() - cj.hand_dx(); var dy := cj.range_dy() - cj.hand_dy()
	var w := dir * wind; var cl := cos(cj.loft()); var sl := sin(cj.loft())
	var best := cj.need_k(); var best_err := INF
	var c := 0.0
	while c <= 1.0 + EPS:
		var v := cj.v_min() + (cj.v_max() - cj.v_min()) * c
		var vx_ := v * cl + w
		if vx_ > 1.0:
			var tf := dx / vx_
			var err := absf(v * sl * tf - 0.5 * C.G * tf * tf - dy)
			if err < best_err: best_err = err; best = c
		c += STEP
	return clampf(best, 0.0, 1.0)

## 매 틱(climb_javelin._process)
func step(dt: float) -> void:
	if not is_instance_valid(fig) or dt <= 0.0: return
	since += dt
	match phase:
		"idle":
			var me := float(s.get("me_t", -99.0))
			if me > seen_me and cj.t - me >= REACT - EPS: seen_me = me; next_at = minf(next_at, cj.t)   # 플레이어가 던졌다 — 따라 던진다
			if other_throwing(): pass   # 플레이어가 받침대에 — 집에서 기다린다
			elif cj.t >= next_at: seen_me = me; _go("walk")
		"walk":
			if other_throwing(): _go("back")   # 플레이어가 먼저 잡았다
			elif _walk(wx, dt): _go("wait")
		"wait":
			if other_throwing(): _go("back")
			elif ready(): _lick()
			elif since >= WAIT_S: _go("back")
			else: fig.face(PI / 2.0 if dir > 0.0 else -PI / 2.0)   # 꽂힌 창이 떨어지길 고리를 보며 기다린다
		"lick":
			if other_throwing(): _end_lick(); _go("back")
			else: _lick_tick(dt)
		"swing":
			_swing()
		"back":
			if _walk(home_x, dt): _rest()
		"gone":
			if cj.t >= next_at: _home()
	_watch()
	_drive()

## target 까지 플레이어의 걸음(WALK)으로 — 닿으면 true 를 주고 카메라를 본다(투창장은 std 발판에만 서니 얼음은 없다)
func _walk(target: float, dt: float) -> bool:
	var d := signf(target - x)
	if d == 0.0 or (target - x) * d <= C.WALK * dt:
		x = target; vx = 0.0; fig.face(0.0); return true
	vx = d * C.WALK
	x += vx * dt; fig.face(PI / 2.0 if d > 0.0 else -PI / 2.0)
	return false

## 바람을 읽는다 — 카메라를 보고 서서 lick; 고개는 바람이 미는 쪽(없으면 고리 쪽)
func _lick() -> void:
	var wind := float(s["wind"])
	lick_t = 0.0; fig.set_meta("lick_t", 0.0); fig.set_meta("lick_lee", signf(wind) if wind != 0.0 else dir)
	fig.face(0.0); fig.pose_request = "lick"; _go("lick")

## 읽기의 시계 — 메타 lick_t 를 적고, 다 하면 당긴다
func _lick_tick(dt: float) -> void:
	lick_t += dt; fig.set_meta("lick_t", lick_t)
	if lick_t >= LickPoses.TOTAL - EPS: _end_lick(); _draw()

## lick 의 메타와 자세를 거둔다
func _end_lick() -> void:
	for key: String in ["lick_t", "lick_lee"]:
		if fig.has_meta(key): fig.remove_meta(key)
	if fig.pose_request == "lick": fig.pose_request = ""

## 당긴다 — 이번 모음을 고르고(바람째 가운데 ± 차례 + 고침) 팩의 throw 에 든다(count 거짓); 받침대가 비었으면(그새 비었다) 집으로
func _draw() -> void:
	c_target = clampf(aim_k(float(s["wind"])) + float(OFFS[(int(s["n"]) + throws) % OFFS.size()]) + bias, 0.0, 1.0)
	var r := cj.throw(x, z, hop, true, fig, false)
	if not bool(r["busy"]): _go("back"); return
	fig.pose_request = "hurl"; _go("swing")

## 당기고·모으고·던진다 — 팩의 시계가 c_target 에 닿을 때까지 누르고 놓는다; 놓은 창을 기억해 둔다(_watch); 몸이 풀리면(swing_s) 집으로
func _swing() -> void:
	var sw := String(s["sw"])
	if sw == "" or (s["sw_fig"] as Stick3D) != fig: fig.pose_request = ""; _go("back"); return   # 풀렸다(또는 팩이 남에게 갔다)
	var held := true
	if sw == "charge": held = (cj.t - float(s["sw_t0"])) / cj.charge_s() < c_target - EPS
	elif sw == "throw": held = false
	var r := cj.throw(x, z, hop, held, fig, false)
	fig.face(PI / 2.0 if dir > 0.0 else -PI / 2.0)   # 던지는 이는 고리 쪽을 본다 — 로더가 플레이어에게 하는 것과 같이
	if sw == "charge" and not held and my_j.is_empty():
		throws += 1; charges.append(float(s["c"])); my_j = (s["javs"] as Array)[int(s["jav"])]; cross_y = NAN
	if not bool(r["busy"]): fig.pose_request = ""; _go("back")

## 내 창을 눈으로 — 고리의 x 를 지난 높이를 적고, 서면(stuck·down·lost) 끝을 판다: 꽂혔으면 명중, 고리 아래로 지났거나 못 닿았으면 짧다(다음은 더), 위로 지났으면 넘었다(덜)
func _watch() -> void:
	if my_j.is_empty(): return
	var st := String(my_j["st"])
	if st == "held": return
	if st == "fly":
		if is_nan(cross_y) and (float(my_j["x"]) - float(s["rx"])) * dir >= 0.0: cross_y = float(my_j["y"])
		return
	if st == "stuck": sticks += 1; ends.append("stuck")
	elif is_nan(cross_y) or cross_y < float(s["ry"]): bias = minf(CORR_MAX, bias + CORR); ends.append("short")
	else: bias = maxf(-CORR_MAX, bias - CORR); ends.append("long")
	my_j = {}; cross_y = NAN

## 집에서 카메라를 보고 선다 — 다음은 1분 뒤(또는 플레이어의 던지기 뒤)
func _rest() -> void:
	vx = 0.0; fig.face(0.0); next_at = cj.t + MINUTE; _go("idle")

## 집에 바로 세운다(점검·돌아옴) — 당기던 것은 팩에서 풀고, 다음 차례는 지금
func _home() -> void:
	x = home_x; vx = 0.0; fig.visible = true; cj._drop(fig); cj.leave(fig); _end_lick(); fig.pose_request = ""
	my_j = {}; cross_y = NAN; seen_me = float(s.get("me_t", -99.0)); next_at = cj.t; fig.face(0.0); _go("idle")

func _go(p: String) -> void:
	phase = p; since = 0.0; trail.append("%s@%.2f" % [p, cj.t])
	if trail.size() > 40: trail.pop_front()

## Stick3D 에 걸음·자리를 — climb.gd 가 플레이어에게 하는 것과 같은 식(투창장 노드의 원점 기준: 받침대의 x, 발판 윗면, 절벽)
func _drive() -> void:
	fig.move_dir = Vector3(signf(vx), 0.0, 0.0) if absf(vx) > 20.0 else Vector3.ZERO
	fig.speed = absf(vx) * C.K
	fig.position = Vector3((x - wx) * C.K, 0.0, (z - C.WALL_Z) * C.K)
