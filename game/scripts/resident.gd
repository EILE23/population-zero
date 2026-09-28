class_name Resident
extends CharacterBody3D
## 주민 — 마을의 AI 등장인물. 자리를 골라 걸어가 벤치에 앉고, 가로등에 기대고, 나무를 흔들고, 다음 자리로 간다.
## 맞으면 움찔하고(flinch), 짧은 시간에 세 대 또는 무거운 한 방이면 넘어져 물건을 떨어뜨리고, 일어나서 때린 사람을 쫓다가 포기한다.
## 사람과 같은 리그(Stick3D)·같은 규칙 — 주민만의 힘은 없다.

const WALK := 1.6
const RUN := 3.4
const REACH := 0.95

var town: Node3D
var fig: Stick3D
var uid := 0
var handle := ""
var state := "routine"      # routine | walk | busy | down | getup | chase
var spot: Dictionary = {}
var target := Vector3.ZERO
var route: Array = []          # 경유지 큐 [{pos, act}] — act: "open" | "close" | ""
var door_ref: Dictionary = {}
var busy_until := 0.0
var down_until := 0.0
var chase_until := 0.0
var next_punch := 0.0
var slot := 0
var stuck_since := -1.0
var stuck_dist := 0.0
var detours := 0
var hits := 0
var last_hit := -9.0
var quarry: Node3D = null
var say_label: Label3D
var say_until := 0.0
var carrying_kind := ""      # 손에 든 것(넘어지면 떨어뜨린다)

const LINES_HIT := ["Excuse me.", "That was uncalled for.", "I felt that.", "Really."]
const LINES_GIVEUP := ["Fine.", "I am tired.", "This is noted.", "Have it your way."]
const LINES_DOWN := ["Ow.", "Right.", "Noted."]

func setup(t: Node3D, id: int, h: String) -> void:
	town = t; uid = id; handle = h
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.18; cap.height = 0.95
	col.shape = cap; col.position.y = 0.5
	add_child(col)
	fig = Stick3D.new()
	fig.color = figure_color(id); fig.head_color = fig.color
	add_child(fig)
	var nl := Label3D.new()
	nl.text = h; nl.font_size = 22; nl.pixel_size = 0.004; nl.modulate = Color("5b4f56")
	nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; nl.no_depth_test = true
	nl.position = Vector3(0, 1.32, 0)
	add_child(nl)
	say_label = Label3D.new()
	say_label.font_size = 26; say_label.pixel_size = 0.004; say_label.modulate = Color("1b0c15")
	say_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; say_label.no_depth_test = true
	say_label.position = Vector3(0, 1.5, 0); say_label.visible = false
	add_child(say_label)
	# 꾸미기(시드): 5명 중 2명은 모자, 5명 중 1명은 안경, 6명 중 1명은 가방 — 마을에 변화가 보이게
	if id % 5 < 2: fig.wear(Wear.make(["cap", "beanie", "tophat", "straw"][id % 4], Wear.palette(id)))
	if id % 5 == 3: fig.wear(Wear.make("glasses" if id % 2 == 0 else "sunglasses"))
	if id % 6 == 1: fig.wear(Wear.make("backpack", Wear.palette(id + 2)))
	# 넷 중 하나는 뭔가 들고 다닌다(뺏을 거리)
	if id % 4 == 1:
		carrying_kind = ["apple", "cup", "paper"][id % 3]
		var it: MeshInstance3D = town.make_item(carrying_kind, Vector3.ZERO)
		fig.hold(it)  # hold() 가 부모에서 떼어 손에 붙인다
	busy_until = Time.get_ticks_msec() / 1000.0 + randf_range(0.5, 4.0)

## 웹 tower.ts figureColor(uid) 와 같은 색 — 사이트와 게임에서 같은 사람은 같은 색
static func figure_color(id: int) -> Color:
	var h := fmod(id * 137.508, 360.0)
	var sat := 52 + (id % 4) * 9
	var lit := 34 + ((id * 7) % 5) * 4
	return Color.from_hsv(h / 360.0, sat / 100.0, minf(1.0, lit / 100.0 * 1.6))

