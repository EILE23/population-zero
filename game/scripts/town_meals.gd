class_name TownMeals
extends TownRide
## 나눠 먹기("Sharing food", 열네 번째로 마을이 짠 체계 — run 85): 벤치에 앉기와 먹을 걸 쪼개 옆 사람에게 건네기.
## 사람도 주민도 같은 규칙·같은 share 자세(stick3d_poses). 주민 쪽은 resident_life._share — 둘 다 여기 split_food 로 쪼갠다.

var shared_once := false   # 처음 한 번만 알림(say_toast) — 그 뒤로는 놀이로 배운다

## 벤치에 앉기 — 세 자리(왼·가운데·오른쪽) 중 주민이 안 앉은 칸에서 지금 선 곳에 가장 가까운 자리. 가운데만 고집하지 않고, 주민 무릎 위에도 앉지 않는다(town_player 에서 옮겨 왔다)
func sit_bench(b: Dictionary) -> bool:
	var taken: Array = []
	for sp in spots:
		if sp["kind"] == "bench" and sp["pos"] == b["pos"]: taken = sp.get("taken", []); break
	var best_slot: Vector3 = b["pos"]; var bd := 99.0
	for i in 3:
		if i < taken.size() and taken[i] != null: continue
		var off: float = [-0.45, 0.0, 0.45][i]
		var slot: Vector3 = b["pos"] + Vector3(cos(b["yaw"]) * off, 0, -sin(b["yaw"]) * off)
		var d := body.global_position.distance_to(slot)
		if d < bd: bd = d; best_slot = slot
	if bd == 99.0: return false   # 꽉 찬 벤치
	seat = b
	player.seated = true
	player.move_dir = Vector3.ZERO; player.speed = 0.0
	body.velocity = Vector3.ZERO
	var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(body, "position", best_slot + Vector3(0, 0.05, 0.02), 0.35)  # 순간이동 대신 미끄러져 앉는다
	player.face(b["yaw"])
	return true

## 먹을 걸 들고 벤치 앞(1m)에서 C = 먼저 앉는다 — 앉아서 먹어야 옆 사람과 나눌 수 있다. 다음 C 부터는 앉은 채 먹는다(빈 벤치면 그냥 앉아 먹는 것)
func sit_with_food(p: Vector3) -> bool:
	for b in benches:
		if p.distance_to(b["pos"]) < 1.0 and sit_bench(b):
			if not shared_once: say_toast("Sit. Anyone beside you gets half.")
			return true
	return false

## 앉은 벤치가 이 자리(spot pos)인가 — 주민이 옆 칸의 사람을 찾을 때
func seat_at(at: Vector3) -> bool:
	return not seat.is_empty() and not seat.has("chair") and (seat["pos"] as Vector3).distance_to(at) < 0.1

## 옆 사람이 내 어느 쪽 어깨 쪽인가(±1 — stick_rig 의 side) — 몸이 보는 방향(yaw) 기준의 옆 거리 부호
static func share_side(yaw: float, from: Vector3, to: Vector3) -> float:
	var d := to - from
	return 1.0 if d.x * cos(yaw) - d.z * sin(yaw) >= 0.0 else -1.0

## 쪼개기: 든 것이 한 입 줄고(0.27), 같은 크기의 반쪽이 하나 생긴다. 한 입 남은 건 못 쪼갠다(null). 한입 수는 물건에 붙는다(사람의 먹기와 같은 meta "bites")
func split_food(it: Node3D) -> Node3D:
	var b := int(it.get_meta("bites", 0)) + 1
	if b >= 3: return null
	it.set_meta("bites", b); it.scale = Vector3.ONE * (1.0 - b * 0.27)
	var half := make_item(String(it.get_meta("kind", "")), Vector3.ZERO)
	half.set_meta("bites", b); half.scale = it.scale
	return half

## 사람이 앉아 먹을 걸 들고 C: 같은 벤치 옆 칸에 빈손으로 앉은 주민이 있으면 먹기 전에 반을 건넨다(share). 없으면 false — 그냥 먹는다
func share_on_bench(now: float) -> bool:
	var food := player.carrying
	if seat.is_empty() or seat.has("chair") or food == null or not (String(food.get_meta("kind", "")) in FOOD) or int(food.get_meta("bites", 0)) >= 2: return false
	for r in residents:
		if r.state != "busy" or not r.fig.seated or r.fig.carrying != null or r.bites > 0 or String(r.spot.get("kind", "")) != "bench": continue
		if not seat_at(r.spot["pos"]) or r.global_position.distance_to(body.global_position) > 1.2: continue
		player.set_meta("share_side", share_side(seat.get("yaw", 0.0), body.global_position, r.global_position))
		player.pose_request = "share"; use_until = now + StickPoses.SHARE_T; action_until = now + StickPoses.SHARE_T
		get_tree().create_timer(StickPoses.SHARE_HAND).timeout.connect(func() -> void: _hand_half(r))
		return true
	return false

