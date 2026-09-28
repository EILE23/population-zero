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
var busy_until := 0.0
var down_until := 0.0
var chase_until := 0.0
var next_punch := 0.0
var stuck_since := -1.0
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
			if now >= busy_until:
				_pick_spot()
		"walk":
			var to := target - global_position; to.y = 0.0
			if to.length() < 0.35:
				_arrive(now)
			else:
				var dir := to.normalized()
				v.x = dir.x * WALK; v.z = dir.z * WALK
				fig.move_dir = dir; fig.speed = WALK
				if Vector2(velocity.x, velocity.z).length() < 0.3:
					if stuck_since < 0.0: stuck_since = now
					elif now - stuck_since > 1.5:  # 벽에 막힘 — 다른 자리
						stuck_since = -1.0; state = "routine"; busy_until = now
				else:
					stuck_since = -1.0
		"busy":
			v.x = 0.0; v.z = 0.0
			fig.move_dir = Vector3.ZERO; fig.speed = 0.0
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
	velocity = v
	move_and_slide()

func _pick_spot() -> void:
	if town.spots.is_empty():
		busy_until = Time.get_ticks_msec() / 1000.0 + 3.0; return
	spot = town.spots[randi() % town.spots.size()]
	target = spot["pos"] + Vector3(randf_range(-0.2, 0.2), 0, 0.5 if spot["kind"] != "bench" else 0.45)
	if spot["kind"] == "bench":
		target = spot["pos"] + Vector3([-0.45, 0.0, 0.45][uid % 3], 0, 0.45)
	state = "walk"

func _arrive(now: float) -> void:
	state = "busy"
	fig.pose_request = ""
	match spot["kind"]:
		"bench":
			fig.seated = true
			global_position = spot["pos"] + Vector3([-0.45, 0.0, 0.45][uid % 3], 0.03, 0.02)
			fig.face(spot.get("yaw", 0.0))
			busy_until = now + randf_range(6.0, 14.0)
		"lamp":
			fig.pose_request = "lean"; fig.face(spot.get("yaw", 0.0))
			busy_until = now + randf_range(4.0, 9.0)
		"tree":
			fig.pose_request = "shake"; fig.face(atan2(spot["pos"].x - global_position.x, spot["pos"].z - global_position.z))
			busy_until = now + randf_range(1.5, 3.0)
		_:
			fig.face(spot.get("yaw", PI))
			busy_until = now + randf_range(2.0, 5.0)

func _leave() -> void:
	fig.seated = false; fig.pose_request = ""
	if spot.get("kind", "") == "bench":
		global_position += Vector3(0, 0, 0.45)
	state = "routine"; busy_until = Time.get_ticks_msec() / 1000.0 + randf_range(0.5, 2.0)

## 맞음 — from_dir 은 때린 방향(밀리는 쪽). heavy 면 바로 넘어진다; 아니면 3초 안에 세 대째에 넘어진다
func hit(from_dir: Vector3, by: Node3D, heavy: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if state == "down" or state == "getup":
		return
	quarry = by
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