## 인사받음 — 손을 흔들어 답하고 한마디(일과 중이면 잠깐 멈춘다)
func greet(from: Node3D) -> void:
	if state == "down" or state == "getup" or state == "chase":
		return
	var now := Time.get_ticks_msec() / 1000.0
	# 하던 자리를 제대로 비운다 — 전엔 spot 만 바꿔서 벤치 칸이 영영 '찬 자리'로 남았고(주민 풀이 조금씩 줄었다),
	# 그네를 타던 중이면 _leave 가 spot["swing"] 을 찾다 죽었다. 그네·밀기는 riding_swing/pushing_swing 이 기억하니 _leave 가 마저 정리한다
	if state == "busy" and spot.get("kind", "") == "bench": global_position += Vector3(0, 0, 0.45)
	_release(); collision_layer = 1; collision_mask = 1
	fig.seated = false
	fig.pose_request = "wave"
	fig.face(atan2(from.global_position.x - global_position.x, from.global_position.z - global_position.z))
	state = "busy"; busy_until = now + 1.4
	spot = { "kind": "greet" }
	say(["Hello.", "Afternoon.", "Yes, hello.", "Good day."][uid % 4], 1.6)

func say(text: String, secs := 2.2) -> void:
	say_label.text = text; say_label.visible = true
	say_until = Time.get_ticks_msec() / 1000.0 + secs

