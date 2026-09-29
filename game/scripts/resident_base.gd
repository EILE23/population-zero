class_name ResidentBase
extends CharacterBody3D
## 주민의 몸과 상태 — 리그·이름표·말풍선, 맞음(flinch·넘어짐), 인사받음, 자리 칸 점유. 일과(자리 고르기·걷기·도착·떠나기)는 resident.gd 에.
## resident.gd 가 465줄로 한도(500)에 닿아 갈랐다(코드 정리, run 72): 여기엔 '이 사람은 무엇인가'만, 저기엔 '무엇을 하나'만. 사람과 같은 리그(Stick3D)·같은 규칙 — 주민만의 힘은 없다.

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
var can_mine := false        # 텃밭에서 제 물뿌리개를 든 중(떠날 때 치운다 — 맞아서 떨어뜨리면 그대로 바닥에 남아 누구든 집는다)
var job := ""                # 일자리 — 집 문에 적힌 것(town_build _residents: 빵집 문의 주민이 "baker"). 일은 진짜 장소에 매인다
var bites := 0               # 창구에서 받은 빵의 남은 입(run 72) — 0 이면 먹는 중이 아니다
var bite_at := 0.0           # 다음 한입 시각
var has_umb := false         # 꽂이에서 빌린 우산을 든 중(run 76) — 비가 그치면(또는 밤이면) 돌려놓으러 간다. 맞아 떨어뜨리면 그냥 바닥의 물건(누구든 주워 돌려놓는다)

const LINES_HIT := ["Excuse me.", "That was uncalled for.", "I felt that.", "Really."]
const LINES_GIVEUP := ["Fine.", "I am tired.", "This is noted.", "Have it your way."]
const LINES_DOWN := ["Ow.", "Right.", "Noted."]
var weather := "clear"
var home_door: Dictionary = {}   # 내 집의 문 — 밤엔 여기로 가서 침대에서 잔다
var riding_swing: Dictionary = {}
var pushing_swing: Dictionary = {}

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
	fig.pose_request = "lwave" if has_umb else "wave"   # 우산을 든 손으론 못 흔든다 — 왼손으로(run 77, StickPoses.lwave; 우산은 있던 대로). 사람도 우산을 든 채 C 로 같은 인사(town_places umbrella_use)
	fig.face(atan2(from.global_position.x - global_position.x, from.global_position.z - global_position.z))
	state = "busy"; busy_until = now + 1.4
	spot = { "kind": "greet" }
	say(["Hello.", "Afternoon.", "Yes, hello.", "Good day."][uid % 4], 1.6)

func say(text: String, secs := 2.2) -> void:
	say_label.text = text; say_label.visible = true
	say_until = Time.get_ticks_msec() / 1000.0 + secs
func _free_slot(sp: Dictionary) -> int:
	var n := 3 if sp["kind"] in ["bench", "rack"] else 1   # 우산꽂이 칸 = 우산 수(run 76)
	var taken: Array = sp.get("taken", [])
	for i in n:
		if i < taken.size() and taken[i] != null and taken[i] != self: continue
		if not _player_on(sp, i): return i
	return -1

## 사람이 앉아(누워) 있는 칸은 찬 자리 — 주민이 플레이어 무릎 위에 앉거나 같은 침대에 눕던 것
func _player_on(sp: Dictionary, i: int) -> bool:
	if town.seat.is_empty() and not town.resting: return false
	var off: float = [-0.45, 0.0, 0.45][i] if sp["kind"] == "bench" else 0.0
	var at: Vector3 = sp["pos"] + Vector3(off, 0, 0)
	var p: Vector3 = town.body.global_position
	return Vector2(p.x - at.x, p.z - at.z).length() < 0.35

func _claim(sp: Dictionary, i: int) -> void:
	var n := 3 if sp["kind"] in ["bench", "rack"] else 1
	if not sp.has("taken") or (sp["taken"] as Array).size() < n:
		var arr := []; arr.resize(n); sp["taken"] = arr
	sp["taken"][i] = self

func _release() -> void:
	if spot.has("taken"):
		var arr: Array = spot["taken"]
		for i in arr.size():
			if arr[i] == self: arr[i] = null
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
	spot = { "kind": "hit" }   # 자리는 위에서 비웠다 — 남겨 두면 _leave 가 벤치에서 한 번 더 물러나고, 걸어가던 집의 문을 닫으러 갔다
	if heavy or hits >= 3:
		hits = 0
		state = "down"; down_until = now + 1.6
		fig.lying = true; fig.action = ""; fig.action_t = 0.0
		fig.face(atan2(-from_dir.x, -from_dir.z))  # 때린 쪽을 보고 눕는다
		velocity = from_dir * 3.5 + Vector3(0, 2.0, 0)
		say(LINES_DOWN[uid % LINES_DOWN.size()], 1.6)
		if fig.carrying:
			var it: Node3D = fig.release(town, global_position + from_dir * 0.6 + Vector3(0, 0.1, 0))
			it.set_meta("dropped_at", now)   # 넘어져 떨어뜨린 표시 — 여우가 6초 안에 노린다(town_systems _fox). 내려놓은 것·던진 것과 구별
			town.items.append(it); carrying_kind = ""; can_mine = false; bites = 0; has_umb = false   # 먹던 빵도 떨어진다 — 남은 입은 없다; 우산도(접혀서)
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
