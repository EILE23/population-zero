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
var in_boat := false         # 거룻배에 탄 중(run 78) — 배가 옮긴다(town_boat _boats), 내릴 땐 town.unboard
var has_umb := false         # 꽂이에서 빌린 우산을 든 중(run 76) — 비가 그치면(또는 밤이면) 돌려놓으러 간다. 맞아 떨어뜨리면 그냥 바닥의 물건(누구든 주워 돌려놓는다)

var weather := "clear"
var home_door: Dictionary = {}   # 내 집의 문 — 밤엔 여기로 가서 침대에서 잔다
var riding_swing: Dictionary = {}
var pushing_swing: Dictionary = {}
var riding_seesaw: Seesaw3D = null
var mind: ResidentMind         # 자아 — 성격·욕구·기분·기억·관계·말투(resident_mind.gd). 대사는 전부 여기 목소리로
var name_label: Label3D
var guard_until := -1.0        # 막기 자세 중(이 시각까지) — sense_attack 이 올린다
var _door_wait := -1.0   # 문을 열었으면 문짝이 다 열릴 때까지 기다린다(resident.gd)

func setup(t: Node3D, id: int, h: String) -> void:
	town = t; uid = id; handle = h
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.18; cap.height = 0.95
	col.shape = cap; col.position.y = 0.5
	add_child(col)
	collision_layer = 4; collision_mask = 7   # 사람은 층 3(값 4) — 차는 사람을 몸으로 느끼지 않아 길막이 없고(밀기·날리기는 스크립트), 사람은 차·세계·서로를 느낀다
	fig = Stick3D.new()
	fig.color = figure_color(id); fig.head_color = fig.color
	add_child(fig)
	var nl := Label3D.new()
	nl.text = h; nl.font_size = 44; nl.pixel_size = 0.002; nl.modulate = Color("5b4f56"); nl.outline_size = 8; nl.outline_modulate = Color("f7f4ef")
	nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; nl.no_depth_test = true
	nl.position = Vector3(0, 1.32, 0)
	add_child(nl); name_label = nl
	say_label = Label3D.new()
	say_label.font_size = 52; say_label.pixel_size = 0.002; say_label.modulate = Color("1b0c15"); say_label.outline_size = 10; say_label.outline_modulate = Color("f7f4ef")
	say_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; say_label.no_depth_test = true
	say_label.position = Vector3(0, 1.5, 0); say_label.visible = false
	add_child(say_label)
	# 꾸미기(시드): 5명 중 2명은 모자, 5명 중 1명은 안경, 6명 중 1명은 가방 — 마을에 변화가 보이게
	if id % 5 < 2: fig.wear(Wear.make(["cap", "beanie", "tophat", "straw"][id % 4], Wear.palette(id)))
	if id % 5 == 3: fig.wear(Wear.make("glasses" if id % 2 == 0 else "sunglasses"))
	if id % 6 == 1: fig.wear(Wear.make("backpack", Wear.palette(id + 2)))
	elif id % 6 == 4: fig.wear(Wear.make("scarf", Wear.palette(id + 3)))   # 목도리(run 82) — 찢어질 수 있는 것을 메고 다니는 사람이 가방 멘 이들뿐이면 재봉사 손님이 너무 적다
	# 넷 중 하나는 뭔가 들고 다닌다(뺏을 거리)
	if id % 4 == 1:
		carrying_kind = ["apple", "cup", "paper"][id % 3]
		var it: MeshInstance3D = town.make_item(carrying_kind, Vector3.ZERO)
		fig.hold(it)  # hold() 가 부모에서 떼어 손에 붙인다
	busy_until = Time.get_ticks_msec() / 1000.0 + randf_range(0.5, 4.0)
	mind = ResidentMind.new(self)

## 웹 tower.ts figureColor(uid) 와 같은 색 — 사이트와 게임에서 같은 사람은 같은 색
static func figure_color(id: int) -> Color:
	var h := fmod(id * 137.508, 360.0)
	var sat := 52 + (id % 4) * 9
	var lit := 34 + ((id * 7) % 5) * 4
	return Color.from_hsv(h / 360.0, sat / 100.0, minf(1.0, lit / 100.0 * 1.6))