func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if say_label.visible and now > say_until:
		say_label.visible = false
	var v := velocity
	if not is_on_floor():
		v.y -= 22.0 * delta
	else:
		v.y = 0.0
	fig.airborne = not is_on_floor(); fig.vertical = v.y
	# 동작(주먹·집기)은 상태와 무관하게 끝나면 지운다 — 쫓다가 포기하면 주먹 자세가 남던 버그
	if fig.action == "punch" or fig.action == "grab":
		if now >= busy_until:
			fig.action = ""; fig.action_t = 0.0
		else:
			fig.action_t = 1.0 - (busy_until - now) / 0.28
	match state:
		"routine":
			v.x = 0.0; v.z = 0.0; fig.move_dir = Vector3.ZERO; fig.speed = 0.0   # 쫓다 포기한 뒤 달리던 속도가 남아 1초 더 미끄러지던 것
			if now >= busy_until:
				_pick_spot()
		"walk":
			var to := target - global_position; to.y = 0.0
			if to.length() < 0.35:
				var step: Dictionary = route.pop_front() if not route.is_empty() else {}
				if step.get("act", "") == "open": town.set_door(door_ref, true)
				elif step.get("act", "") == "close": town.set_door(door_ref, false)
				detours = 0
				if route.is_empty():
					if step.get("act", "") == "close":
						state = "routine"; busy_until = now + randf_range(0.5, 2.0)
					else:
						_arrive(now)
				else:
					target = route[0]["pos"]
			else:
				var dir := to.normalized()
				var spd := WALK * (1.7 if weather == "rain" else 1.0)  # 비 오면 서두른다
				v.x = dir.x * spd; v.z = dir.z * spd
				fig.move_dir = dir; fig.speed = Vector2(velocity.x, velocity.z).length()   # 걸음은 실제 속도로 — 벽에 막히면 제자리 뛰기가 안 난다
				# 막힘은 진행 거리로 판단: 1.2초 동안 목표에 0.15m 도 못 다가가면 옆으로 우회 지점을 하나 두고, 두 번째면 포기
				if stuck_since < 0.0:
					stuck_since = now; stuck_dist = to.length()
				elif now - stuck_since > 1.2:
					if stuck_dist - to.length() < 0.15:
						if detours < 2:
							detours += 1
							var side := Vector3(-dir.z, 0, dir.x) * (1.6 if (uid + detours) % 2 == 0 else -1.6)
							route.push_front({ "pos": global_position + side + dir * 0.8, "act": "" })
							target = route[0]["pos"]
						else:
							detours = 0; _release(); state = "routine"; busy_until = now; route = []
					stuck_since = -1.0
		"busy":
			v.x = 0.0; v.z = 0.0
			fig.move_dir = Vector3.ZERO; fig.speed = 0.0
			if not riding_swing.is_empty():
				global_position = town.swing_seat(riding_swing) + Vector3(0, -0.39, 0)
				fig.swing_k = clampf(riding_swing["vel"] / 3.0, -1.0, 1.0); fig.rotation.x = riding_swing["angle"]
				v.y = 0.0
			else:
				fig.rotation.x = 0.0
			if now >= busy_until:
				_leave()
		"down":
			v.x = lerpf(v.x, 0.0, 0.2); v.z = lerpf(v.z, 0.0, 0.2)
			fig.move_dir = Vector3.ZERO; fig.speed = 0.0
			if now >= down_until:
				fig.lying = false; fig.action = "getup"; fig.action_t = 0.0
				state = "getup"; busy_until = now + 0.6
		"getup":
			v.x = 0.0; v.z = 0.0
			fig.action_t = 1.0 - (busy_until - now) / 0.6
			if now >= busy_until:
				fig.action = ""; fig.action_t = 0.0
				if quarry and randf() < 0.65:
					state = "chase"; chase_until = now + 4.5; say(LINES_HIT[uid % LINES_HIT.size()])
				else:
					state = "routine"; busy_until = now + 0.5
		"chase":
			if quarry == null or now >= chase_until:
				say(LINES_GIVEUP[uid % LINES_GIVEUP.size()]); quarry = null
				fig.action = ""; fig.action_t = 0.0
				state = "routine"; busy_until = now + 1.0
			else:
				var to := quarry.global_position - global_position; to.y = 0.0
				var d := to.length()
				var dir := to.normalized()
				if d > REACH:
					v.x = dir.x * RUN; v.z = dir.z * RUN
					fig.move_dir = dir; fig.speed = RUN
				else:
					v.x = 0.0; v.z = 0.0
					fig.move_dir = dir; fig.speed = 0.0
					fig.face(atan2(dir.x, dir.z))
					if now >= next_punch:
						next_punch = now + 0.55
						fig.punch_side = -fig.punch_side; fig.punch_kind = "jab" if fig.punch_side < 0.0 else "cross"
						fig.action = "punch"; fig.action_t = 0.0; busy_until = now + 0.28
						town.resident_hits_player(self, dir)
	if state == "walk" or state == "chase":
		for o in town.residents:
			if o == self: continue
			var dv: Vector3 = global_position - o.global_position; dv.y = 0.0
			var dl := dv.length()
			if dl < 0.5 and dl > 0.001:
				v += dv.normalized() * (0.5 - dl) * 6.0   # 가까울수록 세게 비킨다
	velocity = v
	if fig.seated or not riding_swing.is_empty():
		return   # 앉거나 그네를 탈 땐 물리로 밀리지 않는다
	if is_on_floor() and Vector2(v.x, v.z).length() > 0.1:
		town.step_up(self, Vector3(v.x, 0, v.z) * delta)   # 턱·문지방·계단 오르기(사람과 같은 규칙)
	move_and_slide()

var weather := "clear"
var home_door: Dictionary = {}   # 내 집의 문 — 밤엔 여기로 가서 침대에서 잔다

## 날씨 바뀜 — 비면 지금 하던 걸 접고 실내로 서두른다(밖 자리에 있었으면 바로 다시 고른다)
func on_weather(w: String) -> void:
	weather = w
	if w != "rain" or not (state in ["busy", "walk", "routine"]) or spot.get("kind", "") in ["chair", "bed", "shelf"]:
		return
	# _leave 로 자리를 제대로 비운다 — 전엔 seated 만 풀어서 그네 rider 가 남아 비 온 뒤 그네가 영영 차 있었고, 걸어가던 목표 칸도 새어 나갔다
	if state == "busy": _leave()
	else: _release()
	state = "routine"; busy_until = Time.get_ticks_msec() / 1000.0 + randf_range(0.0, 1.5)
	say(["Rain.", "Of course.", "Inside, then."][uid % 3], 1.5)

