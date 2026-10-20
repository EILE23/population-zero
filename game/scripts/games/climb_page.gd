class_name ClimbPage
extends RefCounted
## 책 담당(page) — 반납 손수레 팩(climb_barrow.gd, run 184)의 주민 반쪽(run 185; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 수레마다 하나, 발판 a 의 틈 반대쪽 끝(주차 자리 쪽 걷는 선의 끝, 손잡이 앞 카메라 쪽 FRONT_Z)에 카메라를 보고 선 주민 — 밀려 가고 엎어진 수레를 RETURNS 자국으로 되돌리는 이.
## 탑의 1분(MINUTE)마다 한 번(층마다 어긋나게), 그리고 플레이어가 자국 밖이나 엎어진 수레에서 손을 뗀(팩이 count 참일 때 me_t 에 적는다) REACT 초 뒤에, 수레가 다 될 때까지 차례로: 엎어졌으면 바퀴 곁으로 걸어가 같은 step(tally 거짓 — 판의 날에 안 세고 me_t 도 안 적는다)으로 세우고(right — 같은 right_s, 같은 barrow);
## 더미가 있으면 그 틈 쪽에 무릎 꿇고 책을 한 권씩 왼 팔뚝에 모아(gather, stick3d_gather.gd — 팩의 scoop 이 책을 torso 에 붙인다) 들고 손잡이 곁으로 걸어가 통에 쏟고(shelve — 팩의 shelve, 잃은 책도 그때 돌아온다);
## 자국 밖이면 손잡이 뒤에서 수레를 돌리고(turn — 팩의 turn, pivot 자세: 몸은 수레 가운데를 ORBIT 반지름의 호로 돌아 반대쪽 손잡이 뒤에 선다) 자국까지 밀어(push — 같은 grip·slow, 손잡이는 손 앞 HW + AHEAD) 내려놓고(set — 같은 set_s), 다시 돌려 바퀴가 틈을 보게 세운다(park — 자국 위, dir 가 지을 때의 것, 팩의 put_back 이 센다); 그 뒤 집으로(back).
## 플레이어가 수레·더미 곁 NEAR 안에 서 있으면(팩의 step 이 tally 참인 틱에 near_t 에 적는다) 또는 잡고 있으면 집에서 기다린다 — 제 분은 넘기고(skips), 걸어가던 중이면 돌아온다; 시작한 동작(세우기·모으기·돌리기·밀기)은 끝까지 한다 — 반쯤 돈 수레를 두지 않는다.
## 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 마을의 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 mind 는 아직 없다). 노드는 수레의 노드(원점: 자국 px, a 윗면, PLAYER_Z) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_barrow.gd 의 PAGE·GATHER·PIVOT 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 혼자서도 이만큼마다 한 번 본다
const REACT := 2.0        # 플레이어가 손을 뗀 뒤 이만큼 있다 간다
const FRONT_Z := 18.0     # 집에서 카메라 쪽으로 이만큼 앞(px) — 손잡이 앞에 선다, 손잡이를 밟지 않는다
const APPROACH := 4.0     # 바퀴·더미 곁에 설 때 더하는 여유(px) — reach(14) 안
const AHEAD := 3.0        # 손잡이 끝은 손 앞 HW + AHEAD — climb_barrow 의 AHEAD
const NEAR_T := 0.2       # 플레이어를 마지막으로 곁에 본 뒤 이만큼은 가까운 것(s)
const MIN_HOLD := 0.1     # 밀기는 적어도 이만큼 잡고 간다 — 팩의 set 판정(u > 0.05)이 든다
const EPS := 0.000001

var cw: ClimbBarrow
var s: Dictionary         # 수레(climb_barrow.barrows 의 것 — 참조라 bx·dir·up·heap·sw·holder·me_t·near_t 를 같이 본다)
var hop: Dictionary       # step 의 on — 팩은 id 만 읽는다
var fig: Stick3D
var phase := "idle"       # idle | walk | right | gather | carry | shelve | turn | grip | push | set | back
var goal := ""            # walk 가 닿으면 할 일: right | gather | shelve | turn | grip
var since := 0.0
var next_at := 0.0        # 다음 혼자 보는 때(cw.t)
var seen_me := -99.0      # 따라간 플레이어의 me_t — 한 번에 한 번
var x := 0.0; var vx := 0.0; var zq := 0.0   # 자리(px), 걸음, 깊이(px, 카메라 쪽 +)
var face := 1.0           # 팩에 주는 보는 쪽(+1 오른쪽)
var home_x := 0.0; var target_x := 0.0; var px := 0.0
var a_x0 := 0.0; var a_x1 := 0.0   # 발판의 걷는 선(HW 안)
var gat_t := 0.0; var gat_n := 0; var scooped := 0; var gat_d := 0.0
var trips := 0; var puts := 0; var skips := 0; var rights := 0; var turns := 0   # 점검용
var trail: Array = []     # phase@t — 점검용

