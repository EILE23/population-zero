class_name ClimbPorter
extends RefCounted
## 짐꾼 — 이삿짐 상자 팩(climb_crate.gd, run 182)의 주민 반쪽(run 183; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 더미마다 하나, 발판 a 의 틈 쪽 끝 HOME_IN 안에 카메라를 보고 선 주민 — 흩어진 상자를 분필 자리로 되돌리는 이("이사는 끝나지 않는다").
## 탑의 1분(MINUTE)마다 한 번(층마다 어긋나게), 그리고 플레이어의 더미가 max_stack 에 닿은(팩이 count 참일 때 me_t 에 적는다) REACT 초 뒤에: 분필 자리에서 가장 먼 더미 곁(APPROACH — 팩의 reach 안)으로 걸어가(walk, 플레이어의 WALK) 맨 위 상자를 재 보고(heft, stick3d_heft.gd — 숙여 밧줄 손잡이를 당기고 끄덕인다 0.8 s; 손잡이 높이를 heft_h 로),
## 같은 step(tally 거짓 — 제 쌓기는 판의 날에 안 세고 me_t 도 안 적는다)으로 들어(lift — 같은 lift_s, 같은 lug) 안고 분필 자리 곁으로 걸어가(carry — 같은 slow) 내려놓는다(set — 같은 set_s, 분필 더미 위에 맞춰 쌓인다); 더미가 다 돌아올 때까지 한 번에 하나(trip), 그 뒤 집으로 걸어가(back) 카메라를 본다.
## 플레이어가 더미 곁 NEAR 안에 서 있으면(팩의 step 이 tally 참인 틱에 near_t 에 적는다) 또는 상자를 안고 있으면 집에서 기다린다 — 제 분은 나르기 없이 지나고(skips), 걸어가던·재 보던 중이면 돌아온다(플레이어의 더미는 둔다); 손에 든 상자는 끝까지 나른다(반쯤 나른 상자를 두지 않는다).
## 분필 더미가 받지 않으면(자료가 count > max_stack 일 때만 — 지금 자료는 3·3) 안은 채 집으로 가 다음 분에 다시 분필 자리로 간다 — 손에서 놓치는 일은 없다.
## 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 마을의 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 mind 는 아직 없다). 노드는 더미의 노드(원점: 분필 자리 px, a 윗면, PLAYER_Z) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_crate.gd 의 PORTER·HEFT 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 혼자서도 이만큼마다 한 번 나른다
const REACT := 2.0        # 플레이어의 더미가 다 쌓인 뒤 이만큼 있다 간다 — 마지막 thud 를 듣는 사이
const HOME_IN := 20.0     # 틈 쪽 끝 안쪽 이만큼에 선다(px) — 몸 하나 뒤(2 HW)
const APPROACH := 4.0     # 더미 곁에 설 때 HW + w/2 에 더하는 여유(px) — reach(14) 안
const NEAR_T := 0.2       # 플레이어를 마지막으로 더미 곁에 본 뒤 이만큼은 가까운 것(s) — 팩은 선 틱마다 알린다
const HANDS_Y := 1.0      # heft_h 가 1 이 되는 손잡이 높이(m) — 가슴
const EPS := 0.000001     # 시계 비교의 여유

var cc: ClimbCrate
var s: Dictionary         # 더미(climb_crate.piles 의 것 — 참조라 stacks·sw·holder·me_t·near_t 를 같이 본다)
var hop: Dictionary       # step 의 on — 팩은 id 만 읽는다
var fig: Stick3D
var phase := "idle"       # idle | walk | heft | lift | carry | set | back
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0        # 다음 혼자 나르는 때(cc.t)
var seen_me := -99.0      # 따라간 플레이어의 me_t — 한 쌓기에 한 번
var x := 0.0; var vx := 0.0
var face := 1.0           # 들고 놓을 때 보는 쪽(+1 오른쪽) — 분필 자리 쪽
var home_x := 0.0; var target_x := 0.0; var px := 0.0
var a_x0 := 0.0; var a_x1 := 0.0   # 발판의 걷는 선(HW 안)
var heft_t := 0.0         # heft 에 든 뒤 시간 — 메타 heft_t 로 자세에
var trips := 0; var puts := 0; var skips := 0; var hefts: Array = []   # 점검용 — hefts 는 재 본 손잡이 높이들
var trail: Array = []     # phase@t — 점검용

