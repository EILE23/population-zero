class_name ResidentPair
extends ResidentLife
## 둘이 함께 걷기("Walking in pairs" 1조각, run 95) — 친구 사이(명부의 friend 또는 정이 쌓여 relation_k 0.6 이상)인 둘이 8m 안에서 새 자리로 나서면,
## 넷에 한 번 나중에 고른 사람이 먼저 나선 사람의 목적지를 따라 0.6m 옆에서 나란히 걷는다. 앞사람은 조금 늦추고(×0.85) 뒤따르는 이가 걸음을 맞춘다.
## 바깥쪽(따라 걷는 이)은 몇 초마다 고개를 돌려 짝을 본다(Stick3D look_yaw). 닿으면 벤치면 옆 칸, 아니면 곁에 서서 짝이 일어날 때까지 함께 있다.
## 둘 중 누구든 맞으면 짝이 깨지고 둘 다 서서 마주 보고 bicker(PairPoses) — 맞는 것(움찔·넘어짐)은 예전 그대로이고, 다툼은 그 뒤에 온다(세 번째 변형이 아니다).
## 짝은 무작위로 맺지 않는다(관계가 정한다). 사슬: base → life → pair → resident. 아래 층(base.hit)은 call("_pair_hit") 으로 부른다
## 2조각(run 96): 다툰 둘은 90초 동안 서로 토라져 있다(sulk). 하나가 벤치에 앉아 있고 다른 하나가 6m 안에서 한가하면 와서 옆 칸에 앉고,
## 둘이 고개를 돌려 한숨 → 끄덕(makeup, PairPoses) — 정이 0.05 오르고 토라짐이 풀린다. 사람의 C(인사)는 토라진 한쪽을 상대에게 보낼 뿐이다("Go on.") —
## 성미가 급한(temper > 0.7) 상대는 그래도 거절할 수 있다. 억지로 짝을 맺는 길은 없다(base.greet 가 call("_nudge"))

const PAIR_KINDS := ["bench", "lamp", "tree", "lookout", "grass", "bank", "door"]   # 바깥 자리만 — 집 안(문 열기)·나루·일터·놀이기구는 둘이 나란히 못 간다
const SIDE := 0.6
const PAIR_CHANCE := 0.25

var pair: ResidentPair = null   # 지금 나란히 걷는 짝
var pair_follow := false        # 내가 따라 걷는 쪽(바깥)인가
var pair_side := 1.0            # 앞사람 진행 방향의 어느 쪽에 서는가(+1 / -1)
var pace := 1.0                 # 걸음 배율(resident.gd walk) — 짝과 맞춘다
var _pair_cool := 0.0           # 다툰 뒤 90초는 다시 짝을 맺지 않는다(2조각의 sulk 자리)
var _bicker_with: ResidentPair = null   # 맞은 쪽: 움찔·일어나기가 끝나면 이 사람과 다툰다
var _homing := false            # 앞사람이 닿았다 — 따라 걷던 이는 제 끝점으로
var _caught := false            # 한 번은 옆에 붙었다(그 뒤에 3m 처지면 짝이 풀린다)
var sulk_with: ResidentPair = null   # 다툰 상대(2조각) — sulk_until 까지 토라져 있다
var sulk_until := 0.0
var _mending: ResidentPair = null    # 화해하러 가는 중 — 그 사람 벤치 옆 칸이나 그 사람 앞으로
var _mend_until := 0.0               # 그때까지 못 닿으면 그만둔다(움직이는 목표라 막힘 판정을 끈다)
var _nudged := false                 # 사람이 등을 떠밀어 간 길 — 이때만 상대가 거절할 수 있다

## 자리 고르기 앞(resident.gd _pick_spot): 8m 안에서 막 바깥 자리로 나선 친구가 있으면 넷에 한 번 그 목적지로 함께 간다
func _pair_pick(now: float, chance := PAIR_CHANCE) -> bool:
	if pair != null: _unpair()
	if now < _pair_cool or weather == "rain" or has_umb or carrying_kind == "log" or randf() >= chance: return false
	for o in town.residents:
		var b := o as ResidentPair
		if b == null or b == self or b.pair != null or b.state != "walk" or b.in_boat or now < b._pair_cool or b.route.is_empty(): continue
		if not (String(b.spot.get("kind", "")) in PAIR_KINDS) or b.global_position.distance_to(global_position) > 8.0: continue
		if mind.relation_k(b) < 0.6 or b.route.any(func(st: Dictionary) -> bool: return st.get("act", "") != ""): continue
		var dest: Vector3 = b.route[b.route.size() - 1]["pos"]
		if dest.distance_to(b.global_position) < 4.0: continue   # 거의 다 왔으면 함께 걸을 길이 없다
		_pair_up(b, dest, now)
		return true
	return false