func _pick_spot() -> void:
	if town.spots.is_empty():
		busy_until = Time.get_ticks_msec() / 1000.0 + 3.0; return
	if town.is_night() and not home_door.is_empty():
		# 밤: 집으로 가서 침대에 눕는다(집에 침대가 있으면), 아니면 의자
		var mine: Array = town.spots.filter(func(sp): return sp.has("door") and sp["door"] == home_door and sp["kind"] == "bed")
		if mine.is_empty(): mine = town.spots.filter(func(sp): return sp.has("door") and sp["door"] == home_door)
		mine = mine.filter(func(sp): return _free_slot(sp) >= 0)
		if not mine.is_empty():
			spot = mine[0]; slot = 0; _claim(spot, 0)
			door_ref = home_door
			var dp: Vector3 = door_ref["pos"]
			route = _approach(door_ref) + [{ "pos": dp + Vector3(0, 0, 0.8), "act": "open" }, { "pos": dp + Vector3(0, 0, -0.6), "act": "" }, { "pos": spot["pos"] + Vector3(0, 0, 0.35), "act": "" }]
			target = route[0]["pos"]; state = "walk"; return
	var pool: Array = town.spots
	if weather == "rain":
		# 비: 실내(의자·침대·선반) 아니면 차양 아래(문 앞)만 고른다
		pool = town.spots.filter(func(sp): return sp["kind"] in ["chair", "bed", "shelf", "door"])
		if pool.is_empty(): pool = town.spots
	# 찬 자리는 빼고 고른다(운영자: 주민끼리 겹쳐 있으면 안 된다)
	var free: Array = pool.filter(func(sp): return _free_slot(sp) >= 0)
	if free.is_empty():
		busy_until = Time.get_ticks_msec() / 1000.0 + 2.0; return
	spot = free[randi() % free.size()]
	slot = _free_slot(spot)
	_claim(spot, slot)
	route = []
	if (spot["kind"] == "chair" or spot["kind"] == "bed" or spot["kind"] == "shelf") and spot.has("door"):
		# 집 안 의자: (집 앞이 아니면 모서리를 돌아) 문 앞 → 문 열기 → 의자. 나올 땐 _leave 가 반대로
		door_ref = spot["door"]
		var dp: Vector3 = door_ref["pos"]
		route = _approach(door_ref) + [{ "pos": dp + Vector3(0, 0, 0.8), "act": "open" }, { "pos": dp + Vector3(0, 0, -0.6), "act": "" }, { "pos": spot["pos"] + Vector3(0, 0, 0.35), "act": "" }]
	elif spot["kind"] == "bench":
		route = [{ "pos": spot["pos"] + Vector3([-0.45, 0.0, 0.45][slot], 0, 0.45), "act": "" }]
	elif spot["kind"] == "door":
		var near_door: Dictionary = {}
		for dr in town.doors:
			if (dr["pos"] as Vector3).distance_to(spot["pos"]) < 1.2: near_door = dr; break
		route = (_approach(near_door) if not near_door.is_empty() else []) + [{ "pos": spot["pos"] + Vector3(randf_range(-0.2, 0.2), 0, 0.2), "act": "" }]
	else:
		route = [{ "pos": spot["pos"] + Vector3(randf_range(-0.2, 0.2), 0, 0.5), "act": "" }]
	target = route[0]["pos"]
	state = "walk"