func _init(pack: ClimbCrate, pile: Dictionary, parent: Node3D) -> void:
	cc = pack; s = pile
	hop = { "id": String(s["a_id"]) }
	px = float(s["px"])
	a_x0 = float(s["a_x"]) + C.HW; a_x1 = float(s["a_x"]) + float(s["a_w"]) - C.HW
	home_x = clampf(a_x1 - HOME_IN if float(s["dir"]) > 0.0 else a_x0 + HOME_IN, a_x0, a_x1)   # 틈 쪽 끝 — 분필 자리의 반대쪽
	x = home_x
	next_at = cc.t + 30.0 + float(int(s["n"]) % 5) * 6.0   # 층마다 어긋나게 — 옛 홀의 네 층이 한꺼번에 나르지 않는다
	fig = Stick3D.new(); fig.color = Color("7a5c48"); fig.head_color = Color("7a5c48")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "porter"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("7a5c48"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	fig.face(0.0)
	_drive()

## 플레이어가 지금 더미 곁에 서 있나 — 팩의 step 이 tally 참인 틱마다 적는 near_t
func player_near() -> bool:
	return cc.t - float(s.get("near_t", -99.0)) < NEAR_T

## 다른 몸이 이 더미의 상자를 안고 있나(들기·안기·내려놓기·미끄러짐)
func player_lugs() -> bool:
	return String(s["sw"]) != "" and not (is_instance_valid(s["holder"]) and (s["holder"] as Stick3D) == fig)

## 매 틱(climb_crate._process — 팩의 HELD_T 판정보다 먼저라 안은 상자의 step_t 가 늘 새롭다)
func step(delta: float) -> void:
	if not is_instance_valid(fig) or delta <= 0.0: return
	since += delta
	match phase:
		"idle":
			var me := float(s.get("me_t", -99.0))
			if me > seen_me and cc.t - me >= REACT - EPS: seen_me = me; next_at = minf(next_at, cc.t)   # 플레이어가 다 쌓았다 — 따라 나른다
			if cc.t >= next_at:
				seen_me = me
				if player_near() or player_lugs(): skips += 1; next_at = cc.t + MINUTE   # 플레이어가 더미 곁에 — 이번 분은 넘긴다
				elif cc.lugging(fig): _carry_on()   # 지난번에 못 놓은 상자가 손에 — 분필 자리로 다시
				elif not _trip(): _rest()
		"walk":
			if player_near() or player_lugs(): _go("back")   # 플레이어가 더미로 왔다 — 플레이어의 더미가 먼저
			elif _walk(target_x, delta): _heft()
		"heft":
			if player_near() or player_lugs(): _end_heft(); _go("back")
			else: _heft_tick(delta)
		"lift":
			var r := _pack(false, delta)
			if bool(r["lug"]): _carry_on()
			elif not bool(r["busy"]): _go("back")   # 상자가 손에 없다(팩이 거뒀다) — 집으로
		"carry":
			var there := _walk(target_x, delta, cc.slow())
			if there: fig.face(PI / 2.0 if face > 0.0 else -PI / 2.0)   # 분필 자리를 보고 내려놓는다
			var r := _pack(there, delta)
			if not bool(r["lug"]) and not bool(r["busy"]): _go("back")   # 미끄러졌다(없던 일) — 집으로
			elif there: _go("set" if String(s["sw"]) == "set" else "back")   # 받지 않으면 안은 채 집으로 — 다음 분에 다시
		"set":
			var r := _pack(false, delta)
			if not bool(r["busy"]) and not bool(r["lug"]):
				puts += 1; cc.put_back(s)
				if player_near() or player_lugs() or not _trip(): _go("back")
		"back":
			if cc.lugging(fig): _pack(false, delta)   # 안은 채 걷는다(받지 않은 상자) — step 이 끊기면 팩이 상자를 굴린다
			if _walk(home_x, delta, cc.slow() if cc.lugging(fig) else 1.0): _rest()
	_drive()

## 분필 자리에서 가장 먼 더미(상자 있는 것, 분필 더미는 빼고)로 — 없거나 분필 더미가 꽉 찼으면 거짓
func _trip() -> bool:
	var pile: Dictionary = (s["stacks"] as Array)[0]
	if int(pile["n"]) >= cc.max_stack(): return false
	var best: Dictionary = {}; var best_d := -1.0
	for kv in (s["stacks"] as Array):
		var k: Dictionary = kv
		if int(k["n"]) <= 0 or String(k["id"]) == String(pile["id"]): continue
		var d := absf(float(k["x"]) - px)
		if d > best_d: best = k; best_d = d
	if best.is_empty(): return false
	var sx := float(best["x"]); var toward := 1.0 if px >= sx else -1.0   # 더미에서 분필 자리 쪽
	var stand := C.HW + cc.w() / 2.0 + APPROACH
	var side := toward if best_d - stand > C.HW + cc.w() / 2.0 + cc.reach() else -toward   # 분필 더미가 손 닿는 데면 반대쪽에서 집는다 — _nearest 가 분필 더미를 잡지 않게
	target_x = clampf(sx + side * stand, a_x0, a_x1); face = -side
	trips += 1; _go("walk")
	return true

## target 까지 걷는다(플레이어의 WALK × k) — 닿으면 true; 보는 쪽은 걷는 쪽
func _walk(target: float, dt: float, k := 1.0) -> bool:
	var d := signf(target - x); var v := C.WALK * k
	if d == 0.0 or (target - x) * d <= v * dt:
		x = target; vx = 0.0; return true
	vx = d * v
	x += vx * dt; fig.face(PI / 2.0 if d > 0.0 else -PI / 2.0)
	return false

## 맨 위 상자를 재 본다 — 더미를 보고 서서 heft(손잡이 높이를 heft_h 로: 더미 n 의 맨 위 상자의 손잡이)
func _heft() -> void:
	var n := 0
	for kv in (s["stacks"] as Array):
		var k: Dictionary = kv
		if int(k["n"]) > 0 and absf(float(k["x"]) - x) <= C.HW + cc.w() / 2.0 + cc.reach(): n = maxi(n, int(k["n"]))
	var hy := (float(n - 1) * cc.h() + cc.h() * 0.15) * C.K   # 맨 위 상자의 밧줄 손잡이(climb_crate._crate: 상자 높이의 0.15)
	var hh := clampf(hy / HANDS_Y, 0.0, 1.0); hefts.append(hh)
	heft_t = 0.0; fig.set_meta("heft_t", 0.0); fig.set_meta("heft_h", hh)
	fig.face(PI / 2.0 if face > 0.0 else -PI / 2.0); fig.pose_request = "heft"; _go("heft")

## 재 보기의 시계 — 메타 heft_t 를 적고, 다 하면 든다
func _heft_tick(dt: float) -> void:
	heft_t += dt; fig.set_meta("heft_t", heft_t)
	if heft_t >= HeftPoses.TOTAL - EPS:
		_end_heft()
		if bool(_pack(true, dt)["busy"]): _go("lift")
		else: _go("back")   # 그새 상자가 없어졌다(플레이어가 들었다) — 집으로

## heft 의 메타와 자세를 거둔다
func _end_heft() -> void:
	for key: String in ["heft_t", "heft_h"]:
		if fig.has_meta(key): fig.remove_meta(key)
	if fig.pose_request == "heft": fig.pose_request = ""

## 안은 상자를 분필 자리 곁으로 — 거기서 분필 자리를 보고 내려놓으면 팩이 분필 더미 위에 맞춘다(_set_down: x + face·(HW + 2 + w/2) 가 px)
func _carry_on() -> void:
	face = 1.0 if px >= x else -1.0
	target_x = clampf(px - face * (C.HW + 2.0 + cc.w() / 2.0), a_x0, a_x1)
	_go("carry")

## 같은 step(tally 거짓) — 자세는 로더가 플레이어에게 하는 것과 같이 lug 를 세우고 거둔다
func _pack(pressed: bool, dt: float) -> Dictionary:
	var r := cc.step(hop, x, C.PLAYER_Z, face, pressed, dt, fig, false)
	if bool(r["busy"]) or bool(r["lug"]): fig.pose_request = "lug"
	elif fig.pose_request == "lug": fig.pose_request = ""
	return r

## 집에서 카메라를 보고 선다 — 다음은 1분 뒤(또는 플레이어의 쌓기 뒤)
func _rest() -> void:
	vx = 0.0; fig.face(0.0)
	if not cc.lugging(fig): fig.pose_request = ""
	next_at = cc.t + MINUTE; _go("idle")

func _go(p: String) -> void:
	phase = p; since = 0.0; trail.append("%s@%.2f" % [p, cc.t])
	if trail.size() > 40: trail.pop_front()

## Stick3D 에 걸음과 자리를 — climb.gd 가 플레이어에게 하는 것과 같은 식(더미 노드의 원점 기준: 분필 자리 px, a 윗면, PLAYER_Z); 뜀은 없다
func _drive() -> void:
	fig.airborne = false; fig.vertical = 0.0
	fig.move_dir = Vector3(signf(vx), 0.0, 0.0) if absf(vx) > 20.0 else Vector3.ZERO
	fig.speed = absf(vx) * C.K
	fig.position = Vector3((x - px) * C.K, 0.0, 0.0)
