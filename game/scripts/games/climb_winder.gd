class_name ClimbWinder
extends RefCounted
## 시계 감는 이 — 시계추 팩(climb_weight.gd, run 174)의 주민 반쪽(run 175; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 추마다 하나, 추에서 BACK(몸 둘 폭) 떨어져 카메라를 보고 선 주민 — 시계의 지킴이.
## 다 풀린 시계를 탑의 1분(MINUTE) 두면(층마다 어긋나게 시작한다) 추로 걸어가 손에 초크를 치고(chalk, stick3d_chalk.gd — 박수 둘에 가루 퍼프 둘, 비빔, 털기) 같은 lift(count 거짓 — 제 감기는 판에 안 세고 me_t 도 안 적는다)로 같은 press 로 든다;
## 추의 hold_s 를 꼭 채운다(놓치는 법이 없다 — 지킴이니까) → 걸리면 집으로 걸어가 카메라를 보고, 다음은 그 시계가 다 풀린(run_s) 뒤 1분.
## 플레이어가 감으면(팩이 count 참일 때 me_t 에 적는다) 다 풀리길 기다려 clank 뒤 REACT 에 든다. 플레이어가 드는 동안은 집에서 기다린다(걸어가던 중이면 돌아온다 — 플레이어의 들기가 먼저);
## 플레이어가 놓치면(thud 가 신호) STEP 만큼 물러나 LINGER 동안 서 있다 집으로 — 그 뒤 차례가 지났으면 바로 감는다(플레이어가 떨어뜨린 시계는 지킴이가 감는다).
## 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 마을의 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 mind 는 아직 없다). 추 발판을 벗어나지 않는다(걷는 길이 추와 집 사이뿐이라 VOID 가 없다). 노드는 추의 노드(원점: 추의 x, 발판 윗면, 절벽) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_weight.gd 의 WINDER·CHALK 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 다 풀린 시계를 이만큼 두었다 감는다
const REACT := 1.0        # 플레이어가 감은 시계가 다 풀린(clank) 뒤 이만큼 있다 든다
const BACK := 40.0        # 추에서 이만큼 떨어져 선다(px) — 몸 둘 폭(2 × 2 HW)
const STEP := 20.0        # 플레이어가 놓치면 이만큼 물러난다(px)
const LINGER := 1.5       # 물러나 서 있는 시간(s)
const PUFF := 0.3         # 초크 가루 퍼프의 세기 — Jump3D.dust 는 0.25 아래를 버린다
const HANDS_Y := 1.05     # 가루가 나는 높이(m) — 가슴 앞의 손
const EPS := 0.000001

var cw: ClimbWeight
var s: Dictionary         # 추(climb_weight.weights 의 것 — 참조라 st·ph·fig·me_t 를 같이 본다)
var hop: Dictionary       # lift() 의 on — 팩은 id 만 읽는다
var fig: Stick3D
var phase := "idle"       # idle | walk | chalk | lift | back | step | linger | gone
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0        # 다음 감는 때(cw.t) — 시계가 풀려 있어야 간다
var seen_me := -99.0      # 본 플레이어의 me_t — 한 감기에 한 번
var chalk_t := 0.0        # chalk 에 든 뒤 시간 — 메타 chalk_t 로 자세에
var x := 0.0; var z := 0.0; var vx := 0.0
var dir := 1.0            # 추의 어느 쪽에 서나(+x)
var wx := 0.0; var home_x := 0.0; var back_x := 0.0
var puffs := 0            # 점검용 — 날린 가루
var winds := 0            # 점검용 — 감은 수
var wound_mine := false   # 이번 귀가가 제 감기 뒤인가 — _rest 가 다음 차례를 그 시계에 맞춘다
var trail: Array = []     # phase@t — 점검용

