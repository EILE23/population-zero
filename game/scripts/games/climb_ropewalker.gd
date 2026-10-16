class_name ClimbRopewalker
extends RefCounted
## 외줄꾼 — 외줄 팩(climb_tightrope.gd, run 164)의 주민 반쪽(run 165; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 밧줄마다 하나, 아래 고리 옆(턱 끝 IN 안)에 서서 밧줄을 보는 주민.
## 탑의 1분(MINUTE)마다 한 번(층마다 어긋나게), 그리고 플레이어가 이 밧줄에 올라선 뒤 REACT 초 뒤(밧줄이 빈 뒤에 — 둘이 한 밧줄을 흔들지 않는다: 플레이어가 서 있는 동안은 외줄꾼이 멈춘다) 박자가 묻는 대로 건넌다 —
## BURST 초를 WALK 로 걷고 REST 초 서기를 되풀이: 같은 stand() 를 제 st 로 부르니 같은 흔들림이 다스린다(걸으면 진폭이 3.0/0.35 px/s 로 붇고 서면 같은 빠르기로 준다 — 0.15 s 걸음은 1.29 px 를 보태 2.49 에서 멈추니 바람 없는 층은 절대 안 떨어지고,
## 바람 부는 층은 걸음을 BURST_WINDY 로 줄여도 바람 80 px/s 를 넘으면 둘째 걸음에서 떨어진다 — 그게 '바람 부는 날의 낙상'). 밧줄 위는 tiptoe, 건너편 고리에 닿으면 flourish(stick3d_flourish.gd — 한 팔을 허리에 접고 다른 팔을 펴 몸을 숙였다 드는 절), 1분 뒤 되돌아온다.
## 떨어지면 같은 lurch 로 틈 아래로(x 그대로, G) — 이 층의 발판(plan 이 적어 준 hops: 위 턱까지의 발판들) 위로 로더의 판정처럼 내리고(윗면을 지나며 x 가 HW 안), SIT 초 뒤 발판 꼭대기를 타고 올라온다: 다음 발판 쪽 끝으로 걸어가 JUMP_V 로 뛰되 vx 는 그 발판 가까운 끝에 내리게 맞춘다(RUN 안) — 아래 턱에 닿으면 집으로 걸어와 1분을 센다.
## 이 층의 어느 발판에도 안 닿고 VOID 아래로 지나면 층을 떠난 것(아래 층은 다른 band — 팩은 못 본다): 몸을 감추고 1분 뒤 집에 돌아와 있다.
## 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 마을의 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 mind 는 아직 없다). 노드는 밧줄의 노드(원점: 왼 끝 x0, y0, 밧줄의 z) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_tightrope.gd 의 WALKER 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0        # 탑의 1분 — 혼자서도 이만큼마다 한 번 건넌다
const REACT := 1.5          # 플레이어가 올라선 뒤 이만큼 있다 간다(밧줄이 비면)
const BURST := 0.15         # 바람 없는 층의 걸음(s, WALK) — 진폭 +1.29 → 2.49 < 3.0
const BURST_WINDY := 0.12   # 바람 부는 층의 걸음 — +1.03: 바람 80 까지는 버틴다
const REST := 0.25          # 걸음 사이 서는 시간 — 2.14 을 덜어 어느 걸음이든 바닥(base)으로 돌린다
const EPS := 0.000001       # 박자 비교의 여유 — 1/60 을 아홉 번 더해도 0.15 에 닿게
const IN := 4.0             # 턱 끝 안쪽 이만큼에 선다(고리는 6 안)
const SIT := 2.0            # 떨어져 내린 발판 위에서, 또 발판마다 이만큼 숨 돌린다(lurch 의 회수 0.3 보다 길다)
const VOID := 400.0         # 가장 낮은 발판보다 이만큼 아래 → 층을 떠났다

var tr: ClimbTightrope
var rope: Dictionary        # 밧줄(climb_tightrope.ropes 의 것 — 참조라 stood·me_t·stepped_t 를 같이 본다)
var fig: Stick3D
var st := { "px": 0.0, "rid": "" }   # stand() 에 주는 제 걸음 상태
var hops: Array = []        # 이 층의 발판 {id, x, w, y, amp} — 아래서 위로, 위 턱까지(plan 이 적는다)
var phase := "idle"         # idle | cross | flourish | fall | up | walk | leap | gone
var since := 0.0            # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0          # 다음 혼자 건너는 때(tr.t)
var seen_step := -99.0      # 따라간 플레이어의 stepped_t — 한 번에 한 번
var at_far := false         # 건너편 고리에 있나
var burst := true; var beat := 0.0   # cross: 걷는 중인가, 그 안에서 흐른 시간
var d := 1.0                # 지금 가는 방향(±x)
var x_end := 0.0            # cross·walk 의 목표 x
var then_leap := false      # walk 끝에 뛰나(발판 꼭대기를 타고 오를 때)
var hop: Dictionary = {}    # 떨어져 내린 발판
var aim: Dictionary = {}    # 뛰어 오를 다음 발판
var x := 0.0; var y := 0.0; var vx := 0.0; var vy := 0.0
var dir := 1.0              # 밧줄의 dir — 아래 턱에서 위 턱으로 가는 방향
var x_home := 0.0; var x_far := 0.0
var crossings := 0; var falls := 0; var bows := 0; var max_off := 0.0; var leaps := 0   # 점검용