func _init(pack: ClimbBarrow, barrow: Dictionary, parent: Node3D) -> void:
	cw = pack; s = barrow
	hop = { "id": String(s["a_id"]) }
	px = float(s["px"])
	a_x0 = float(s["a_x"]) + C.HW; a_x1 = float(s["a_x"]) + float(s["a_w"]) - C.HW
	home_x = a_x0 if float(s["dir"]) > 0.0 else a_x1   # 틈 반대쪽 끝 — 자국 쪽
	x = home_x; zq = FRONT_Z
	next_at = cw.t + 30.0 + float(int(s["n"]) % 5) * 6.0   # 층마다 어긋나게 — 서재의 다섯 층이 한꺼번에 움직이지 않는다
	fig = Stick3D.new(); fig.color = Color("5a4a6b"); fig.head_color = Color("5a4a6b")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "page"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("5a4a6b"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	fig.face(0.0)
	_drive()

## 플레이어가 지금 수레·더미 곁에 서 있나 — 팩의 step 이 tally 참인 틱마다 적는 near_t
func player_near() -> bool:
	return cw.t - float(s.get("near_t", -99.0)) < NEAR_T

## 다른 몸이 이 수레를 잡고 있나
func player_holds() -> bool:
	return String(s["sw"]) != "" and not (is_instance_valid(s["holder"]) and (s["holder"] as Stick3D) == fig)

func dir() -> float:
	return float(s["dir"])

## 매 틱(climb_barrow._process — 팩의 HELD_T 판정보다 먼저라 잡은 수레의 step_t 가 늘 새롭다)
func step(delta: float) -> void:
	if not is_instance_valid(fig) or delta <= 0.0: return
	since += delta
	match phase:
		"idle":
			zq = move_toward(zq, FRONT_Z, 60.0 * delta)   # 집에서는 손잡이 앞(카메라 쪽)에
			var me := float(s.get("me_t", -99.0))
			if me > seen_me and cw.t - me >= REACT - EPS: seen_me = me; next_at = minf(next_at, cw.t)   # 플레이어가 손을 뗐다 — 따라 간다(제 분이 곁에서 넘겨졌어도 이건 따로 온다)
			if cw.t >= next_at:
				if player_near() or player_holds(): skips += 1; next_at = cw.t + MINUTE   # 플레이어가 수레 곁에 — 이번 분은 넘긴다
				elif not _trip(): _rest()
		"walk":
			if player_near() or player_holds(): _go("back")   # 플레이어가 수레로 왔다 — 플레이어가 먼저
			elif _walk(target_x, delta): _arrive()
		"right", "set":
			if not bool(_pack(false, false, delta)["busy"]): _after()
		"gather": _gather_tick(delta)
		"carry":
			var there := _walk(target_x, delta, cw.slow())
			fig.set_meta("gat_w", absf(vx) / (C.WALK * cw.slow()))
			if there: fig.set_meta("gat_w", 0.0); face = dir(); fig.face(PI / 2.0 if face > 0.0 else -PI / 2.0); gat_d = 0.0; _go("shelve")
		"shelve":
			gat_d = minf(1.0, gat_d + delta / GatherPoses.DROP_T); fig.set_meta("gat_d", gat_d)
			if gat_d >= 1.0: _shelve(); _end_gather(); _after()
		"turn":
			var r := _pack(false, false, delta)
			var q := PivotPoses.swing(fig); var o := _orbit()
			x = clampf(float(s["bx"]) - face * o * cos(PI * q), a_x0, a_x1); zq = face * o * sin(PI * q)   # 수레 가운데를 도는 호 — 반대쪽 손잡이 뒤에 닿는다(발판 끝이면 걷는 선 끝에)
			fig.face(atan2(float(s["bx"]) - x, -zq))
			if not bool(r["busy"]): face = dir(); _after()
		"grip":
			var r := _pack(false, true, delta)
			if bool(r["push"]): _go("push")
			elif not bool(r["busy"]): _go("back")   # 잡지 못했다(다른 손이 먼저) — 집으로
		"push":
			var there := _walk(target_x, delta, cw.slow_of(fig))
			var r := _pack(false, not there or since < MIN_HOLD, delta)
			if String(s["sw"]) == "set": _go("set")
			elif not bool(r["busy"]) and not bool(r["push"]): _go("back")   # 손을 놓았다(끝·틱 끊김) — 다음 분에 다시
		"back":
			if _walk(home_x, delta, 1.0, FRONT_Z): _rest()
	_drive()

## 수레를 보고 다음 할 일을 고른다 — 엎어졌으면 세우기, 더미가 있으면 모으기, 자국 밖이면 돌리기나 밀기(자국이 앞이면 민다), 돌아섰으면 돌리기; 다 됐으면 거짓
func _trip() -> bool:
	if String(s["sw"]) != "": return false
	var d := dir(); var bx := float(s["bx"])
	if bool(s["up"]): _walk_to(cw._wheel_x(s) - d * (cw.wheel_r() + C.HW + APPROACH), "right", d); return true
	if (s["heap"] as Array).size() > 0: _walk_to(float(s["heap_x"]) + d * (cw.heap_w() / 2.0 + C.HW + 2.0), "gather", -d); return true
	var on_mark := absf(bx - px) < 0.5
	if on_mark and d == float(s["dir0"]): return false
	var ahead := (px - bx) * d > 0.0
	_walk_to(cw._handle_x(s) - d * (C.HW + AHEAD), "grip" if (ahead and not on_mark) else "turn", d)
	return true

func _walk_to(tx: float, g: String, f: float) -> void:
	target_x = clampf(tx, a_x0, a_x1); goal = g; face = f; trips += 1; _go("walk")

## 걸어가 닿았다 — goal 대로
func _arrive() -> void:
	fig.face(PI / 2.0 if face > 0.0 else -PI / 2.0)
	match goal:
		"right":
			if bool(_pack(true, true, 0.0)["busy"]): rights += 1; _go("right")
			else: _go("back")
		"gather": _start_gather()
		"shelve": gat_d = 0.0; _go("shelve")
		"turn":
			if cw.turn(s, x, fig): turns += 1; fig.pose_request = "pivot"; _go("turn")
			else: _go("back")
		"grip":
			if bool(_pack(true, true, 0.0)["busy"]): target_x = clampf(px - dir() * (C.HW + AHEAD + cw.length() / 2.0), a_x0, a_x1); _go("grip")
			else: _go("back")

## 한 동작이 끝났다 — 플레이어가 왔으면 집으로, 아니면 다음 일(다 됐으면 자국 위에 세운 것: put_back)
func _after() -> void:
	if phase in ["turn", "set"] and absf(float(s["bx"]) - px) < 0.5 and dir() == float(s["dir0"]): _put_back()
	if player_near() or player_holds() or not _trip(): _go("back")

## target 까지 걷는다(플레이어의 WALK × k) — 닿으면 true; 보는 쪽은 걷는 쪽; 깊이는 zt 로(일할 땐 발판의 선 0, 집으로 갈 땐 FRONT_Z)
func _walk(target: float, dt: float, k := 1.0, zt := 0.0) -> bool:
	zq = move_toward(zq, zt, 60.0 * dt)
	var d := signf(target - x); var v := C.WALK * k
	if d == 0.0 or (target - x) * d <= v * dt:
		x = target; vx = 0.0; return true
	vx = d * v
	x += vx * dt; fig.face(PI / 2.0 if d > 0.0 else -PI / 2.0)
	return false

## 돌리는 호의 반지름(px) — 손잡이 끝 + 손 앞 HW + AHEAD
func _orbit() -> float:
	return cw.length() / 2.0 + C.HW + AHEAD

## 더미 곁에 무릎 꿇는다 — 권수만큼 퍼 올린다(gat_n), 손이 바닥에 닿는 틱마다 팩의 scoop
func _start_gather() -> void:
	gat_n = (s["heap"] as Array).size(); gat_t = 0.0; scooped = 0
	fig.set_meta("gat_t", 0.0); fig.set_meta("gat_n", gat_n); fig.pose_request = "gather"; _go("gather")

func _gather_tick(dt: float) -> void:
	gat_t += dt; fig.set_meta("gat_t", gat_t)
	while scooped < gat_n and gat_t >= GatherPoses.KNEEL_T + (float(scooped) + 0.5) * GatherPoses.SCOOP_T: _scoop(scooped); scooped += 1
	if gat_t >= GatherPoses.total(gat_n) - EPS:
		var d := dir()
		_walk_to(cw._tray_cx(s) - d * (cw.tray_w() / 2.0 + C.HW + 2.0), "shelve", d)   # 손잡이 쪽에서 통에 — 자세는 그대로 들고 걷는다(carry)
		_go("carry")

## 더미의 맨 위 책을 왼 팔뚝에(i 권째는 그 위에) — 몸(torso)의 자식, 팩의 hand 에; 손에 든 것이니 팩의 되돌림 시계는 끈다
func _scoop(i: int) -> void:
	var heap: Array = s["heap"]
	if heap.is_empty() or fig.torso == null: return
	var nd := heap.pop_back() as Node3D; (s["hand"] as Array).append(nd)
	ClimbBarrow._reparent(nd, fig.torso, Vector3(-0.05, 0.36 + 0.035 * float(i), 0.2)); nd.rotation = Vector3(0.0, 0.0, PI / 2.0)   # 눕혀 쌓는다
	s["righted_t"] = -1.0
	if heap.is_empty(): s["heap_x"] = 0.0

## 팔뚝의 책을 통에(남은 더미·잃은 것도 그때) — 팩의 _restock 그대로
func _shelve() -> void:
	for hv in (s["hand"] as Array): (s["heap"] as Array).append(hv)
	s["hand"] = []; cw._restock(s); s["righted_t"] = -1.0

## 자국 위에 바퀴가 틈을 보게 세웠다 — 오늘의 셈(팩의 top_today 가 읽는다), 판의 'the page brought it back N times'
func _put_back() -> void:
	if int(s["put_day"]) != cw.day(): s["put_day"] = cw.day(); s["day_puts"] = 0
	s["day_puts"] = int(s["day_puts"]) + 1; s["puts"] = int(s["puts"]) + 1; puts += 1

## gather 의 메타와 자세를 거둔다
func _end_gather() -> void:
	for key: String in ["gat_t", "gat_n", "gat_w", "gat_d"]:
		if fig.has_meta(key): fig.remove_meta(key)
	if fig.pose_request == "gather": fig.pose_request = ""

## 같은 step(tally 거짓) — 자세는 로더가 플레이어에게 하는 것과 같이 barrow(돌릴 땐 pivot)를 세우고 거둔다
func _pack(pressed: bool, held: bool, dt: float) -> Dictionary:
	var r := cw.step(hop, x, C.PLAYER_Z, face, pressed, held, dt, fig, false)
	if String(s["sw"]) == "turn" and cw.pushing(fig): fig.pose_request = "pivot"
	elif bool(r["busy"]) or bool(r["push"]): fig.pose_request = "barrow"
	elif fig.pose_request in ["barrow", "pivot"]: fig.pose_request = ""
	return r

## 집에서 카메라를 보고 선다 — 다음은 1분 뒤(또는 플레이어가 손을 뗀 뒤)
func _rest() -> void:
	vx = 0.0; fig.face(0.0); fig.pose_request = ""
	next_at = cw.t + MINUTE; _go("idle")

func _go(p: String) -> void:
	phase = p; since = 0.0; trail.append("%s@%.2f" % [p, cw.t])
	if trail.size() > 40: trail.pop_front()

## Stick3D 에 걸음과 자리를 — climb.gd 가 플레이어에게 하는 것과 같은 식(수레 노드의 원점 기준: 자국 px, a 윗면, PLAYER_Z); 뜀은 없다
func _drive() -> void:
	fig.airborne = false; fig.vertical = 0.0
	fig.move_dir = Vector3(signf(vx), 0.0, 0.0) if absf(vx) > 20.0 else Vector3.ZERO
	fig.speed = absf(vx) * C.K
	fig.position = Vector3((x - px) * C.K, 0.0, zq * C.K)