func _hand_half(r: ResidentBase) -> void:
	if player.pose_request != "share" or player.carrying == null or not is_instance_valid(r) or not r.fig.seated or r.fig.carrying != null or r.state != "busy" or r.spot.get("kind", "") != "bench" or not seat_at(r.spot.get("pos", Vector3.INF)): return   # 그새 일어났거나(맞았거나) 손이 찼다 — 안 쪼갠다
	var half := split_food(player.carrying)
	if half: r.take_half(half, body); shared_once = true

## 주민이 반을 건넨다(resident_life._share) — 앉은 사람 손에. 그 뒤 C 두 번이면 다 먹는다
func take_share(half: Node3D, from: ResidentBase) -> void:
	player.hold(half)
	if not shared_once: say_toast(from.handle + " shared. C to eat.")
	shared_once = true

## 건네기("Sharing food" 2조각, run 86): 쪼개지 않고 통째로 옆 칸에 넘긴다 — 컵도(쪼갤 수 없는 것). 같은 벤치 옆 칸(0.6m 안)에 앉은 빈손의 주민이나 사람
static func passable(kind: String) -> bool:
	return kind in FOOD or kind == "cup"

## 이 벤치에 앉은 사람들(주민 + 사람) — 줄을 따라 넘길 때 몇이 앉았나·누가 옆인가
func bench_row(at: Vector3) -> Array[Node3D]:
	var row: Array[Node3D] = []
	for r in residents:
		if r.state == "busy" and r.fig.seated and String(r.spot.get("kind", "")) == "bench" and (r.spot["pos"] as Vector3).distance_to(at) < 0.1: row.append(r)
	if seat_at(at): row.append(body)
	return row

## 사람이 앉아 컵·먹을 걸 들고 C 를 길게(0.45초): 옆 칸 빈손의 주민에게 통째로 건넨다(pass). 짧게 누르면 그대로 반 쪼개기·먹기. 받은 주민은 줄 반대쪽으로 또 넘길 수 있다(0.15)
func pass_on_bench(now: float) -> bool:
	var it := player.carrying
	if seat.is_empty() or seat.has("chair") or it == null or not passable(String(it.get_meta("kind", ""))): return false
	for o in bench_row(seat["pos"]):
		if o == body or o.global_position.distance_to(body.global_position) > 0.6: continue
		var r := o as ResidentLife
		if r.fig.carrying != null or r.bites > 0: continue
		player.set_meta("share_side", share_side(seat.get("yaw", 0.0), body.global_position, r.global_position))
		player.pose_request = "pass"; use_until = now + StickPoses.PASS_T; action_until = now + StickPoses.PASS_T
		get_tree().create_timer(StickPoses.PASS_HAND).timeout.connect(func() -> void: _hand_pass(r))
		return true
	return false

func _hand_pass(r: ResidentLife) -> void:
	if player.pose_request != "pass" or player.carrying == null or not is_instance_valid(r) or not r.fig.seated or r.fig.carrying != null or r.state != "busy" or r.spot.get("kind", "") != "bench" or not seat_at(r.spot.get("pos", Vector3.INF)): return   # 리뷰 2026-10-01: fig.seated 는 운전·의자·시소에서도 참 — 같은 벤치인지까지 본다   # 그새 일어났거나 손이 찼다 — 안 넘긴다
	r.take_passed(player.release(self, Vector3.ZERO), body, 0.15)
	shared_once = true

## 주민이 줄을 따라 넘긴 걸 받는다 — 앉은 사람 손에. 먹을 거면 C 로 먹고, 길게 누르면 또 넘긴다
func take_passed(it: Node3D, from: ResidentBase) -> void:
	player.hold(it)
	if not shared_once: say_toast(from.handle + " passed it along. Hold C to pass it on.")
	shared_once = true

## 나누기·넘기기·앉아 먹기 자세를 시간이 되면 푼다(리뷰 2026-10-01: 앉은 동안엔 town_player 가 먼저 return 해 share/pass/eat 이 영영 남았다). _tick 이 부른다
func _meal_tick(now: float) -> void:
	if use_until > 0.0 and now >= use_until and player.pose_request in ["share", "pass", "eat"]:
		player.pose_request = ""; use_until = -1.0