## 인사받음 — 손을 흔들어 답하고 한마디(일과 중이면 잠깐 멈춘다)
func greet(from: Node3D) -> void:
	if state == "down" or state == "getup" or state == "chase" or in_boat:
		return
	if state == "drive":   # 운전 중엔 차 안에서 한마디만 — 전엔 인사하러 내려서 빈 차가 혼자 달렸다
		if from == town.body: mind.greeted(); say(mind.greet_line(), 1.6)
		return
	var now := Time.get_ticks_msec() / 1000.0
	# 하던 자리를 제대로 비운다 — 전엔 spot 만 바꿔서 벤치 칸이 영영 '찬 자리'로 남았고(주민 풀이 조금씩 줄었다),
	# 그네를 타던 중이면 _leave 가 spot["swing"] 을 찾다 죽었다. 그네·밀기는 riding_swing/pushing_swing 이 기억하니 _leave 가 마저 정리한다
	if state == "busy" and spot.get("kind", "") == "bench": global_position += Vector3(0, 0, 0.45)
	_release(); collision_layer = 4; collision_mask = 7
	fig.seated = false
	fig.pose_request = "lwave" if has_umb else "wave"   # 우산을 든 손으론 못 흔든다 — 왼손으로(run 77, StickPoses.lwave; 우산은 있던 대로). 사람도 우산을 든 채 C 로 같은 인사(town_places umbrella_use)
	fig.face(atan2(from.global_position.x - global_position.x, from.global_position.z - global_position.z))
	state = "busy"; busy_until = now + 1.4
	spot = { "kind": "greet" }
	if from == town.body:
		# 사람의 인사는 기억에 남는다 — 몇 번째인지, 전에 맞았는지에 따라 답이 다르다. 이름표 아래에 지금 속(배고픔·피곤·나를 어떻게 보는지)이 잠깐 뜬다
		mind.greeted(); say(mind.greet_line(), 1.8); show_mind()
	else:
		say(mind.line("greet_new"), 1.6)

func show_mind(secs := 3.5) -> void:
	name_label.text = handle + "\n" + mind.status()
	get_tree().create_timer(secs).timeout.connect(func() -> void: name_label.text = handle)

## 선물 받기 — 사람이 든 걸 건네면(town_critters give) 손에 든다. 먹을 거면 그 자리에서 세 입에 먹는다. 호감이 오른다
func take_gift(it: Node3D) -> void:
	fig.hold(it); carrying_kind = String(it.get_meta("kind", ""))
	mind.gifted(); say(mind.line("gift"), 1.8)
	var now := Time.get_ticks_msec() / 1000.0
	fig.face(atan2(town.body.global_position.x - global_position.x, town.body.global_position.z - global_position.z))
	state = "busy"; spot = { "kind": "greet" }; busy_until = now + 1.4
	if carrying_kind in town.FOOD: bites = 3; bite_at = now + 1.0; busy_until = now + 0.9 * 3 + 1.4

## 반쪽 받기(run 85, 나눠 먹기) — 옆 칸에서 쪼개 건넨 걸(town_meals split_food) 앉은 채 남은 입에 먹는다. 준 이가 사람이면 호감, 주민이면 둘이 조금 친해진다
func take_half(it: Node3D, from: Node3D) -> void:
	fig.hold(it); carrying_kind = String(it.get_meta("kind", ""))
	var now := Time.get_ticks_msec() / 1000.0
	bites = 3 - int(it.get_meta("bites", 1)); bite_at = now + 0.9; busy_until = maxf(busy_until, now + 0.9 * bites + 1.5)
	if from == town.body: mind.gifted()
	elif from is ResidentBase: mind.befriend(from as ResidentBase, 0.1); (from as ResidentBase).mind.befriend(self, 0.1)
	say(mind.line("share_take"), 1.6)

func say(text: String, secs := 2.2) -> void:
	say_label.text = text; say_label.visible = true
	say_until = Time.get_ticks_msec() / 1000.0 + secs
func _free_slot(sp: Dictionary) -> int:
	var n := 3 if sp["kind"] in ["bench", "rack"] else (2 if sp["kind"] == "seesaw" else 1)   # 우산꽂이 칸 = 우산 수(run 76)
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
	var n := 3 if sp["kind"] in ["bench", "rack"] else (2 if sp["kind"] == "seesaw" else 1)
	if not sp.has("taken") or (sp["taken"] as Array).size() < n:
		var arr := []; arr.resize(n); sp["taken"] = arr
	sp["taken"][i] = self

func _release() -> void:
	if spot.has("taken"):
		var arr: Array = spot["taken"]
		for i in arr.size():
			if arr[i] == self: arr[i] = null