func _pair_up(b: ResidentPair, dest: Vector3, now: float) -> void:
	_release()
	var fwd := dest - b.global_position; fwd.y = 0.0; fwd = fwd.normalized()
	var side := Vector3(-fwd.z, 0, fwd.x)
	pair_side = 1.0 if (global_position - b.global_position).dot(side) >= 0.0 else -1.0   # 지금 서 있는 쪽에 선다 — 앞을 가로지르지 않게
	var end := dest + side * pair_side * SIDE
	spot = { "kind": "pair", "pos": end, "yaw": atan2(dest.x - end.x, dest.z - end.z) }   # 닿으면 짝 쪽을 본다(resident.gd _arrive 의 기본 갈래)
	var bsp: Dictionary = b.spot
	if bsp["kind"] == "bench":
		var i := _free_slot(bsp)
		if i >= 0: spot = bsp; slot = i; _claim(bsp, i); end = bsp["pos"] + Vector3([-0.45, 0.0, 0.45][i], 0, 0.45)   # 같은 벤치 옆 칸에 앉는다
	route = town.via_bridge(global_position, [{ "pos": end, "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now; fig.pose_request = ""
	pair = b; pair_follow = true; _homing = false; _caught = false
	b.pair = self; b.pair_follow = false; b.pace = 0.85
	if randf() < 0.5: say(mind.line("pair_walk"), 1.6)

func _unpair() -> void:
	var o := pair
	_pair_drop()
	if o != null and o.pair == self: o._pair_drop()

## 짝을 놓는다 — 따라 걷던 중이면 덮어쓰던 목표를 제 끝점으로 되돌린다(안 그러면 낡은 목표에 닿아 경유지를 하나 건너뛴다)
func _pair_drop() -> void:
	if pair_follow and state == "walk" and not route.is_empty(): route = [route[route.size() - 1]]; target = route[0]["pos"]
	pair = null; pair_follow = false; pace = 1.0; fig.look_yaw = 0.0

## 따라 걷는 이가 매 프레임: 앞사람 옆 0.6m 에서 1m 앞을 겨냥하고(닿음 판정에 안 걸리게) 앞뒤 차이만큼 걸음을 맞춘다. 앞사람이 닿으면 제 끝점으로, 함께 머문다
func _pair_tick(now: float) -> void:
	var b := pair
	if not is_instance_valid(b) or b.pair != self or not (String(b.spot.get("kind", "")) in PAIR_KINDS):
		_unpair(); return
	var mine: String = spot.get("kind", "")
	if state == "walk" and b.state == "walk" and not _homing:
		var fwd := b.target - b.global_position; fwd.y = 0.0
		if fwd.length() < 0.05: return
		fwd = fwd.normalized()
		var at := b.global_position + Vector3(-fwd.z, 0, fwd.x) * pair_side * SIDE
		var gap := global_position.distance_to(at)
		if gap < 1.0: _caught = true
		elif gap > 3.0 and _caught: _unpair(); return   # 나란히 걷다 막혀 처졌다 — 각자 간다(처음 8m 를 따라잡는 동안은 아니다)
		target = at + fwd * 1.0; stuck_since = -1.0   # 움직이는 목표라 '못 다가갔다'로 읽히면 헛우회한다 — 막힘은 앞사람이 판단한다
		pace = clampf(b.pace - (global_position - at).dot(fwd) * 0.8, 0.6, 1.3)   # 뒤처지면 서두르고 앞서면 늦춘다
	elif state == "walk" and b.state == "busy":
		if not _homing:
			_homing = true; pace = 1.0
			if not route.is_empty(): route = [route[route.size() - 1]]; target = route[0]["pos"]   # 건너온 다리 경유지는 이미 지났다 — 끝점만
	elif state == "busy" and b.state == "busy" and (mine == "pair" or mine == "bench"):
		busy_until = maxf(busy_until, minf(b.busy_until, now + 20.0))   # 짝이 일어날 때까지 곁에
	else:
		_unpair(); return
	# 바깥쪽이 3.5초에 한 번 1.2초쯤 짝을 돌아본다
	var look := fmod(now + float(uid) * 0.7, 3.5) < 1.2
	var to := b.global_position - global_position
	fig.look_yaw = clampf(wrapf(atan2(to.x, to.z) - fig.rotation.y, -PI, PI), -1.0, 1.0) if look else 0.0

## 맞았다(resident_base.hit 이 부른다): 짝이 깨진다. 짝은 곧장, 나는 움찔·일어나기가 끝나면 다툰다
func _pair_hit() -> void:
	if pair == null: return
	var o := pair
	var now := Time.get_ticks_msec() / 1000.0
	_unpair()
	_bicker_with = o; _pair_cool = now + 90.0
	sulk_with = o; sulk_until = now + 90.0; o.sulk_with = self; o.sulk_until = now + 90.0   # 둘 다 토라진다 — 짝 다시 맺기 쿨다운과 같은 90초
	if o.state in ["walk", "busy", "routine"] and not o.in_boat and o.riding_swing.is_empty() and o.riding_seesaw == null: o._bicker(self, now)

## 다툼 한 번 — 서서 마주 보고 bicker(BICKER_T), 한마디. 끝나면 busy 가 풀려(_leave) 각자 제 갈 길로
func _bicker(o: ResidentPair, now: float) -> void:
	if state == "busy":
		call("_leave")
		if state == "walk": return   # _leave 가 집 문으로 걷게 했다 — 다툼은 밖에서만
	else: _release()
	state = "busy"; spot = { "kind": "bicker" }; busy_until = now + PairPoses.BICKER_T + 0.2
	fig.seated = false; fig.pose_request = "bicker"; collision_layer = 4; collision_mask = 7
	fig.face(atan2(o.global_position.x - global_position.x, o.global_position.z - global_position.z))
	_pair_cool = now + 90.0
	say(mind.line("bicker"), 1.6)

func _sulking(now: float) -> bool:
	return sulk_with != null and is_instance_valid(sulk_with) and now < sulk_until and sulk_with.sulk_with == self

## 벤치에 앉은 나 — 바로 옆 칸이 비었나(사람이 앉은 칸도 찬 자리)
func _slot_beside() -> int:
	var taken: Array = spot.get("taken", [])
	for i: int in [slot - 1, slot + 1]:
		if i < 0 or i > 2 or (i < taken.size() and taken[i] != null) or _player_on(spot, i): continue
		return i
	return -1

## 화해하러 간다: 상대가 벤치에 앉아 있고 옆 칸이 비었으면 거기 앉으러, 아니면 그 사람 앞까지(따라가며)
func _go_mend(o: ResidentPair, now: float) -> void:
	if pair != null: _unpair()
	_release()
	_mending = o; _mend_until = now + 20.0; pace = 1.0; fig.pose_request = ""; fig.seated = false; busy_until = now
	var bi := o._slot_beside() if o.state == "busy" and o.fig.seated and String(o.spot.get("kind", "")) == "bench" else -1
	if bi >= 0:
		spot = o.spot; slot = bi; _claim(spot, bi)
		route = town.via_bridge(global_position, [{ "pos": spot["pos"] + Vector3([-0.45, 0.0, 0.45][bi], 0, 0.45), "act": "" }])
	else:
		spot = { "kind": "mend", "pos": o.global_position }
		route = [{ "pos": o.global_position, "act": "" }]
	target = route[0]["pos"]; state = "walk"

## 사람의 C(인사) — 토라진 한쪽이면 인사 대신 상대에게 보낸다. 집 안·배·그네 위는 아니다(인사로 처리)
func _nudge(now: float) -> bool:
	if not _sulking(now) or _mending != null or in_boat or not riding_swing.is_empty() or riding_seesaw != null: return false
	var o := sulk_with
	if o.state in ["down", "getup", "chase", "drive"] or o.in_boat or o.global_position.distance_to(global_position) > 12.0: return false
	if String(spot.get("kind", "")) in ["chair", "bed", "shelf", "stove"] or (state == "walk" and route.any(func(st: Dictionary) -> bool: return st.get("act", "") != "")): return false
	town.call("say_toast", "Go on.")
	if state == "busy": call("_leave")
	_go_mend(o, now); _nudged = true
	say(mind.line("go_on"), 1.6)
	return true

## 화해하러 가는 이가 매 프레임: 벤치면 앉으면 끝, 아니면 상대를 따라가 1.3m 안이면 끝. 맞거나 쫓거나 상대가 일어나면 그만(토라짐은 남는다)
func _mend_tick(now: float) -> void:
	var o := _mending
	var kind := String(spot.get("kind", ""))
	if not is_instance_valid(o) or now > _mend_until or not (state in ["walk", "busy"]) or not (o.state in ["walk", "busy", "routine"]) or not (kind in ["mend", "bench"]):
		_mending = null; _nudged = false; return
	if kind == "bench":
		if not is_same(o.spot, spot) or not o.fig.seated: _mending = null; _nudged = false; return   # 그새 일어났다 — 앉는 건 그대로, 화해는 아니다
		if state == "busy": _reconcile(o, now)   # 앉았다(닿자마자 옆 사람과 수다로 붙잡혀 서 있어도 — 거기서 화해한다)
		return
	var to := global_position - o.global_position; to.y = 0.0
	if to.length() < 1.3: _reconcile(o, now); return
	if state == "walk":
		target = o.global_position + to.normalized() * 0.8; route = [{ "pos": target, "act": "" }]; stuck_since = -1.0

## 화해 한 번 — 둘 다 서로를 보고 makeup(한숨 → 끄덕 → 손바닥), 정 +0.05, 토라짐과 짝 쿨다운이 풀린다. 등 떠밀려 온 길이면 성미 급한 상대는 거절
func _reconcile(o: ResidentPair, now: float) -> void:
	if _nudged and o.mind.temper > 0.7:
		_mending = null; _nudged = false
		if state != "busy": _release(); state = "busy"; spot = { "kind": "mend" }; route = []; busy_until = now + 1.5
		if not o.fig.seated: o.fig.face(atan2(o.global_position.x - global_position.x, o.global_position.z - global_position.z))   # 등을 돌린다
		o.say(o.mind.line("sulk"), 1.8)
		return
	for pr in [[self, o], [o, self]]:
		var a: ResidentPair = pr[0]; var b: ResidentPair = pr[1]
		a._mending = null; a._nudged = false; a.sulk_with = null; a._pair_cool = now; a.mind.befriend(b, 0.05)
		if a.fig.pose_request in ["share", "pass"]: continue   # 앉자마자 반씩 나누는 중(run 85) — 그게 화해다
		if a.state != "busy":
			a._release(); a.state = "busy"; a.spot = { "kind": "mend" }; a.route = []
		var yaw := atan2(b.global_position.x - a.global_position.x, b.global_position.z - a.global_position.z)
		if a.fig.seated: a.fig.look_yaw = clampf(wrapf(yaw - a.fig.rotation.y, -PI, PI), -1.0, 1.0)   # 앉은 이는 몸 대신 고개만
		else: a.fig.face(yaw)
		a.fig.pose_request = "makeup"; a.busy_until = maxf(a.busy_until, now + PairPoses.MAKEUP_T + (4.0 if a.fig.seated else 0.4))   # 앉은 둘은 조금 더 같이 앉아 있다
	say(mind.line("made_up"), 1.8)

## 토라진 동안: 내가 벤치에 앉아 있고 상대가 6m 안에서 한가하면(돌아다니거나 고르는 중) 상대가 옆 칸으로 온다
func _sulk_tick(now: float) -> void:
	if not _sulking(now):
		sulk_with = null; _mending = null; _nudged = false; return
	if _mending != null: _mend_tick(now); return
	var o := sulk_with
	if state != "busy" or not fig.seated or String(spot.get("kind", "")) != "bench" or o._mending != null or o.pair != null or o.in_boat: return
	if not (o.state in ["routine", "walk"]) or o.global_position.distance_to(global_position) > 6.0: return
	if o.state == "walk" and o.route.any(func(st: Dictionary) -> bool: return st.get("act", "") != ""): return   # 문·나루를 지나는 길은 끊지 않는다
	if _slot_beside() >= 0: o._go_mend(self, now)

func _process(delta: float) -> void:
	super(delta)
	if state == "drive": return
	var now := Time.get_ticks_msec() / 1000.0
	if pair != null and pair_follow: _pair_tick(now)
	elif pair != null and not (state in ["walk", "busy"]): _unpair()
	if sulk_with != null: _sulk_tick(now)
	if pair == null and fig.look_yaw != 0.0 and fig.pose_request != "makeup": fig.look_yaw = 0.0   # 화해하며 돌린 고개를 되돌린다
	if _bicker_with != null:
		var o := _bicker_with
		if state == "routine":
			_bicker_with = null
			if is_instance_valid(o) and o.global_position.distance_to(global_position) < 4.0: _bicker(o, now)
		elif not (state in ["busy", "down", "getup"]): _bicker_with = null   # 쫓거나 피하러 갔다 — 그게 먼저