func _init(pack: ClimbTightrope, s: Dictionary, parent: Node3D) -> void:
	tr = pack; rope = s; dir = float(s["dir"]); hops = s.get("hops", [])
	var lo := float(s["x0"]) if dir > 0.0 else float(s["x1"]); var hi := float(s["x1"]) if dir > 0.0 else float(s["x0"])
	x_home = lo - dir * IN; x_far = hi + dir * IN
	x = x_home; y = tr.surf(s, x)
	next_at = tr.t + 20.0 + float(int(s["n"]) % 5) * 8.0   # 층마다 어긋나게 — 별밤의 다섯 층이 한꺼번에 건너지 않는다
	fig = Stick3D.new(); fig.color = Color("4e5a6b"); fig.head_color = Color("4e5a6b")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "ropewalker"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("4e5a6b"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	_face(dir)
	_drive()

## 매 틱(climb_tightrope._process)
func step(dt: float) -> void:
	if not is_instance_valid(fig) or dt <= 0.0: return
	since += dt
	match phase:
		"idle":
			var sp := float(rope.get("stepped_t", -99.0))
			if sp != seen_step and tr.t - sp >= REACT: seen_step = sp; next_at = minf(next_at, tr.t)   # 플레이어가 올라섰다 — 따라 건넌다
			if tr.t >= next_at and tr.t - float(rope["stood"]) > 0.1: _start_cross()   # 밧줄이 비어야 간다
		"cross":
			_cross(dt)
		"flourish":
			if since >= FlourishPoses.FLOURISH_T: fig.pose_request = ""; _rest()   # 자세의 시계를 묻지 않는다(헤드리스 점검은 프레임을 안 돌린다)
		"fall", "leap":
			_air(dt)
		"up":
			if since >= SIT: fig.pose_request = ""; _next_up()
		"walk":
			_walk(dt)
		"gone":
			if tr.t >= next_at: _home()
	_drive()

## 건너는 틱 — BURST 걷고 REST 서기; 플레이어가 밧줄에 서 있으면 박자를 멈추고 가만히 선다(제 걸음으로 남의 발밑을 흔들지 않는다)
func _cross(dt: float) -> void:
	var player_on := tr.t - float(rope.get("me_t", -99.0)) < 0.1
	var moving := false
	if not player_on:
		beat += dt
		var b := BURST_WINDY if absf(float(rope.get("wind", 0.0))) > 0.0 else BURST
		if burst and beat >= b - EPS: burst = false; beat = 0.0
		elif not burst and beat >= REST - EPS: burst = true; beat = 0.0
		moving = burst
	vx = d * C.WALK if moving else 0.0
	x += vx * dt
	if (x - x_end) * d >= 0.0:
		x = x_end; vx = 0.0; y = tr.surf(rope, x); at_far = not at_far; crossings += 1; bows += 1
		fig.pose_request = "flourish"; phase = "flourish"; since = 0.0
		return
	var r := tr.stand(rope, x, dt, fig, st)
	y = float(r["y"]); max_off = maxf(max_off, absf(float(r["off"])))
	if bool(r["fall"]): _fall()

## 공중의 틱(fall: x 그대로 / leap: vx 로) — 로더와 같은 순서(중력 → 자리 → 착지 판정); 이 층의 발판 윗면을 내려 지나며 x 가 HW(+ 움직이는 폭) 안이면 가장 높은 것에 내린다
func _air(dt: float) -> void:
	vy -= C.G * dt
	var ny := y + vy * dt
	x += vx * dt
	if vy <= 0.0:
		for i in range(hops.size() - 1, -1, -1):
			var h: Dictionary = hops[i]
			var hy := float(h["y"]); var amp := float(h.get("amp", 0.0))
			if y >= hy and ny <= hy and x >= float(h["x"]) - C.HW - amp and x <= float(h["x"]) + float(h["w"]) + C.HW + amp:
				_land(h); return
	var lowest := float((hops[0] as Dictionary)["y"]) if hops.size() > 0 else tr.surf(rope, x_home) - 200.0
	if ny < lowest - VOID: _gone(); return
	y = ny

func _land(h: Dictionary) -> void:
	y = float(h["y"]); vx = 0.0; vy = 0.0; hop = h
	fig.squash = -0.6   # 로더의 평이한 착지와 같은 squash; lurch 의 회수는 airborne 이 꺼지며 제 시계로 간다
	phase = "up"; since = 0.0

## 숨 돌린 뒤 — 아래 턱이면 집으로, 위 턱이면 건너편 고리로, 아니면 다음 발판 쪽 끝으로 걸어가 뛴다
func _next_up() -> void:
	var id := String(hop.get("id", ""))
	if id == String(rope["a_id"]): at_far = false; _go_walk(x_home, false); return
	if id == String(rope["b_id"]): at_far = true; _go_walk(x_far, false); return
	var i := -1
	for j in hops.size():
		if String((hops[j] as Dictionary).get("id", "")) == id: i = j
	if i < 0 or i + 1 >= hops.size(): _gone(); return   # 모를 발판 — 층을 떠난 것으로 친다(일어날 일은 없다: hop 은 hops 에서 왔다)
	aim = hops[i + 1]
	var cx := float(aim["x"]) + float(aim["w"]) / 2.0
	_go_walk(float(hop["x"]) + float(hop["w"]) - IN if cx > x else float(hop["x"]) + IN, true)

func _go_walk(to: float, leap_after: bool) -> void:
	x_end = to; then_leap = leap_after; phase = "walk"; since = 0.0
	d = 1.0 if to >= x else -1.0; _face(d)

## 발판 위를 걷는 틱(걸음은 WALK) — 끝에 닿으면 뛰거나 쉰다
func _walk(dt: float) -> void:
	vx = d * C.WALK
	x += vx * dt
	if (x - x_end) * d < 0.0: return
	x = x_end; vx = 0.0
	if then_leap: _leap()
	else: _rest()

## 다음 발판으로 — JUMP_V 로 뛰어 그 발판의 가까운 끝(2 IN 안)에 내리도록 vx 를 맞춘다(RUN 안; 모자라면 로더의 판정대로 더 낮은 발판에 내려 다시 오른다)
func _leap() -> void:
	var dy := float(aim["y"]) - y
	var tf := (C.JUMP_V + sqrt(maxf(0.0, C.JUMP_V * C.JUMP_V - 2.0 * C.G * dy))) / C.G
	var cx := float(aim["x"]) + float(aim["w"]) / 2.0
	var target := float(aim["x"]) + 2.0 * IN if cx > x else float(aim["x"]) + float(aim["w"]) - 2.0 * IN
	vx = clampf((target - x) / maxf(tf, 0.01), -C.RUN, C.RUN); vy = C.JUMP_V
	_face(1.0 if vx >= 0.0 else -1.0)
	phase = "leap"; since = 0.0; leaps += 1

func _fall() -> void:
	fig.pose_request = "lurch"; phase = "fall"; since = 0.0; vx = 0.0; vy = 0.0; falls += 1

func _start_cross() -> void:
	d = -dir if at_far else dir; x_end = x_home if at_far else x_far
	burst = true; beat = 0.0; phase = "cross"; since = 0.0
	fig.pose_request = "tiptoe"; _face(d)

## 고리 옆에 서서 밧줄을 본다 — 다음은 1분 뒤(또는 플레이어가 올라선 뒤)
func _rest() -> void:
	phase = "idle"; since = 0.0; vx = 0.0; vy = 0.0; hop = {}; fig.pose_request = ""; fig.crouch = 0.0
	_face(-dir if at_far else dir); next_at = tr.t + MINUTE

func _gone() -> void:
	fig.visible = false; fig.pose_request = ""; phase = "gone"; since = 0.0; vx = 0.0; vy = 0.0; next_at = tr.t + MINUTE

## 층을 떠났다 돌아온다 — 집(아래 고리)에, 밧줄이 비면 바로 건넌다
func _home() -> void:
	x = x_home; y = tr.surf(rope, x); at_far = false; hop = {}; fig.visible = true
	phase = "idle"; since = 0.0; next_at = tr.t; _face(dir)

func _face(dd: float) -> void:
	fig.face(PI / 2.0 if dd > 0.0 else -PI / 2.0)

## Stick3D 에 걸음·공중을 — climb.gd 가 플레이어에게 하는 것과 같은 식(밧줄 노드의 원점 기준; 몸의 z 는 플레이어의 PLAYER_Z)
func _drive() -> void:
	var air := phase == "fall" or phase == "leap"
	fig.airborne = air; fig.vertical = vy * C.K if air else 0.0
	fig.move_dir = Vector3(signf(vx), 0, 0) if absf(vx) > 20.0 and not air else Vector3.ZERO
	fig.speed = absf(vx) * C.K
	fig.position = Vector3((x - float(rope["x0"])) * C.K, (y - float(rope["y0"])) * C.K, (C.PLAYER_Z - float(rope["z"])) * C.K)