func _arrive(now: float) -> void:
	state = "busy"
	fig.pose_request = ""
	match spot["kind"]:
		"bench":
			fig.seated = true; collision_layer = 0; collision_mask = 0
			global_position = spot["pos"] + Vector3([-0.45, 0.0, 0.45][slot], 0.05, 0.02)
			fig.face(spot.get("yaw", 0.0))
			busy_until = now + randf_range(6.0, 14.0)
		"swing":
			var sw: Dictionary = spot["swing"]
			if sw["rider"] == null:
				sw["rider"] = self; riding_swing = sw
				fig.pose_request = "swing"; fig.face(0.0)
				busy_until = now + randf_range(10.0, 25.0)
			else:
				# 누가 타고 있으면 뒤에서 밀어 준다
				go_push(sw)
		"chair":
			fig.seated = true; collision_layer = 0; collision_mask = 0
			global_position = spot["pos"] + Vector3(0, 0.05, 0.02)
			fig.face(spot.get("yaw", 0.0))
			busy_until = now + randf_range(6.0, 12.0)
		"bed":
			fig.pose_request = "rest"
			global_position = spot["pos"] + Vector3(0, 0.02, 0)
			fig.face(spot.get("yaw", 0.0))
			busy_until = now + (randf_range(60.0, 120.0) if town.is_night() else randf_range(8.0, 16.0))
		"shelf":
			fig.pose_request = "read"; fig.face(spot.get("yaw", PI))
			busy_until = now + randf_range(4.0, 8.0)
		"push":
			fig.pose_request = "push"; fig.face(0.0)
			busy_until = now + randf_range(12.0, 20.0)
		"lamp":
			fig.pose_request = "lean"; fig.face(spot.get("yaw", 0.0))
			busy_until = now + randf_range(4.0, 9.0)
		"tree":
			fig.pose_request = "shake"; fig.face(atan2(spot["pos"].x - global_position.x, spot["pos"].z - global_position.z))
			busy_until = now + randf_range(1.5, 3.0)
		_:
			fig.face(spot.get("yaw", PI))
			busy_until = now + randf_range(2.0, 5.0)

## 집 앞이 아닌 곳(옆·뒤)에서 출발하면 집 모서리를 돌아 앞길로 나오는 경유지 — 벽 모서리에 막혀 문을 못 찾던 것(운영자 지적, 비 오는 날)
func _approach(dr: Dictionary) -> Array:
	var dp: Vector3 = dr["pos"]
	var hw: float = dr.get("hw", 2.0); var hd: float = dr.get("hd", 1.8)
	var front_z := dp.z + 0.3
	if global_position.z > front_z + 0.2 and absf(global_position.x - dp.x) < hw + 1.0:
		return []   # 이미 집 앞
	var side := 1.0 if global_position.x >= dp.x else -1.0
	var out := []
	if global_position.z <= front_z + 0.2:
		# 옆이나 뒤: 그쪽 옆면을 따라 앞으로 나온다
		out.append({ "pos": Vector3(dp.x + side * (hw + 1.1), 0, global_position.z), "act": "" })
		out.append({ "pos": Vector3(dp.x + side * (hw + 1.1), 0, front_z + 1.6), "act": "" })
	out.append({ "pos": Vector3(dp.x, 0, front_z + 1.6), "act": "" })
	return out

## 자리 점유 — 벤치는 3칸, 나머지는 1칸. 비어 있는 칸 번호를 돌려주고 없으면 -1
func _free_slot(sp: Dictionary) -> int:
	var n := 3 if sp["kind"] == "bench" else 1
	var taken: Array = sp.get("taken", [])
	for i in n:
		if i >= taken.size() or taken[i] == null or taken[i] == self: return i
	return -1

func _claim(sp: Dictionary, i: int) -> void:
	var n := 3 if sp["kind"] == "bench" else 1
	if not sp.has("taken") or (sp["taken"] as Array).size() < n:
		var arr := []; arr.resize(n); sp["taken"] = arr
	sp["taken"][i] = self

func _release() -> void:
	if spot.has("taken"):
		var arr: Array = spot["taken"]
		for i in arr.size():
			if arr[i] == self: arr[i] = null

var riding_swing: Dictionary = {}
var pushing_swing: Dictionary = {}