func hit(from_dir: Vector3, by: Node3D, heavy: bool, push := -1.0, lift := -1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if state == "down" or state == "getup" or state == "drive":   # 운전 중엔 차 안이다
		return
	# 막기: 가드를 올리고 때린 쪽을 보고 있으면 막는다 — 팔이 밀리고 반 발짝 밀려날 뿐. 띄우는 기술(lift 3 넘게)과 차는 못 막는다
	var facing := Vector3(sin(fig.rotation.y), 0, cos(fig.rotation.y))
	if now < guard_until and facing.dot(-from_dir) > 0.4 and lift < 3.0 and not (by is Car3D):
		velocity = from_dir * maxf(push, 2.0) * 0.35; fig.action_t = 0.3
		FightPoses.spark(town, global_position + Vector3(0, 0.95, 0) - from_dir * 0.2, false)
		if randf() < 0.4: say(["Not today.", "Ha.", "Saw that."][randi() % 3], 1.0)
		return
	# 누가 했나: 사람의 주먹·발, 또는 사람이 모는 차. 주민이 모는 차는 사고라 쫓지 않는다. 사람이면 기억하고, 곁에서 본 이들도 사람을 조금 덜 좋아하게 된다
	var by_player: bool = by == town.body or (by is Car3D and (by as Car3D).driver == town.body)
	quarry = town.body if by_player else (null if by is Car3D else by)
	if by_player:
		mind.hurt_by_player(heavy)
		for o in town.residents:
			if o != self and o.state != "drive" and o.global_position.distance_to(global_position) < 7.0:
				o.mind.witnessed()
				if randf() < 0.25: o.say(o.mind.line("witness"), 1.6)
	if riding_seesaw: riding_seesaw.leave(self); riding_seesaw = null
	if spot.get("kind", "") == "repair": (spot["crack"] as Dictionary)["by"] = null   # 수리 중 맞으면 금을 내려놓는다
	_release(); collision_layer = 4; collision_mask = 7
	if not riding_swing.is_empty(): riding_swing["rider"] = null; riding_swing = {}; fig.rotation.x = 0.0
	if not pushing_swing.is_empty(): pushing_swing["pusher"] = null; pushing_swing = {}
	if in_boat: town.unboard(self)
	if now - last_hit > 3.0: hits = 0
	hits += 1; last_hit = now
	fig.seated = false; fig.pose_request = ""
	if state == "busy" and spot.get("kind", "") == "bench":
		global_position += Vector3(0, 0, 0.3)
	spot = { "kind": "hit" }   # 자리는 위에서 비웠다 — 남겨 두면 _leave 가 벤치에서 한 번 더 물러나고, 걸어가던 집의 문을 닫으러 갔다
	if heavy or hits >= 3:
		hits = 0
		state = "down"; down_until = now + 1.6
		collision_layer = 0; collision_mask = 1   # 누운 몸은 차를 막지도 느끼지도 않는다(깔고 넘어간다) — 바닥은 계속 딛는다(mask 1)
		fig.lying = true; fig.action = ""; fig.action_t = 0.0
		fig.face(atan2(-from_dir.x, -from_dir.z))  # 때린 쪽을 보고 눕는다
		velocity = from_dir * (push if push >= 0.0 else 4.2) + Vector3(0, 3.2 + maxf(lift, 0.0), 0)   # 뒤로 붕 떠서 쓰러진다 — 기술마다 밀리는 세기·뜨는 높이가 다르다(FightMoves)
		say(mind.line("down"), 1.6)
		Wear.tear(fig.worn.get("back"))   # 바닥에 쓸려 등의 가방·목도리가 찢어진다 — 재봉사(run 82, town_trades)에게 간다
		while fig.carrying:   # 들고 있던 걸 전부 떨어뜨린다(셋까지 든다)
			var it: Node3D = fig.release(town, global_position + from_dir * randf_range(0.4, 0.8) + Vector3(randf_range(-0.3, 0.3), 0.1, 0))
			it.set_meta("dropped_at", now)   # 넘어져 떨어뜨린 표시 — 여우가 6초 안에 노린다(town_systems _fox). 내려놓은 것·던진 것과 구별
			town.items.append(it); carrying_kind = ""; can_mine = false; bites = 0; has_umb = false   # 먹던 빵도 떨어진다 — 남은 입은 없다; 우산도(접혀서)
	else:
		fig.action = "flinch"; fig.action_t = 0.0
		state = "busy"; busy_until = now + FightPoses.FLINCH_T
		velocity = from_dir * (push * 0.7 if push >= 0.0 else 2.2) + Vector3(0, maxf(lift, 0.0) * 0.5, 0)
		if hits == 2 or mind.temper > 0.7: say(mind.line("hurt"), 1.2)

## 날아가기(차에 치임) — 속도 그대로 포물선을 그리고, 닿으면 stun 초 동안 기절했다 일어난다
func launch(vel: Vector3, stun: float) -> void:
	if state == "drive": return   # 차 안의 운전사는 안 날아간다(hit 와 같은 규칙)
	velocity = vel
	down_until = Time.get_ticks_msec() / 1000.0 + stun
	say(mind.line("down"), 1.4)

## flinch 진행은 busy 상태에서 town 이 아니라 여기서 돌린다
func _process(_delta: float) -> void:
	if fig.action == "flinch":
		var now := Time.get_ticks_msec() / 1000.0
		fig.action_t = 1.0 - (busy_until - now) / FightPoses.FLINCH_T
		if now >= busy_until:
			fig.action = ""; fig.action_t = 0.0
			if quarry and state == "busy" and mind.retaliates():   # 성미·배짱이 정한다 — 전엔 누구나 반반
				state = "chase"; chase_until = now + 4.0
			elif state == "busy":
				state = "routine"; busy_until = now + 0.3