func _init(pack: ClimbWeight, weight: Dictionary, parent: Node3D) -> void:
	cw = pack; s = weight; wx = float(s["wx"]); z = C.PLAYER_Z
	hop = { "id": String(s["hop_id"]) }
	var half := float(s["hop_w"]) / 2.0 - C.HW
	home_x = clampf(wx + dir * BACK, wx - half, wx + half)   # 좁은 발판(110)이면 끝 안쪽까지만
	back_x = clampf(home_x + dir * STEP, wx - half, wx + half)
	x = home_x
	next_at = cw.t + 25.0 + float(int(s["n"]) % 5) * 7.0   # 층마다 어긋나게 — 태엽의 다섯 층이 한꺼번에 감지 않는다
	fig = Stick3D.new(); fig.color = Color("4e5f6b"); fig.head_color = Color("4e5f6b")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "winder"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("4e5f6b"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	fig.face(0.0)
	_drive()

## 남(플레이어)이 이 추를 들고 있나(걸기·놓침의 회수까지)
func other_lifting() -> bool:
	return String(s["ph"]) != "" and (s["fig"] as Stick3D) != fig

## 매 틱(climb_weight._process)
func step(dt: float) -> void:
	if not is_instance_valid(fig) or dt <= 0.0: return
	since += dt
	match phase:
		"idle":
			var me := float(s.get("me_t", -99.0))
			if me > seen_me: seen_me = me; next_at = me + cw.run_s() + REACT   # 플레이어가 감았다 — 다 풀리길 기다려 clank 뒤에 든다(집에서만 본다 — 걷다 돌아온 뒤에도 늦지 않다)
			if other_lifting():
				if String(s["ph"]) == "drop" and bool(s["thudded"]): _go("step")   # 플레이어가 놓쳤다 — thud 가 신호, 물러난다
			elif String(s["st"]) == "down" and String(s["ph"]) == "" and cw.t >= next_at: _go("walk")
		"walk":
			if other_lifting(): _go("back")   # 플레이어가 먼저 잡았다 — 집에서 기다린다
			elif _walk(wx, dt): chalk_t = 0.0; fig.set_meta("chalk_t", 0.0); fig.pose_request = "chalk"; _go("chalk")
		"chalk":
			if other_lifting(): _end_chalk(); _go("back")
			else: _chalk(dt)
		"lift":
			var r := cw.lift(x, z, hop, true, fig, false)   # C 를 쥔 채 — hold_s 를 꼭 채운다
			if not bool(r["busy"]):
				if String(s["st"]) == "wound": winds += 1; wound_mine = true
				fig.pose_request = ""; _go("back")
		"back":
			if _walk(home_x, dt): _rest()
		"step":
			if _walk(back_x, dt): _go("linger")
		"linger":
			if since >= LINGER: _go("back")
		"gone":
			if cw.t >= next_at: _home()
	_drive()

## target 까지 플레이어의 걸음(WALK)으로 — 닿으면 true 를 주고 카메라를 본다(추는 std 발판에만 서니 얼음은 없다)
func _walk(target: float, dt: float) -> bool:
	var d := signf(target - x)
	if d == 0.0 or (target - x) * d <= C.WALK * dt:
		x = target; vx = 0.0; fig.face(0.0); return true
	vx = d * C.WALK
	x += vx * dt; fig.face(PI / 2.0 if d > 0.0 else -PI / 2.0)
	return false

## 초크의 시계 — 메타 chalk_t 를 적고, 손이 맞부딪친 틱에 가루를 날리고, 다 하면 든다
func _chalk(dt: float) -> void:
	var u0 := chalk_t
	chalk_t += dt; fig.set_meta("chalk_t", chalk_t)
	if ChalkPoses.clap_between(u0, chalk_t) and fig.is_inside_tree():
		puffs += 1
		Jump3D.dust(fig.get_parent() as Node3D, fig.position + Vector3(0.0, HANDS_Y, 0.0), PUFF)   # 가루 — 로더의 착지 먼지 그대로, 가슴 앞에서
	if chalk_t >= ChalkPoses.TOTAL - EPS: _end_chalk(); _lift()

## chalk 의 메타와 자세를 거둔다
func _end_chalk() -> void:
	if fig.has_meta("chalk_t"): fig.remove_meta("chalk_t")
	if fig.pose_request == "chalk": fig.pose_request = ""

## 든다 — 팩의 lift 에 든다(count 거짓); 추가 바닥에 없으면(그새 감겼다) 집으로
func _lift() -> void:
	var r := cw.lift(x, z, hop, true, fig, false)
	if not bool(r["busy"]): _go("back"); return
	fig.pose_request = "press"; _go("lift")

## 집에서 카메라를 보고 선다 — 제가 감았으면 다음은 그 시계가 다 풀린 뒤 1분, 아니면 차례는 그대로(지났으면 시계가 풀리는 대로 간다)
func _rest() -> void:
	vx = 0.0; fig.face(0.0)
	if wound_mine: wound_mine = false; next_at = float(s["wound_t0"]) + cw.run_s() + MINUTE
	_go("idle")

## 집에 바로 세운다(점검·돌아옴) — 들던 것은 팩에서 풀고, 다음 차례는 지금
func _home() -> void:
	x = home_x; vx = 0.0; fig.visible = true; cw._away(fig); cw.leave(fig); _end_chalk(); fig.pose_request = ""
	wound_mine = false; next_at = cw.t; fig.face(0.0); _go("idle")

func _go(p: String) -> void:
	phase = p; since = 0.0; trail.append("%s@%.2f" % [p, cw.t])
	if trail.size() > 40: trail.pop_front()

## Stick3D 에 걸음·자리를 — climb.gd 가 플레이어에게 하는 것과 같은 식(추 노드의 원점 기준: 추의 x, 발판 윗면, 절벽)
func _drive() -> void:
	fig.move_dir = Vector3(signf(vx), 0.0, 0.0) if absf(vx) > 20.0 else Vector3.ZERO
	fig.speed = absf(vx) * C.K
	fig.position = Vector3((x - wx) * C.K, 0.0, (z - C.WALL_Z) * C.K)