## 그네 뒤로 가서 밀어 주기(사람이 타는데 안 밀 때 town 이 부르거나, 주민이 그네 자리에 왔는데 차 있을 때)
func go_push(sw: Dictionary) -> void:
	_release()   # 걸어가던(또는 방금 잡은 그네) 자리를 비운다 — 안 비우면 그 칸이 영영 '찬 자리'
	pushing_swing = sw; sw["pusher"] = self
	spot = { "kind": "push", "swing": sw }
	route = [{ "pos": sw["at"] + Vector3(0, 0, -1.1), "act": "" }]
	target = route[0]["pos"]; state = "walk"
	say(["Hold on.", "Here.", "Higher?"][uid % 3], 1.5)

func _leave() -> void:
	_release()
	collision_layer = 1; collision_mask = 1
	if not riding_swing.is_empty():
		riding_swing["rider"] = null
		global_position = riding_swing["at"] + Vector3(0, 0.02, 0.9); fig.pose_request = ""; fig.rotation.x = 0.0
		riding_swing = {}
	if not pushing_swing.is_empty():
		if pushing_swing["pusher"] == self: pushing_swing["pusher"] = null
		pushing_swing = {}; fig.pose_request = ""
	fig.seated = false; fig.pose_request = ""
	if spot.get("kind", "") == "bench":
		global_position += Vector3(0, 0, 0.45)
	if spot.get("kind", "") in ["chair", "bed", "shelf"] and not door_ref.is_empty():
		global_position += Vector3(0, 0, 0.35)
		var dp: Vector3 = door_ref["pos"]
		route = [{ "pos": dp + Vector3(0, 0, -0.6), "act": "" }, { "pos": dp + Vector3(0, 0, 0.8), "act": "close" }]
		target = route[0]["pos"]; state = "walk"
		return
	state = "routine"; busy_until = Time.get_ticks_msec() / 1000.0 + randf_range(0.5, 2.0)

## 맞음 — from_dir 은 때린 방향(밀리는 쪽). heavy 면 바로 넘어진다; 아니면 3초 안에 세 대째에 넘어진다
func hit(from_dir: Vector3, by: Node3D, heavy: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if state == "down" or state == "getup":
		return
	quarry = by
	_release(); collision_layer = 1; collision_mask = 1
	if not riding_swing.is_empty(): riding_swing["rider"] = null; riding_swing = {}; fig.rotation.x = 0.0
	if not pushing_swing.is_empty(): pushing_swing["pusher"] = null; pushing_swing = {}
	if now - last_hit > 3.0: hits = 0
	hits += 1; last_hit = now
	fig.seated = false; fig.pose_request = ""
	if state == "busy" and spot.get("kind", "") == "bench":
		global_position += Vector3(0, 0, 0.3)
	if heavy or hits >= 3:
		hits = 0
		state = "down"; down_until = now + 1.6
		fig.lying = true; fig.action = ""; fig.action_t = 0.0
		fig.face(atan2(-from_dir.x, -from_dir.z))  # 때린 쪽을 보고 눕는다
		velocity = from_dir * 3.5 + Vector3(0, 2.0, 0)
		say(LINES_DOWN[uid % LINES_DOWN.size()], 1.6)
		if fig.carrying:
			var it: Node3D = fig.release(town, global_position + from_dir * 0.6 + Vector3(0, 0.1, 0))
			town.items.append(it); carrying_kind = ""
	else:
		fig.action = "flinch"; fig.action_t = 0.0
		state = "busy"; busy_until = now + 0.3
		velocity = from_dir * 1.6
		if hits == 2: say(LINES_HIT[(uid + 1) % LINES_HIT.size()], 1.2)

## flinch 진행은 busy 상태에서 town 이 아니라 여기서 돌린다
func _process(_delta: float) -> void:
	if fig.action == "flinch":
		var now := Time.get_ticks_msec() / 1000.0
		fig.action_t = 1.0 - (busy_until - now) / 0.3
		if now >= busy_until:
			fig.action = ""; fig.action_t = 0.0
			if quarry and state == "busy" and randf() < 0.5:
				state = "chase"; chase_until = now + 4.0
			elif state == "busy":
				state = "routine"; busy_until = now + 0.3
