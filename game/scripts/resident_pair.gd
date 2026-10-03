class_name ResidentPair
extends ResidentLife
## 둘이 함께 걷기("Walking in pairs" 1조각, run 95) — 친구 사이(명부의 friend 또는 정이 쌓여 relation_k 0.6 이상)인 둘이 8m 안에서 새 자리로 나서면,
## 넷에 한 번 나중에 고른 사람이 먼저 나선 사람의 목적지를 따라 0.6m 옆에서 나란히 걷는다. 앞사람은 조금 늦추고(×0.85) 뒤따르는 이가 걸음을 맞춘다.
## 바깥쪽(따라 걷는 이)은 몇 초마다 고개를 돌려 짝을 본다(Stick3D look_yaw). 닿으면 벤치면 옆 칸, 아니면 곁에 서서 짝이 일어날 때까지 함께 있다.
## 둘 중 누구든 맞으면 짝이 깨지고 둘 다 서서 마주 보고 bicker(PairPoses) — 맞는 것(움찔·넘어짐)은 예전 그대로이고, 다툼은 그 뒤에 온다(세 번째 변형이 아니다).
## 짝은 무작위로 맺지 않는다(관계가 정한다). 사슬: base → life → pair → resident. 아래 층(base.hit)은 call("_pair_hit") 으로 부른다

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

func _process(delta: float) -> void:
	super(delta)
	if state == "drive": return
	var now := Time.get_ticks_msec() / 1000.0
	if pair != null and pair_follow: _pair_tick(now)
	elif pair != null and not (state in ["walk", "busy"]): _unpair()
	if _bicker_with != null:
		var o := _bicker_with
		if state == "routine":
			_bicker_with = null
			if is_instance_valid(o) and o.global_position.distance_to(global_position) < 4.0: _bicker(o, now)
		elif not (state in ["busy", "down", "getup"]): _bicker_with = null   # 쫓거나 피하러 갔다 — 그게 먼저
